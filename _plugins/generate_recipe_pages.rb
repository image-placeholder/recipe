require "json"
require "jekyll"
require "parallel"

module Jekyll
  class GenerateRecipePages < Generator
    safe true
    priority :low

    def generate(site)
      recipe_dir = File.join(site.source, "api", "recipes")
      return unless Dir.exist?(recipe_dir)

      Jekyll.logger.info "Recipe Gen:", "Processing recipes in parallel..."

      recipe_files = Dir[File.join(recipe_dir, "*.json")]
      per_page = 12

      # 1. Parallel Parsing
      # We extract only the data needed for indexing to keep memory low
      recipe_data_list = Parallel.map(recipe_files, in_processes: Parallel.processor_count) do |file_path|
        begin
          raw_data = JSON.parse(File.read(file_path))
          base_slug = File.basename(file_path, ".json")
          
          # Prepare Schema
          allowed_keys = %w[url name image description cookTime cookTimeOriginalFormat prepTime 
                            prepTimeOriginalFormat totalTime totalTimeOriginalFormat recipeYield 
                            recipeIngredients recipeInstructions recipeCategories recipeCuisines 
                            recipeTypes keywords]
          
          schema = raw_data.select { |k, _| allowed_keys.include?(k) }

          {
            "slug" => base_slug,
            "data" => raw_data,
            "schema" => schema,
            "category" => raw_data["recipeCategory"].to_s.strip,
            "cuisine" => raw_data["recipeCuisine"].to_s.strip,
            "title" => raw_data["name"].to_s
          }
        rescue => e
          puts "Error parsing #{file_path}: #{e.message}"
          nil
        end
      end.compact

      # Sort once
      recipe_data_list.sort_by! { |r| r["title"].downcase }

      # 2. Initialize Collections
      all_recipe_pages = []
      categories = Hash.new { |h, k| h[k] = [] }
      cuisines   = Hash.new { |h, k| h[k] = [] }

      # 3. Create Individual Pages (Main Process)
      recipe_data_list.each_with_index do |r, i|
        page = Jekyll::PageWithoutAFile.new(site, site.source, "recipes/#{r['slug']}", "index.html")
        
        # Navigation Data
        prev_recipe = i > 0 ? { "url" => "/recipes/#{recipe_data_list[i-1]['slug']}/", "title" => recipe_data_list[i-1]['title'] } : nil
        next_recipe = i < recipe_data_list.length - 1 ? { "url" => "/recipes/#{recipe_data_list[i+1]['slug']}/", "title" => recipe_data_list[i+1]['title'] } : nil

        page.data = r["data"].merge({
          "layout" => "recipe",
          "title" => r["title"],
          "permalink" => "/recipes/#{r['slug']}/",
          "slug" => r["slug"],
          "recipe_schema" => r["schema"],
          "pagination" => { "previous" => prev_recipe, "next" => next_recipe }
        })
        
        page.content = ""
        all_recipe_pages << page
        site.pages << page

        categories[r["category"]] << page unless r["category"].empty?
        cuisines[r["cuisine"]] << page unless r["cuisine"].empty?
      end

      # 4. Generate All Archives (Paginated)
      generate_paginated_archive(site, all_recipe_pages, "recipes", "Recipes", "recipes", "/recipes/", per_page)
      
      generate_grouped_archives(site, categories, "category", per_page)
      generate_grouped_archives(site, cuisines, "cuisine", per_page)

      # 5. Generate Landing Pages (Category/Cuisine list)
      generate_landing_pages(site, categories, "category", "Categories", per_page)
      generate_landing_pages(site, cuisines, "cuisine", "Cuisines", per_page)
    end

    private

    def generate_grouped_archives(site, groups, type, per_page)
      groups.each do |name, pages|
        slug = slugify(name)
        generate_paginated_archive(site, pages, "recipes/#{type}/#{slug}", name, type, "/recipes/#{type}/#{slug}/", per_page)
      end
    end

    def generate_paginated_archive(site, items, base_dir, title, type, base_url, per_page)
      total_pages = (items.size.to_f / per_page).ceil
      (1..total_pages).each do |page_num|
        dir = page_num == 1 ? base_dir : "#{base_dir}/#{page_num}"
        page = Jekyll::PageWithoutAFile.new(site, site.source, dir, "index.html")
        page.data = {
          "layout" => "recipe-archive",
          "title" => title,
          "type" => type,
          "paginated_recipes" => items.slice((page_num - 1) * per_page, per_page).map(&:data),
          "pagination" => {
            "current_page" => page_num,
            "total_pages" => total_pages,
            "next_page" => page_num < total_pages ? page_num + 1 : nil,
            "prev_page" => page_num > 1 ? page_num - 1 : nil,
            "base_url" => base_url
          }
        }
        site.pages << page
      end
    end

    def generate_landing_pages(site, groups, type, title, per_page)
      items = groups.map do |name, pages|
        { "title" => name, "name" => name, "slug" => slugify(name), "count" => pages.size, "permalink" => "/recipes/#{type}/#{slugify(name)}/" }
      end.sort_by { |c| c["name"].downcase }

      generate_paginated_archive(site, items, "recipes/#{type}", title, "#{type}s", "/recipes/#{type}/", per_page)
    end

    def slugify(text)
      text.to_s.downcase.strip.gsub(/\s+/, "-").gsub(/[^\w-]/, "").gsub(/--+/, "-")
    end
  end
end
