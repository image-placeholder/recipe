// 1. Better Vector Math using Maps (O(n) instead of O(n^2))
function cosineSimilarity(vec1, vec2) {
  let dotProduct = 0;
  let mag1 = 0;
  let mag2 = 0;

  // We only need to iterate over the keys of the smaller vector for the dot product
  for (const [term, weight] of vec1) {
    mag1 += weight ** 2;
    if (vec2.has(term)) {
      dotProduct += weight * vec2.get(term);
    }
  }
  
  for (const weight of vec2.values()) {
    mag2 += weight ** 2;
  }

  return dotProduct / (Math.sqrt(mag1) * Math.sqrt(mag2) || 1);
}

// 2. Advanced Feature Extraction with Weighting
function getFeatureMap(recipe) {
  const weights = new Map();
  
  const addTerm = (term, importance) => {
    if (!term) return;
    const clean = term.toLowerCase().trim().replace(/s$/, ''); // Very basic stemming
    weights.set(clean, (weights.get(clean) || 0) + importance);
  };

  // Weighting Strategy
  if (recipe.keywords) recipe.keywords.forEach(k => addTerm(k, 3));
  if (recipe.name) recipe.name.split(/\s+/).forEach(w => addTerm(w, 2));
  if (recipe.recipeIngredient) recipe.recipeIngredient.forEach(i => addTerm(i, 1));
  
  return weights;
}

// 3. Optimized Search
export function getSimilarRecipes(targetRecipe, allRecipes, topN = 3) {
  // Pre-process target
  const targetVec = getFeatureMap(targetRecipe);
  
  return allRecipes
    .filter(r => r.name !== targetRecipe.name)
    .map(r => ({
      recipe: r,
      score: cosineSimilarity(targetVec, getFeatureMap(r))
    }))
    .sort((a, b) => b.score - a.score)
    .slice(0, topN)
    .map(x => ({ ...x.recipe, similarity: x.score.toFixed(2) }));
}
