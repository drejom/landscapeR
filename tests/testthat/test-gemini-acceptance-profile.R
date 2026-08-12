test_that("Gemini AML production profile is bound to measured pilot resources", {
    profile_path <- system.file(
        "extdata", "k1-acceptance-gemini-targets.R",
        package = "landscapeR", mustWork = TRUE
    )
    pilot_path <- system.file(
        "extdata", "k1-aml-gemini-resource-pilot.tsv",
        package = "landscapeR", mustWork = TRUE
    )
    record_path <- system.file(
        "extdata", "k1-aml-gemini-resource-pilot-record.rds",
        package = "landscapeR", mustWork = TRUE
    )
    profile <- paste(readLines(profile_path, warn = FALSE), collapse = "\n")
    pilot <- utils::read.delim(pilot_path, check.names = FALSE)
    record <- readRDS(record_path)
    record_digest <- record$record_digest
    digest_payload <- record
    digest_payload$record_digest <- NULL
    resource_value <- function(field) {
        pattern <- paste0(field, " = ([0-9]+)L")
        match <- regexec(pattern, profile)
        value <- regmatches(profile, match)[[1L]]
        expect_length(value, 2L)
        as.integer(value[[2L]])
    }
    slurm_cpus <- resource_value("slurm_cpus")
    slurm_memory_gb <- resource_value("slurm_mem_gigabytes")
    slurm_walltime_min <- resource_value("slurm_walltime_minutes")
    tasks_per_worker <- resource_value("tasks_max")

    expect_false(grepl("AML production is blocked", profile, fixed = TRUE))
    expect_identical(slurm_cpus, 2L)
    expect_identical(slurm_memory_gb, 8L)
    expect_identical(slurm_walltime_min, 60L)
    expect_identical(tasks_per_worker, 8L)

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
    expect_gte(
        slurm_memory_gb / record$resources$peak_memory_gb,
        4
    )
    expect_gte(
        slurm_cpus,
        max(1L, ceiling(record$resources$peak_cpu_pct / 100))
    )
    expect_lte(
        tasks_per_worker * record$resources$duration_min,
        0.55 * slurm_walltime_min
    )

    expect_equal(nrow(pilot), 1L)
    expect_identical(pilot$run_date, record$run_date)
    expect_identical(pilot$installed_revision, record$installed_revision)
    expect_identical(pilot$source_sha256, record$source_sha256)
    expect_identical(pilot$slurm_job_id, record$slurm_job_id)
    expect_identical(pilot$task_id, record$task_id)
    expect_identical(pilot$seed_root, record$seed_root)
    expect_identical(
        pilot$subjects_per_condition,
        record$subjects_per_condition
    )
    expect_identical(pilot$n_observations, record$n_observations)
    expect_identical(pilot$n_features, record$n_features)
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
    expect_identical(pilot$diagnostic, record$diagnostic)
})
