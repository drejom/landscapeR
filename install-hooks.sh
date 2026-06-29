#!/usr/bin/env bash
# Symlink repo hooks into .git/hooks/ so they run automatically.
# Run once after cloning: bash install-hooks.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
HOOKS_SRC="$REPO_ROOT/hooks"
HOOKS_DST="$REPO_ROOT/.git/hooks"

for hook in "$HOOKS_SRC"/*; do
  name=$(basename "$hook")
  target="$HOOKS_DST/$name"
  chmod +x "$hook"
  ln -sf "$REPO_ROOT/hooks/$name" "$target"
  echo "  linked $name → .git/hooks/$name"
done

echo "Hooks installed. Run 'git push' to verify."
