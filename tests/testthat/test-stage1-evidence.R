stage1_evidence_fixture <- function(split = c("calibration", "holdout")) {
    split <- match.arg(split)
    manifest <- stage1_benchmark_manifest()
    rows <- do.call(rbind, lapply(if (split == "calibration") 1001:1002 else 1021:1022,
        function(seed) run_stage1_benchmark_replicate(manifest, seed = seed)))
    rows$shared_recovery_error[rows$candidate == "C1_symmetric_consensus"] <- .10
    rows$shared_recovery_error[rows$candidate == "C2_block_scaled_svd"] <- .20
    rows$exclusive_leakage <- .10
    rows$projection_error <- .10
    rows$elapsed_sec <- ifelse(rows$candidate == "C1_symmetric_consensus", 1, 1.1)
    rows
}

test_that("calibration selector is split-safe and applies frozen C1 rule", {
    calibration <- stage1_evidence_fixture("calibration")
    selection <- select_stage1_candidate(calibration)
    expect_identical(selection$selected_candidate, "C1_symmetric_consensus")
    expect_true(all(selection$conditions))
    expect_error(select_stage1_candidate(stage1_evidence_fixture("holdout")),
                 class = "stage1_evidence_error")

    fallback <- calibration
    fallback$gate_passed[fallback$candidate == "C1_symmetric_consensus"] <- FALSE
    selection <- select_stage1_candidate(fallback)
    expect_identical(selection$selected_candidate, "C2_block_scaled_svd")
    execution <- selection$bootstrap_executions$shared_recovery_error
    expect_s3_class(execution, "landscapeR_repetition_result")
    expect_identical(execution$account$n_requested, 10000L)
    expect_identical(execution$account$n_completed, 10000L)
    expect_identical(execution$account$n_failed, 0L)
    expect_identical(execution$provenance$compute_tier, "evidence")
    expect_identical(execution$provenance$run_seed, 11001L)
    expect_true(all(selection$bootstrap_measurements[[1L]] > 0))
})

test_that("runtime diagnostics cannot change the scientific selection", {
    calibration <- stage1_evidence_fixture("calibration")
    fast <- select_stage1_candidate(calibration)
    slow <- calibration
    slow$elapsed_sec[slow$candidate == "C1_symmetric_consensus"] <- 100
    slow$elapsed_sec[slow$candidate == "C2_block_scaled_svd"] <- 1
    delayed <- select_stage1_candidate(slow)
    expect_identical(delayed$selected_candidate, fast$selected_candidate)
    expect_false(delayed$elapsed_within_limit)
    expect_match(delayed$runtime_note, "not used for candidate selection", fixed = TRUE)
})

