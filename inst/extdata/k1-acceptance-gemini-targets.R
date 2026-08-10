# Gemini _targets.R profile for the frozen K=1 independent acceptance run.
# Copy this file into a dedicated execution directory before use.

phase_a_merge <- Sys.getenv("LANDSCAPER_K1_PHASE_A_MERGE")
if (!grepl("^[0-9a-f]{40}$", phase_a_merge)) {
    stop("LANDSCAPER_K1_PHASE_A_MERGE must be the reviewed 40-character SHA-1")
}

scratch_root <- file.path(
    "/scratch",
    Sys.info()[["user"]],
    "landscapeR",
    "k1-independent-acceptance"
)
dir.create(scratch_root, recursive = TRUE, showWarnings = FALSE)
if (!identical(
    normalizePath(getwd(), mustWork = TRUE),
    normalizePath(scratch_root, mustWork = TRUE)
)) {
    stop(
        "run the K=1 Gemini workflow from its dedicated scratch root: ",
        scratch_root
    )
}

# hprcc reads these values when it is attached. Setting them first prevents an
# unrelated user-level targets configuration from supplying the store path.
Sys.setenv(
    HPRCC_TARGETS_STORE_BASE = file.path(scratch_root, "_targets")
)
options(
    hprcc.slurm_jobs = TRUE,
    hprcc.slurm_logs = TRUE,
    hprcc.default_partition = "compute"
)

library(targets)
library(hprcc)
library(landscapeR)

# Dedicated acceptance resources are operational policy. These values follow
# hprcc::summarize_resource_usage() on the development-only largest-cell pilot
# recorded in docs/agents/gemini-hprcc-deployment.md. Changing them does not
# change the scientific graph.
hprcc::add_controller(
    name = "k1-acceptance",
    slurm_cpus = 2L,
    slurm_mem_gigabytes = 8L,
    slurm_walltime_minutes = 60L,
    slurm_partition = "compute",
    tasks_max = 1L
)

k1_acceptance_targets(
    phase_a_merge_commit = phase_a_merge,
    artifact_root = file.path(scratch_root, "artifacts"),
    controller = "k1-acceptance"
)
