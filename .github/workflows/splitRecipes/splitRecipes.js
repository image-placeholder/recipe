const fs = require('fs');
const path = require('path');
const { isoDuration, en } = require("@musement/iso-duration");
const _fs = require('fs').promises;
const { getSimilarRecipes } = require("./similarRecipes.js");
const humanizeDuration = require('humanize-duration');
const { RecipeEngine } = require('./RecipeEngine.js');
const yaml = require('js-yaml');
const { glob } = require('glob');

// Configuration
const RECIPE_PATTERN = '_data/recipes*.@(json|md)'; // Adjust pattern as needed
const OUTPUT_DIR = path.join(process.cwd(), 'api');

// Setup locales
isoDuration.setLocales(
  {
    en,
  },
  {
    fallbackLocale: 'en',
  }
);

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

function parseRecipeFilename(filename) {
  const dateRegex = /^\d{4}(-\d{2}){0,2}$/;
  const base = filename.replace(/^recipes_?/, '');
  if (!base) return { source: null, date: null };

  const parts = base.split('_');
  const last = parts[parts.length - 1];

  if (dateRegex.test(last)) {
    return { 
      source: parts.slice(0, -1).join('_').replaceAll("-", " ").replaceAll("_", " ") || null, 
      date: last 
    };
  } else {
    return { 
      source: parts.join('_').replaceAll("-", " ").replaceAll("_", " ") || null, 
      date: null 
    };
  }
}

function loadJekyllConfig(configPath = '_config.yml') {
  try {
    const fullPath = path.resolve(process.cwd(), configPath);
    if (!fs.existsSync(fullPath)) {
      return {};
    }

    const file = fs.readFileSync(fullPath, 'utf8');
    return yaml.load(file) || {};
  } catch (err) {
    console.warn('[config] Failed to load _config.yml:', err.message);
    return {};
  }
}

async function createSimilarityEngine(settings) {
  if (settings.engine === 'transformers') {
    const engine = new RecipeEngine(settings.vector_path);
    // Properly bind the method to maintain 'this' context
    return {
      type: 'transformers',
      model: settings.model,
      similarity: (recipe, recipes, amount) => engine.getRecommendations(recipe, recipes, amount),
      max_recommendations: settings.max_recommendations,
      engine: engine // Keep reference to engine instance
    };
  }

  return {
    type: 'simple',
    similarity: getSimilarRecipes,
    max_recommendations: settings.max_recommendations
  };
}

function getRecommendationSettings(config) {
  const rec = config.recommendations || {};

  const maxRecommendations = Number.isFinite(Number(rec.max_recommendations))
    ? Number(rec.max_recommendations)
    : 5;

  return {
    engine: rec.engine === 'transformers' ? 'transformers' : 'simple',
    model: typeof rec.model === 'string' ? rec.model : 'all-MiniLM-L6-v2',
    vector_path: typeof rec.vector_path === 'string'
      ? rec.vector_path
      : './_cache/recipe-vectors.json',
    max_recommendations: maxRecommendations
  };
}

const slugify = (text) => {
  return text
    .toString()
    .toLowerCase()
    .trim()
    .replace(/\s+/g, '-')
    .replace(/[^\w-]+/g, '')
    .replace(/--+/g, '-');
};

const ensureDir = (dir) => {
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
};

