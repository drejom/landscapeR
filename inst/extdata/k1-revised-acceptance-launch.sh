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
payload_digest_script=$(cd "$(dirname "$0")" && pwd)/k1-revised-acceptance-payload-digest.sh
payload_digest_file="$run_root/landscapeR-payload-sha256.txt"

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

[[ -x "$payload_digest_script" ]] || {
    printf 'landscapeR payload verifier is missing\n' >&2
    exit 2
}
[[ -f "$payload_digest_file" ]] || {
    printf 'landscapeR payload identity file is missing\n' >&2
    exit 2
}

load_singularity "$cluster"
cd "$run_root"
package_root=$(Rscript --vanilla -e 'cat(system.file(package = "landscapeR"))')
observed_payload_digest=$("$payload_digest_script" "$package_root")
expected_payload_digest=$(tr -d '[:space:]' < "$payload_digest_file")
[[ "$observed_payload_digest" = "$expected_payload_digest" ]] || {
    printf 'installed landscapeR payload does not match the reviewed identity\n' >&2
    exit 2
}
run_in_container "${BIOCONDUCTOR_VERSION:-3.22}" \
    'targets::tar_make(use_crew = TRUE, callr_function = NULL)'
