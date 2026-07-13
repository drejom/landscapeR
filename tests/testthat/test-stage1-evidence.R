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

test_that("canonical task enumerator covers each supplied stratum and seed once", {
    strata <- landscapeR:::.stage1_benchmark_strata()[1:2, , drop = FALSE]
    seen <- landscapeR:::.stage1_execute_tasks(strata, c(1L, 2L),
        runner = function(task) paste(task$stratum_index, task$seed, sep = ":"))
    expect_identical(unlist(seen), c("1:1", "2:1", "1:2", "2:2"))
})

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
    holdout_rows <- stage1_evidence_fixture("holdout")
    holdout_rows <- holdout_rows[holdout_rows$candidate == selection$selected_candidate, , drop = FALSE]
    holdout <- assess_stage1_holdout(selection$selected_candidate, holdout_rows)
    root <- tempfile("stage1-evidence-root-")
    artifact <- landscapeR:::.stage1_write_full_artifact(root, manifest,
        rbind(calibration, stage1_evidence_fixture("holdout")), selection, holdout,
        workers = 1L, source_commit = paste(rep("a", 40L), collapse = ""))
    expect_true(verify_stage1_evidence_artifact(artifact))
    expect_identical(read_stage1_evidence_artifact(artifact)$selection$selected_candidate,
                     "C1_symmetric_consensus")

    file.create(file.path(artifact, "undeclared.txt"))
    expect_error(verify_stage1_evidence_artifact(artifact), class = "stage1_evidence_error")
    unlink(file.path(artifact, "undeclared.txt"))
    cat("tampered", file = file.path(artifact, "results.csv"), append = TRUE)
    expect_error(verify_stage1_evidence_artifact(artifact), class = "stage1_evidence_error")
})
