# Gemini _targets.R profile for the reviewed version 4 graph. Do not schedule
# this profile until the runner revision containing it has merged and that exact
# revision is installed on every worker.

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

scratch_root <- file.path(
    "/scratch", Sys.info()[["user"]], "landscapeR",
    "k1-revised-acceptance"
)
shared_library_host <-
    "/packages/singularity/shared_cache/rbioc/rlibs/bioc-3.22"
shared_library_container <- "/opt/coh-r-library"
dir.create(scratch_root, recursive = TRUE, showWarnings = FALSE)
if (!identical(
    normalizePath(getwd(), mustWork = TRUE),
    normalizePath(scratch_root, mustWork = TRUE)
)) {
    stop("run revised K=1 acceptance from its scratch root: ", scratch_root)
}

Sys.setenv(HPRCC_TARGETS_STORE_BASE = file.path(scratch_root, "_targets"))
options(
    hprcc.slurm_jobs = TRUE,
    hprcc.slurm_logs = TRUE,
    hprcc.default_partition = "compute",
    hprcc.r_libs_user = shared_library_container,
    hprcc.r_libs_site = shared_library_container,
    hprcc.singularity_bind_dirs = paste(
        paste0(shared_library_host, ":", shared_library_container),
        "/scratch", "/run", sep = ","
    ),
    hprcc.singularity_container =
        "/packages/singularity/shared_cache/rbioc/rbiocverse_3.22.sif"
)

library(targets)
library(hprcc)
library(landscapeR)

# Scheduler resources are operational policy and may be tuned from pilot
# telemetry without changing the scientific graph or manifest.
hprcc::add_controller(
    name = "k1-revised-acceptance",
    slurm_cpus = 2L,
    slurm_mem_gigabytes = 12L,
    slurm_walltime_minutes = 120L,
    slurm_partition = "compute",
    tasks_max = 8L
)

k1_revised_acceptance_targets(
    phase_a_merge_commit = protocol_merge,
    runner_revision = runner_merge,
    artifact_root = file.path(scratch_root, "artifacts"),
    controller = "k1-revised-acceptance"
)
