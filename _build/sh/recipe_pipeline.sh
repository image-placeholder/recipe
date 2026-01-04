#!/usr/bin/env sh

set -e

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

# -----------------------------
# Configure GitHub token for push
# -----------------------------
if [ -n "$GITHUB_TOKEN" ]; then
  git remote set-url origin "https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git"
fi


git config --global user.email "github-actions[bot]@users.noreply.github.com"
git config --global user.name "github-actions[bot]"

git add .
git commit -m "Add Recipe JSON Endpoint"
git push
