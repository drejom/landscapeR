#!/usr/bin/env bash
# Enforce ADR 0021: package-owned transient output belongs under .scratch/.

set -euo pipefail

REPO_ROOT="${1:-}"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || {
    echo "ERROR: repository root could not be resolved." >&2
    exit 2
  }
fi

if [[ ! -d "$REPO_ROOT/.git" && ! -f "$REPO_ROOT/.git" ]]; then
  echo "ERROR: not a Git worktree: $REPO_ROOT" >&2
  exit 2
fi

UNEXPECTED=()
while IFS= read -r -d '' entry; do
  [[ "${entry:0:2}" == "??" ]] || continue
  path="${entry:3}"
  [[ "$path" == ".scratch" || "$path" == .scratch/* ]] && continue
  UNEXPECTED+=("$path")
done < <(git -C "$REPO_ROOT" status --porcelain=v1 -z --untracked-files=all --ignored=no)

if [[ ${#UNEXPECTED[@]} -gt 0 ]]; then
  echo "ERROR: unexpected untracked files outside .scratch/:" >&2
  for path in "${UNEXPECTED[@]}"; do
    printf '  %s\n' "$path" >&2
  done
  echo "Commit deliberate artifacts, remove residue, or route transient output through configured .scratch/ paths." >&2
  exit 1
fi

echo "✓ Repository hygiene: no unexpected untracked files outside .scratch/."
