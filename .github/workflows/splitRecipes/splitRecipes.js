const fs = require('fs'); 
const path = require('path');
const { isoDuration, en } = require("@musement/iso-duration");
const _fs = require('fs').promises;
const {getSimilarRecipes} = require("./similarRecipes.js");
const humanizeDuration = require('humanize-duration');


// ----------------------------------
// Helpers
// ----------------------------------
const humanizeISODuration = (iso) => {
  if (!iso) return null;

  try {
    const duration = isoDuration(iso);

    return duration.humanize('en');
  } catch {
    return null;
  }
};


// Setup locales
//   key - string you want to use in `humanize` function
//   value - IsoDuration i18n object.
isoDuration.setLocales(
  {
    en,
  //  pl,
   // it,
  },
  {
    fallbackLocale: 'en',
  }
)


// ----------------------------------
// Main
// ----------------------------------
async function naturalizeRecipeTimes(recipes) {
  try {
    const updatedRecipes = recipes.map(recipe => ({
      ...recipe,
      _naturalized_times: {
        prepTime: humanizeISODuration(recipe.prepTime),
        cookTime: humanizeISODuration(recipe.cookTime),
        totalTime: humanizeISODuration(recipe.totalTime),
      },
    }));

    await _fs.writeFile(
      DATA_FILE,
      JSON.stringify(updatedRecipes, null, 2),
      'utf8'
    );

    console.log(`✓ Naturalized times added to ${updatedRecipes.length} recipes`);
  } catch (err) {
    console.error('✗ Failed to naturalize recipe times:', err);
    process.exitCode = 1;
  }
}




function similarRecipes(recipe, recipes, amount=5) {
  if (!recipe || typeof recipe !== 'object') return recipe;

  return {
    ...recipe,
    _similar: getSimilarRecipes(recipe, recipes, amount),
  };
}

function naturalizeRecipeTimes(recipe) {
  if (!recipe || typeof recipe !== 'object') return recipe;

  return {
    ...recipe,
    _naturalized_times: {
      prepTime: humanizeISODuration(recipe.prepTime),
      cookTime: humanizeISODuration(recipe.cookTime),
      totalTime: humanizeISODuration(recipe.totalTime),
    },
  };
}


// 1. Configuration
const DATA_FILE = path.join(process.cwd(), '_data', 'recipes.json');
const OUTPUT_DIR = path.join(process.cwd(), 'api');

// Utility to create a URL-friendly slug
const slugify = (text) => {
  return text
    .toString()
    .toLowerCase()
    .trim()
    .replace(/\s+/g, '-')     // Replace spaces with -
    .replace(/[^\w-]+/g, '')  // Remove all non-word chars
    .replace(/--+/g, '-');    // Replace multiple - with single -
};

// Ensure directory exists
const ensureDir = (dir) => {
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
};

