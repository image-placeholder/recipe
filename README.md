## ⚡ Quick Start

### Fetch all recipes
```http
GET /api/recipes.json
````

Returns full recipe data.

### Search / minimal info

```http
GET /api/search.json
```

Returns minimal recipe info for search or listings, including `name`, `author`, `category`, `cuisine`, and URL slug.

### Filter by category

```http
GET /api/categories/:slug.json
```

Example:

```http
GET /api/categories/salad.json
```

Returns all recipes in the `Salad` category.

### Filter by cuisine

```http
GET /api/cuisines/:slug.json
```

Example:

```http
GET /api/cuisines/american.json
```

Returns all recipes with `American` cuisine.

### Filter by author

```http
GET /api/authors/:slug.json
```

Example:

```http
GET /api/authors/meghan-brand.json
```

Returns all recipes authored by `Meghan Brand`.

### Get API stats

```http
GET /api/stats.json
```

Returns total counts for recipes, authors, categories, and cuisines.

---

# 📚 Recipe API Endpoints
Static JSON API powered by custom Node.js generators.

---

## 📝 Recipes

### 🔹 GET /api/recipes.json
Returns all recipes with full content.

**Example Response:**

```json
[
  {
    "name": "Bacon Broccoli Salad",
    "author": [
      {"name": "Meghan Brand"},
      {"name": "Mona Hamilton"}
    ],
    "description": "A hearty broccoli salad...",
    "recipeCategory": "Salad",
    "recipeCuisine": "American",
    "prepTime": "PT15M",
    "cookTime": "PT0M",
    "totalTime": "PT2H15M",
    "recipeYield": "6 servings",
    "recipeIngredient": ["3 cups broccoli florets", "½ cup low-fat yogurt"],
    "recipeInstructions": [
      {"text": "Combine the broccoli..."},
      {"text": "Mix together the dressing..."}
    ],
    "keywords": "broccoli salad, bacon salad, yogurt dressing"
  }
]
````

### 🔹 GET /api/recipes/:slug.json

Returns a single recipe by its unique slug.

**Example:**

`GET /api/recipes/bacon-broccoli-salad-1.json`

**Example Response:**

```json
{
  "name": "Bacon Broccoli Salad",
  "author": [
    {"name": "Meghan Brand"},
    {"name": "Mona Hamilton"}
  ],
  "description": "A hearty broccoli salad...",
  "recipeCategory": "Salad",
  "recipeCuisine": "American",
  "prepTime": "PT15M",
  "cookTime": "PT0M",
  "totalTime": "PT2H15M",
  "recipeYield": "6 servings",
  "recipeIngredient": ["3 cups broccoli florets", "½ cup low-fat yogurt"],
  "recipeInstructions": [
    {"text": "Combine the broccoli..."},
    {"text": "Mix together the dressing..."}
  ],
  "keywords": "broccoli salad, bacon salad, yogurt dressing"
}
```

---

## 🔍 Search Index

### 🔹 GET /api/search.json

Returns minimal recipe info optimized for search or listing.

**Example Response:**

```json
[
  {
    "name": "Bacon Broccoli Salad",
    "author": "Meghan Brand, Mona Hamilton",
    "keyword": "broccoli salad, bacon salad, yogurt dressing",
    "category": "Salad",
    "cuisine": "American",
    "url": "recipes/bacon-broccoli-salad-1"
  }
]
```

---

## 📂 Categories

### 🔹 GET /api/categories.json

Returns all categories with recipe count and slug.

**Example Response:**

```json
[
  {
    "name": "Salad",
    "slug": "salad",
    "count": 5
  },
  {
    "name": "Dessert",
    "slug": "dessert",
    "count": 3
  }
]
```

### 🔹 GET /api/categories/:slug.json

Returns all recipes in a given category.

**Example:**

`GET /api/categories/salad.json`

**Example Response:**

```json
[
  {
    "name": "Bacon Broccoli Salad",
    "author": "Meghan Brand, Mona Hamilton",
    "keyword": "broccoli salad, bacon salad, yogurt dressing",
    "category": "Salad",
    "cuisine": "American",
    "url": "recipes/bacon-broccoli-salad-1"
  }
]
```

---

## 🌎 Cuisines

### 🔹 GET /api/cuisines.json

Returns all cuisines with recipe count and slug.

**Example Response:**

```json
[
  {
    "name": "American",
    "slug": "american",
    "count": 7
  },
  {
    "name": "Italian",
    "slug": "italian",
    "count": 4
  }
]
```

### 🔹 GET /api/cuisines/:slug.json

Returns all recipes for a given cuisine.

**Example:**

`GET /api/cuisines/american.json`

**Example Response:**

```json
[
  {
    "name": "Bacon Broccoli Salad",
    "author": "Meghan Brand, Mona Hamilton",
    "keyword": "broccoli salad, bacon salad, yogurt dressing",
    "category": "Salad",
    "cuisine": "American",
    "url": "recipes/bacon-broccoli-salad-1"
  }
]
```

