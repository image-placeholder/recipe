import { pipeline } from '@xenova/transformers';
import path from "path";
import fs from "fs";


export class RecipeEngine {
  constructor(storagePath = './recipe-vectors.json') {
    this.storagePath = path.resolve(storagePath);
    this.extractor = null;
    this.cache = this._loadCache();
  }

  async init() {
    if (!this.extractor) {
      this.extractor = await pipeline('feature-extraction', 'Xenova/all-MiniLM-L6-v2', {
        dtype: 'q8', 
      });
    }
  }

  _loadCache() {
    if (fs.existsSync(this.storagePath)) {
      try {
        return JSON.parse(fs.readFileSync(this.storagePath, 'utf8'));
      } catch (e) {
        console.error("Malformed cache file, resetting.");
        return {};
      }
    }
    return {};
  }

  async buildIndex(recipes, batchSize = 5) {
    await this.init();
    const toProcess = recipes.filter(r => !this.cache[r.id || r.name]);
    
    if (toProcess.length === 0) return;

    for (let i = 0; i < toProcess.length; i += batchSize) {
      const batch = toProcess.slice(i, i + batchSize);
      const texts = batch.map(r => `${r.name} ${r.recipeIngredient?.join(' ') || ''}`);
      
      const output = await this.extractor(texts, { pooling: 'mean', normalize: true });

      batch.forEach((recipe, idx) => {
        this.cache[recipe.id || recipe.name] = Array.from(output[idx].data);
      });

      fs.writeFileSync(this.storagePath, JSON.stringify(this.cache));
      await new Promise(resolve => setTimeout(resolve, 50));
    }
  }

  _similarity(v1, v2) {
    if (!v1 || !v2) return 0;
    return v1.reduce((acc, val, i) => acc + val * v2[i], 0);
  }

  async getRecommendations(targetRecipe, allRecipes, topN = 3) {
    const targetId = targetRecipe.id || targetRecipe.name;
    
    // CRITICAL FIX: Ensure all recipes (including target) are in cache
    await this.buildIndex([targetRecipe, ...allRecipes]);

    const targetVec = this.cache[targetId];
    if (!targetVec) return [];

    return allRecipes
      .filter(r => (r.id || r.name) !== targetId)
      .map(r => {
        const score = this._similarity(targetVec, this.cache[r.id || r.name]);
        return { ...r, score };
      })
      .sort((a, b) => b.score - a.score)
      .slice(0, topN);
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
