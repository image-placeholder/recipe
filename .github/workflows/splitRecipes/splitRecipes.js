const fs = require('fs'); 
const path = require('path');
const { isoDuration, en } = require("@musement/iso-duration");
const _fs = require('fs').promises;
const {getSimilarRecipes} = require("./similarRecipes.js");
const humanizeDuration = require('humanize-duration');
const {RecipeEngine} = require('./RecipeEngine.js');
const yaml = require('js-yaml');

/*
to do implment glob - parse sources.
import fs from 'fs/promises';
import { glob } from 'glob';

async function readAllFiles(pattern) {
  // Find all files matching the glob pattern
  const files = await glob(pattern);

  // Read all files in parallel
  const contents = await Promise.all(
    files.map(async file => {
      const data = await fs.readFile(file, 'utf-8');
      return { file, data };
    })
  );

  return contents;
}

// Example usage
(async () => {
  const allFiles = await readAllFiles('recipes/**/*.txt'); // change pattern
  console.log(allFiles);
})();

// stream version
import fs from 'fs';
import readline from 'readline';
import { glob } from 'glob';

// Reuse parseRecipes logic for filenames
function parseRecipeFilename(filename) {
  const dateRegex = /^\d{4}(-\d{2}){0,2}$/;
  const base = filename.replace(/^recipes_?/, '');
  if (!base) return { source: null, date: null };

  const parts = base.split('_');
  const last = parts[parts.length - 1];

  if (dateRegex.test(last)) {
    return { source: parts.slice(0, -1).join('_') || null, date: last };
  } else {
    return { source: parts.join('_') || null, date: null };
  }
}

async function processFiles(pattern) {
  const files = await glob(pattern);
  const results = [];

  for (const file of files) {
    const filename = file.split('/').pop().replace(/\..+$/, ''); // remove path & extension
    const parsed = parseRecipeFilename(filename);

    // Stream file content line by line
    const rl = readline.createInterface({
      input: fs.createReadStream(file),
      crlfDelay: Infinity
    });

    const lines = [];
    for await (const line of rl) {
      lines.push(line);
    }

    results.push({
      file,
      parsedFilename: parsed,
      content: lines.join('\n') // can keep as array if you want streaming
    });
  }

  return results;
}

// Example usage
(async () => {
  const allData = await processFiles('recipes/**/*.txt'); // adjust pattern
  console.log(allData);
})();


*/


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

function createSimilarityEngine(settings) {
  if (settings.engine === 'transformers') {
    // Initialize with a custom filename
    const engine = new RecipeEngine(settings.vector_path);
    return {
      type: 'transformers',
      model: settings.model,
      similarity: engine.getRecommendations,
      max_recommendations: settings.max_recommendations
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


function parseRecipes(arr) {
  const dateRegex = /^\d{4}(-\d{2}){0,2}$/;

  return arr.map(str => {
    // Remove "recipes" prefix
    const rest = str.replace(/^recipes_?/, '');
    if (!rest) return { source: null, date: null };

    const parts = rest.split('_');
    let date = null;
    let source = null;

    // Try to detect the last part as a date
    const lastPart = parts[parts.length - 1];
    const secondLastPart = parts.length > 1 ? parts[parts.length - 2] : null;

    if (dateRegex.test(lastPart)) {
      date = lastPart;
      source = parts.slice(0, -1).join('_') || null;
    } else if (secondLastPart && dateRegex.test(parts.slice(-2).join('-'))) {
      // Handles split dates like ["2017","10","12"]
      date = parts.slice(-2).join('-');
      source = parts.slice(0, -2).join('_') || null;
    } else {
      source = parts.join('_') || null;
    }

    if(source){
      source = source.replaceAll("-", " ").replaceAll("_", " ")
    }
    return { source, date };
  });
}

/*
[// [object Object] 
{
  "source": "Exeter Cookbook",
  "date": "2017-10"
},// [object Object] 
{
  "source": "Exeter Cookbook",
  "date": "2017-10-12"
},// [object Object] 
{
  "source": null,
  "date": null
},// [object Object] 
{
  "source": "Exeter Cookbook",
  "date": "2017"
},// [object Object] 
{
  "source": "Exeter Cookbook Special",
  "date": "2018-03"
},// [object Object] 
{
  "source": "OnlySource",
  "date": null
},// [object Object] 
{
  "source": null,
  "date": "2021"
}]

const input = [
  "recipes_Exeter_Cookbook_2017-10",
  "recipes_Exeter_Cookbook_2017-10-12",
  "recipes",
  "recipes_Exeter_Cookbook_2017",
  "recipes_Exeter_Cookbook_Special_2018-03",
  "recipes_OnlySource",
  "recipes_2021"
];

console.log(parseRecipes(input));

*/

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




async function similarRecipes(recipe, recipes, amount=5, engine) {
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
    console.log(`Processing ${recipes.length} recipes...`);
    const config = loadJekyllConfig();
    const settings = getRecommendationSettings(config);
    const engine = createSimilarityEngine(settings);
    console.log(`Using ${engine.engine} for calculating similar recipes...`);
    // First pass: Pre-assign URLs so recommendations have valid links when rendered in JEKYLL. 
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

    // FIX: Use for...of instead of forEach to respect await
    for (const [index, recipe] of recipesWithUrls.entries()) {
      const id = recipe.id || (index + 1);
      const baseSlug = slugify(recipe.name || 'untitled-recipe');
      const fileName = `${baseSlug}-${id}.json`;
      const filePath = path.join(OUTPUT_DIR, 'recipes');
      ensureDir(filePath);

      console.log(`Processing similarities for: ${recipe.name}`);

      // Run Recommendation System (Await now works correctly)
      const recipeWithRecs = await similarRecipes(recipe, recipesWithUrls, 5, engine.similarity, settings.max_recommendations);

      delete recipeWithRecs.url; // if you don't it will get stuck in /recipe/#id.json in Jekyll build. 
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

    // ALL aggregate file writes below now wait until the loop above is 100% finished
    console.log('Finalizing aggregate files...');

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

    console.log('✅ Generation complete!');
  } catch (error) {
    console.error('❌ Error processing recipes:', error);
  }
};

generateRecipes();
