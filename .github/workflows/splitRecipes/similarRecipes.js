// Cosine similarity for arrays of strings
function cosineSimilarity(arr1, arr2) {
  const set = new Set([...arr1, ...arr2]);
  const vec1 = [], vec2 = [];
  set.forEach(word => {
    vec1.push(arr1.includes(word) ? 1 : 0);
    vec2.push(arr2.includes(word) ? 1 : 0);
  });
  let dot = 0, mag1 = 0, mag2 = 0;
  for (let i = 0; i < vec1.length; i++) {
    dot += vec1[i] * vec2[i];
    mag1 += vec1[i] ** 2;
    mag2 += vec2[i] ** 2;
  }
  return dot / (Math.sqrt(mag1) * Math.sqrt(mag2) || 1);
}

// Flatten and weight recipe features
function flattenFeatures(recipe) {
  const words = [];

  // High weight: keywords (weight 3)
  if (recipe.keywords) {
    recipe.keywords.split(',').forEach(k =>
      words.push(...k.toLowerCase().split(/\s+/).map(w => w + '_kw')) // add suffix to distinguish
    );
  }

  // Medium weight: recipeCategory and recipeCuisine
  if (recipe.recipeCategory) words.push(recipe.recipeCategory.toLowerCase() + '_cat');
  if (recipe.recipeCuisine) words.push(recipe.recipeCuisine.toLowerCase() + '_cui');

   // Lower weight: ingredients (weight 1)
  if (recipe.recipeIngredient) {
    recipe.recipeIngredient.forEach(ing =>
      words.push(...ing.toLowerCase().split(/\s+/).map(w => w + '_ing'))
    );
  }
  
     // Lower weight: ingredients (weight 1)
  if (recipe.name) {
    recipe.name.split(" ").forEach(ing =>
      words.push(...ing.toLowerCase().split(/\s+/).map(w => w + '_ing'))
    );
  }

  // Remove generic stopwords
  const stopwords = new Set(['cup', 'tbsp', 'tsp', 'dash', 'small', 'medium', 'large', 'oz', 'in', 'a', 'quick', 'easy', 'fast', 'dip']);
  return words.map(w => w.trim()).filter(Boolean).filter(w => !stopwords.has(w.replace(/_.*$/, '')));
}

// Get top N similar recipes to a target
export function getSimilarRecipes(targetRecipe, recipes, topN = 3) {
  const targetFeatures = flattenFeatures(targetRecipe);
  const sameCategory = true;
  return recipes
    .filter(r => r.name !== targetRecipe.name)
    .filter(r => !sameCategory || r.recipeCategory === targetRecipe.recipeCategory)
    .map(r => {
      const score = cosineSimilarity(targetFeatures, flattenFeatures(r));
      return { recipe: r, score };
    })
    .sort((a, b) => b.score - a.score)
    .slice(0, topN)
    .map(x => ({ ...x.recipe, similarity: x.score.toFixed(2) }));
}

/*

// Example dataset
const recipes = [
  {
    name: "Nacho Dip",
    keywords: ["nacho dip","creamy dip","taco seasoning","salsa dip"],
    recipeIngredient: [
      "8 oz pkg cream cheese",
      "500 g tub sour cream",
      "¼ pkg taco seasoning mix",
      "1 cup shredded cheddar cheese",
      "1 small container salsa sauce",
      "1 chopped red pepper",
      "1 chopped green pepper",
      "1 chopped tomato",
      "Baked nacho chips for serving"
    ]
  },
  {
    name: "Guacamole",
    keywords: ["guacamole","avocado","dip","mexican"],
    recipeIngredient: [
      "2 avocados",
      "1 lime",
      "1 small tomato",
      "Salt and pepper"
    ]
  },
  {
    name: "Cheese Quesadilla",
    keywords: ["quesadilla","cheese","mexican"],
    recipeIngredient: [
      "Tortillas",
      "Cheddar cheese",
      "Butter"
    ]
  },
  {
    name: "Salsa",
    keywords: ["salsa","tomato","dip"],
    recipeIngredient: [
      "4 tomatoes",
      "1 small onion",
      "1 jalapeno",
      "Cilantro",
      "Salt"
    ]
  }
];

// Get top N similar recipes to a target
function getSimilarRecipes(targetRecipe, topN = 2) {
  const targetFeatures = flattenFeatures(targetRecipe);

  return recipes
    .filter(r => r.name !== targetRecipe.name)
    .map(r => {
      const score = cosineSimilarity(targetFeatures, flattenFeatures(r));
      return { recipe: r, score };
    })
    .sort((a, b) => b.score - a.score)
    .slice(0, topN)
    .map(x => ({ ...x.recipe, similarity: x.score.toFixed(2) })); // include similarity
}

// Example usage: recommend for Nacho Dip
const recipe = recipes[0];
const recommendations = getSimilarRecipes(recipe, recipes, 2);
console.log(`Recommended recipes for ${recipe.name}:`);
console.log("Recommended recipes for Nacho Dip:");
recommendations.forEach(r => console.log(`${r.name} (similarity: ${r.similarity})`));
*/
 
