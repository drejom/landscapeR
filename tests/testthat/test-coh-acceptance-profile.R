test_that("revised K=1 execution delegates cluster infrastructure to hprcc", {
    profile_path <- system.file(
        "extdata", "k1-revised-acceptance-targets.R",
        package = "landscapeR", mustWork = TRUE
    )
    profile <- paste(readLines(profile_path, warn = FALSE), collapse = "\n")

    forbidden <- c(
        "/packages/", "/opt/", "/scratch/", "slurm_partition",
        "hprcc.default_partition", "hprcc.r_libs_user",
        "hprcc.r_libs_site", "hprcc.singularity_bind_dirs",
        "hprcc::add_controller"
    )
    for (term in forbidden) {
        expect_false(
            grepl(term, profile, fixed = TRUE),
            info = paste("active profile must not own", term)
        )
    }

    expect_match(profile, 'Sys.getenv\\("SINGULARITY_CONTAINER"')
    expect_match(
        profile,
        '"^rbiocverse_[0-9]+\\\\.[0-9]+\\\\.sif$"',
        fixed = TRUE
    )
    expect_match(profile, "hprcc.singularity_container = active_container")
    expect_match(profile, "hprcc.slurm_logs = TRUE", fixed = TRUE)
    expect_match(profile, "normalizePath(getwd(), mustWork = TRUE)", fixed = TRUE)
    expect_match(profile, 'file.path(run_root, "artifacts")', fixed = TRUE)
    expect_match(profile, 'sbatch_path <- Sys.which("sbatch")', fixed = TRUE)
    expect_match(profile, 'flock_path <- Sys.which("flock")', fixed = TRUE)
    expect_match(profile, 'file.path(run_root, ".submission-bin")', fixed = TRUE)
    expect_match(profile, 'file.path(run_root, ".submission.lock")', fixed = TRUE)
    expect_match(profile, "Sys.chmod(submission_wrapper", fixed = TRUE)
    expect_match(profile, "Sys.setenv(", fixed = TRUE)
    expect_match(
        profile,
        'getFromNamespace("create_controller", "hprcc")',
        fixed = TRUE
    )
    expect_match(profile, "slurm_workers = 96L", fixed = TRUE)
    expect_match(profile, "tasks_max = 100L", fixed = TRUE)
    expect_match(profile, 'controller = "k1-acceptance"', fixed = TRUE)
    expect_match(profile, "cohmathonc/hprcc#36", fixed = TRUE)
})

test_that("revised K=1 launch delegates deployment to rbiocverse", {
    launch_path <- system.file(
        "extdata", "k1-revised-acceptance-launch.sh",
        package = "landscapeR", mustWork = TRUE
    )
    launch <- paste(readLines(launch_path, warn = FALSE), collapse = "\n")

    forbidden <- c(
        "/opt/", "/packages/", "/labs/", "/scratch/",
        "cluster-config.sh", "RBIOCVERSE_CONFIG", "get_slurm_partition",
        "load_singularity", "run_in_container", "sbatch",
        "rbiocverse_3.22.sif", "bioc-3.22", "partition=all",
        "partition=compute"
    )
    for (term in forbidden) {
        expect_false(
            grepl(term, launch, fixed = TRUE),
            info = paste("tracked launcher must not own", term)
        )
    }

    expect_match(launch, "SLURM_JOB_ID", fixed = TRUE)
    expect_match(launch, "SINGULARITY_CONTAINER", fixed = TRUE)
    expect_match(launch, "Rscript --vanilla", fixed = TRUE)
    expect_match(launch, 'requireNamespace("hprcc", quietly = TRUE)', fixed = TRUE)
    expect_match(
        launch,
        "targets::tar_make(use_crew = TRUE, callr_function = NULL)",
        fixed = TRUE
    )
})
