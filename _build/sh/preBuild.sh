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
if git diff --quiet HEAD^ HEAD -- _data/recipe; then
  echo "No changes in _data/recipe — skipping recipe processing."
  exit 0
fi

echo "Changes detected in _data/recipe — running recipe pipeline."

npm install humanize-duration js-yaml @musement/iso-duration @huggingface/transformers @xenova/transformers

node --max-old-space-size=6144 .github/workflows/splitRecipes/splitRecipes.js

# Only commit if something actually changed
if git diff --quiet; then
  echo "No output changes to commit."
  exit 0
fi

git config --global user.email "github-actions[bot]@users.noreply.github.com"
git config --global user.name "github-actions[bot]"

git add .
git commit -m "Add converted CSV to JSON output"
git push
