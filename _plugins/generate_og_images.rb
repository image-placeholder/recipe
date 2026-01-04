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

      # Ensure Directory
      begin
        FileUtils.mkdir_p(@output_dir)
        FileUtils.chmod_R(0755, @output_dir)
      rescue Errno::EACCES => e
        Jekyll.logger.error "OG Generation:", "Permission denied: #{e.message}"
        return
      end

      # Optimized Grover Options for Speed and Low RAM
      @grover_options = {
        format: 'png',
        viewport: { width: 1200, height: 630 },
        wait_until: 'domcontentloaded', # Faster than networkidle0
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

      items = (site.posts.docs + site.pages).reject do |p| 
        p.data['image'] && !p.data['image'].include?(@og_folder)
      end

      # Parallel processing with Processes instead of Threads
      # We return the data needed to update the site object since forks can't modify the parent memory
      results = Parallel.map(items, in_processes: Parallel.processor_count) do |item|
        process_item_in_fork(site.source, item)
      end

      # Back in the main process: Register files and update metadata
      results.compact.each do |result_data|
        item = result_data[:item_ref]
        image_name = result_data[:image_name]
        image_path = result_data[:relative_path]

        register_static_file(site, image_name)
        set_og_meta_tags(item, image_path)
      end

      Jekyll.logger.info "OG Generation:", "Complete."
    end

    private

    def process_item_in_fork(site_source, item)
      slug = normalize_slug(item.data['slug'] || item.data['title'])
      image_name = "#{slug}-og.png"
      image_path = File.join(@output_dir, image_name)
      relative_path = File.join('/', @og_folder, image_name)

      # 1. Immediate Freshness Check (Speed Boost)
      if File.exist?(image_path) && File.size?(image_path).to_i > 0
        if item.path && File.exist?(item.path) && (File.mtime(image_path) > File.mtime(item.path))
          return { item_ref: item, image_name: image_name, relative_path: relative_path }
        end
      end

      # 2. Render Template
      template_full_path = File.join(site_source, @template_path)
      return nil unless File.exist?(template_full_path)

      html_content = render_template_content(site_source, item)

      # 3. Generate Image
      begin
        grover = Grover.new(html_content, **@grover_options)
        png = grover.to_png
        
        if png && !png.empty?
          File.binwrite(image_path, png)
          FileUtils.chmod(0644, image_path)
          return { item_ref: item, image_name: image_name, relative_path: relative_path }
        end
      rescue => e
        # Minimal logging in forks to avoid IO congestion
        puts "OG Error for #{slug}: #{e.message}"
      end

      nil
    end

    def register_static_file(site, name)
      site.static_files << Jekyll::StaticFile.new(site, site.source, @og_folder, name)
    end

    def render_template_content(site_source, item)
      template_content = File.read(File.join(site_source, @template_path))
      liquid = Liquid::Template.parse(template_raw)

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

    def set_og_meta_tags(item, image_path)
      raw_excerpt = item.data['excerpt'] || item.content[0..150]
      excerpt_content = raw_excerpt.to_s.strip
      excerpt_content = "No preview available" if excerpt_content.empty?

      item.data['image'] = image_path
      item.data['og'] ||= {}
      item.data['og'].merge!({
        'image' => image_path,
        'type' => 'article',
        'title' => item.data['title']&.strip || "Untitled",
        'description' => excerpt_content
      })
    end

    def normalize_slug(text)
      text.to_s.downcase.strip.gsub(/\s+/, '-').gsub(/[^a-z0-9\-]/, '')
    end
  end
end
