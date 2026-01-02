# Force Node to find puppeteer in your local project folder
ENV['NODE_PATH'] = File.expand_path('node_modules', Dir.pwd)

require 'grover'
require 'fileutils'
require 'parallel'

module Jekyll
  class GenerateOgImages < Generator
    safe true
    priority :normal

    def generate(site)
      @og_folder = site.config['og_images_folder'] || 'assets/og-images'
      @output_dir = File.join(site.source, @og_folder)
      @template_path = File.join(site.source, site.config['og_template'] || '_includes/og-template.html')
      
      FileUtils.mkdir_p(@output_dir)
      
      # Filter items. We process if they don't have an image OR if that image is one we generated
      posts = (site.posts.docs + site.pages).reject do |p| 
        p.data['image'] && !p.data['image'].include?(@og_folder)
      end

      @grover_options = {
        format: 'png',
        viewport: { width: 1200, height: 630 },
        wait_until: 'networkidle0',
        launch_args: ['--no-sandbox', '--disable-setuid-sandbox', '--font-render-hinting=none']
      }

      Jekyll.logger.info "OG Generation:", "Checking #{posts.size} items..."

      # Using threads for browser concurrency
      Parallel.each(posts, in_threads: 4) do |post|
        process_post(site, post)
      end
    end

    def process_post(site, post)
      slug = post.data['slug'] || post.data['title'].to_s.downcase.gsub(/[^a-z0-9]+/, '-')
      image_name = "#{slug}-og.png"
      image_path = File.join(@output_dir, image_name)
      relative_path = File.join('/', @og_folder, image_name)

      # 1. CACHE CHECK: Skip generation if image is newer than source
      is_fresh = File.exist?(image_path) && post.path && File.exist?(post.path) && (File.mtime(image_path) > File.mtime(post.path))

      if is_fresh
        register_static_file(site, image_name)
        post.data['image'] = relative_path
        return
      end

      # 2. GENERATE: Only if cache check fails
      html = render_liquid(site, post)
      
      begin
        grover = Grover.new(html, **@grover_options)
        png = grover.to_png
        
        File.binwrite(image_path, png)
        
        # 3. REGISTER: Tell Jekyll to include this file in the build
        register_static_file(site, image_name)
        
        post.data['image'] = relative_path
        Jekyll.logger.info "OG Image:", "Generated #{image_name}"
      rescue => e
        Jekyll.logger.error "OG Image Error:", "Failed for #{slug}: #{e.message}"
      end
    end

    private

    def register_static_file(site, name)
      # This ensures the file is copied to _site/assets/og-images/
      site.static_files << Jekyll::StaticFile.new(site, site.source, @og_folder, name)
    end

    def render_liquid(site, post)
      return "" unless File.exist?(@template_path)
      
      template_content = File.read(@template_path)
      payload = { 
        'page' => post.data, 
        'site' => site.config,
        'title' => post.data['title'],
        'date' => post.respond_to?(:date) ? post.date : nil
      }
      
      Liquid::Template.parse(template_content).render(payload)
    end
  end
end
