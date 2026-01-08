#!/usr/bin/env sh
set -e

# Ensure every HTML file has a <title> and a meta description
for file in $(find ./_site -name "*.html"); do
    if ! grep -q "<title>" "$file"; then
        printf "[\033[31mSEO WARN\033[0m] Missing title in %s\n" "$file"
    fi
done

# -----------------------------
# RUN OG COMMITER (COMMIT ANY FILES CREATED BY OG IMAGE GENERATOR PLUGIN)
# -----------------------------
chmod +x _build/sh/commit_og_images.sh
./_build/sh/commit_og_images.sh



# 2. Run Pagefind to index the built site
# --site _site points to Jekyll's default output folder
echo "Running Pagefind indexing..."
npx -y pagefind --site _site





echo "Build and Indexing complete!"
