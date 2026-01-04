require 'grover'
require 'fileutils'
require 'parallel'

module Jekyll
  class GenerateOgImages < Generator
    safe true
    priority :high # Run late to ensure front matter is already processed by other plugins

    def generate(site)
      @og_folder = site.config['og_images_folder'] || 'assets/og-images'
      @template_path = site.config['og_template'] || '_includes/og-template.html'
      @output_dir = File.join(site.source, @og_folder)

      # Ensure directory exists
      FileUtils.mkdir_p(@output_dir)

      template_full_path = File.join(site.source, @template_path)
      return unless File.exist?(template_full_path)
      
      template_raw = File.read(template_full_path)
      template_mtime = File.mtime(template_full_path).to_i

      @grover_options = {
        format: 'png',
        viewport: { width: 1200, height: 630 },
        wait_until: 'domcontentloaded',
        root_path: Dir.pwd,
        launch_args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage', '--disable-gpu', '--single-process']
      }

      all_items = (site.posts.docs + site.pages).reject { |p| p.data['og_skip'] }

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

      return if items_to_process.empty?

      Jekyll.logger.info "OG Generation:", "Processing #{items_to_process.size} images..."

      # Sanitize config for Parallel processing
      sanitized_config = site.config.each_with_object({}) { |(k, v), h| h[k.to_s] = v unless v.is_a?(Proc) }

      processing_queue = items_to_process.map do |item|
        {
          'id' => item.url,
          'image_path' => File.join(@output_dir, "#{normalize_slug(item.data['slug'] || item.data['rendered_title'])}-og.png"),
          'title' => item.data['rendered_title'],
          'content' => item.content.to_s[0..500],
          'excerpt' => item.data['excerpt'].to_s,
          'page_data' => item.data.transform_values { |v| v.is_a?(Proc) ? nil : v },
          'site_config' => sanitized_config
        }
      end

      Parallel.each(processing_queue, in_processes: Parallel.processor_count) do |item_data|
        html = render_liquid(item_data, template_raw)
        begin
          png = Grover.new(html, **@grover_options).to_png
          File.binwrite(item_data['image_path'], png)
        rescue => e
          Jekyll.logger.error "OG Error:", "Grover failed for #{item_data['id']}: #{e.message}"
        end
      end
    end

    private

    # Helper to render Liquid inside front matter strings (like titles)
    def render_string(str, item, site)
      return str unless str.include?('{{')
      template = Liquid::Template.parse(str)
      template.render(site.site_payload.merge("page" => item.data))
    end

    def render_liquid(item_data, template_str)
      liquid = Liquid::Template.parse(template_str)
      payload = {
        'page' => item_data['page_data'],
        'site' => item_data['site_config'],
        'title' => item_data['title'],
        'excerpt' => item_data['excerpt'].empty? ? item_data['content'][0..150] : item_data['excerpt']
      }
      liquid.render(payload)
    end

    def register_static_file(site, name)
      site.static_files << Jekyll::StaticFile.new(site, site.source, @og_folder, name)
    end

    def set_og_meta_tags(item, image_path)
      item.data['image'] = image_path
      item.data['og_image'] = image_path # Useful for some SEO plugins
    end

    def normalize_slug(text)
      text.to_s.downcase.strip.gsub(/\s+/, '-').gsub(/[^a-z0-9\-]/, '')
    end
  end
end
