const fs = require('fs');
const path = require('path');

// 1. Configuration
// Data file is in the root _data folder
const DATA_FILE = path.join(process.cwd(), '_data', 'recipes.json');

// Output directory is in root/api/recipes
const OUTPUT_DIR = path.join(process.cwd(), 'api', 'recipes');

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

const generateRecipes = () => {
  try {
    // 2. Ensure the output directory exists
    if (!fs.existsSync(OUTPUT_DIR)) {
      fs.mkdirSync(OUTPUT_DIR, { recursive: true });
      console.log(`Created directory: ${OUTPUT_DIR}`);
    }

    // 3. Read and parse the JSON data
    const rawData = fs.readFileSync(DATA_FILE, 'utf8');
    const recipes = JSON.parse(rawData);

    console.log(`Processing ${recipes.length} recipes...`);

    // 4. Iterate and write individual files
    recipes.forEach((recipe, index) => {
      // Use recipe.id if it exists, otherwise use the array index
      const id = recipe.id || (index + 1);
      const baseSlug = slugify(recipe.title || 'untitled-recipe');
      
      // Combine slug and ID for uniqueness: "spaghetti-bolognese-1.json"
      const fileName = `${baseSlug}-${id}.json`;
      const filePath = path.join(OUTPUT_DIR, fileName);

      fs.writeFileSync(filePath, JSON.stringify(recipe, null, 2));
      console.log(`Successfully wrote: ${fileName}`);
    });

    console.log('Generation complete!');
  } catch (error) {
    console.error('Error processing recipes:', error.message);
  }
};

generateRecipes();
