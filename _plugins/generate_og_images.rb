require 'grover'
require 'fileutils'
require 'parallel'
require 'digest'

module Jekyll
  class GenerateOgImages < Generator
    safe true
    priority :lowest

    def generate(site)
      @og_folder = site.config['og_images_folder'] || 'assets/og-images'
      @template_path = site.config['og_template'] || '_includes/og-template.html'
      @output_dir = File.join(site.source, @og_folder)
      FileUtils.mkdir_p(@output_dir) unless Dir.exist?(@output_dir)

      # 1. Template Hashing (The "Nuclear" Option for Freshness)
      template_full_path = File.expand_path(@template_path, site.source)
      return unless File.exist?(template_full_path)

      template_raw = File.read(template_full_path)
      # Create a unique fingerprint of the template content
      current_template_hash = Digest::MD5.hexdigest(template_raw)
      
      # We store the hash in a hidden file to compare against previous runs
      hash_file = File.join(@output_dir, '.template_hash')
      old_template_hash = File.exist?(hash_file) ? File.read(hash_file).strip : nil
      
      template_changed = (current_template_hash != old_template_hash)

      if template_changed
        Jekyll.logger.info "OG Generation:", "Template change detected (Hash mismatch). Forcing full rebuild."
      end

      @grover_options = {
        format: 'png',
        viewport: { width: 1200, height: 630 },
        wait_until: 'domcontentloaded',
        root_path: Dir.pwd,
        launch_args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage', '--disable-gpu', '--single-process']
      }

      all_items = (site.posts.docs + site.pages).reject do |p| 
        p.data['image'] && !p.data['image'].include?(@og_folder)
      end

      items_to_process = all_items.select do |item|
        slug = normalize_slug(item.data['slug'] || item.data['title'])
        image_name = "#{slug}-og.png"
        image_path = File.join(@output_dir, image_name)
        
        # Freshness Logic
        image_exists = File.exist?(image_path)
        source_path = item.path ? File.expand_path(item.path, site.source) : nil
        source_newer = source_path && File.exist?(source_path) && (File.mtime(source_path) > File.mtime(image_path)) rescue false

        needs_update = !image_exists || template_changed || source_newer

        if needs_update
          true
        else
          register_static_file(site, image_name)
          set_og_meta_tags(item, File.join('/', @og_folder, image_name))
          false
        end
      end

      if items_to_process.empty?
        Jekyll.logger.info "OG Generation:", "Everything up to date."
        return
      end

      Jekyll.logger.info "OG Generation:", "Processing #{items_to_process.size} images..."

      # Prepare Queue
      sanitized_config = site.config.each_with_object({}) { |(k, v), h| h[k.to_s] = v.is_a?(Proc) ? nil : v }
      processing_queue = items_to_process.map do |item|
        {
          'id' => item.url,
          'title' => item.data['title'].to_s,
          'slug' => item.data['slug'].to_s,
          'content' => item.content.to_s[0..500],
          'excerpt' => item.data['excerpt'].to_s,
          'date' => item.respond_to?(:date) && item.date ? item.date.strftime('%B %d, %Y') : nil,
          'page_data' => item.data.transform_values { |v| v.is_a?(Proc) ? nil : v },
          'site_config' => sanitized_config
        }
      end

      # Run Grover
      results = Parallel.map(processing_queue, in_processes: Parallel.processor_count) do |item_data|
        process_in_fork(item_data, template_raw)
      end

      # Save the new hash after successful generation
      File.write(hash_file, current_template_hash)

      # Register Results
      results.compact.each do |res|
        original_item = all_items.find { |i| i.url == res[:id] }
        next unless original_item
        register_static_file(site, res[:image_name])
        set_og_meta_tags(original_item, res[:relative_path])
      end

      Jekyll.logger.info "OG Generation:", "Finished."
    end

    private

    def process_in_fork(item_data, template_raw)
      slug = normalize_slug(item_data['slug'].empty? ? item_data['title'] : item_data['slug'])
      image_name = "#{slug}-og.png"
      image_path = File.join(@output_dir, image_name)
      relative_path = File.join('/', @og_folder, image_name)

      html = render_liquid(item_data, template_raw)

      begin
        grover = Grover.new(html, **@grover_options)
        png = grover.to_png
        File.binwrite(image_path, png) if png
        { id: item_data['id'], image_name: image_name, relative_path: relative_path }
      rescue => e
        puts "Grover Error: #{e.message}"
        nil
      end
    end

    def render_liquid(item_data, template_str)
      liquid = Liquid::Template.parse(template_str)
      excerpt = item_data['excerpt'].empty? ? item_data['content'][0..150] : item_data['excerpt']
      payload = {
        'page' => item_data['page_data'],
        'site' => item_data['site_config'],
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
