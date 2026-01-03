require 'fileutils'
require 'open3'
require 'set'
require 'tmpdir'
require 'parallel'

module Jekyll
  class GenerateOgImages < Generator
    safe true
    priority :normal

    def generate(site)
      workers = [Etc.nprocessors - 1, 1].max
      Jekyll.logger.info "Starting Open Graph image generation..."

      @generated_og_images = Set.new

      og_folder = site.config['og_images_folder'] || 'assets/og-images'
      template_path = site.config['og_template'] || '_includes/og-template.html'
      output_dir = File.join(site.source, og_folder)

      begin
        FileUtils.mkdir_p(output_dir)
        FileUtils.chmod_R(0755, output_dir)
        Jekyll.logger.info "OG image directory ensured: #{output_dir}"
      rescue Errno::EACCES => e
        Jekyll.logger.error "Permission denied creating directory: #{e.message}"
        return
      end

      unless system('wkhtmltoimage --version >/dev/null 2>&1')
        Jekyll.logger.error "wkhtmltoimage not found. Please install it (e.g., 'brew install wkhtmltopdf')."
        return
      end

      # Parallelize post processing
      posts_to_process = site.posts.docs + site.pages
      Parallel.each(posts_to_process, in_threads: 4) do |post|
        process_post(post, site, output_dir, og_folder, template_path)
      end

      Jekyll.logger.info "Open Graph image generation complete."
    end

    private

    def process_post(post, site, output_dir, og_folder, template_path, blogPost = true)
      has_image = post.content =~ /(?:src|href)=["']?(https?:\/\/[^"'\s]+\.(?:jpg|jpeg|png|gif|svg))/i || post.data['image']
      return if has_image

      slug = normalize_slug(post.data['slug'] || post.data['title'])
      og_image_name = "#{slug}-og.png"
      og_image_path = File.join(output_dir, og_image_name)
      relative_path = File.join('/', og_folder, og_image_name)

      return if @generated_og_images.include?(og_image_path)

      if File.exist?(og_image_path) && File.size?(og_image_path).to_i > 0
        Jekyll.logger.info "OG image already exists, skipping: #{og_image_path}"
        site.static_files << Jekyll::StaticFile.new(site, site.source, og_folder, og_image_name)
        set_og_meta_tags(post, relative_path)
        @generated_og_images << og_image_path
        return
      end

      template_full_path = File.join(site.source, template_path)
      unless File.exist?(template_full_path)
        Jekyll.logger.error "Template not found: #{template_full_path}"
        return
      end

      html_content = render_template(site, template_path, post, blogPost)
      temp_html = File.join(Dir.tmpdir, "#{slug}-og-#{Time.now.to_i}.html")

      begin
        File.write(temp_html, html_content)

        if generate_image(temp_html, og_image_path) && verify_file(og_image_path)
          site.static_files << Jekyll::StaticFile.new(site, site.source, og_folder, og_image_name)
          set_og_meta_tags(post, relative_path)
          @generated_og_images << og_image_path
        else
          Jekyll.logger.error "Image generation failed: #{og_image_path}"
        end
      rescue => e
        Jekyll.logger.error "Error processing post #{post.path}: #{e.message}"
      ensure
        File.delete(temp_html) if File.exist?(temp_html)
      end
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

    def generate_image(html_file, output_path)
      FileUtils.mkdir_p(File.dirname(output_path))
      FileUtils.chmod(0755, File.dirname(output_path))

      cmd = "wkhtmltoimage --width 1200 --height 630 --quality 85 '#{html_file}' '#{output_path}'"
      stdout, stderr, status = Open3.capture3(cmd)

      if status.success?
        Jekyll.logger.info "Generated OG image: #{output_path}"
        true
      else
        Jekyll.logger.error "wkhtmltoimage failed: #{stderr.strip}"
        false
      end
    end

    def verify_file(file_path)
      5.times do |i|
        if File.exist?(file_path) && File.size?(file_path).to_i > 0
          return true
        else
          sleep 0.5
        end
      end
      false
    end

    def set_og_meta_tags(post, image_path)
      raw_excerpt = post.data['excerpt'] || post.content[0..150]
      excerpt_content = raw_excerpt.is_a?(Jekyll::Excerpt) ? raw_excerpt.to_s : raw_excerpt.to_s
      excerpt_content = "No preview available" if excerpt_content.strip.empty?

      post.data['og'] ||= {}
      post.data['image'] = image_path
      post.data['og'].merge!({
        'image' => image_path,
        'type' => 'article',
        'title' => post.data['title']&.strip || "Untitled",
        'description' => excerpt_content.strip
      })
    end

    def normalize_slug(text)
      text.to_s.downcase.strip.gsub(/\s+/, '-').gsub(/[^a-z0-9\-]/, '')
    end
  end
end
