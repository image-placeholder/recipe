require 'json'
require 'jekyll'

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
      
      # Track used slugs to handle duplicates
      # Format: { "john-doe" => 1 }
      used_slugs = {}

      json_files.each do |file_path|
        begin
          person_data = JSON.parse(File.read(file_path))
          raw_name = person_data["name"] || File.basename(file_path, ".json")
          
          # 1. Generate initial slug from name
          base_slug = Utils.slugify(raw_name)
          
          # 2. Check for duplicates and append index if necessary
          unique_slug = base_slug
          if used_slugs.key?(base_slug)
            used_slugs[base_slug] += 1
            unique_slug = "#{base_slug}-#{used_slugs[base_slug]}"
          else
            used_slugs[base_slug] = 1
          end

          dir = File.join("people", unique_slug)
          page_name = "index.html"

          page = Jekyll::PageWithoutAFile.new(site, site.source, dir, page_name)
          page.data = person_data.merge({
            "layout" => "recipe",
            "title" => raw_name,
            "slug" => unique_slug,
            "permalink" => "/recipe/#{unique_slug}/",
            "robots" => "noindex"
          })

          page.content = "" 
          site.pages << page

          Jekyll.logger.info "✓ Page generated for '#{raw_name}' as /people/#{unique_slug}/"

        rescue JSON::ParserError => e
          Jekyll.logger.error "JSON parse error for #{file_path}: #{e.message}"
        rescue StandardError => e
          Jekyll.logger.error "Error creating page for #{file_path}: #{e.message}"
        end
      end
    end
  end
end
