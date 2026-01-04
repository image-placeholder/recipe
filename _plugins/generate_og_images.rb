require 'grover'
require 'fileutils'
require 'parallel'
require 'thread'
require 'set'

module Jekyll
  class GenerateOgImages < Generator
    safe true
    priority :lowest

    def generate(site)
      Jekyll.logger.info "Starting Grover OG image generation..."

      @generated_og_images = Set.new
      @log_mutex = Mutex.new
      @static_mutex = Mutex.new

      @og_folder = site.config['og_images_folder'] || 'assets/og-images'
      @template_path = site.config['og_template'] || '_includes/og-template.html'
      @output_dir = File.join(site.source, @og_folder)

      # Ensure Directory and Permissions
      begin
        FileUtils.mkdir_p(@output_dir)
        FileUtils.chmod_R(0755, @output_dir)
        Jekyll.logger.info "OG image directory ensured: #{@output_dir}"
      rescue Errno::EACCES => e
        Jekyll.logger.error "Permission denied creating directory: #{e.message}"
        return
      end

      @grover_options = {
        format: 'png',
        viewport: { width: 1200, height: 630 },
        wait_until: 'networkidle0',
        root_path: Dir.pwd,
        launch_args: ['--no-sandbox', '--disable-setuid-sandbox', '--font-render-hinting=none']
      }

      posts_to_process = (site.posts.docs + site.pages).reject do |p| 
        p.data['image'] && !p.data['image'].include?(@og_folder)
      end

      Jekyll.logger.info "OG Generation:", "Processing #{posts_to_process.size} items..."

      Parallel.each(posts_to_process, in_threads: 4) do |post|
        process_post(site, post)
      end

      Jekyll.logger.info "Open Graph image generation complete."
    end

    private

    def process_post(site, post)
      slug = normalize_slug(post.data['slug'] || post.data['title'])
      image_name = "#{slug}-og.png"
      image_path = File.join(@output_dir, image_name)
      relative_path = File.join('/', @og_folder, image_name)

      return if @generated_og_images.include?(image_path)

      # Cache & Freshness Check
      if File.exist?(image_path) && File.size?(image_path).to_i > 0
        if post.path && File.exist?(post.path) && (File.mtime(image_path) > File.mtime(post.path))
          register_static_file(site, image_name)
          set_og_meta_tags(post, relative_path)
          @generated_og_images << image_path
          return
        end
      end

      template_full_path = File.join(site.source, @template_path)
      unless File.exist?(template_full_path)
        @log_mutex.synchronize { Jekyll.logger.error "Template not found: #{template_full_path}" }
        return
      end

      html_content = render_template(site, post)
      
      begin
        grover = Grover.new(html_content, **@grover_options)
        png = grover.to_png
        
        if png.nil? || png.empty?
          raise "Grover returned empty binary data"
        end

        File.binwrite(image_path, png)
        FileUtils.chmod(0644, image_path) # Ensure file is readable

        if verify_file(image_path)
          register_static_file(site, image_name)
          set_og_meta_tags(post, relative_path)
          @generated_og_images << image_path
          @log_mutex.synchronize { Jekyll.logger.info "Generated OG image: #{image_path}" }
        else
          raise "File verification failed for #{image_path}"
        end

      rescue => e
        @log_mutex.synchronize do
          Jekyll.logger.error "OG Image Error:", "Failed for #{slug}: #{e.message}"
        end
      end
    end

    def register_static_file(site, name)
      @static_mutex.synchronize do
        site.static_files << Jekyll::StaticFile.new(site, site.source, @og_folder, name)
      end
    end

    def render_template(site, post)
      template = File.read(File.join(site.source, @template_path))
      liquid = Liquid::Template.parse(template)

      raw_excerpt = post.data['excerpt'] || post.content[0..150]
      excerpt_content = raw_excerpt.to_s.strip
      excerpt_content = "No preview available" if excerpt_content.empty?

      payload = {
        'page' => post.data,
        'title' => post.data['title']&.strip || "Untitled",
        'site' => site.config,
        'excerpt' => excerpt_content,
        'date' => post.respond_to?(:date) ? post.date.strftime('%B %d, %Y') : nil
      }

      liquid.render(payload)
    end

    def verify_file(file_path)
      5.times do
        return true if File.exist?(file_path) && File.size?(file_path).to_i > 0
        sleep 0.5
      end
      false
    end

    def set_og_meta_tags(post, image_path)
      raw_excerpt = post.data['excerpt'] || post.content[0..150]
      excerpt_content = raw_excerpt.to_s.strip
      excerpt_content = "No preview available" if excerpt_content.empty?

      post.data['image'] = image_path
      post.data['og'] ||= {}
      post.data['og'].merge!({
        'image' => image_path,
        'type' => 'article',
        'title' => post.data['title']&.strip || "Untitled",
        'description' => excerpt_content
      })
    end

    def normalize_slug(text)
      text.to_s.downcase.strip.gsub(/\s+/, '-').gsub(/[^a-z0-9\-]/, '')
    end
  end
end
