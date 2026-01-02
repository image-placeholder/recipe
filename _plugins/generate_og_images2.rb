require 'fileutils'
require 'open3'
require 'parallel'
require 'etc'

module Jekyll
  class GenerateOgImages < Generator
    safe true
    priority :normal

     def generate(site)
      workers = [Etc.nprocessors - 1, 1].max
      og_folder = site.config['og_images_folder'] || 'assets/og-images'
      output_dir = File.join(site.source, og_folder)
      FileUtils.mkdir_p(output_dir)
    
      posts_to_process = (site.posts.docs + site.pages).reject do |post|
        post.content =~ /(?:src|href)=["']?(https?:\/\/[^"'\s]+\.(?:jpg|jpeg|png|gif|svg))/i || post.data['image']
      end
    
      # 1. GENERATE IMAGES IN PARALLEL
      # We don't try to update the 'post' object here.
      Parallel.each(posts_to_process, in_processes: workers) do |post|
        generate_image_file(post, site, output_dir, og_folder)
      end
    
      # 2. UPDATE METADATA IN SEQUENTIAL (MAIN PROCESS)
      # Now that files exist on disk, update the actual objects Jekyll uses.
      posts_to_process.each do |post|
        slug = normalize_slug(post.data['slug'] || post.data['title'])
        og_image_name = "#{slug}-og.png"
        relative_path = File.join('/', og_folder, og_image_name)
        
        # Update the post data so it persists in the main build
        post.data['image'] = relative_path
        
        # Ensure Jekyll knows this is a static file to be copied to _site
        site.static_files << Jekyll::StaticFile.new(site, site.source, og_folder, og_image_name)
      end
    end
    private

    def process_single_post(post, site, output_dir, og_folder)
      slug = normalize_slug(post.data['slug'] || post.data['title'])
      og_image_name = "#{slug}-og.png"
      og_image_path = File.join(output_dir, og_image_name)
      relative_path = File.join('/', og_folder, og_image_name)

      # Skip if exists and not empty
      if File.exist?(og_image_path) && File.size(og_image_path) > 0
        attach_to_post(post, site, og_folder, og_image_name, relative_path)
        return
      end
      template_path = site.config['og_template'] || '_includes/og-template.html'
      # Render HTML directly to a variable
      html_content = render_template(site, template_path, post, false)

      # 4. Pipe directly to wkhtmltoimage (Avoids temp file I/O)
      cmd = "wkhtmltoimage --width 1200 --height 630 --quality 85 - - " # Dash means stdin/stdout
      
      stdout, stderr, status = Open3.capture3(cmd, stdin_data: html_content)

      if status.success?
        File.binwrite(og_image_path, stdout)
        attach_to_post(post, site, og_folder, og_image_name, relative_path)
      end
    end

    def attach_to_post(post, site, og_folder, og_image_name, relative_path)
      # This needs to be handled carefully in parallel mode
      # Jekyll's site.static_files is not thread-safe; usually 
      # it's better to let Jekyll discover files naturally or add them in a final pass
      post.data['image'] = relative_path
    end

    def normalize_slug(text)
      text.to_s.downcase.strip.gsub(/[^a-z0-9]+/, '-')
    end
    
    def render_template(site, template_path, post, blogPost = true)
      template = File.read(File.join(site.source, template_path))
      liquid = Liquid::Template.parse(template)

      raw_excerpt = post.data['excerpt'] || post.content[0..150]
      excerpt_content = raw_excerpt.is_a?(Jekyll::Excerpt) ? raw_excerpt.to_s : raw_excerpt.to_s
      excerpt_content = "No preview available" if excerpt_content.strip.empty?

      payload = {
        'title' => post.data['title']&.strip || "Untitled",
        'site' => site.config
      }
      payload['excerpt'] = excerpt_content.strip if blogPost
      payload['date'] = post.date.strftime('%B %d, %Y') if blogPost && post.respond_to?(:date)

      liquid.render(payload)
    end
  end
end
