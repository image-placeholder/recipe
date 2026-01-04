#!/usr/bin/env sh

set -e

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
git commit -m "Add Recipe JSON Endpoint"
git push
