#!/usr/bin/env sh

set -e

echo "Running post build script...."

# put any of your post build scripts here


#!/bin/sh
set -e

OG_PATH="assets/og-images"
TARGET_BRANCH="gh-pages"

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
  echo "Not in a git repository — skipping."
  exit 0
fi

# -----------------------------
# BRANCH CHECK (GH PAGES ONLY)
# -----------------------------
CURRENT_BRANCH="$(git branch --show-current 2>/dev/null || true)"

if [ "$CURRENT_BRANCH" != "$TARGET_BRANCH" ]; then
  echo "Current branch is '$CURRENT_BRANCH' (not '$TARGET_BRANCH') — skipping."
  exit 0
fi

# -----------------------------
# CHANGE CHECK
# -----------------------------
if [ ! -d "$OG_PATH" ]; then
  echo "No $OG_PATH directory — nothing to commit."
  exit 0
fi

if git diff --quiet -- "$OG_PATH"; then
  echo "No changes detected in $OG_PATH."
  exit 0
fi

# -----------------------------
# COMMIT & PUSH
# -----------------------------
echo "Committing OG images on $TARGET_BRANCH."

git config --global user.email "github-actions[bot]@users.noreply.github.com"
git config --global user.name "github-actions[bot]"

git add "$OG_PATH"
git commit -m "Add/update generated OG images"
git push

echo "▶ Post build script finished"
