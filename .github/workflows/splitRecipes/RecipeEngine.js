import { pipeline } from '@xenova/transformers';
import path from "path";
import fs from "fs";

 export class RecipeEngine {
  constructor(storagePath = './embeddings.json') {
    this.extractor = null;
    this.storagePath = path.resolve(storagePath);
    this.embeddingCache = new Map();
    
    // Load existing embeddings from disk immediately
    this._loadFromDisk();
  }

  async init() {
    if (!this.extractor) {
      // Note: In CommonJS, we use the standard package name
      this.extractor = await pipeline('feature-extraction', 'Xenova/all-MiniLM-L6-v2', {
        // q8 uses significantly less RAM than the default fp32
        dtype: 'q8', 
      });
    }
  }

  _loadFromDisk() {
    try {
      if (fs.existsSync(this.storagePath)) {
        const data = JSON.parse(fs.readFileSync(this.storagePath, 'utf8'));
        // Convert plain object back to Map
        this.embeddingCache = new Map(Object.entries(data));
        console.log(`💾 Loaded ${this.embeddingCache.size} embeddings from cache.`);
      }
    } catch (err) {
      console.error("⚠️ Could not load cache file, starting fresh:", err.message);
    }
  }

  _saveToDisk() {
    try {
      const data = Object.fromEntries(this.embeddingCache);
      fs.writeFileSync(this.storagePath, JSON.stringify(data), 'utf8');
    } catch (err) {
      console.error("⚠️ Failed to save embeddings to disk:", err);
    }
  }

  _prepareText(recipe) {
    const ingredients = recipe.recipeIngredient?.join(', ') || '';
    const keywords = Array.isArray(recipe.keywords) ? recipe.keywords.join(', ') : (recipe.keywords || '');
    return `Recipe: ${recipe.name}. Ingredients: ${ingredients}. Keywords: ${keywords}.`
      .toLowerCase()
      .replace(/\s+/g, ' ');
  }

  _similarity(v1, v2) {
    return v1.reduce((acc, val, i) => acc + val * v2[i], 0);
  }

  async precomputeEmbeddings(recipes) {
    // Only process recipes that don't have a cached ID
    const toProcess = recipes.filter(r => !this.embeddingCache.has(r.id || r.name));
    
    if (toProcess.length > 0) {
      await this.init();
      const texts = toProcess.map(r => this._prepareText(r));
      const output = await this.extractor(texts, { pooling: 'mean', normalize: true });

      toProcess.forEach((recipe, i) => {
        const vector = Array.from(output[i].data);
        const key = recipe.id || recipe.name;
        this.embeddingCache.set(key, vector);
      });

      // Persist new embeddings to JSON
      this._saveToDisk();
    }
  }

  async getRecommendations(targetRecipe, allRecipes, topN = 3) {
    const targetKey = targetRecipe.id || targetRecipe.name;

    // Ensure target and pool are embedded (checks cache first)
    await this.precomputeEmbeddings([targetRecipe, ...allRecipes]);

    const targetVec = this.embeddingCache.get(targetKey);

    return allRecipes
      .filter(r => (r.id || r.name) !== targetKey)
      .map(r => ({
        ...r,
        similarity: this._similarity(targetVec, this.embeddingCache.get(r.id || r.name))
      }))
      .sort((a, b) => b.similarity - a.similarity)
      .slice(0, topN)
      .map(r => ({ ...r, similarity: r.similarity.toFixed(4) }));
  }
}

// --- Example Usage ---

const recipes = [
  { id: "nacho-001", name: "Nacho Dip", keywords: ["dip"], recipeIngredient: ["cheese", "salsa"] },
  { id: "guac-002", name: "Guacamole", keywords: ["dip"], recipeIngredient: ["avocado", "lime"] },
  { id: "taco-003", name: "Beef Tacos", keywords: ["mexican"], recipeIngredient: ["beef", "shells"] }
];

async function run() {
  // Initialize with a custom filename
  const engine = new RecipeEngine('./recipe-vectors.json');

  const target = recipes[0];
  const results = await engine.getRecommendations(target, recipes, 2);

  console.log(`\nRecommendations for ${target.name}:`);
  results.forEach(r => console.log(`- ${r.name} (${(r.similarity * 100).toFixed(1)}%)`));
}

//run();
