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
SCRIPT_PATH=".github/workflows/splitRecipes/splitRecipes.js"
CACHE_DIR=".npm-cache"

# Detect GitHub Actions
IS_GH_ACTIONS=false
[ "$GITHUB_ACTIONS" = "true" ] && IS_GH_ACTIONS=true

echo "Environment:"
echo "  GitHub Actions: $IS_GH_ACTIONS"
echo "  OS: $(uname -s)"

# -----------------------------
# NPM CACHE (portable)
# -----------------------------
mkdir -p "$CACHE_DIR"
npm config set cache "$CACHE_DIR" --global

# -----------------------------
# GIT AVAILABILITY CHECK
# -----------------------------
if command -v git >/dev/null 2>&1; then
  HAS_GIT=true
else
  HAS_GIT=false
fi

# -----------------------------
# CHANGE DETECTION
# -----------------------------
if [ "$HAS_GIT" = "true" ] && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  if git rev-parse HEAD^ >/dev/null 2>&1; then
    if git diff --name-only HEAD^ HEAD -- "$DATA_PATH" | grep -q .; then
      echo "Changes detected in $DATA_PATH."
    else
      echo "No changes in $DATA_PATH — skipping recipe processing."
      exit 0
    fi
  else
    echo "No previous commit — running recipe pipeline."
  fi
else
  echo "Git not available or not a repository — running recipe pipeline."
fi

# -----------------------------
# RUN PIPELINE
# -----------------------------
echo "Running recipe pipeline..."

npm install \
  humanize-duration \
  js-yaml \
  @musement/iso-duration \
  @huggingface/transformers \
  @xenova/transformers

node --max-old-space-size=6144 "$SCRIPT_PATH"

# -----------------------------
# STOP HERE IF NOT CI
# -----------------------------
if [ "$IS_GH_ACTIONS" != "true" ]; then
  echo "Local or non-Git environment — skipping git commit and push."
  exit 0
fi

# -----------------------------
# COMMIT & PUSH (CI ONLY)
# -----------------------------
if [ "$HAS_GIT" != "true" ]; then
  echo "Git not available — cannot commit."
  exit 0
fi

if git diff --quiet; then
  echo "No output changes to commit."
  exit 0
fi

git config --global user.email "github-actions[bot]@users.noreply.github.com"
git config --global user.name "github-actions[bot]"

git add .
git commit -m "Add converted CSV to JSON output"
git push
