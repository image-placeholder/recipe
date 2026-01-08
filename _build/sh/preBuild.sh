#!/usr/bin/env sh

set -e

#!/bin/sh

# --- Jekyll Config Utility ---

# Load Jekyll YAML into prefixed shell variables
load_jekyll_config() {
    local config_file="${1:-_config.yml}"
    local prefix="_jekyll_"
    
    if [ ! -f "$config_file" ]; then
        printf "[\033[31mERROR\033[0m] %s not found.\n" "$config_file" >&2
        return 1
    fi

    if ! command -v yq >/dev/null 2>&1; then
        printf "[\033[31mERROR\033[0m] 'yq' (Mike Farah version) is required.\n" >&2
        return 1
    fi

    # Parse, prefix, and load
    eval "$(yq -o=shell "$config_file" | sed "s/^/${prefix}/")"
    printf "[\033[32mSUCCESS\033[0m] Variables loaded with prefix: %s\n" "$prefix"
}

# Remove all loaded Jekyll variables from memory
cleanup_jekyll_config() {
    local prefix="_jekyll_"
    
    # Get a list of all variable names starting with the prefix and unset them
    # 'set' lists variables; 'cut' gets the name before the '='
    for var in $(set | grep "^${prefix}" | cut -d'=' -f1); do
        unset "$var"
    done
    
    printf "[\033[34mCLEANUP\033[0m] All %s* variables have been unset.\n" "$prefix"
}

# --- Workflow Example ---

# 1. Load the data
load_jekyll_config

# 2. Use the data
echo "Site Name: $_jekyll_title"

# 3. Clean up when done
cleanup_jekyll_config

# Verification: This will now be empty
echo "After cleanup: [$_jekyll_title]"

echo "Running post build script...."

echo "▶ Purging Jekyll Cache"
rm -rf .jekyll-cache
echo "✔ Cached Purged"

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
npm install liquid glob js-yaml front-matter lazysizes markmap-lib markmap-view tocbot leaflet.markercluster leaflet vanillajs-datepicker @knadh/autocomp --save
npm run build
npx tailwindcss -i ./assets/css/_tailwind.css -o ./assets/css/tailwind.min.css --minify

echo "✔ Pre Webpack Build Completed"
