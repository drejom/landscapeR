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

if [[ -z "${SLURM_JOB_ID:-}" ]]; then
    exec sbatch \
        --job-name=landscapeR-k1-v4 \
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
    'targets::tar_make(use_crew = TRUE, callr_function = NULL)'
