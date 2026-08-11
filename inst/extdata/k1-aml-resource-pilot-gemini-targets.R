# Gemini targets profile for the disclosed-seed AML largest-cell resource pilot.
# This profile cannot derive or publish governed acceptance seeds.

pilot_root <- file.path(
    "/scratch",
    Sys.info()[["user"]],
    "landscapeR",
    "k1-aml-resource-pilot"
)
shared_library_host <-
    "/packages/singularity/shared_cache/rbioc/rlibs/bioc-3.22"
shared_library_container <- "/opt/coh-r-library"
dir.create(pilot_root, recursive = TRUE, showWarnings = FALSE)
if (!identical(
    normalizePath(getwd(), mustWork = TRUE),
    normalizePath(pilot_root, mustWork = TRUE)
)) {
    stop("run the AML resource pilot from ", pilot_root)
}

Sys.setenv(HPRCC_TARGETS_STORE_BASE = file.path(pilot_root, "_targets"))
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

hprcc::add_controller(
    name = "k1-aml-resource-pilot",
    slurm_cpus = 2L,
    slurm_mem_gigabytes = 16L,
    slurm_walltime_minutes = 240L,
    slurm_partition = "compute",
    tasks_max = 1L
)

targets::tar_option_set(packages = "landscapeR", error = "stop")

list(
    targets::tar_target(
        pilot_identity,
        landscapeR:::.k1_acceptance_worker_identity()
    ),
    targets::tar_target_raw(
        name = "aml_largest_cell_resource_pilot",
        command = quote({
            protocol <- landscapeR::k1_acceptance_protocol()
            task <- data.frame(
                task_id = "disclosed-aml-resource-pilot-867530900",
                control = "aml_synchronized",
                n = 264L,
                p = 10000L,
                subjects_per_condition = 12L,
                replicate_index = 1L,
                seed_root = 867530900L,
                canonical_cell = "development-only-resource-pilot",
                stringsAsFactors = FALSE
            )
            task$stream_seeds <- list(c(
                generator = 867530900L,
                association = 867530901L,
                permutations = 867530902L,
                identifiability = 867530903L
            ))
            landscapeR:::.k1_aml_resource_pilot(
                task,
                protocol,
                expected_identity = pilot_identity
            )
        }),
        deployment = "worker",
        resources = targets::tar_resources(
            crew = targets::tar_resources_crew(
                controller = "k1-aml-resource-pilot"
            )
        )
    )
)
