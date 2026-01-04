module Jekyll
  class FrontMatterGenerator < Generator
    priority :high # Run early in the build process

    def generate(site)
      # Process pages, posts, and collection documents
      (site.pages + site.posts.docs + site.collections.values.flat_map(&:docs)).each do |doc|
        process_front_matter(doc, site)
      end
    end

    def process_front_matter(doc, site)
      # Define which fields you want to allow Liquid in
      # Add 'description', 'og_title', etc., to this list
      keys_to_render = ['title', 'description', 'og_image_description']

      keys_to_render.each do |key|
        if doc.data[key] && doc.data[key].include?("{{")
          begin
            template = Liquid::Template.parse(doc.data[key])
            # Render using the site payload and the document's own data
            doc.data[key] = template.render(site.site_payload.merge("page" => doc.data))
          rescue StandardError => e
            Jekyll.logger.warn "Front Matter Error:", "#{e.message} in #{doc.path}"
          end
        end
      end
    end
  end
end