test_that("Stage 1 summary bootstraps are invariant across future plans", {
    previous <- future::plan()
    on.exit(future::plan(previous), add = TRUE)
    calibration <- stage1_evidence_fixture("calibration")
    exact <- landscapeR:::.stage1_exact_rows(calibration)
    rules <- stage1_benchmark_manifest()$selection_rules

    strata <- split(exact, exact$stratum_digest)
    paired <- lapply(strata, function(stratum) {
        c1 <- stratum[
            stratum$candidate == "C1_symmetric_consensus",
            c("seed", "shared_recovery_error"),
            drop = FALSE
        ]
        c2 <- stratum[
            stratum$candidate == "C2_block_scaled_svd",
            c("seed", "shared_recovery_error"),
            drop = FALSE
        ]
        c1 <- c1[order(c1$seed), , drop = FALSE]
        c2 <- c2[order(c2$seed), , drop = FALSE]
        c1$shared_recovery_error - c2$shared_recovery_error
    })
    setup_rng(rules$bootstrap_seed)
    legacy_paired <- vapply(seq_len(rules$bootstrap_resamples), function(i) {
        mean(vapply(paired, function(values) {
            mean(sample(values, length(values), replace = TRUE))
        }, numeric(1L)))
    }, numeric(1L))
    legacy_paired_interval <- stats::quantile(
        legacy_paired,
        probs = c(0.025, 0.975),
        names = FALSE,
        type = 7L
    )
    median_values <- c(0.1, 0.2, 0.3, 0.4)
    setup_rng(11002L)
    legacy_medians <- vapply(seq_len(10000L), function(i) {
        stats::median(sample(
            median_values,
            length(median_values),
            replace = TRUE
        ))
    }, numeric(1L))
    legacy_median_interval <- stats::quantile(
        legacy_medians,
        probs = c(0.025, 0.975),
        names = FALSE,
        type = 7L
    )

    future::plan(future::sequential)
    paired_sequential <- landscapeR:::.stage1_paired_bootstrap(
        exact,
        "shared_recovery_error",
        rules
    )
    median_sequential <- landscapeR:::.stage1_bootstrap_median_ci(
        median_values,
        11002L,
        list(bootstrap_resamples = 10000L),
        "test-stratum:shared_recovery_error"
    )
    paired_nested <- landscapeR:::.stage1_paired_bootstrap(
        exact,
        "shared_recovery_error",
        rules,
        sequential_internal = TRUE
    )
    median_nested <- landscapeR:::.stage1_bootstrap_median_ci(
        median_values,
        11002L,
        list(bootstrap_resamples = 10000L),
        "test-stratum:shared_recovery_error",
        sequential_internal = TRUE
    )
    expect_identical(paired_sequential$execution$account$n_requested, 10000L)
    expect_identical(median_sequential$execution$account$n_requested, 10000L)
    expect_identical(paired_sequential$execution$account$n_failed, 0L)
    expect_identical(median_sequential$execution$account$n_failed, 0L)
    expect_identical(paired_sequential$interval, legacy_paired_interval)
    expect_identical(median_sequential$interval, legacy_median_interval)
    expect_identical(paired_nested, paired_sequential)
    expect_identical(median_nested, median_sequential)
    expect_identical(
        paired_sequential$execution$provenance$seed_derivation,
        "legacy-sequential-stream-v1"
    )
    expect_identical(paired_sequential$execution$provenance$run_seed, 11001L)
    expect_identical(median_sequential$execution$provenance$run_seed, 11002L)
    expect_match(
        paired_sequential$execution$provenance$task_ids[[1L]],
        "^stage1-calibration:shared_recovery_error:paired-bootstrap:00001$"
    )
    expect_match(
        median_sequential$execution$provenance$task_ids[[10000L]],
        "^stage1-holdout:test-stratum:shared_recovery_error:median-bootstrap:10000$"
    )

    skip_if(
        pkgload::is_dev_package("landscapeR"),
        "multisession requires the installed-package check context"
    )
    available <- suppressWarnings(tryCatch({
        future::plan(future::multisession, workers = 2L)
        identical(future::value(future::future(TRUE)), TRUE)
    }, error = function(condition) FALSE))
    if (!available) {
        if (nzchar(Sys.getenv("CI"))) {
            testthat::fail("CI must provide a working multisession backend")
        }
        testthat::skip("multisession workers are unavailable in this test context")
    }
    paired_parallel <- landscapeR:::.stage1_paired_bootstrap(
        exact,
        "shared_recovery_error",
        rules,
        future_scheduling = 0.5
    )
    median_parallel <- landscapeR:::.stage1_bootstrap_median_ci(
        median_values,
        11002L,
        list(bootstrap_resamples = 10000L),
        "test-stratum:shared_recovery_error",
        future_scheduling = 0.5
    )

    expect_identical(paired_parallel, paired_sequential)
    expect_identical(median_parallel, median_sequential)
})

test_that("Stage 1 public evidence workflows expose nested-future control", {
    for (fn in list(
        select_stage1_candidate,
        assess_stage1_holdout,
        execute_stage1_benchmark_full
    )) {
        expect_true(all(c(
            "sequential_internal",
            "future_scheduling"
        ) %in% names(formals(fn))))
    }
})

test_that("Stage 1 summary failures retain typed execution accounting", {
    repetition <- landscapeR:::.future_numeric_repetition(
        tasks = list(1L),
        task_ids = "stage1-summary-failure:00001",
        run_seed = 11001L,
        compute_tier = "evidence",
        worker = function(task, task_id, task_stream) NA_real_,
        failure_code = "stage1-summary-test-failure"
    )
    condition <- tryCatch(
        landscapeR:::.stage1_require_summary_completion(
            repetition,
            "test summary"
        ),
        stage1_evidence_error = identity
    )

    expect_s3_class(condition, "stage1_evidence_error")
    expect_s3_class(condition$execution, "landscapeR_repetition_result")
    expect_identical(condition$execution$account$n_requested, 1L)
    expect_identical(condition$execution$account$n_completed, 0L)
    expect_identical(condition$execution$account$n_failed, 1L)
    expect_identical(
        condition$execution$account$failure_codes,
        "stage1-summary-test-failure"
    )
})

