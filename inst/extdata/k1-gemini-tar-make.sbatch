#!/bin/bash
#SBATCH --job-name=landscapeR-targets
#SBATCH --partition=compute
#SBATCH --cpus-per-task=2
#SBATCH --mem=16G
#SBATCH --time=08:00:00
#SBATCH --output=targets-controller-%j.out
#SBATCH --error=targets-controller-%j.err

set -euo pipefail

run_root=${LANDSCAPER_RUN_ROOT:-${SLURM_SUBMIT_DIR:?}}
singularity_bin=/packages/easy-build/software/singularity/3.7.0/bin/singularity
container=/packages/singularity/shared_cache/rbioc/rbiocverse_3.22.sif
shared_library=/packages/singularity/shared_cache/rbioc/rlibs/bioc-3.22

cd "$run_root"

"$singularity_bin" exec \
    --env "R_LIBS_SITE=$shared_library" \
    -B /packages,/run,/scratch,/ref_genomes \
    "$container" \
    Rscript -e 'targets::tar_make(
        use_crew = TRUE,
        callr_function = NULL
    )'
