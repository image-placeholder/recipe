# _plugins/recipe_json_generator.rb
require 'json'

module Jekyll
  class RecipeJSONGenerator < Generator
    safe true
    priority :low

    def generate(site)
      # Load recipes from _data/recipes.json
      data_file = File.join(site.source, '_data', 'recipes.json')
      return unless File.exist?(data_file)

      recipes = JSON.parse(File.read(data_file))
      puts "Processing #{recipes.size} recipes..."

      search_index = []
      categories_map = {}
      cuisines_map = {}
      authors_map = {}

      recipes.each_with_index do |recipe, index|
        id = recipe['id'] || (index + 1)
        slug = slugify(recipe['name'] || "untitled-recipe")
        file_name = "#{slug}-#{id}.json"

        # Write individual recipe JSON
        write_json(site, "api/recipes/#{file_name}", recipe)

        # Handle authors
        authors = []
        if recipe['author'].is_a?(Array)
          authors = recipe['author'].map { |a| a['name'] }
        elsif recipe['author'].is_a?(Hash) && recipe['author']['name']
          authors = [recipe['author']['name']]
        end

        # Build search index
        search_item = {
          'name' => recipe['name'],
          'author' => authors.join(', '),
          'keyword' => recipe['keywords'] || '',
          'category' => recipe['recipeCategory'] || '',
          'description' => recipe['description'] || '',
          'cuisine' => recipe['recipeCuisine'] || '',
          'url' => "recipes/#{file_name.gsub('.json','')}"
        }
        search_index << search_item

        # Categories
        category = recipe['recipeCategory'] || 'Uncategorized'
        categories_map[category] ||= []
        categories_map[category] << search_item

        # Cuisines
        cuisine = recipe['recipeCuisine'] || 'Unspecified'
        cuisines_map[cuisine] ||= []
        cuisines_map[cuisine] << search_item

        # Authors
        authors.each do |author|
          authors_map[author] ||= []
          authors_map[author] << search_item
        end
      end

      # Write main search index
      write_json(site, 'api/search.json', search_index)

      # Categories list & per-category
      categories_map.each do |name, items|
        slug = slugify(name)
        write_json(site, "api/categories/#{slug}.json", items)
      end
      categories_list = categories_map.map { |name, items|
        { 'name' => name, 'slug' => slugify(name), 'count' => items.size }
      }
      write_json(site, 'api/categories.json', categories_list)

      # Cuisines list & per-cuisine
      cuisines_map.each do |name, items|
        slug = slugify(name)
        write_json(site, "api/cuisines/#{slug}.json", items)
      end
      cuisines_list = cuisines_map.map { |name, items|
        { 'name' => name, 'slug' => slugify(name), 'count' => items.size }
      }
      write_json(site, 'api/cuisines.json', cuisines_list)

      # Authors list & per-author
      authors_map.each do |name, items|
        slug = slugify(name)
        write_json(site, "api/authors/#{slug}.json", items)
      end
      authors_list = authors_map.map { |name, items|
        { 'name' => name, 'slug' => slugify(name), 'count' => items.size }
      }
      write_json(site, 'api/authors.json', authors_list)

      # Stats
      stats = {
        'totalRecipes' => recipes.size,
        'totalAuthors' => authors_map.keys.size,
        'totalCategories' => categories_map.keys.size,
        'totalCuisines' => cuisines_map.keys.size
      }
      write_json(site, 'api/stats.json', stats)

      puts 'Recipe JSON generation complete!'
    end

    private

    def slugify(text)
      text.to_s.downcase.strip.gsub(' ', '-').gsub(/[^\w-]/, '')
    end

    # Utility to create a JSON page in Jekyll
    def write_json(site, path, content)
      dir = File.dirname(path)
      filename = File.basename(path)

      page = PageWithoutAFile.new(site, site.source, dir, filename)
      page.content = content.is_a?(String) ? content : JSON.pretty_generate(content)
      page.data['layout'] = nil
      page.data['permalink'] = "/#{path}"
      page.output = page.content
      page.ext = ".json"

      site.pages << page
    end
  end
end
