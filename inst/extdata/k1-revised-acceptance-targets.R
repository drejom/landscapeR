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

# The reviewed development pilot supports eight short tasks per worker. Bound
# the pool as well so large graphs do not burst-submit hprcc's 350-worker
# default. cohmathonc/hprcc#36 will make this available through add_controller().
controller_constructor <- getFromNamespace("create_controller", "hprcc")
if (!"slurm_workers" %in% names(formals(controller_constructor))) {
    stop("the installed hprcc does not support bounded worker controllers")
}
acceptance_controller <- controller_constructor(
    name = "k1-acceptance",
    slurm_cpus = 2L,
    slurm_mem_gigabytes = 8L,
    slurm_walltime_minutes = 60L,
    slurm_workers = 8L,
    tasks_max = 8L
)
controller_group <- targets::tar_option_get("controller")
if (is.null(controller_group)) {
    stop("hprcc did not configure its controller group")
}
targets::tar_option_set(
    controller = do.call(
        crew::crew_controller_group,
        unname(c(controller_group$controllers, list(acceptance_controller)))
    )
)

k1_revised_acceptance_targets(
    phase_a_merge_commit = protocol_merge,
    runner_revision = runner_merge,
    artifact_root = file.path(run_root, "artifacts"),
    controller = "k1-acceptance"
)
