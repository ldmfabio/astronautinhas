#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/site/dist"
BRANCH="gh-pages"
REMOTE="origin"

cd "$ROOT_DIR"

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "Erro: há alterações locais não commitadas. Faça commit ou stash antes do deploy." >&2
  exit 1
fi

python3 scripts/validate_content.py
npm --prefix site install
GITHUB_PAGES=true npm --prefix site run build

if [[ ! -f "$DIST_DIR/index.html" ]]; then
  echo "Erro: build não gerou site/dist/index.html." >&2
  exit 1
fi

git fetch "$REMOTE" "$BRANCH" 2>/dev/null || true

TMP_DIR="$(mktemp -d)"
cleanup() {
  git worktree remove --force "$TMP_DIR" >/dev/null 2>&1 || true
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

if git show-ref --verify --quiet "refs/remotes/$REMOTE/$BRANCH"; then
  git worktree add --detach "$TMP_DIR" "$REMOTE/$BRANCH"
else
  git worktree add --detach "$TMP_DIR" HEAD
  (
    cd "$TMP_DIR"
    git checkout --orphan "$BRANCH"
    git rm -rf . >/dev/null 2>&1 || true
  )
fi

find "$TMP_DIR" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
cp -a "$DIST_DIR"/. "$TMP_DIR"/
touch "$TMP_DIR/.nojekyll"

(
  cd "$TMP_DIR"
  git add -A
  if git diff --cached --quiet; then
    echo "Nenhuma alteração no site publicado."
    exit 0
  fi
  git commit -m "deploy: publish Astronautinhas site"
  git push "$REMOTE" HEAD:"$BRANCH"
)

echo "Publicado em: https://ldmfabio.github.io/astronautinhas/"
