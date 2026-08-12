test_that("Gemini AML production profile is bound to measured pilot resources", {
    root <- testthat::test_path("..", "..")
    profile_path <- file.path(
        root, "inst", "extdata", "k1-acceptance-gemini-targets.R"
    )
    pilot_path <- file.path(
        root, ".github", "landing-proof", "issue-67",
        "gemini-resource-pilot.tsv"
    )
    profile <- paste(readLines(profile_path, warn = FALSE), collapse = "\n")
    pilot <- utils::read.delim(pilot_path, check.names = FALSE)

    expect_false(grepl("AML production is blocked", profile, fixed = TRUE))
    expect_match(profile, "slurm_cpus = 2L", fixed = TRUE)
    expect_match(profile, "slurm_mem_gigabytes = 8L", fixed = TRUE)
    expect_match(profile, "slurm_walltime_minutes = 60L", fixed = TRUE)
    expect_match(profile, "tasks_max = 8L", fixed = TRUE)

    expect_equal(nrow(pilot), 1L)
    expect_identical(pilot$status, "success")
    expect_identical(
        pilot$claim_status,
        "non_evidentiary_resource_pilot"
    )
    expect_identical(pilot$permutations_completed, 99L)
    expect_identical(pilot$identifiability_completed, 99L)
    expect_identical(pilot$computational_failures, 0L)
    expect_identical(pilot$hprcc_recommendation, "tiny")
    expect_equal(pilot$peak_memory_gb, 1.65)
    expect_equal(pilot$duration_min, 3.8)
})
