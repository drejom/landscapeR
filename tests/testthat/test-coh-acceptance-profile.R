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
    expect_match(
        profile,
        'getFromNamespace("create_controller", "hprcc")',
        fixed = TRUE
    )
    expect_match(profile, "slurm_workers = 8L", fixed = TRUE)
    expect_match(profile, "tasks_max = 8L", fixed = TRUE)
    expect_match(profile, 'controller = "k1-acceptance"', fixed = TRUE)
    expect_match(profile, "cohmathonc/hprcc#36", fixed = TRUE)
})
