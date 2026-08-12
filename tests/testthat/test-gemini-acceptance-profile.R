test_that("Gemini AML production profile is bound to measured pilot resources", {
    root <- testthat::test_path("..", "..")
    profile_path <- file.path(
        root, "inst", "extdata", "k1-acceptance-gemini-targets.R"
    )
    pilot_path <- file.path(
        root, ".github", "landing-proof", "issue-67",
        "gemini-resource-pilot.tsv"
    )
    record_path <- file.path(
        root, ".github", "landing-proof", "issue-67",
        "gemini-resource-pilot-record.rds"
    )
    profile <- paste(readLines(profile_path, warn = FALSE), collapse = "\n")
    pilot <- utils::read.delim(pilot_path, check.names = FALSE)
    record <- readRDS(record_path)
    record_digest <- record$record_digest
    digest_payload <- record
    digest_payload$record_digest <- NULL

    expect_false(grepl("AML production is blocked", profile, fixed = TRUE))
    expect_match(profile, "slurm_cpus = 2L", fixed = TRUE)
    expect_match(profile, "slurm_mem_gigabytes = 8L", fixed = TRUE)
    expect_match(profile, "slurm_walltime_minutes = 60L", fixed = TRUE)
    expect_match(profile, "tasks_max = 8L", fixed = TRUE)

    expect_identical(
        record_digest,
        digest::digest(digest_payload, algo = "sha256")
    )
    expect_identical(record$schema_version, "1.0.0")
    expect_match(record$installed_revision, "^[0-9a-f]{40}$")
    expect_match(record$source_sha256, "^[0-9a-f]{64}$")
    expect_identical(record$slurm_state, "COMPLETED")
    expect_identical(record$slurm_exit_code, "0:0")
    expect_identical(record$task_id, pilot$task_id)
    expect_identical(record$seed_root, pilot$seed_root)
    expect_identical(record$subjects_per_condition, 12L)
    expect_identical(record$n_observations, 264L)
    expect_identical(record$n_features, 10000L)
    expect_identical(record$permutation$requested, 99L)
    expect_identical(record$permutation$completed, 99L)
    expect_identical(record$identifiability$requested, 99L)
    expect_identical(record$identifiability$completed, 99L)
    expect_identical(record$identifiability$computational_failures, 0L)
    expect_identical(record$status, "success")
    expect_identical(
        record$evidence_status,
        "non_evidentiary_resource_pilot"
    )

    expect_equal(nrow(pilot), 1L)
    expect_identical(pilot$installed_revision, record$installed_revision)
    expect_identical(pilot$source_sha256, record$source_sha256)
    expect_identical(pilot$slurm_job_id, record$slurm_job_id)
    expect_identical(pilot$status, record$status)
    expect_identical(pilot$claim_status, record$evidence_status)
    expect_identical(
        pilot$permutations_requested,
        record$permutation$requested
    )
    expect_identical(
        pilot$permutations_completed,
        record$permutation$completed
    )
    expect_identical(
        pilot$identifiability_requested,
        record$identifiability$requested
    )
    expect_identical(
        pilot$identifiability_completed,
        record$identifiability$completed
    )
    expect_identical(
        pilot$computational_failures,
        record$identifiability$computational_failures
    )
    expect_identical(
        pilot$hprcc_recommendation,
        record$resources$hprcc_recommendation
    )
    expect_equal(pilot$peak_memory_gb, record$resources$peak_memory_gb)
    expect_equal(pilot$peak_cpu_pct, record$resources$peak_cpu_pct)
    expect_equal(pilot$duration_min, record$resources$duration_min)
})
