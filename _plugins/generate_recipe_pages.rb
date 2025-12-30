require "json"
require "jekyll"

module Jekyll
  class GenerateRecipePages < Generator
    safe true
    priority :low

    def generate(site)
      recipe_dir = File.join(site.source, "api", "recipes")
      return unless Dir.exist?(recipe_dir)

      all_recipe_pages = []
      used_slugs = {}

      categories = Hash.new { |h, k| h[k] = [] }
      cuisines   = Hash.new { |h, k| h[k] = [] }

      # -----------------------------
      # 1. Individual Recipe Pages
      # -----------------------------
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

          page = Jekyll::PageWithoutAFile.new(
            site,
            site.source,
            "recipes/#{unique_slug}",
            "index.html"
          )

          page.data = data.merge(
            "layout"    => "recipe",
            "title"     => data["name"],
            "permalink" => "/recipes/#{unique_slug}/",
            "slug"      => unique_slug
          )

          page.content = ""
          all_recipe_pages << page

          # Collect categories
          category = data["recipeCategory"]
          if category && !category.to_s.strip.empty?
            categories[category] << page
          end

          # Collect cuisines
          cuisine = data["recipeCuisine"]
          if cuisine && !cuisine.to_s.strip.empty?
            cuisines[cuisine] << page
          end

        rescue StandardError => e
          Jekyll.logger.error "Recipe parse error:", "#{file_path} — #{e.message}"
        end
      end

      # Alphabetical order
      all_recipe_pages.sort_by! { |p| p.data["title"].to_s.downcase }

      # -----------------------------
      # 2. Previous / Next Navigation
      # -----------------------------
      all_recipe_pages.each_with_index do |p, i|
        p.data["pagination"] = {
          "previous" => i > 0 ? {
            "url"   => all_recipe_pages[i - 1].data["permalink"],
            "title" => all_recipe_pages[i - 1].data["title"]
          } : nil,
          "next" => i < all_recipe_pages.length - 1 ? {
            "url"   => all_recipe_pages[i + 1].data["permalink"],
            "title" => all_recipe_pages[i + 1].data["title"]
          } : nil
        }

        site.pages << p
      end

      # -----------------------------
      # 3. Main Recipe Index Pagination
      # -----------------------------
      per_page = 12
      total_pages = (all_recipe_pages.size.to_f / per_page).ceil

      (1..total_pages).each do |page_num|
        offset = (page_num - 1) * per_page
        slice  = all_recipe_pages.slice(offset, per_page)

        dir = page_num == 1 ? "recipes" : "recipes/#{page_num}"

        index_page = Jekyll::PageWithoutAFile.new(site, site.source, dir, "index.html")
        index_page.data = {
          "layout" => "recipe-archive",
          "title"  => "Recipes — Page #{page_num}",
          "paginated_recipes" => slice.map(&:data),
          "pagination" => {
            "current_page" => page_num,
            "total_pages"  => total_pages,
            "next_page"    => page_num < total_pages ? page_num + 1 : nil,
            "prev_page"    => page_num > 1 ? page_num - 1 : nil
          }
        }

        site.pages << index_page
      end

      # -----------------------------
      # 4. Paginated Category Pages
      # -----------------------------
      per_page = 12
      
      categories.each do |name, pages|
        slug = slugify(name)
        total_pages = (pages.size.to_f / per_page).ceil
      
        (1..total_pages).each do |page_num|
          offset = (page_num - 1) * per_page
          slice  = pages.slice(offset, per_page)
      
          dir =
            if page_num == 1
              "recipes/category/#{slug}"
            else
              "recipes/category/#{slug}/#{page_num}"
            end
      
          category_page = Jekyll::PageWithoutAFile.new(
            site,
            site.source,
            dir,
            "index.html"
          )
      
          category_page.data = {
            "layout"  => "recipe-archive",
            "title"   => name,
            "type"    => "category",
            "slug"    => slug,
            "count"   => pages.size,
            "recipes" => slice.map(&:data),
            "pagination" => {
              "current_page" => page_num,
              "total_pages"  => total_pages,
              "next_page"    => page_num < total_pages ? page_num + 1 : nil,
              "prev_page"    => page_num > 1 ? page_num - 1 : nil,
              "base_url"     => "/recipes/category/#{slug}/"
            }
          }
      
          site.pages << category_page
        end
      end


    # -----------------------------
    # Utility: slugify
    # -----------------------------
    def slugify(text)
      text.to_s
          .downcase
          .strip
          .gsub(/\s+/, "-")
          .gsub(/[^\w-]/, "")
          .gsub(/--+/, "-")
    end
  end
end
