#!/usr/bin/env bash

# Reproducible entrypoint for revised K=1 acceptance. Run this only from an
# active standard hprcc/rbiocverse Slurm session. hprcc owns cluster detection,
# partitions, containers, libraries, bind mounts, and worker submission.

set -euo pipefail

: "${SLURM_JOB_ID:?run the tracked launcher from an active Slurm session}"
: "${SINGULARITY_CONTAINER:?run the tracked launcher from a standard rbiocverse session}"
: "${BIOCONDUCTOR_VERSION:?set the reviewed Bioconductor version in the active session}"
: "${LANDSCAPER_K1_PROTOCOL_MERGE:?set the reviewed protocol revision}"
: "${LANDSCAPER_K1_RUNNER_MERGE:?set the reviewed runner revision}"
: "${LANDSCAPER_PAYLOAD_SHA256:?set the preflight payload identity}"
: "${LANDSCAPER_PAYLOAD_VERIFIER:?set the preflight payload verifier path}"
: "${LANDSCAPER_PAYLOAD_VERIFIER_SHA256:?set the preflight verifier identity}"

run_root=$(cd "${LANDSCAPER_RUN_ROOT:-.}" && pwd)
payload_digest_script="$LANDSCAPER_PAYLOAD_VERIFIER"

command -v Rscript >/dev/null 2>&1 || {
    printf 'Rscript is unavailable; enter a standard rbiocverse session first\n' >&2
    exit 2
}
[[ -f "$SINGULARITY_CONTAINER" ]] || {
    printf 'the active rbiocverse container is unavailable\n' >&2
    exit 2
}
[[ "$BIOCONDUCTOR_VERSION" =~ ^[0-9]+\.[0-9]+$ ]] || {
    printf 'the active Bioconductor version is invalid\n' >&2
    exit 2
}
container_name=$(basename -- "$SINGULARITY_CONTAINER")
container_pattern="^(rbiocverse|vscode-rbioc)_${BIOCONDUCTOR_VERSION//./\\.}\.sif$"
[[ "$container_name" =~ $container_pattern ]] || {
    printf 'the active rbiocverse container does not match the reviewed Bioconductor version\n' >&2
    exit 2
}

[[ -x "$payload_digest_script" ]] || {
    printf 'landscapeR payload verifier is missing\n' >&2
    exit 2
}
expected_payload_digest="$LANDSCAPER_PAYLOAD_SHA256"
expected_payload_verifier_digest="$LANDSCAPER_PAYLOAD_VERIFIER_SHA256"
[[ "$expected_payload_digest" =~ ^[0-9a-f]{64}$ ]] || {
    printf 'landscapeR payload identity is invalid\n' >&2
    exit 2
}
[[ "$expected_payload_verifier_digest" =~ ^[0-9a-f]{64}$ ]] || {
    printf 'landscapeR payload verifier identity is invalid\n' >&2
    exit 2
}
if command -v sha256sum >/dev/null 2>&1; then
    observed_payload_verifier_digest=$(sha256sum "$payload_digest_script" | awk '{print $1}')
else
    observed_payload_verifier_digest=$(shasum -a 256 "$payload_digest_script" | awk '{print $1}')
fi
[[ "$observed_payload_verifier_digest" = "$expected_payload_verifier_digest" ]] || {
    printf 'landscapeR payload verifier differs from the reviewed identity\n' >&2
    exit 2
}
export LANDSCAPER_PAYLOAD_SHA256="$expected_payload_digest"
export LANDSCAPER_PAYLOAD_VERIFIER="$payload_digest_script"
export LANDSCAPER_PAYLOAD_VERIFIER_SHA256="$expected_payload_verifier_digest"
export LANDSCAPER_ACCEPTANCE_RUN=true
cd "$run_root"
Rscript --vanilla -e '
if (!requireNamespace("hprcc", quietly = TRUE)) {
    stop("active rbiocverse session does not provide hprcc")
}
library_path <- getFromNamespace("r_libs_site", "hprcc")()
if (!is.character(library_path) || length(library_path) != 1L ||
    !nzchar(library_path) || !dir.exists(library_path)) {
    stop("hprcc-selected shared R library is unavailable")
}
.libPaths(unique(c(library_path, .libPaths())))
expected <- Sys.getenv("LANDSCAPER_PAYLOAD_SHA256")
verifier <- Sys.getenv("LANDSCAPER_PAYLOAD_VERIFIER")
package_root <- system.file(package = "landscapeR")
observed <- system2("bash", c(verifier, package_root), stdout = TRUE, stderr = TRUE)
observed <- trimws(tail(observed, 1L))
if (!nzchar(package_root) || !identical(observed, expected)) {
    stop("installed landscapeR payload does not match the reviewed identity")
}
targets::tar_make(use_crew = TRUE, callr_function = NULL)
'