test_that("expected typed negative control is an eligible passed gate", {
    manifest <- stage1_benchmark_manifest()
    stratum <- list(n = 20L, K = 2L, shared_signal = 24, exclusive_signal = 12,
        confounder_signal = 12, noise_sd = 1, missing_block_rate = 0,
        sample_order = "permuted", feature_order = "permuted", projection_case = "missing_id")
    rows <- run_stage1_benchmark_replicate(manifest, seed = 1001L, stratum = stratum)
    expect_true(all(rows$gate_expected == "typed_failure"))
    expect_true(all(rows$gate_observed == "typed_failure"))
    expect_true(all(rows$gate_passed))
})

test_that("holdout assessment rejects other splits and reports frozen medians", {
    holdout <- stage1_evidence_fixture("holdout")
    report <- assess_stage1_holdout("C1_symmetric_consensus",
        holdout[holdout$candidate == "C1_symmetric_consensus", , drop = FALSE])
    expect_true(report$all_gates_passed)
    expect_true(report$thresholds_passed)
    expect_identical(report$decision, "accepted")
    expect_true(length(report$bootstrap_executions) > 0L)
    expect_true(all(vapply(
        report$bootstrap_executions,
        function(execution) execution$account$n_requested == 10000L &&
            execution$account$n_completed == 10000L &&
            execution$account$n_failed == 0L,
        logical(1L)
    )))
    expect_true(all(vapply(
        report$bootstrap_measurements,
        function(measurements) all(measurements > 0),
        logical(1L)
    )))
    expect_error(assess_stage1_holdout("C1_symmetric_consensus",
        stage1_evidence_fixture("calibration")[1, , drop = FALSE]), class = "stage1_evidence_error")
})

test_that("committed full v2 artifact verifies and records the failed confirmation", {
    artifact <- system.file("benchmarks",
        "stage1-heterogeneous-v2-a28239b9af0c5569e3be1892a5b60308c8451aefa04a165852cf521606087d4c",
        package = "landscapeR")
    expect_true(nzchar(artifact))
    expect_true(verify_stage1_evidence_artifact(artifact))
    evidence <- read_stage1_evidence_artifact(artifact)
    expect_identical(evidence$environment$commit, "6f1f0614b2c4f0d539baa69a20df1ef43705ade6")
    strata <- landscapeR:::.stage1_benchmark_strata(evidence$manifest)
    expected_tasks <- nrow(strata) * nrow(evidence$manifest$seeds)
    observed_tasks <- nrow(unique(evidence$results[c("stratum_digest", "seed")]))
    expect_identical(expected_tasks, 40960L)
    expect_identical(observed_tasks, expected_tasks)
    expect_identical(nrow(evidence$results), observed_tasks * length(evidence$manifest$candidates))
    expect_silent(landscapeR:::.stage1_assert_full_coverage(evidence$results, evidence$manifest, strata))
    expect_identical(evidence$selection$selected_candidate, "C2_block_scaled_svd")
    expect_identical(evidence$holdout$decision, "failed")
    expect_false(evidence$holdout$thresholds_passed)
    expect_true(all(evidence$results$gate_passed))
})

