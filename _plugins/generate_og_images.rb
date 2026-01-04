require 'grover'
require 'fileutils'
require 'parallel'
require 'set'

module Jekyll
  class GenerateOgImages < Generator
    safe true
    priority :lowest

    def generate(site)
      Jekyll.logger.info "OG Generation:", "Starting optimized Grover process..."

      @og_folder = site.config['og_images_folder'] || 'assets/og-images'
      @template_path = site.config['og_template'] || '_includes/og-template.html'
      @output_dir = File.join(site.source, @og_folder)

      # Directory setup
      FileUtils.mkdir_p(@output_dir) unless Dir.exist?(@output_dir)

      @grover_options = {
        format: 'png',
        viewport: { width: 1200, height: 630 },
        wait_until: 'domcontentloaded',
        root_path: Dir.pwd,
        launch_args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage', '--disable-gpu', '--single-process']
      }

      # We map items to a simple hash to avoid Marshal errors
      items = (site.posts.docs + site.pages).reject do |p| 
        p.data['image'] && !p.data['image'].include?(@og_folder)
      end

      template_full_path = File.join(site.source, @template_path)
      return unless File.exist?(template_full_path)
      template_raw = File.read(template_full_path)

      # Convert Jekyll objects to simple data hashes for the fork
      processing_queue = items.map do |item|
        {
          'id' => item.url,
          'path' => item.path,
          'title' => item.data['title'].to_s,
          'slug' => item.data['slug'].to_s,
          'content' => item.content.to_s[0..500], # Pass snippet only
          'excerpt' => item.data['excerpt'].to_s,
          'date' => item.respond_to?(:date) && item.date ? item.date.strftime('%B %d, %Y') : nil,
          'data' => item.data.transform_values(&:to_s) # Ensure strings
        }
      end

      # Run Parallel Processes
      # Return ONLY simple strings/hashes to avoid "can't dump" errors
      results = Parallel.map(processing_queue, in_processes: Parallel.processor_count) do |item_data|
        process_in_fork(item_data, template_raw)
      end

      # Main Process: Update the actual Jekyll objects
      results.compact.each do |res|
        original_item = items.find { |i| i.url == res[:id] }
        next unless original_item

        register_static_file(site, res[:image_name])
        set_og_meta_tags(original_item, res[:relative_path])
      end

      Jekyll.logger.info "OG Generation:", "Finished 1000s of pages."
    end

    private

    def process_in_fork(item_data, template_raw)
      slug = normalize_slug(item_data['slug'].empty? ? item_data['title'] : item_data['slug'])
      image_name = "#{slug}-og.png"
      image_path = File.join(@output_dir, image_name)
      relative_path = File.join('/', @og_folder, image_name)

      # Cache Check
      if File.exist?(image_path) && File.size?(image_path).to_i > 0
        if item_data['path'] && File.exist?(item_data['path'])
          return { id: item_data['id'], image_name: image_name, relative_path: relative_path } if File.mtime(image_path) > File.mtime(item_data['path'])
        end
      end

      # Render
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
        'page' => item_data['data'],
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
