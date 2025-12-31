module Jekyll
  class FileReadTag < Liquid::Tag
    def initialize(tag_name, text, tokens)
      super
      @file_path = text.strip
    end

    def render(context)
      site = context.registers[:site]
      cache = site.config["file_read_cache"] || {}

      cache[@file_path] || "Error: File not found."
    end
  end
end

Liquid::Template.register_tag("file_read", Jekyll::FileReadTag)
