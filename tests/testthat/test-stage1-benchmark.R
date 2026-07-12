test_that("stage1 benchmark manifest is frozen and validates", {
    manifest <- stage1_benchmark_manifest()
    expect_silent(validate_stage1_benchmark_manifest(manifest))
    expect_equal(manifest$seeds$split, rep(c("calibration", "holdout"), each = 20L))
    manifest$candidates <- "wrong"
    expect_error(validate_stage1_benchmark_manifest(manifest), class = "stage1_benchmark_error")
    manifest <- stage1_benchmark_manifest()
    manifest$rank <- 3L
    expect_error(validate_stage1_benchmark_manifest(manifest), class = "stage1_benchmark_error")
})

test_that("one benchmark replicate is deterministic and artifact hashes verify", {
    manifest <- stage1_benchmark_manifest()
    first <- run_stage1_benchmark_replicate(manifest)
    second <- run_stage1_benchmark_replicate(manifest)
    compare <- setdiff(names(first), c("elapsed_sec", "peak_vcells_bytes"))
    expect_equal(first[, compare], second[, compare])
    other_seed <- run_stage1_benchmark_replicate(manifest, 1002L)
    expect_equal(other_seed$seed, c(1002L, 1002L))
    missing_block <- run_stage1_benchmark_replicate(
        manifest, stratum = modifyList(list(n = 20L, K = 2L, shared_signal = 24,
        exclusive_signal = 12, confounder_signal = 12, noise_sd = 1,
        missing_block_rate = 0, sample_order = "permuted", feature_order = "permuted",
        projection_case = "exact_ids"), list(missing_block_rate = .20)))
    expect_true(all(missing_block$gate_passed))
    three_layer_missing <- run_stage1_benchmark_replicate(manifest, seed = 1001L,
        stratum = modifyList(list(n = 20L, K = 2L, shared_signal = 24,
        exclusive_signal = 12, confounder_signal = 12, noise_sd = 1,
        missing_block_rate = 0, sample_order = "permuted", feature_order = "permuted",
        projection_case = "exact_ids"), list(K = 3L, missing_block_rate = .20)))
    expect_true(all(three_layer_missing$gate_passed))
    control <- landscapeR:::.stage1_heterogeneous_control(
        seed = 1001L, n = 20L, p = c(80L, 400L, 1200L), missing_block_rate = .20)
    expect_gte(nrow(landscapeR:::.prototype_complete_layers(control)$matrices[[1L]]), 12L)
    expect_equal(manifest$feature_counts[["3"]], c(80L, 400L, 1200L))
    missing_id <- run_stage1_benchmark_replicate(manifest, stratum = modifyList(
        list(n = 20L, K = 2L, shared_signal = 24, exclusive_signal = 12,
             confounder_signal = 12, noise_sd = 1, missing_block_rate = 0,
             sample_order = "permuted", feature_order = "permuted",
             projection_case = "exact_ids"), list(projection_case = "missing_id")))
    expect_true(all(missing_id$typed_failure_rate == 1L))
    expect_true(all(is.na(missing_id$projection_error)))

    expect_error(run_stage1_benchmark_replicate(manifest,
        stratum = modifyList(list(n = 20L, K = 2L, shared_signal = 24,
        exclusive_signal = 12, confounder_signal = 12, noise_sd = 1,
        missing_block_rate = 0, sample_order = "permuted", feature_order = "permuted",
        projection_case = "exact_ids"), list(n = 21L))), class = "stage1_benchmark_error")

    path <- tempfile("stage1-artifact-")
    write_stage1_benchmark_artifact(path, manifest)
    saved <- utils::read.csv(file.path(path, "results.csv"), stringsAsFactors = FALSE)
    expect_true(all(c("stratum", "exclusions", "failure_reason", "protocol_digest", "generator_digest") %in% names(saved)))
    expect_true(verify_stage1_benchmark_artifact(path))
    expect_error(write_stage1_benchmark_artifact(path, manifest), class = "stage1_benchmark_error")
})
