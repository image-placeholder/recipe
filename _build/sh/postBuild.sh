#!/usr/bin/env sh
set -e

echo "▶ Running post build script for OG images..."

OG_PATH="assets/og-images"
TARGET_BRANCH="main"

# -----------------------------
# ENVIRONMENT CHECKS
# -----------------------------
if [ "$GITHUB_ACTIONS" != "true" ]; then
  echo "Not running in GitHub Actions — skipping."
  exit 0
fi

if ! command -v git >/dev/null 2>&1; then
  echo "Git not available — skipping."
  exit 0
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Not inside a git repository — skipping."
  exit 0
fi

# -----------------------------
# BRANCH CHECK
# -----------------------------
CURRENT_BRANCH="$(git branch --show-current 2>/dev/null || echo "$GITHUB_REF_NAME")"

if [ "$CURRENT_BRANCH" != "$TARGET_BRANCH" ]; then
  echo "Current branch is '$CURRENT_BRANCH' (not '$TARGET_BRANCH') — skipping commit."
  exit 0
fi

# -----------------------------
# CHECK FOR OG IMAGE CHANGES
# -----------------------------
if [ ! -d "$OG_PATH" ]; then
  echo "No $OG_PATH directory — nothing to commit."
  exit 0
fi

if git diff --quiet -- "$OG_PATH"; then
  echo "No changes detected in $OG_PATH — skipping commit."
  exit 0
fi

# -----------------------------
# COMMIT & PUSH
# -----------------------------
echo "Changes detected in $OG_PATH — committing to $TARGET_BRANCH..."

git config --global user.email "github-actions[bot]@users.noreply.github.com"
git config --global user.name "github-actions[bot]"

git add "$OG_PATH"
git commit -m "Add/update generated OG images"
git push --quiet

echo "▶ Post build script finished."