test_that("full evidence artifact verifier rejects undeclared and altered payloads", {
    manifest <- stage1_benchmark_manifest()
    calibration <- stage1_evidence_fixture("calibration")
    selection <- select_stage1_candidate(calibration)
    holdout_results <- stage1_evidence_fixture("holdout")
    holdout_rows <- holdout_results
    holdout_rows <- holdout_rows[holdout_rows$candidate == selection$selected_candidate, , drop = FALSE]
    holdout <- assess_stage1_holdout(selection$selected_candidate, holdout_rows)
    all_results <- rbind(calibration, holdout_results)
    root <- tempfile("stage1-evidence-root-")
    artifact <- landscapeR:::.stage1_write_full_artifact(root, manifest,
        all_results, selection, holdout,
        workers = 1L, source_commit = paste(rep("a", 40L), collapse = ""))
    operational_selection <- selection
    operational_selection$bootstrap_measurements <- list(
        backend_bytes = data.frame(serialized_execution_bytes = 999999)
    )
    operational_holdout <- holdout
    operational_holdout$bootstrap_measurements <- list(
        backend_bytes = data.frame(serialized_execution_bytes = 888888)
    )
    repeated <- landscapeR:::.stage1_write_full_artifact(root, manifest,
        all_results, operational_selection, operational_holdout,
        workers = 4L, source_commit = paste(rep("a", 40L), collapse = ""),
        execution = list(backend = "synthetic-scheduler"))
    expect_true(verify_stage1_evidence_artifact(artifact))
    expect_identical(repeated, artifact)
    expect_identical(read_stage1_evidence_artifact(artifact)$selection$selected_candidate,
                     "C1_symmetric_consensus")
    expect_true(testthat::with_mocked_bindings(
        verify_stage1_evidence_artifact(artifact),
        .stage1_write_figures = function(...) {
            stop("semantic verification must not rerender PNG files")
        },
        .package = "landscapeR"
    ))

    interrupted_root <- tempfile("stage1-evidence-interrupted-")
    expect_error(
        testthat::with_mocked_bindings(
            landscapeR:::.stage1_write_full_artifact(
                interrupted_root, manifest,
                all_results, selection, holdout, workers = 1L,
                source_commit = paste(rep("a", 40L), collapse = "")
            ),
            .artifact_atomic_move = function(from, to) FALSE,
            .package = "landscapeR"
        ),
        class = "stage1_evidence_error"
    )
    expect_length(
        list.files(interrupted_root, all.files = TRUE, no.. = TRUE),
        0L
    )

    rejected_root <- tempfile("stage1-evidence-rejected-")
    expect_error(
        testthat::with_mocked_bindings(
            landscapeR:::.stage1_write_full_artifact(
                rejected_root, manifest,
                all_results, selection, holdout, workers = 1L,
                source_commit = paste(rep("a", 40L), collapse = "")
            ),
            .stage1_verify_current_artifact = function(artifact_dir) {
                landscapeR:::.stage1_evidence_abort(
                    "synthetic semantic rejection"
                )
            },
            .package = "landscapeR"
        ),
        "synthetic semantic rejection",
        class = "stage1_evidence_error"
    )
    expect_length(
        list.files(rejected_root, all.files = TRUE, no.. = TRUE),
        0L
    )

    file.create(file.path(artifact, "undeclared.txt"))
    expect_error(verify_stage1_evidence_artifact(artifact), class = "stage1_evidence_error")
    unlink(file.path(artifact, "undeclared.txt"))
    missing <- file.path(artifact, "holdout-summary.csv")
    backup <- readBin(missing, "raw", n = file.info(missing)$size)
    unlink(missing)
    expect_error(verify_stage1_evidence_artifact(artifact), class = "stage1_evidence_error")
    writeBin(backup, missing)

    selection_path <- file.path(artifact, "calibration-selection.rds")
    original_selection <- readRDS(selection_path)
    altered_selection <- original_selection
    altered_selection$selected_candidate <- "C2_block_scaled_svd"
    saveRDS(altered_selection, selection_path)
    manifest_path <- file.path(artifact, "MANIFEST.tsv")
    original_manifest <- utils::read.delim(
        manifest_path, stringsAsFactors = FALSE
    )
    altered_manifest <- original_manifest
    selection_row <- altered_manifest$file == "calibration-selection.rds"
    altered_manifest$sha256[selection_row] <-
        landscapeR:::.artifact_file_digest(selection_path)
    utils::write.table(
        altered_manifest, manifest_path, sep = "\t", quote = FALSE,
        row.names = FALSE
    )
    expect_error(
        verify_stage1_evidence_artifact(artifact),
        "selection or holdout does not reproduce",
        class = "stage1_evidence_error"
    )
    saveRDS(original_selection, selection_path)
    utils::write.table(
        original_manifest, manifest_path, sep = "\t", quote = FALSE,
        row.names = FALSE
    )

    cat("tampered", file = file.path(artifact, "results.csv"), append = TRUE)
    expect_error(verify_stage1_evidence_artifact(artifact), class = "stage1_evidence_error")
})
