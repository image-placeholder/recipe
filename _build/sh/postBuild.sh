#!/usr/bin/env sh
set -e


# -----------------------------
# RUN OG COMMITER (COMMIT ANY FILES CREATED BY OG IMAGE GENERATOR PLUGIN)
# -----------------------------
chmod +x _build/sh/commit_og_images.sh
./_build/sh/commit_og_images.sh
