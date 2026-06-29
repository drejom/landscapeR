#!/usr/bin/env bash
# Enforce registry-based dispatch patterns in R/
#
# Violations caught:
#   1. if (method == "...") dispatchers — use register_strategy() instead
#   2. switch(method, ...) dispatchers — same
#   3. Hard-coded numeric thresholds that should be PipelineConfig params
#      (degree, bandwidth, n_grid when embedded as bare literals in strategy code)
#
# Exemptions:
#   - Test files (tests/)
#   - The registry implementation itself (R/07-registry.R)
#   - setup_rng() in R/10-rng.R (uses switch for L'Ecuyer kinds, intentional)

set -euo pipefail

FAILED=0
R_FILES=$(find R/ -name "*.R" \
  ! -name "07-registry.R" \
  ! -name "10-rng.R")

# ── 1. if (method == "...") dispatchers ─────────────────────────────────────
DISPATCH_IF=$(echo "$R_FILES" | xargs grep -l \
  -E 'if\s*\(.*method\s*==\s*"' 2>/dev/null || true)
if [[ -n "$DISPATCH_IF" ]]; then
  echo "✗ if-dispatcher found (use register_strategy() instead):"
  echo "$DISPATCH_IF" | sed 's/^/  /'
  FAILED=1
fi

# ── 2. switch(method, ...) dispatchers ──────────────────────────────────────
DISPATCH_SW=$(echo "$R_FILES" | xargs grep -l \
  -E 'switch\s*\(\s*(method|strategy|estimator|decomposer)' 2>/dev/null || true)
if [[ -n "$DISPATCH_SW" ]]; then
  echo "✗ switch-dispatcher found (use register_strategy() instead):"
  echo "$DISPATCH_SW" | sed 's/^/  /'
  FAILED=1
fi

# ── 3. Hard-coded poly_degree / n_grid in stage implementations ─────────────
# Strategy params must come from strategy@params, not bare literals.
# Pattern: assignment of poly_degree or n_grid to a bare integer NOT inside
# a modifyList() defaults block.
HARDCODED=$(echo "$R_FILES" | xargs grep -n \
  -E '^\s+(poly_degree|n_grid|bandwidth)\s*<-\s*[0-9]' 2>/dev/null || true)
if [[ -n "$HARDCODED" ]]; then
  echo "✗ Hard-coded config parameter (should be in PipelineConfig / strategy@params):"
  echo "$HARDCODED" | sed 's/^/  /'
  FAILED=1
fi

if [[ $FAILED -eq 0 ]]; then
  echo "✓ Registry compliance: no dispatcher anti-patterns found."
fi

exit $FAILED
