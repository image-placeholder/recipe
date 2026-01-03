# Recipes Data

Recipes **must be stored in `_data/recipes.json`** as an **array of Schema.org `Recipe` objects**.

Each entry in the array represents **one `Recipe` entity** and must conform to the **Schema.org [`Recipe`](https://schema.org/Recipe)** specification.

## Data Format

* `_data/recipes.json` must contain a **JSON array**
* Each array item must be a **valid `Recipe` object**
* The file must be valid JSON (no trailing commas, comments, or malformed values)

Example structure (simplified):

```json
[
  { "name": "Recipe One", "...": "..." },
  { "name": "Recipe Two", "...": "..." }
]
```

## Supported `Recipe` Properties

During the build process, recipe objects are **filtered to supported Schema.org `Recipe` properties**. Only the following properties are preserved and emitted:

* `url`
* `name`
* `image`
* `description`
* `prepTime`
* `cookTime`
* `totalTime`
* `recipeYield`
* `recipeIngredient`
* `recipeInstructions`
* `recipeCategory`
* `recipeCuisine`
* `keywords`

All other properties, including build-time or non-Schema.org fields, are removed.

## Build Pipeline

1. **Node.js preprocessing**

   * Parses `_data/recipes.json`
   * Validates and normalizes each `Recipe` object
   * May introduce temporary, build-time–only fields

2. **Jekyll generation**

   * Consumes the processed recipe data
   * Removes non-Schema.org and build-time properties
   * Generates:

     * Individual recipe pages
     * Paginated recipe indexes
     * Paginated `recipeCategory` and `recipeCuisine` archive pages

## Slug & URL Behavior

* Each recipe page is generated from its position in the array
* Slugs are derived from recipe identifiers during generation
* Duplicate slugs are automatically disambiguated

## Data Integrity

* All recipes must be valid `Recipe` objects
* Invalid or non-conforming entries may be excluded from the build
* Cleaned recipe data may be written back during the build process


# Build Hooks: Pre-Build & Post-Build

Our Jekyll project includes **pre-build** and **post-build** shell scripts that you can modify to customize your build process.

## File Locations

| Hook       | File Path                | Purpose                                                                                                                                                    |
| ---------- | ------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Pre-Build  | `_build/sh/preBuild.sh`  | Run any commands **before Jekyll builds**. For example: generating data files, cleaning directories, or installing dependencies like **Tailwind CSS**.     |
| Post-Build | `_build/sh/postBuild.sh` | Run any commands **after Jekyll has built the site**. For example: installing frontend packages like Font Awesome, running PurgeCSS, or processing assets. |



## Notes

* Scripts are written in **POSIX shell (`sh`)** for maximum portability.
* **Tailwind CSS is installed in `preBuild.sh`**, so your styles are compiled before Jekyll builds the site.
* Using these hooks lets you **extend your build process without modifying core Jekyll files**.
* Keep in mind the **order matters**:

  1. `preBuild.sh` runs **before** the Jekyll build.
  2. `postBuild.sh` runs **after** the Jekyll build completes.

---

## Example Use Cases

* **preBuild.sh**

  * Install **Tailwind CSS**
  * Compile Sass or other assets

* **postBuild.sh**
  * Optimize images or minify assets produced by Jekyll build.

# Recommendation System

The `_similar` array is **generated at build time** by the recipe recommendation system and is intended for use **only inside**:

```
_layouts/recipe.html
```

It enables rich, static “Similar Recipes” sections without JavaScript or runtime queries.

---

## How `_similar` Is Generated

During the build process:

1. All recipe JSON objects are **cloned** and assigned a stable `url`
2. A similarity algorithm compares the current recipe against all others
3. The top matches are attached to the recipe as `_similar`

The system evaluates similarity using:

* Keywords
* Category (`recipeCategory`)
* Cuisine (`recipeCuisine`)
* Textual overlap in name and description

The result is a **ranked list** of related recipes.

---

## `_similar` Recipe Object

Each item in the `_similar` array is a full recipe object and includes:

* `name` – recipe title
* `description` – short description
* `url` – relative link to the recipe page
* `similarity` – numeric score (`0–1`) indicating relevance
* `_naturalized_times`

  * `prepTime`
  * `cookTime`
  * `totalTime`

All other recipe schema fields are also available, including:

* `author`
* `recipeCategory`
* `recipeCuisine`
* `prepTime`, `cookTime`, `totalTime`

---

## Using `_similar` in a Recipe Page

In `_layouts/recipe.html`, iterate over `_similar` using standard Liquid:

```liquid
<h2>Similar Recipes</h2>
<ul>
{% for recipe in page._similar limit:3 %}
  <li>
    <a href="/{{ recipe.url }}">{{ recipe.name }}</a>
    {{ recipe.description }}
    {{ recipe.similarity }}
  </li>
{% endfor %}
</ul>
```

> Use `limit:3` (or any number) to control how many recommendations appear.

---

## Example Output

For the recipe **“Bacon Broccoli Salad”**, `_similar` might render:

```
Bacon Broccoli Salad
A hearty broccoli salad with crispy bacon, red onion, and a tangy dressing featuring low-fat yogurt and feta cheese.
recipes/bacon-broccoli-salad-63 0.49
```

---

## Fallback Behavior

If no `_similar` recipes are available:

1. Recipes from the same **category** are used
2. If no category matches exist, **cuisine-based** recipes are used
3. If no fallback data exists, the section is not rendered

This ensures recipe pages always feel intentional and complete.

---

## Modify the default simple engine

If you would like to customize, the simple recommendation simple modify the [similarRecipes.js](.github/workflows/splitRecipes/similarRecipes.js#L58) function written in JavaScript. 

---

## Notes

* `_similar` is **static** and generated during build
* No client-side JavaScript is required
* The recommendation system can be configured via `_config.yml`
* Supports simple similarity or transformer-based similarity engines

---

This system provides **editorial-quality recommendations** while remaining fast, predictable, and fully compatible with Jekyll’s static build process.



# Recommendation System (first draft)

The recipe recommendation system generates a `_similar` array **at build time** and attaches it to each recipe object.
This data is intended for use **only inside**:

```
_layouts/recipe.html
```

It enables fully static, high-quality “Similar Recipes” sections with no runtime JavaScript.

---

## How Recommendations Are Generated

During the build process:

1. All recipe JSON objects are **cloned** and assigned stable `url` values
2. A similarity engine compares the current recipe against all others
3. The highest-scoring matches are attached as `_similar`

The system supports **two similarity engines**:

* **Simple similarity** (default)
* **Transformer-based similarity** (optional)

The engine is selected via Jekyll configuration.

---

## Similarity Engines

### 1. Simple Similarity (Default)

Used when:

* No configuration is provided
* Configuration is missing or invalid

**How it works:**

* Tokenizes and compares text from:

  * Recipe name
  * Description
  * Keywords
  * Category (`recipeCategory`)
  * Cuisine (`recipeCuisine`)
* Calculates overlap and assigns a similarity score

**Pros**

* Fast
* No dependencies
* Deterministic
* Ideal for most sites

---

### 2. Transformer-Based Similarity (Optional)

Enabled explicitly via `_config.yml`.

**How it works:**

* Uses text embeddings generated by a transformer model
* Compares recipes using semantic similarity
* Produces more nuanced matches for large archives

**Pros**

* Better semantic understanding
* Handles phrasing differences well

**Cons**

* Slower
* Requires additional dependencies
* Higher build cost

---

## Configuration (`_config.yml`)

All configuration is optional.
If anything is missing, the system **fails safely** to simple similarity.

### Basic Configuration

```yml
recommendations:
  engine: simple
```

### Enable Transformers

```yml
recommendations:
  engine: transformers
  model: all-MiniLM-L6-v2
```

### Supported Options

| Key      | Description                | Default            |
| -------- | -------------------------- | ------------------ |
| `engine` | `simple` or `transformers` | `simple`           |
| `model`  | Transformer model name     | `all-MiniLM-L6-v2` |

---

## Failure & Fallback Behavior

The system is defensive by design:

| Scenario                  | Result            |
| ------------------------- | ----------------- |
| `_config.yml` missing     | Simple similarity |
| `recommendations` missing | Simple similarity |
| Invalid `engine`          | Simple similarity |
| Missing `model`           | Default model     |
| Transformer failure       | Simple similarity |

Builds will **never fail** due to recommendation configuration.

---

## `_similar` Recipe Object

Each item in the `_similar` array includes:

* `name` – recipe title
* `description` – short description
* `url` – relative link to the recipe page
* `similarity` – numeric score (`0–1`)
* `_naturalized_times`

  * `prepTime`
  * `cookTime`
  * `totalTime`

All other recipe schema fields are also available.

---

## Using `_similar` in a Recipe Page

In `_layouts/recipe.html`:

```liquid
<h2>Similar Recipes</h2>
<ul>
{% for recipe in page._similar limit:3 %}
  <li>
    <a href="/{{ recipe.url }}">{{ recipe.name }}</a>
    {{ recipe.description }}
    {{ recipe.similarity }}
  </li>
{% endfor %}
</ul>
```

---

## Example Output

```
Bacon Broccoli Salad
A hearty broccoli salad with crispy bacon, red onion, and a tangy dressing featuring low-fat yogurt and feta cheese.
recipes/bacon-broccoli-salad-63 0.49
```

---

## Fallback Rendering (UI)

If `_similar` is empty:

1. Recipes from the same **category** are shown
2. If none exist, recipes from the same **cuisine** are shown
3. If still empty, the section is not rendered

This guarantees consistent, editorial-quality pages.

---

## Summary

* Recommendations are **static**
* Configuration is **optional**
* Defaults are **safe**
* Transformer support is **opt-in**
* No runtime JavaScript required

This approach balances **quality, performance, and reliability** for a static recipe archive.

---
 



# Recommendation System

* The `_similar` array is **generated using a recommendation algorithm** and is available ONLY to use in `_layouts/recipe.html`.
* It finds recipes that are most similar to the current recipe based on:

  * Keywords
  * Category (`recipeCategory`)
  * Cuisine (`recipeCuisine`)
* Each recipe in `_similar` includes:
  * `url` – link to that recipe page
  * `_naturalized_times` – human-readable prep/cook/total times
  * `similarity` – a numeric score (0–1) representing how similar it is to the current recipe
  * You can use any other fields from the JSON schema (`prepTime`, `cookTime`, `author`, etc.) in the template.
* This allows you to **dynamically populate similar recipes** on each recipe page during your Jekyll build.

  

## Using `_similar` in a Recipe Page

In your `_layouts/recipe.html`, you can iterate over the `_similar` array using standard Jekyll/Liquid syntax:

```liquid
<h2>Similar Recipes</h2>
<ul>
{% for recipe in page._similar %}
  <li>
    <a href="{{ recipe.url }}">{{ recipe.name }}</a>  
    - {{ recipe.description }}  
    - Similarity: {{ recipe.similarity }}
  </li>
{% endfor %}
</ul>
```

## Example Output

For example, using the `_similar` array for a "Bacon Broccoli Salad" recipe might produce:

```
Bacon Broccoli Salad  
A hearty broccoli salad with crispy bacon, red onion, and a tangy dressing featuring low-fat yogurt and feta cheese.  
recipes/bacon-broccoli-salad-63 0.49
```

---

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
