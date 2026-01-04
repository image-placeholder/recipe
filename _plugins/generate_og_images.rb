require 'grover'
require 'fileutils'
require 'parallel'
require 'set'

module Jekyll
  class GenerateOgImages < Generator
    safe true
    priority :lowest

    def generate(site)
      @og_folder = site.config['og_images_folder'] || 'assets/og-images'
      @template_path = site.config['og_template'] || '_includes/og-template.html'
      @output_dir = File.join(site.source, @og_folder)

      # 1. Template Freshness Check - Direct from Disk
      template_full_path = File.expand_path(@template_path, site.source)
      
      unless File.exist?(template_full_path)
        Jekyll.logger.warn "OG Generation:", "Template not found at #{template_full_path}"
        return
      end

      template_raw = File.read(template_full_path)
      # We get the mtime directly from the OS to ensure it's not cached
      template_mtime = File.mtime(template_full_path).to_i

      @grover_options = {
        format: 'png',
        viewport: { width: 1200, height: 630 },
        wait_until: 'domcontentloaded',
        root_path: Dir.pwd,
        launch_args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage', '--disable-gpu', '--single-process']
      }

      FileUtils.mkdir_p(@output_dir) unless Dir.exist?(@output_dir)

      # 2. Filter items: Determine which items actually need processing
      all_items = (site.posts.docs + site.pages).reject do |p| 
        p.data['image'] && !p.data['image'].include?(@og_folder)
      end

      items_to_process = all_items.select do |item|
        slug = normalize_slug(item.data['slug'] || item.data['title'])
        image_name = "#{slug}-og.png"
        image_path = File.join(@output_dir, image_name)

        # Get image mtime (0 if it doesn't exist)
        image_mtime = File.exist?(image_path) ? File.mtime(image_path).to_i : 0
        
        # Get source file mtime
        source_path = item.path ? File.expand_path(item.path, site.source) : nil
        source_mtime = (source_path && File.exist?(source_path)) ? File.mtime(source_path).to_i : 0

        # REGENERATION LOGIC
        # We use a 1-second buffer. If Template or Source is >= Image, we rebuild.
        needs_update = false
        if image_mtime == 0
          needs_update = true
        elsif template_mtime > image_mtime
          needs_update = true
        elsif source_mtime > image_mtime
          needs_update = true
        end
        
        if needs_update
          true
        else
          # If no update needed, register the existing file so Jekyll doesn't delete it
          register_static_file(site, image_name)
          set_og_meta_tags(item, File.join('/', @og_folder, image_name))
          false
        end
      end

      if items_to_process.empty?
        Jekyll.logger.info "OG Generation:", "No changes detected in template or content. Skipping."
        return
      end

      Jekyll.logger.info "OG Generation:", "Changes detected! Regenerating #{items_to_process.size} images..."

      # 3. Process the queue
      sanitized_config = site.config.each_with_object({}) { |(k, v), h| h[k.to_s] = v.is_a?(Proc) ? nil : v }

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

      # 4. Finalize registration
      results.compact.each do |res|
        original_item = all_items.find { |i| i.url == res[:id] }
        next unless original_item
        register_static_file(site, res[:image_name])
        set_og_meta_tags(original_item, res[:relative_path])
      end

      Jekyll.logger.info "OG Generation:", "Finished."
    end

    private

    def process_in_fork(item_data, template_raw)
      slug = normalize_slug(item_data['slug'].empty? ? item_data['title'] : item_data['slug'])
      image_name = "#{slug}-og.png"
      image_path = File.join(@output_dir, image_name)
      relative_path = File.join('/', @og_folder, image_name)

      html = render_liquid(item_data, template_raw)

      begin
        grover = Grover.new(html, **@grover_options)
        png = grover.to_png
        if png
          File.binwrite(image_path, png)
          { id: item_data['id'], image_name: image_name, relative_path: relative_path }
        end
      rescue => e
        puts "Grover Error: #{e.message}"
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
