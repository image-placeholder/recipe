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
      
      posts = (site.posts.docs + site.pages).reject { |p| p.data['image'] }

      # Grover configuration (Optimized for speed)
      @grover_options = {
        format: 'png',
        viewport: { width: 1200, height: 630 },
        display_url: site.config['url'],
        launch_args: ['--no-sandbox', '--disable-setuid-sandbox']
      }

      Jekyll.logger.info "OG Generation:", "Capturing HTML for #{posts.size} items..."

      # Use threads so we can talk to the browser driver concurrently
      Parallel.each(posts, in_threads: 4) do |post|
        process_post(site, post)
      end
    end

    def process_post(site, post)
      slug = post.data['slug'] || post.data['title'].to_s.downcase.gsub(/[^a-z0-9]+/, '-')
      image_path = File.join(@output_dir, "#{slug}-og.png")
      
      return if File.exist?(image_path)

      html = render_liquid(site, post)
      
      # Grover captures the HTML string directly
      grover = Grover.new(html, @grover_options)
      png = grover.to_png
      
      File.binwrite(image_path, png)
      post.data['image'] = File.join('/', @og_folder, "#{slug}-og.png")
    end

    def render_liquid(site, post)
      template_content = File.read(@template_path)
      payload = { 
        'page' => post.data, 
        'site' => site.config,
        'title' => post.data['title']
      }
      Liquid::Template.parse(template_content).render(payload)
    end
  end
end
