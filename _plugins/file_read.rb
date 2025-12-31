module Jekyll
  class FileReadTag < Liquid::Tag
    @@cache = {}

    def initialize(tag_name, text, tokens)
      super
      @file_path = text.strip
    end

    def render(context)
      return @@cache[@file_path] if @@cache.key?(@file_path)

      site = context.registers[:site]
      file_path = File.join(site.source, @file_path)

      return "Error: File not found." unless File.exist?(file_path)

      content = File.read(file_path)

      if content.start_with?('---')
        fm_end = content.index('---', 3)
        front_matter = content[3...fm_end]
        body_content = content[(fm_end + 3)..]

        context['front_matter'] = YAML.safe_load(front_matter) if front_matter
      else
        body_content = content
      end

      template = Liquid::Template.parse(body_content)

      # 🔑 THIS IS THE IMPORTANT PART
      expanded_content = template.render!(
        site.site_payload,
        registers: context.registers
      )

      @@cache[@file_path] = expanded_content
      expanded_content
    end
  end
end

Liquid::Template.register_tag('file_read', Jekyll::FileReadTag)
