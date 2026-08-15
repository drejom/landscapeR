# Cluster-neutral _targets.R profile for the reviewed version 4 graph. Run it
# from a dedicated directory inside a standard rbiocverse Slurm session. hprcc
# owns cluster detection, worker libraries, bind mounts, partitions, and named
# resource controllers.

protocol_merge <- Sys.getenv("LANDSCAPER_K1_PROTOCOL_MERGE")
runner_merge <- Sys.getenv("LANDSCAPER_K1_RUNNER_MERGE")
if (!grepl("^[0-9a-f]{40}$", protocol_merge) ||
        !grepl("^[0-9a-f]{40}$", runner_merge) ||
        identical(protocol_merge, runner_merge)) {
    stop(
        "LANDSCAPER_K1_PROTOCOL_MERGE and LANDSCAPER_K1_RUNNER_MERGE must ",
        "identify distinct reviewed 40-character revisions"
    )
}

run_root <- normalizePath(getwd(), mustWork = TRUE)

# Temporary workaround for cohmathonc/hprcc#35. Pin workers to the active
# rbiocverse image already selected by the standard cluster environment. Do
# not reconstruct a cluster-specific path here. Remove this override after the
# upstream default resolves to rbiocverse on every supported cluster.
active_container <- Sys.getenv("SINGULARITY_CONTAINER")
if (!nzchar(active_container) ||
        !grepl(
            "^rbiocverse_[0-9]+\\.[0-9]+\\.sif$",
            basename(active_container)
        ) ||
        !file.exists(active_container)) {
    stop(
        "run revised K=1 acceptance inside the standard rbiocverse ",
        "Slurm environment"
    )
}
options(
    hprcc.slurm_jobs = TRUE,
    hprcc.slurm_logs = TRUE,
    hprcc.singularity_container = active_container
)

library(targets)
library(hprcc)
library(landscapeR)

k1_revised_acceptance_targets(
    phase_a_merge_commit = protocol_merge,
    runner_revision = runner_merge,
    artifact_root = file.path(run_root, "artifacts")
)