async function similarRecipes(recipe, recipes, amount = 5, engine) {
  if (!recipe || typeof recipe !== 'object') return recipe;

  return {
    ...recipe,
    _similar: await engine(recipe, recipes, amount),
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

// ----------------------------------
// Load recipes from files
// ----------------------------------
async function loadRecipesFromFiles(pattern) {
  console.log(`Searching for recipe files matching: ${pattern}`);
  const files = await glob(pattern);
  console.log(`Found ${files.length} recipe files`);

  const recipes = [];

  for (const file of files) {
    try {
      const filename = path.basename(file, path.extname(file));
      const parsed = parseRecipeFilename(filename);
      
      const content = await _fs.readFile(file, 'utf8');
      let recipeData = JSON.parse(content);

      // Handle if the file contains an array of recipes
      if (Array.isArray(recipeData)) {
        console.log(`  ${file} contains ${recipeData.length} recipes (array)`);
        recipeData.forEach((recipe, idx) => {
          if (!recipe || typeof recipe !== 'object') {
            console.warn(`  Skipping invalid recipe at index ${idx} in ${file}`);
            return;
          }
          
          const enrichedRecipe = {
            ...recipe,
            _file_source: parsed.source,
            _file_date: parsed.date,
            _file_path: file
          };
          recipes.push(enrichedRecipe);
        });
      } else if (recipeData && typeof recipeData === 'object') {
        // Single recipe object
        console.log(`  ${file} contains 1 recipe (object): ${recipeData.name || 'UNNAMED'}`);
        
        if (!recipeData.name) {
          console.warn(`  Warning: Recipe in ${file} has no name property!`);
          console.warn(`  Available properties: ${Object.keys(recipeData).join(', ')}`);
        }
        
        const enrichedRecipe = {
          ...recipeData,
          _file_source: parsed.source,
          _file_date: parsed.date,
          _file_path: file
        };
        recipes.push(enrichedRecipe);
      } else {
        console.error(`  Invalid recipe format in ${file}`);
      }
    } catch (err) {
      console.error(`Failed to process ${file}:`, err.message);
    }
  }

  console.log(`Successfully loaded ${recipes.length} recipes from ${files.length} files`);
  return recipes;
}

// ----------------------------------
// Main generation function
// ----------------------------------
const generateRecipes = async () => {
  try {
    ensureDir(OUTPUT_DIR);

    // Load recipes from files instead of single JSON
    const recipes = await loadRecipesFromFiles(RECIPE_PATTERN);

    if (recipes.length === 0) {
      console.error('No recipes found. Check your RECIPE_PATTERN.');
      process.exit(1);
    }

    console.log(`Processing ${recipes.length} recipes...`);

    const config = loadJekyllConfig();
    const settings = getRecommendationSettings(config);
    const engine = await createSimilarityEngine(settings);
    console.log(`Using ${engine.type} engine for calculating similar recipes...`);

    // First pass: Pre-assign URLs
    const recipesWithUrls = recipes.map((recipe, index) => {
      const id = recipe.id || (index + 1);
      const baseSlug = slugify(recipe.name || 'untitled-recipe');
      const fileName = `${baseSlug}-${id}`;
      return {
        ...recipe,
        url: fileName
      };
    });

    const searchIndex = [];
    const categoriesMap = {};
    const categorySlugMap = {};
    const cuisinesMap = {};
    const cuisineSlugMap = {};
    const authorsMap = {};
    const authorSlugMap = {};

    // Process each recipe
    for (const [index, recipe] of recipesWithUrls.entries()) {
      const id = recipe.id || (index + 1);
      const baseSlug = slugify(recipe.name || 'untitled-recipe');
      const fileName = `${baseSlug}-${id}.json`;
      const filePath = path.join(OUTPUT_DIR, 'recipes');
      ensureDir(filePath);

      console.log(`[${index + 1}/${recipes.length}] Processing: ${recipe.name}`);

      // Calculate similar recipes
      const recipeWithRecs = await similarRecipes(
        recipe, 
        recipesWithUrls, 
        settings.max_recommendations, 
        engine.similarity
      );

      delete recipeWithRecs.url;

      // Write individual recipe file
      fs.writeFileSync(
        path.join(filePath, fileName),
        JSON.stringify(naturalizeRecipeTimes(recipeWithRecs), null, 2)
      );

      // Handle authors
      let authors = [];
      if (Array.isArray(recipe.author)) {
        authors = recipe.author.map(a => a.name);
      } else if (recipe.author && recipe.author.name) {
        authors = [recipe.author.name];
      }

      // Build search index item
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

      // Map categories
      const category = recipe.recipeCategory || 'Uncategorized';
      if (!categoriesMap[category]) {
        categoriesMap[category] = [];
        categorySlugMap[category] = slugify(category);
      }
      categoriesMap[category].push(searchItem);

      // Map cuisines
      const cuisine = recipe.recipeCuisine || 'Unspecified';
      if (!cuisinesMap[cuisine]) {
        cuisinesMap[cuisine] = [];
        cuisineSlugMap[cuisine] = slugify(cuisine);
      }
      cuisinesMap[cuisine].push(searchItem);

      // Map authors
      authors.forEach(author => {
        if (!authorsMap[author]) {
          authorsMap[author] = [];
          authorSlugMap[author] = slugify(author);
        }
        authorsMap[author].push(searchItem);
      });
    }

    // Write all aggregate files
    console.log('Finalizing aggregate files...');

    // Search index
    fs.writeFileSync(
      path.join(OUTPUT_DIR, 'search.json'),
      JSON.stringify(searchIndex, null, 2)
    );

    // Categories
    const categoriesList = Object.keys(categoriesMap).map(cat => ({
      name: cat,
      slug: categorySlugMap[cat],
      count: categoriesMap[cat].length
    }));
    fs.writeFileSync(
      path.join(OUTPUT_DIR, 'categories.json'),
      JSON.stringify(categoriesList, null, 2)
    );

    const categoryDir = path.join(OUTPUT_DIR, 'categories');
    ensureDir(categoryDir);
    Object.entries(categoriesMap).forEach(([category, items]) => {
      const catSlug = categorySlugMap[category];
      fs.writeFileSync(
        path.join(categoryDir, `${catSlug}.json`),
        JSON.stringify(items, null, 2)
      );
    });

    // Cuisines
    const cuisinesList = Object.keys(cuisinesMap).map(c => ({
      name: c,
      slug: cuisineSlugMap[c],
      count: cuisinesMap[c].length
    }));
    fs.writeFileSync(
      path.join(OUTPUT_DIR, 'cuisines.json'),
      JSON.stringify(cuisinesList, null, 2)
    );

    const cuisineDir = path.join(OUTPUT_DIR, 'cuisines');
    ensureDir(cuisineDir);
    Object.entries(cuisinesMap).forEach(([cuisine, items]) => {
      const cuisineSlug = cuisineSlugMap[cuisine];
      fs.writeFileSync(
        path.join(cuisineDir, `${cuisineSlug}.json`),
        JSON.stringify(items, null, 2)
      );
    });

    // Authors
    const authorsList = Object.keys(authorsMap).map(a => ({
      name: a,
      slug: authorSlugMap[a],
      count: authorsMap[a].length
    }));
    fs.writeFileSync(
      path.join(OUTPUT_DIR, 'authors.json'),
      JSON.stringify(authorsList, null, 2)
    );

    const authorDir = path.join(OUTPUT_DIR, 'authors');
    ensureDir(authorDir);
    Object.entries(authorsMap).forEach(([author, items]) => {
      const authorSlug = authorSlugMap[author];
      fs.writeFileSync(
        path.join(authorDir, `${authorSlug}.json`),
        JSON.stringify(items, null, 2)
      );
    });

    // Stats
    const stats = {
      totalRecipes: recipes.length,
      totalAuthors: Object.keys(authorsMap).length,
      totalCategories: Object.keys(categoriesMap).length,
      totalCuisines: Object.keys(cuisinesMap).length
    };
    fs.writeFileSync(
      path.join(OUTPUT_DIR, 'stats.json'),
      JSON.stringify(stats, null, 2)
    );

    console.log('✅ Generation complete!');
    console.log(`   Recipes: ${stats.totalRecipes}`);
    console.log(`   Authors: ${stats.totalAuthors}`);
    console.log(`   Categories: ${stats.totalCategories}`);
    console.log(`   Cuisines: ${stats.totalCuisines}`);
  } catch (error) {
    console.error('❌ Error processing recipes:', error);
    process.exit(1);
  }
};

generateRecipes();
