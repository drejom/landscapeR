# Gemini _targets.R profile for the frozen K=1 independent acceptance run.
# Copy this file into a dedicated execution directory before use.

protocol_merge <- Sys.getenv("LANDSCAPER_K1_PROTOCOL_MERGE")
if (!grepl("^[0-9a-f]{40}$", protocol_merge)) {
    stop(
        "LANDSCAPER_K1_PROTOCOL_MERGE must be the reviewed ",
        "40-character protocol merge SHA-1"
    )
}
runner_merge <- Sys.getenv("LANDSCAPER_K1_RUNNER_MERGE")

phase_b1_controls <- c(
    "generic_double_well", "pure_noise", "single_well",
    "shared_baseline_missing_cells"
)
controls_value <- Sys.getenv(
    "LANDSCAPER_K1_CONTROLS",
    paste(phase_b1_controls, collapse = ",")
)
controls <- trimws(strsplit(controls_value, ",", fixed = TRUE)[[1L]])
supported_controls <- c(phase_b1_controls, "aml_synchronized")
if (!length(controls) || any(!nzchar(controls)) ||
        any(!controls %in% supported_controls) || anyDuplicated(controls)) {
    stop(
        "LANDSCAPER_K1_CONTROLS must be a comma-separated unique subset of: ",
        paste(supported_controls, collapse = ", ")
    )
}
run_name <- if (identical(controls, "aml_synchronized")) {
    "k1-aml-acceptance"
} else if (setequal(controls, phase_b1_controls)) {
    "k1-independent-acceptance"
} else {
    stop(
        "the Gemini profile supports only the complete phase-B1 control set ",
        "or aml_synchronized alone"
    )
}
if (identical(controls, "aml_synchronized") &&
        !grepl("^[0-9a-f]{40}$", runner_merge)) {
    stop(
        "LANDSCAPER_K1_RUNNER_MERGE must be the reviewed 40-character ",
        "AML runner merge SHA-1"
    )
}
if (!nzchar(runner_merge)) runner_merge <- NULL
if (identical(controls, "aml_synchronized")) {
    stop(
        "AML production is blocked until the disclosed-seed largest-cell ",
        "resource pilot is recorded and this profile is reviewed with its ",
        "measured resource settings"
    )
}

scratch_root <- file.path(
    "/scratch",
    Sys.info()[["user"]],
    "landscapeR",
    run_name
)
shared_library_host <-
    "/packages/singularity/shared_cache/rbioc/rlibs/bioc-3.22"
shared_library_container <- "/opt/coh-r-library"
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
    hprcc.default_partition = "compute",
    hprcc.r_libs_user = shared_library_container,
    hprcc.r_libs_site = shared_library_container,
    hprcc.singularity_bind_dirs = paste(
        paste0(shared_library_host, ":", shared_library_container),
        "/scratch",
        "/run",
        sep = ","
    ),
    hprcc.singularity_container =
        "/packages/singularity/shared_cache/rbioc/rbiocverse_3.22.sif"
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
    tasks_max = 8L
)

k1_acceptance_targets(
    phase_a_merge_commit = protocol_merge,
    artifact_root = file.path(scratch_root, "artifacts"),
    controller = "k1-acceptance",
    controls = controls,
    runner_revision = runner_merge
)
