require 'json'
require 'jekyll'

module Jekyll
  class GenerateRecipePages < Generator
    safe true
    priority :low

    def generate(site)
      # 1. Setup paths and data
      recipe_dir = File.join(site.source, "api", "recipes")
      return unless Dir.exist?(recipe_dir)

      # 2. Generate all individual recipe pages
      all_recipe_pages = []
      used_slugs = {}
      
      Dir[File.join(recipe_dir, "*.json")].each do |file_path|
        begin
          data = JSON.parse(File.read(file_path))
          base_slug = File.basename(file_path, ".json")
          
          unique_slug = base_slug
          if used_slugs.key?(base_slug)
            used_slugs[base_slug] += 1
            unique_slug = "#{base_slug}-#{used_slugs[base_slug]}"
          else
            used_slugs[base_slug] = 1
          end

          page = Jekyll::PageWithoutAFile.new(site, site.source, "recipe/#{unique_slug}", "index.html")
          page.data = data.merge({
            "layout" => "recipe",
            "title" => data["name"],
            "permalink" => "/recipe/#{unique_slug}/"
          })
          page.content = ""
          all_recipe_pages << page
        rescue StandardError => e
          Jekyll.logger.error "Error parsing #{file_path}: #{e.message}"
        end
      end

      # Sort alphabetically to establish order
      all_recipe_pages.sort_by! { |p| p.data["title"].downcase }

      # --- RELATIONSHIP PAGINATION (Next/Prev for Single Recipes) ---
      all_recipe_pages.each_with_index do |p, i|
        # Use a hash structure similar to your index pagination
        p.data["pagination"] = {
          "previous" => i > 0 ? { 
            "url" => all_recipe_pages[i - 1].data["permalink"], 
            "title" => all_recipe_pages[i - 1].data["title"] 
          } : nil,
          "next" => i < all_recipe_pages.length - 1 ? { 
            "url" => all_recipe_pages[i + 1].data["permalink"], 
            "title" => all_recipe_pages[i + 1].data["title"] 
          } : nil
        }
        site.pages << p
      end

      # 3. Handle Index Pagination (Archive Pages)
      per_page = 12
      total_pages = (all_recipe_pages.size.to_f / per_page).ceil

      (1..total_pages).each do |page_num|
        offset = (page_num - 1) * per_page
        recipes_for_this_page = all_recipe_pages.slice(offset, per_page)
        
        dir = page_num == 1 ? 'recipe' : "recipe/page#{page_num}"
        
        index_page = Jekyll::PageWithoutAFile.new(site, site.source, dir, "index.html")
        index_page.data = {
          "layout" => "recipe-index",
          "title" => "Recipe Archive - Page #{page_num}",
          "paginated_recipes" => recipes_for_this_page.map(&:data),
          "pagination" => {
            "current_page" => page_num,
            "total_pages" => total_pages,
            "next_page" => (page_num < total_pages ? page_num + 1 : nil),
            "prev_page" => (page_num > 1 ? page_num - 1 : nil)
          }
        }
        site.pages << index_page
      end
    end
  end
end
