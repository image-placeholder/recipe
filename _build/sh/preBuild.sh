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

echo "▶ Installing OG Image Generation Dependencies"
# These are the Linux libraries Chrome needs to run in a headless environment 
sudo apt update
sudo apt-get update
sudo apt-get install -y libgbm-dev libnss3 libatk-bridge2.0-0 libgtk-3-0 libasound2t64
npm install puppeteer
echo "✔ OG Image Generation Dependencies Installed"

# -----------------------------
# RUN RECIPE PIPELINE (SPLIT & RANK SIMILARITES)
# -----------------------------
chmod +x _build/sh/recipe_pipeline.sh
./_build/sh/recipe_pipeline.sh

echo "▶ Running Webpack Build (Pre-Build)"

npm i
npm install liquid js-yaml front-matter lazysizes markmap-lib markmap-view tocbot leaflet.markercluster leaflet vanillajs-datepicker @knadh/autocomp --save
npm run build
npx tailwindcss -i ./assets/css/_tailwind.css -o ./assets/css/tailwind.min.css --minify

echo "✔ Pre Webpack Build Completed"