---

## 👤 Authors

### 🔹 GET /api/authors.json

Returns all authors with recipe counts and slug.

**Example Response:**

```json
[
  {
    "name": "Meghan Brand",
    "slug": "meghan-brand",
    "count": 4
  },
  {
    "name": "Mona Hamilton",
    "slug": "mona-hamilton",
    "count": 3
  }
]
```

### 🔹 GET /api/authors/:slug.json

Returns all recipes by a specific author.

**Example:**

`GET /api/authors/meghan-brand.json`

**Example Response:**

```json
[
  {
    "name": "Bacon Broccoli Salad",
    "author": "Meghan Brand, Mona Hamilton",
    "keyword": "broccoli salad, bacon salad, yogurt dressing",
    "category": "Salad",
    "cuisine": "American",
    "url": "recipes/bacon-broccoli-salad-1"
  }
]
```

---

## 📊 Stats

### 🔹 GET /api/stats.json

Returns basic statistics for the API.

**Example Response:**

```json
{
  "totalRecipes": 20,
  "totalAuthors": 6,
  "totalCategories": 5,
  "totalCuisines": 4
}
```

---

### ✅ Notes

* All slugs are **URL-friendly**: lowercase, hyphens instead of spaces, non-alphanumeric characters removed.
* Recipes can have **single or multiple authors**, both handled consistently.
* All listing endpoints (`categories`, `cuisines`, `authors`) return a **slug** for fetching the detailed list.

---

## ⚡ Dynamic Example Workflow: Fetching Recipes by Category, Cuisine, and Author

```javascript
const API_BASE = '/api';

// Fetch JSON helper
async function fetchJSON(url) {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`Failed to fetch ${url}`);
  return await res.json();
}

// Fetch all categories dynamically
async function fetchAllCategories() {
  return await fetchJSON(`${API_BASE}/categories.json`);
}

// Fetch all cuisines dynamically
async function fetchAllCuisines() {
  return await fetchJSON(`${API_BASE}/cuisines.json`);
}

// Fetch all authors dynamically
async function fetchAllAuthors() {
  return await fetchJSON(`${API_BASE}/authors.json`);
}

// Fetch recipes by slug for category, cuisine, or author
async function fetchRecipesBySlug(type, slug) {
  // type can be 'categories', 'cuisines', 'authors'
  return await fetchJSON(`${API_BASE}/${type}/${slug}.json`);
}

// Fetch search index
async function fetchSearchIndex() {
  return await fetchJSON(`${API_BASE}/search.json`);
}

// Local search function
function searchRecipes(recipes, query) {
  const lowerQuery = query.toLowerCase();
  return recipes.filter(r =>
    r.name.toLowerCase().includes(lowerQuery) ||
    r.author.toLowerCase().includes(lowerQuery) ||
    r.keyword.toLowerCase().includes(lowerQuery)
  );
}

// Example dynamic workflow
(async function main() {
  try {
    // 1. Fetch all dynamic categories, cuisines, authors
    const [categories, cuisines, authors] = await Promise.all([
      fetchAllCategories(),
      fetchAllCuisines(),
      fetchAllAuthors()
    ]);

    console.log('Available Categories:', categories.map(c => c.name));
    console.log('Available Cuisines:', cuisines.map(c => c.name));
    console.log('Available Authors:', authors.map(a => a.name));

    // 2. Pick first category, cuisine, author dynamically
    const firstCategorySlug = categories[0]?.slug;
    const firstCuisineSlug = cuisines[0]?.slug;
    const firstAuthorSlug = authors[0]?.slug;

    // 3. Fetch recipes for selected category, cuisine, and author
    const [categoryRecipes, cuisineRecipes, authorRecipes] = await Promise.all([
      fetchRecipesBySlug('categories', firstCategorySlug),
      fetchRecipesBySlug('cuisines', firstCuisineSlug),
      fetchRecipesBySlug('authors', firstAuthorSlug)
    ]);

    console.log(`Recipes in category "${categories[0].name}":`, categoryRecipes);
    console.log(`Recipes in cuisine "${cuisines[0].name}":`, cuisineRecipes);
    console.log(`Recipes by author "${authors[0].name}":`, authorRecipes);

    // 4. Fetch search index and perform local search
    const searchIndex = await fetchSearchIndex();
    const searchResults = searchRecipes(searchIndex, 'bacon'); // example search term
    console.log('Search Results for "bacon":', searchResults);

  } catch (error) {
    console.error('Error in dynamic workflow:', error);
  }
})();
```

### ✅ What this example demonstrates:

* Fetching **all recipes** and working with full content
* Filtering recipes by **category**, **cuisine**, or **author**
* Performing a **local search** in the minimal search index
* Using **async/await** and **fetch API** for modern front-end workflows

---

This workflow can be easily integrated into **React, Vue, or vanilla JS** projects to dynamically render recipes, filter lists, or implement a search feature.
