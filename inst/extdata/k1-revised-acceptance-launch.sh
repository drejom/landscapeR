#!/usr/bin/env bash

# Reproducible Slurm entrypoint for revised K=1 acceptance. The caller supplies
# a reviewed rbiocverse cluster-config.sh; rbiocverse owns cluster detection,
# partitions, containers, libraries, bind mounts, and Singularity execution.

set -euo pipefail

: "${RBIOCVERSE_CONFIG:?set RBIOCVERSE_CONFIG to rbiocverse cluster-config.sh}"
: "${LANDSCAPER_K1_PROTOCOL_MERGE:?set the reviewed protocol revision}"
: "${LANDSCAPER_K1_RUNNER_MERGE:?set the reviewed runner revision}"
: "${LANDSCAPER_PAYLOAD_SHA256:?set the preflight payload identity}"
: "${LANDSCAPER_PAYLOAD_VERIFIER:?set the preflight payload verifier path}"
: "${LANDSCAPER_PAYLOAD_VERIFIER_SHA256:?set the preflight verifier identity}"

# shellcheck source=/dev/null
source "$RBIOCVERSE_CONFIG"
cluster=$(validate_cluster)
run_root=$(cd "${LANDSCAPER_RUN_ROOT:-.}" && pwd)
launch_script=$(cd "$(dirname "$0")" && pwd)/$(basename "$0")
payload_digest_script="$LANDSCAPER_PAYLOAD_VERIFIER"

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

if [[ -z "${SLURM_JOB_ID:-}" ]]; then
    exec sbatch \
        --job-name=landscapeR-k1-acceptance \
        --partition="$(get_slurm_partition "$cluster")" \
        --time=24:00:00 \
        --cpus-per-task=2 \
        --mem=12G \
        --chdir="$run_root" \
        --output=controller-%j.out \
        --error=controller-%j.err \
        --export=ALL \
        "$launch_script"
fi

load_singularity "$cluster"
cd "$run_root"
run_in_container "${BIOCONDUCTOR_VERSION:-3.22}" \
    'expected <- Sys.getenv("LANDSCAPER_PAYLOAD_SHA256"); verifier <- Sys.getenv("LANDSCAPER_PAYLOAD_VERIFIER"); package_root <- system.file(package = "landscapeR"); observed <- system2("bash", c(verifier, package_root), stdout = TRUE, stderr = TRUE); observed <- trimws(tail(observed, 1L)); if (!nzchar(package_root) || !identical(observed, expected)) stop("installed landscapeR payload does not match the reviewed identity"); targets::tar_make(use_crew = TRUE, callr_function = NULL)'
