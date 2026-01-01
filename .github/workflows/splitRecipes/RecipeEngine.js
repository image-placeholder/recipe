import { pipeline } from '@xenova/transformers';
import path from "path";
import fs from "fs";

class RecipeEngine {
  constructor(storagePath = './embeddings.json') {
    this.storagePath = storagePath;
    this.extractor = null;
    this.cache = this._loadCache();
  }

  async init() {
    if (!this.extractor) {
      this.extractor = await pipeline('feature-extraction', 'Xenova/all-MiniLM-L6-v2', {
        // q8 uses significantly less RAM than the default fp32
        dtype: 'q8', 
      });
    }
  }

  _loadCache() {
    if (fs.existsSync(this.storagePath)) {
      return JSON.parse(fs.readFileSync(this.storagePath, 'utf8'));
    }
    return {};
  }

  /**
   * Process in small batches to prevent Exit Code 143
   */
  async buildIndex(recipes, batchSize = 5) {
    await this.init();
    const toProcess = recipes.filter(r => !this.cache[r.id || r.name]);
    
    console.log(`Processing ${toProcess.length} new recipes in batches of ${batchSize}...`);

    for (let i = 0; i < toProcess.length; i += batchSize) {
      const batch = toProcess.slice(i, i + batchSize);
      const texts = batch.map(r => `${r.name} ${r.recipeIngredient.join(' ')}`);
      
      // Compute embeddings for the batch
      const output = await this.extractor(texts, { pooling: 'mean', normalize: true });

      // Save to local cache object
      batch.forEach((recipe, idx) => {
        this.cache[recipe.id || recipe.name] = Array.from(output[idx].data);
      });

      // Periodic save to disk to keep memory low
      fs.writeFileSync(this.storagePath, JSON.stringify(this.cache));
      console.log(`Buffered batch ${Math.floor(i / batchSize) + 1}`);
      
      // Manual delay to allow Node.js garbage collection to breathe
      await new Promise(resolve => setTimeout(resolve, 100));
    }
  }

  _similarity(v1, v2) {
    return v1.reduce((acc, val, i) => acc + val * v2[i], 0);
  }

  getSimilar(targetId, allRecipes, topN = 3) {
    const targetVec = this.cache[targetId];
    if (!targetVec) return [];

    return allRecipes
      .filter(r => (r.id || r.name) !== targetId)
      .map(r => ({
        ...r,
        score: this._similarity(targetVec, this.cache[r.id || r.name])
      }))
      .sort((a, b) => b.score - a.score)
      .slice(0, topN);
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
