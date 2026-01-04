#!/usr/bin/env sh

set -e

echo "Running post build script...."

echo "▶ Installing Font Awesome"

npm install --save @fortawesome/fontawesome-free
npm install --save copy-webpack-plugin

echo "✔ Font Awesome installed"

echo "▶ Installing Tailwind CSS"
npm install -g purgecss
npm install tailwindcss@3.4.17 postcss autoprefixer
echo "✔ Tailwind installed"
echo "▶ Compiling Tailwind CSS"
npx tailwindcss -i ./assets/css/_tailwind.css -o ./assets/css/tailwind.min.css --minify

echo "✔ Tailwind Compiled To /assets/css/tailwind.min.css"

# These are the Linux libraries Chrome needs to run in a headless environment
sudo apt update
sudo apt-get update
sudo apt-get install -y libgbm-dev libnss3 libatk-bridge2.0-0 libgtk-3-0 libasound2t64
npm install puppeteer


# Check for changes in _data/recipe

DATA_PATH="_data/recipe"
IS_GH_ACTIONS=false

# Detect GitHub Actions
if [ "$GITHUB_ACTIONS" = "true" ]; then
  IS_GH_ACTIONS=true
fi

# Ensure we're in a git repo
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Not in a git repository — running recipe pipeline unconditionally."
  RUN_PIPELINE=true
else
  # Check for previous commit
  if git rev-parse HEAD^ >/dev/null 2>&1; then
    if git diff --quiet HEAD^ HEAD -- "$DATA_PATH"; then
      echo "No changes in $DATA_PATH — skipping recipe processing."
      exit 0
    fi
    RUN_PIPELINE=true
  else
    echo "No previous commit found — running recipe pipeline."
    RUN_PIPELINE=true
  fi
fi

if [ "$RUN_PIPELINE" != "true" ]; then
  exit 0
fi

echo "Running recipe pipeline..."

npm install humanize-duration js-yaml @musement/iso-duration @huggingface/transformers @xenova/transformers

node --max-old-space-size=6144 .github/workflows/splitRecipes/splitRecipes.js

# If not on GitHub Actions, stop here (local build)
if [ "$IS_GH_ACTIONS" != "true" ]; then
  echo "Local build detected — skipping git commit and push."
  exit 0
fi

# Only commit if something changed
if git diff --quiet; then
  echo "No output changes to commit."
  exit 0
fi

git config --global user.email "github-actions[bot]@users.noreply.github.com"
git config --global user.name "github-actions[bot]"

git add .
git commit -m "Converted Recipes into JSON API Endpoints"
git push
