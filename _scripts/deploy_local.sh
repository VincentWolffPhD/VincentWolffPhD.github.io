#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# Sanity-Check
if [ ! -f "_config.yml" ]; then
  echo "Bitte im Repo-Root ausführen (hier fehlt _config.yml)." >&2
  exit 1
fi

echo "==> Bundle check/build"
bundle check || bundle install
export JEKYLL_ENV=production
bundle exec jekyll build

# Optional: PurgeCSS, falls vorhanden
if command -v purgecss >/dev/null 2>&1 && [ -f "purgecss.config.js" ]; then
  echo "==> PurgeCSS"
  purgecss -c purgecss.config.js || echo "PurgeCSS übersprungen"
else
  echo "==> PurgeCSS nicht verfügbar, überspringe"
fi

# Robust: Deploy ohne Worktree
TMP_DIR="$(mktemp -d)"
echo "==> Kopiere _site nach $TMP_DIR"
rsync -av --delete "_site/" "$TMP_DIR"/
touch "$TMP_DIR/.nojekyll"

ORIGIN_URL="$(git remote get-url origin)"

pushd "$TMP_DIR" >/dev/null
git init -q
git add -A
git -c user.name="Auto Deploy" -c user.email="deploy@local" commit -m "Deploy site"
git branch -M gh-pages
git remote add origin "$ORIGIN_URL"
git push -u --force origin gh-pages
popd >/dev/null

rm -rf "$TMP_DIR"

echo "==> Fertig. Stelle GitHub Pages jetzt auf Branch gh-pages:"
echo "    https://github.com/VincentWolffPhD/VincentWolffPhD.github.io/settings/pages"
echo "    Source: Deploy from a branch, Branch: gh-pages, Folder: /"
