#!/usr/bin/env sh
set -e


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