const generateRecipes = async () => {
  try {
    ensureDir(OUTPUT_DIR);
    const rawData = fs.readFileSync(DATA_FILE, 'utf8');
    const recipes = JSON.parse(rawData);
    //await naturalizeRecipeTimes(recipes);
    console.log(`Processing ${recipes.length} recipes...`);

    const searchIndex = [];
    const categoriesMap = {};
    const categorySlugMap = {};
    const cuisinesMap = {};
    const cuisineSlugMap = {};
    const authorsMap = {};
    const authorSlugMap = {};

    recipes.forEach((recipe, index) => {
      const id = recipe.id || (index + 1);
      const baseSlug = slugify(recipe.name || 'untitled-recipe');
      const fileName = `${baseSlug}-${id}.json`;
      const filePath = path.join(OUTPUT_DIR, 'recipes');
      ensureDir(filePath);

      // Run Recommendation System
      const _recipe = similarRecipes(recipe, recipes, 5);

      _recipe.url = `/recipes/${fileName}`;
      // Write individual recipe file
      fs.writeFileSync(path.join(filePath, fileName), JSON.stringify(naturalizeRecipeTimes(_recipe), null, 2));

      // Handle authors (array or single object)
      let authors = [];
      if (Array.isArray(recipe.author)) {
        authors = recipe.author.map(a => a.name);
      } else if (recipe.author && recipe.author.name) {
        authors = [recipe.author.name];
      }

      // Build minimal search index
      const searchItem = {
        name: recipe.name,
        author: authors.join(', '),
        keyword: recipe.keywords || '',
        description: recipe.description || '',
        category: recipe.recipeCategory || '',
        cuisine: recipe.recipeCuisine || '',
        url: `recipes/${fileName.replace('.json', '')}`
      };
      searchIndex.push(searchItem);

      // Categories
      const category = recipe.recipeCategory || 'Uncategorized';
      if (!categoriesMap[category]) {
        categoriesMap[category] = [];
        categorySlugMap[category] = slugify(category);
      }
      categoriesMap[category].push(searchItem);

      // Cuisines
      const cuisine = recipe.recipeCuisine || 'Unspecified';
      if (!cuisinesMap[cuisine]) {
        cuisinesMap[cuisine] = [];
        cuisineSlugMap[cuisine] = slugify(cuisine);
      }
      cuisinesMap[cuisine].push(searchItem);

      // Authors
      authors.forEach(author => {
        if (!authorsMap[author]) {
          authorsMap[author] = [];
          authorSlugMap[author] = slugify(author);
        }
        authorsMap[author].push(searchItem);
      });
    });

    // Write search index
    fs.writeFileSync(path.join(OUTPUT_DIR, 'search.json'), JSON.stringify(searchIndex, null, 2));

    // Write categories list
    const categoriesList = Object.keys(categoriesMap).map(cat => ({
      name: cat,
      slug: categorySlugMap[cat],
      count: categoriesMap[cat].length
    }));
    fs.writeFileSync(path.join(OUTPUT_DIR, 'categories.json'), JSON.stringify(categoriesList, null, 2));

    // Write per-category recipes
    const categoryDir = path.join(OUTPUT_DIR, 'categories');
    ensureDir(categoryDir);
    Object.entries(categoriesMap).forEach(([category, items]) => {
      const catSlug = categorySlugMap[category];
      fs.writeFileSync(path.join(categoryDir, `${catSlug}.json`), JSON.stringify(items, null, 2));
    });

    // Write cuisines list
    const cuisinesList = Object.keys(cuisinesMap).map(c => ({
      name: c,
      slug: cuisineSlugMap[c],
      count: cuisinesMap[c].length
    }));
    fs.writeFileSync(path.join(OUTPUT_DIR, 'cuisines.json'), JSON.stringify(cuisinesList, null, 2));

    // Write per-cuisine recipes
    const cuisineDir = path.join(OUTPUT_DIR, 'cuisines');
    ensureDir(cuisineDir);
    Object.entries(cuisinesMap).forEach(([cuisine, items]) => {
      const cuisineSlug = cuisineSlugMap[cuisine];
      fs.writeFileSync(path.join(cuisineDir, `${cuisineSlug}.json`), JSON.stringify(items, null, 2));
    });

    // Write authors list
    const authorsList = Object.keys(authorsMap).map(a => ({
      name: a,
      slug: authorSlugMap[a],
      count: authorsMap[a].length
    }));
    fs.writeFileSync(path.join(OUTPUT_DIR, 'authors.json'), JSON.stringify(authorsList, null, 2));

    // Write per-author recipes
    const authorDir = path.join(OUTPUT_DIR, 'authors');
    ensureDir(authorDir);
    Object.entries(authorsMap).forEach(([author, items]) => {
      const authorSlug = authorSlugMap[author];
      fs.writeFileSync(path.join(authorDir, `${authorSlug}.json`), JSON.stringify(items, null, 2));
    });

    // Write stats
    const stats = {
      totalRecipes: recipes.length,
      totalAuthors: Object.keys(authorsMap).length,
      totalCategories: Object.keys(categoriesMap).length,
      totalCuisines: Object.keys(cuisinesMap).length
    };
    fs.writeFileSync(path.join(OUTPUT_DIR, 'stats.json'), JSON.stringify(stats, null, 2));

    console.log('Generation complete!');
  } catch (error) {
    console.error('Error processing recipes:', error.message);
  }
};

generateRecipes();
