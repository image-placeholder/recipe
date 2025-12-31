module Jekyll
  Hooks.register :site, :post_render do |site|
    site.config["file_read_cache"] ||= {}

    site.pages.each do |page|
      next unless page.data["file_read"]

      file_path = File.join(site.source, page.data["file_read"])
      next unless File.exist?(file_path)

      content = File.read(file_path)

      if content.start_with?('---')
        fm_end = content.index('---', 3)
        body = content[(fm_end + 3)..]
      else
        body = content
      end

      template = Liquid::Template.parse(body)
      rendered = template.render(site.site_payload)

      site.config["file_read_cache"][file_path] = rendered
    end
  end
end
