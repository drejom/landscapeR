#!/usr/bin/env bash

# Reproducible Slurm entrypoint for revised K=1 acceptance. The caller supplies
# a reviewed rbiocverse cluster-config.sh; rbiocverse owns cluster detection,
# partitions, containers, libraries, bind mounts, and Singularity execution.

set -euo pipefail

: "${RBIOCVERSE_CONFIG:?set RBIOCVERSE_CONFIG to rbiocverse cluster-config.sh}"
: "${LANDSCAPER_K1_PROTOCOL_MERGE:?set the reviewed protocol revision}"
: "${LANDSCAPER_K1_RUNNER_MERGE:?set the reviewed runner revision}"

# shellcheck source=/dev/null
source "$RBIOCVERSE_CONFIG"
cluster=$(validate_cluster)
run_root=$(cd "${LANDSCAPER_RUN_ROOT:-.}" && pwd)
launch_script=$(cd "$(dirname "$0")" && pwd)/$(basename "$0")
payload_digest_script="$run_root/k1-revised-acceptance-payload-digest.sh"
payload_digest_file="$run_root/landscapeR-payload-sha256.txt"

[[ -x "$payload_digest_script" ]] || {
    printf 'landscapeR payload verifier is missing\n' >&2
    exit 2
}
[[ -f "$payload_digest_file" ]] || {
    printf 'landscapeR payload identity file is missing\n' >&2
    exit 2
}
expected_payload_digest=$(tr -d '[:space:]' < "$payload_digest_file")
[[ "$expected_payload_digest" =~ ^[0-9a-f]{64}$ ]] || {
    printf 'landscapeR payload identity is invalid\n' >&2
    exit 2
}
export LANDSCAPER_PAYLOAD_SHA256="$expected_payload_digest"
export LANDSCAPER_PAYLOAD_VERIFIER="$payload_digest_script"

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
