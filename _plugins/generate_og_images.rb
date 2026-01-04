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

      begin
        FileUtils.mkdir_p(@output_dir)
        FileUtils.chmod_R(0755, @output_dir)
      rescue Errno::EACCES => e
        Jekyll.logger.error "OG Generation:", "Permission denied: #{e.message}"
        return
      end

      # Config for headless browser
      @grover_options = {
        format: 'png',
        viewport: { width: 1200, height: 630 },
        wait_until: 'domcontentloaded',
        root_path: Dir.pwd,
        launch_args: [
          '--no-sandbox',
          '--disable-setuid-sandbox',
          '--disable-dev-shm-usage',
          '--disable-gpu',
          '--no-first-run',
          '--no-zygote',
          '--single-process',
          '--font-render-hinting=none'
        ]
      }

      # Filter items
      items = (site.posts.docs + site.pages).reject do |p| 
        p.data['image'] && !p.data['image'].include?(@og_folder)
      end

      # Capture template content before forking
      template_full_path = File.join(site.source, @template_path)
      unless File.exist?(template_full_path)
        Jekyll.logger.error "OG Generation:", "Template missing at #{template_full_path}"
        return
      end
      
      template_raw_content = File.read(template_full_path)

      # Process in parallel processes
      results = Parallel.map(items, in_processes: Parallel.processor_count) do |item|
        process_item_in_fork(item, template_raw_content)
      end

      # Update the main site object with results
      results.compact.each do |result_data|
        item = result_data[:item_ref]
        image_name = result_data[:image_name]
        image_rel_path = result_data[:relative_path]

        register_static_file(site, image_name)
        set_og_meta_tags(item, image_rel_path)
      end

      Jekyll.logger.info "OG Generation:", "Processed #{items.size} items."
    end

    private

    def process_item_in_fork(item, template_raw)
      return nil if item.nil?

      slug = normalize_slug(item.data['slug'] || item.data['title'])
      image_name = "#{slug}-og.png"
      image_path = File.join(@output_dir, image_name)
      relative_path = File.join('/', @og_folder, image_name)

      # Freshness Check
      if File.exist?(image_path) && File.size?(image_path).to_i > 0
        if item.path && File.exist?(item.path) && (File.mtime(image_path) > File.mtime(item.path))
          return { item_ref: item, image_name: image_name, relative_path: relative_path }
        end
      end

      # Render Template
      html_content = render_template_content(item, template_raw)

      begin
        grover = Grover.new(html_content, **@grover_options)
        png = grover.to_png
        
        if png && !png.empty?
          File.binwrite(image_path, png)
          FileUtils.chmod(0644, image_path)
          return { item_ref: item, image_name: image_name, relative_path: relative_path }
        end
      rescue => e
        # Output to stdout because logger can behave weirdly in forks
        puts "OG Error for #{slug}: #{e.message}"
      end

      nil
    end

    def render_template_content(item, template_str)
      liquid = Liquid::Template.parse(template_str)

      # Defensive excerpt handling
      content_str = item.content.to_s
      raw_excerpt = item.data['excerpt'].to_s
      
      excerpt_content = raw_excerpt.empty? ? content_str[0..150] : raw_excerpt
      excerpt_content = excerpt_content.to_s.strip
      excerpt_content = "No preview available" if excerpt_content.empty?

      payload = {
        'page' => item.data,
        'title' => (item.data['title'] || "Untitled").to_s.strip,
        'excerpt' => excerpt_content,
        'date' => item.respond_to?(:date) && item.date ? item.date.strftime('%B %d, %Y') : nil
      }

      liquid.render(payload)
    end

    def register_static_file(site, name)
      site.static_files << Jekyll::StaticFile.new(site, site.source, @og_folder, name)
    end

    def set_og_meta_tags(item, image_path)
      content_str = item.content.to_s
      raw_excerpt = item.data['excerpt'].to_s
      excerpt_content = raw_excerpt.empty? ? content_str[0..150] : raw_excerpt
      excerpt_content = excerpt_content.to_s.strip

      item.data['image'] = image_path
      item.data['og'] ||= {}
      item.data['og'].merge!({
        'image' => image_path,
        'type' => 'article',
        'title' => (item.data['title'] || "Untitled").to_s.strip,
        'description' => excerpt_content
      })
    end

    def normalize_slug(text)
      text.to_s.downcase.strip.gsub(/\s+/, '-').gsub(/[^a-z0-9\-]/, '')
    end
  end
end
