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

      per_page = 12

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



          schema = data.dup

          # 🔥 Remove persisted build-time fields to be removed from recipe schemas.
          ["_naturalized_times", "_similar"].each do |field|
            schema.delete(field) if schema.key?(field)
          end
          
          page.data = data.merge(
            "layout"    => "recipe",
            "title"     => data["name"],
            "permalink" => "/recipes/#{unique_slug}/",
            "slug"      => unique_slug,
            "recipe_schema"      => schema
          )

          page.content = ""
          all_recipe_pages << page

          if data["recipeCategory"].to_s.strip != ""
            categories[data["recipeCategory"]] << page
          end

          if data["recipeCuisine"].to_s.strip != ""
            cuisines[data["recipeCuisine"]] << page
          end

          # 🔥 Remove persisted build-time field
          if data.key?("_naturalized_times")
            data.delete("_naturalized_times")
          end
          
          # 🔥 Remove persisted build-time field
          #if data.key?("url")
          #  data.delete("url")
          #end
          
          # 🔥 Remove persisted build-time field
          if data.key?("_similar")
            data.delete("_similar")
          end
          
          # ✍️ Write cleaned data back to file
          File.write(
            file_path,
            JSON.pretty_generate(data),
            mode: "w"
          )
 

        rescue StandardError => e
          Jekyll.logger.error "Recipe parse error:", "#{file_path} — #{e.message}"
        end
      end

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
      total_pages = (all_recipe_pages.size.to_f / per_page).ceil

      (1..total_pages).each do |page_num|
        slice = all_recipe_pages.slice((page_num - 1) * per_page, per_page)

        dir = page_num == 1 ? "recipes" : "recipes/#{page_num}"

        page = Jekyll::PageWithoutAFile.new(site, site.source, dir, "index.html")
        page.data = {
          "layout" => "recipe-archive",
          "title"  => "Recipes",
          "type"   => "recipes",
          "paginated_recipes" => slice.map(&:data),
          "pagination" => {
            "current_page" => page_num,
            "total_pages"  => total_pages,
            "next_page"    => page_num < total_pages ? page_num + 1 : nil,
            "prev_page"    => page_num > 1 ? page_num - 1 : nil,
            "base_url"     => "/recipes/"
          }
        }

        site.pages << page
      end

      # -----------------------------
      # 4. Paginated Category Pages
      # -----------------------------
      categories.each do |name, pages|
        slug = slugify(name)
        total_pages = (pages.size.to_f / per_page).ceil

        (1..total_pages).each do |page_num|
          slice = pages.slice((page_num - 1) * per_page, per_page)
          dir = page_num == 1 ? "recipes/category/#{slug}" : "recipes/category/#{slug}/#{page_num}"

          page = Jekyll::PageWithoutAFile.new(site, site.source, dir, "index.html")
          page.data = {
            "layout" => "recipe-archive",
            "title"  => name,
            "type"   => "category",
            "slug"   => slug,
            "count"  => pages.size,
            "paginated_recipes" => slice,
            "pagination" => {
              "current_page" => page_num,
              "total_pages"  => total_pages,
              "next_page"    => page_num < total_pages ? page_num + 1 : nil,
              "prev_page"    => page_num > 1 ? page_num - 1 : nil,
              "base_url"     => "/recipes/category/#{slug}/"
            }
          }

          site.pages << page
        end
      end

      # -----------------------------
      # 5. Paginated Cuisine Pages
      # -----------------------------
      cuisines.each do |name, pages|
        slug = slugify(name)
        total_pages = (pages.size.to_f / per_page).ceil

        (1..total_pages).each do |page_num|
          slice = pages.slice((page_num - 1) * per_page, per_page)
          dir = page_num == 1 ? "recipes/cuisine/#{slug}" : "recipes/cuisine/#{slug}/#{page_num}"

          page = Jekyll::PageWithoutAFile.new(site, site.source, dir, "index.html")
          page.data = {
            "layout" => "recipe-archive",
            "title"  => name,
            "type"   => "cuisine",
            "slug"   => slug,
            "count"  => pages.size,
            "paginated_recipes" => slice,
            "pagination" => {
              "current_page" => page_num,
              "total_pages"  => total_pages,
              "next_page"    => page_num < total_pages ? page_num + 1 : nil,
              "prev_page"    => page_num > 1 ? page_num - 1 : nil,
              "base_url"     => "/recipes/cuisine/#{slug}/"
            }
          }

          site.pages << page
        end
      end

      # -----------------------------
      # 6. Paginated Category Landing Pages
      # -----------------------------
      category_items = categories.map do |name, pages|
        {
          "title" => name,
          "name"  => name,
          "slug"  => slugify(name),
          "count" => pages.size,
          "permalink" => "/recipes/category/#{slugify(name)}/"
        }
      end.sort_by { |c| c["name"].downcase }

      total_pages = (category_items.size.to_f / per_page).ceil

      (1..total_pages).each do |page_num|
        slice = category_items.slice((page_num - 1) * per_page, per_page)
        dir = page_num == 1 ? "recipes/category" : "recipes/category/#{page_num}"

        page = Jekyll::PageWithoutAFile.new(site, site.source, dir, "index.html")
        page.data = {
          "layout" => "recipe-archive",
          "title"  => "Categories",
          "type"   => "categories",
          "paginated_recipes" => slice,
          "pagination" => {
            "current_page" => page_num,
            "total_pages"  => total_pages,
            "next_page"    => page_num < total_pages ? page_num + 1 : nil,
            "prev_page"    => page_num > 1 ? page_num - 1 : nil,
            "base_url"     => "/recipes/category/"
          }
        }

        site.pages << page
      end

      # -----------------------------
      # 7. Paginated Cuisine Landing Pages
      # -----------------------------
      cuisine_items = cuisines.map do |name, pages|
        {
          "title" => name,
          "name"  => name,
          "slug"  => slugify(name),
          "count" => pages.size,
          "permalink" => "/recipes/cuisine/#{slugify(name)}/"
        }
      end.sort_by { |c| c["name"].downcase }

      total_pages = (cuisine_items.size.to_f / per_page).ceil

      (1..total_pages).each do |page_num|
        slice = cuisine_items.slice((page_num - 1) * per_page, per_page)
        dir = page_num == 1 ? "recipes/cuisine" : "recipes/cuisine/#{page_num}"

        page = Jekyll::PageWithoutAFile.new(site, site.source, dir, "index.html")
        page.data = {
          "layout" => "recipe-archive",
          "title"  => "Cuisines",
          "type"   => "cuisines-categories",
          "paginated_recipes" => slice,
          "pagination" => {
            "current_page" => page_num,
            "total_pages"  => total_pages,
            "next_page"    => page_num < total_pages ? page_num + 1 : nil,
            "prev_page"    => page_num > 1 ? page_num - 1 : nil,
            "base_url"     => "/recipes/cuisine/"
          }
        }

        site.pages << page
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
