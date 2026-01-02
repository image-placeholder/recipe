require 'yaml'

module Jekyll
  class FileReadTag < Liquid::Tag
    @@cache = {}

    def initialize(tag_name, text, tokens)
      super
      @file_path = text.strip
    end

    def render(context)
      # Check cache first
      return @@cache[@file_path] if @@cache.key?(@file_path)

      site = context.registers[:site]
      
      # 1. Look for the file in site.pages (for files with Front Matter) 
      # or site.static_files (for raw assets)
      target_file = site.pages.find { |p| p.path == @file_path } || 
                    site.static_files.find { |f| f.relative_path == @file_path }

      if target_file
        # Grab the output if it's already generated, otherwise read the raw content
        # .output is usually populated after minification/processing
        content = target_file.respond_to?(:output) && !target_file.output.nil? ? target_file.output : nil
        
        # Fallback to reading the physical file if it hasn't been "rendered" yet
        if content.nil?
          full_path = File.join(site.source, @file_path)
          content = File.exist?(full_path) ? File.read(full_path) : nil
        end

        return "Error: File content empty or unreadable." if content.nil?

        # 2. Process Front Matter if it exists
        if content.start_with?('---')
          begin
            if content =~ /\A(---\s*\n.*?\n?)^((---|\.\.\.)\s*$\n?)/m
              front_matter_raw = $1
              body_content = $' # Content after the match
              context['front_matter'] = YAML.safe_load(front_matter_raw)
            end
          rescue => e
            Jekyll.logger.warn "FileReadTag:", "Error parsing YAML in #{@file_path}: #{e.message}"
            body_content = content
          end
        else
          body_content = content
        end

        # 3. Render Liquid (allows included scripts to use liquid variables)
        template = Liquid::Template.parse(body_content)
        expanded_content = template.render(context)

        # Cache and return
        @@cache[@file_path] = expanded_content
        expanded_content
      else
        "Error: File #{@file_path} not found in site static files or pages."
      end
    end
  end
end

Liquid::Template.register_tag('file_read', Jekyll::FileReadTag)
