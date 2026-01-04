#!/usr/bin/env sh
OG_PATH="assets/og-images"
TARGET_BRANCH="main"

echo "▶ Running post build script for OG images..."

# -----------------------------
# Environment checks
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
# Branch check (detached HEAD safe)
# -----------------------------
CURRENT_BRANCH="$(git branch --show-current 2>/dev/null || echo "$GITHUB_REF_NAME")"

if [ "$CURRENT_BRANCH" != "$TARGET_BRANCH" ]; then
  echo "Current branch is '$CURRENT_BRANCH' (not '$TARGET_BRANCH') — skipping commit."
  exit 0
fi

# -----------------------------
# Check for changes
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
# Configure GitHub token for push
# -----------------------------
if [ -n "$GITHUB_TOKEN" ]; then
  git remote set-url origin "https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git"
fi

# -----------------------------
# Commit & push
# -----------------------------
git config --global user.email "github-actions[bot]@users.noreply.github.com"
git config --global user.name "github-actions[bot]"

git add "$OG_PATH"
git commit -m "Add/update generated OG images"
git push --quiet

echo "▶ Post build script finished."
