# _plugins/generate_people_pages.rb
require 'json'

module Jekyll
  class GeneratePeoplePages < Generator
    safe true
    priority :low

    def generate(site)
      Jekyll.logger.info "Starting people page generation..."

      people_dir = File.join(site.source, "assets", "people")
      unless Dir.exist?(people_dir)
        Jekyll.logger.warn "People directory not found:", people_dir
        return
      end

      json_files = Dir[File.join(people_dir, "*.json")]
      Jekyll.logger.info "Found #{json_files.size} people JSON files."

      json_files.each do |file_path|
        begin
          # Use filename (without extension) as slug
          slug = File.basename(file_path, ".json")
          person_data = JSON.parse(File.read(file_path))

          dir = File.join("people", slug)
          name = "index.html"

          Jekyll.logger.info "Creating person page for '#{slug}' at '#{dir}/#{name}'"

          personName = person_data["name"]
          # Create a new virtual page
          page = Jekyll::PageWithoutAFile.new(site, site.source, dir, name)
          page.data = person_data.merge({
            "layout" => "tribute",
            "title" => personName || slug.capitalize,
            "slug" => slug,
            "permalink" => "/people/#{slug}/",
            "robots" => "noindex"
          })

          page.content = "" # Layout will render based on person data
          site.pages << page

          Jekyll.logger.info "✓ Page generated for '#{slug}'"

        rescue JSON::ParserError => e
          Jekyll.logger.error "JSON parse error for #{file_path}: #{e.message}"
        rescue StandardError => e
          Jekyll.logger.error "Error creating page for #{file_path}: #{e.message}"
        end
      end

      Jekyll.logger.info "People page generation complete."
    end
  end
end
