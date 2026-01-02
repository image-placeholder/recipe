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
      
      # Ensure output directory exists
      FileUtils.mkdir_p(@output_dir)
      
      # Filter posts/pages that don't already have a manual image assigned
      posts = (site.posts.docs + site.pages).reject { |p| p.data['image'] }

      # Grover configuration: networkidle0 is key for Tailwind CDN to finish processing
      @grover_options = {
        format: 'png',
        viewport: { width: 1200, height: 630 },
        wait_until: 'networkidle0',
        root_path: Dir.pwd,
        launch_args: ['--no-sandbox', '--disable-setuid-sandbox', '--font-render-hinting=none']
      }

      Jekyll.logger.info "OG Generation:", "Checking #{posts.size} items..."

      # Use threads to allow concurrent browser rendering
      Parallel.each(posts, in_threads: 4) do |post|
        process_post(site, post)
      end
    end

    def process_post(site, post)
      # 1. Generate unique filename and paths
      slug = post.data['slug'] || post.data['title'].to_s.downcase.gsub(/[^a-z0-9]+/, '-')
      image_name = "#{slug}-og.png"
      image_path = File.join(@output_dir, image_name)
      relative_path = File.join('/', @og_folder, image_name)

      # 2. CACHE CHECK: Only generate if the post has been modified since the image was last created
      # This makes incremental builds nearly instant.
      if File.exist?(image_path) && post.path && File.exist?(post.path)
        return if File.mtime(image_path) > File.mtime(post.path)
      end

      # 3. Render the HTML using Liquid
      html = render_liquid(site, post)
      
      # 4. Capture with Grover
      begin
        # Use ** to pass options as keyword arguments (Fixes ArgumentError)
        grover = Grover.new(html, **@grover_options)
        png = grover.to_png
        
        File.binwrite(image_path, png)
        post.data['image'] = relative_path
        Jekyll.logger.info "OG Image:", "Generated #{image_name}"
      rescue => e
        Jekyll.logger.error "OG Image Error:", "Failed for #{slug}: #{e.message}"
      end
    end

    private

    def render_liquid(site, post)
      unless File.exist?(@template_path)
        Jekyll.logger.error "OG Image:", "Template missing at #{@template_path}"
        return ""
      end

      template_content = File.read(@template_path)
      
      # Prepare the payload for Liquid
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
