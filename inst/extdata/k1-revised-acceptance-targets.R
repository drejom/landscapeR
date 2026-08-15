# Cluster-neutral _targets.R profile for a reviewed revised-acceptance graph. Run it
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

# hprcc launches worker submissions asynchronously. On clusters whose
# container-to-scheduler relay uses SSH, an unbounded submission burst can
# exhaust that relay before Slurm sees the requests. Serialize only the short
# submission calls; once queued, workers run concurrently at the full pool
# size. This is operational throttling and does not alter scientific work.
sbatch_path <- Sys.which("sbatch")
flock_path <- Sys.which("flock")
if (!nzchar(sbatch_path) || !nzchar(flock_path)) {
    stop("the active Slurm environment must provide sbatch and flock")
}
submission_bin <- file.path(run_root, ".submission-bin")
dir.create(submission_bin, recursive = TRUE, showWarnings = FALSE)
if (!dir.exists(submission_bin)) {
    stop("could not create the run-local submission relay")
}
submission_lock <- file.path(run_root, ".submission.lock")
submission_wrapper <- file.path(submission_bin, "sbatch")
writeLines(
    c(
        "#!/bin/sh",
        sprintf(
            "exec %s %s %s \"$@\"",
            shQuote(flock_path),
            shQuote(submission_lock),
            shQuote(sbatch_path)
        )
    ),
    submission_wrapper
)
Sys.chmod(submission_wrapper, mode = "0755")
Sys.setenv(
    PATH = paste(submission_bin, Sys.getenv("PATH"), sep = .Platform$path.sep)
)

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

# Keep a substantial bounded pool alive for enough tasks to consume the full
# graph. A low per-worker task cap forces thousands of short branches through
# repeated Slurm submissions and leaves compute idle behind scheduler latency.
# cohmathonc/hprcc#36 will make the worker bound available through
# add_controller().
controller_constructor <- getFromNamespace("create_controller", "hprcc")
if (!"slurm_workers" %in% names(formals(controller_constructor))) {
    stop("the installed hprcc does not support bounded worker controllers")
}
acceptance_controller <- controller_constructor(
    name = "k1-acceptance",
    slurm_cpus = 2L,
    slurm_mem_gigabytes = 8L,
    slurm_walltime_minutes = 60L,
    slurm_workers = 96L,
    tasks_max = 100L
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
