#!/usr/bin/env bash
# Build the pkgdown site through a stack-balance guard.
#
# downlit discovers packages named in library() calls while highlighting R code.
# If landscapeR is cold-loaded from inside downlit's vapply(), the transitive
# SummarizedExperiment namespace load leaves R's protection stack two entries
# higher. Loading landscapeR once at top level avoids that external load-timing
# interaction. The log check keeps the containment executable: any recurrence is
# a failed build, rather than a successful check carrying unsafe annotations.

set -euo pipefail

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || {
  echo "[pkgdown] Cannot resolve the repository root." >&2
  exit 1
}
cd "$REPO_ROOT"

mkdir -p .scratch
LOG_FILE=$(mktemp .scratch/pkgdown-build.XXXXXX.log)
trap 'rm -f "$LOG_FILE"' EXIT

if ! Rscript -e '
  withr::local_temp_libpaths()
  utils::install.packages(".", repos = NULL, type = "source", quiet = TRUE)
  loadNamespace("landscapeR")
  pkgdown::build_site(devel = FALSE, new_process = FALSE, install = FALSE)
' 2>&1 | tee "$LOG_FILE"; then
  echo "[pkgdown] Site build failed." >&2
  exit 1
fi

if grep -Fq "stack imbalance" "$LOG_FILE"; then
  echo "[pkgdown] R protection-stack imbalance detected; refusing the site build." >&2
  grep -F "stack imbalance" "$LOG_FILE" >&2
  exit 1
fi

echo "[pkgdown] Site build completed without protection-stack imbalance."
