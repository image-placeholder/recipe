require 'grover'
require 'fileutils'
require 'parallel'
require 'set'

module Jekyll
  class GenerateOgImages < Generator
    safe true
    priority :high

    def generate(site)
      Jekyll.logger.info "OG Generation:", "Starting optimized Grover process..."

      @og_folder = site.config['og_images_folder'] || 'assets/og-images'
      @template_path = site.config['og_template'] || '_includes/og-template.html'
      @output_dir = File.join(site.source, @og_folder)

      FileUtils.mkdir_p(@output_dir) unless Dir.exist?(@output_dir)

      # 1. Template Freshness Check
      template_full_path = File.join(site.source, @template_path)
      return unless File.exist?(template_full_path)
      template_raw = File.read(template_full_path)
      template_mtime = File.mtime(template_full_path)

      @grover_options = {
        format: 'png',
        viewport: { width: 1200, height: 630 },
        wait_until: 'domcontentloaded',
        root_path: Dir.pwd,
        launch_args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage', '--disable-gpu', '--single-process']
      }

      # 2. Filter items: Only process if incremental is OFF OR if the file actually needs an update
      all_items = (site.posts.docs + site.pages).reject do |p| 
        p.data['image'] && !p.data['image'].include?(@og_folder)
      end

      # Determine which items actually need processing
      items_to_process = all_items.select do |item|
        # 1. PRE-RENDER the title in case it contains Liquid like {{ site.title }}
        rendered_title = render_string(item.data['title'].to_s, item, site)
        item.data['rendered_title'] = rendered_title # Save for the fork
        
        slug = normalize_slug(item.data['slug'] || rendered_title)
        image_name = "#{slug}-og.png"
        image_path = File.join(@output_dir, image_name)
        
        source_path = item.path ? File.expand_path(item.path, site.source) : nil
        image_exists = File.exist?(image_path) && File.size(image_path) > 0
        
        # 2. BETTER FRESHNESS CHECK
        needs_update = false
        if !image_exists
          needs_update = true
        else
          image_mtime = File.mtime(image_path).to_i
          # Update if template changed
          needs_update = true if template_mtime > image_mtime
          # Update if source file changed (using 1s buffer for precision)
          needs_update = true if source_path && File.exist?(source_path) && File.mtime(source_path).to_i > image_mtime
        end

        # Always register and set tags, whether we generate now or use cache
        register_static_file(site, image_name)
        set_og_meta_tags(item, File.join('/', @og_folder, image_name))

        needs_update
      end

      if items_to_process.empty?
        Jekyll.logger.info "OG Generation:", "Everything up to date. Skipping."
        return
      end

      Jekyll.logger.info "OG Generation:", "Regenerating #{items_to_process.size} items..."

      # 3. Sanitize site config
      sanitized_config = site.config.each_with_object({}) do |(k, v), h|
        h[k.to_s] = v.is_a?(Proc) ? nil : v
      end

      # 4. Prepare only the items that need updates
      processing_queue = items_to_process.map do |item|
        {
          'id' => item.url,
          'path' => item.path,
          'title' => item.data['title'].to_s,
          'slug' => item.data['slug'].to_s,
          'content' => item.content.to_s[0..500],
          'excerpt' => item.data['excerpt'].to_s,
          'date' => item.respond_to?(:date) && item.date ? item.date.strftime('%B %d, %Y') : nil,
          'page_data' => item.data.transform_values { |v| v.is_a?(Proc) ? nil : v },
          'site_config' => sanitized_config
        }
      end

      results = Parallel.map(processing_queue, in_processes: Parallel.processor_count) do |item_data|
        process_in_fork(item_data, template_raw)
      end

      # 5. Finalize the newly generated items
      results.compact.each do |res|
        original_item = all_items.find { |i| i.url == res[:id] }
        next unless original_item

        register_static_file(site, res[:image_name])
        set_og_meta_tags(original_item, res[:relative_path])
      end

      Jekyll.logger.info "OG Generation:", "Finished processing."
    end

    private

    def process_in_fork(item_data, template_raw)
      slug = normalize_slug(item_data['slug'].empty? ? item_data['title'] : item_data['slug'])
      image_name = "#{slug}-og.png"
      image_path = File.join(@output_dir, image_name)
      relative_path = File.join('/', @og_folder, image_name)

      # Freshness Check
      if File.exist?(image_path) && File.size?(image_path).to_i > 0
        if item_data['path'] && File.exist?(item_data['path'])
          if File.mtime(image_path) > File.mtime(item_data['path'])
            return { id: item_data['id'], image_name: image_name, relative_path: relative_path }
          end
        end
      end

      html = render_liquid(item_data, template_raw)

      begin
        grover = Grover.new(html, **@grover_options)
        png = grover.to_png
        if png
          File.binwrite(image_path, png)
          { id: item_data['id'], image_name: image_name, relative_path: relative_path }
        end
      rescue => e
        puts "Grover Error for #{item_data['id']}: #{e.message}"
        nil
      end
    end

    def render_liquid(item_data, template_str)
      liquid = Liquid::Template.parse(template_str)
      excerpt = item_data['excerpt'].empty? ? item_data['content'][0..150] : item_data['excerpt']
      
      payload = {
        'page' => item_data['page_data'],
        'site' => item_data['site_config'],
        'title' => item_data['title'],
        'excerpt' => excerpt.to_s.strip,
        'date' => item_data['date']
      }
      liquid.render(payload)
    end

    def register_static_file(site, name)
      site.static_files << Jekyll::StaticFile.new(site, site.source, @og_folder, name)
    end

    def set_og_meta_tags(item, image_path)
      item.data['image'] = image_path
      item.data['og'] ||= {}
      item.data['og']['image'] = image_path
    end

    def normalize_slug(text)
      text.to_s.downcase.strip.gsub(/\s+/, '-').gsub(/[^a-z0-9\-]/, '')
    end
  end
end
