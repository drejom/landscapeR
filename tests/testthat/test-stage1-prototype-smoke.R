test_that("stage1_candidate_smoke runs the frozen heterogeneous smoke stratum", {
    smoke <- stage1_candidate_smoke()

    expect_identical(smoke$protocol_id, "stage1-heterogeneous-v1")
    expect_s4_class(smoke$control@ground_truth, "HeterogeneousSubspaceGroundTruth")
    expect_equal(smoke$results$candidate,
                 c("C1_symmetric_consensus", "C2_block_scaled_svd"))
    expect_true(all(is.finite(as.matrix(smoke$results[, c(
        "shared_recovery_error", "response_recovery_error",
        "exclusive_leakage", "projection_error"
    )]))))
    expect_true(smoke$gates$sample_map_aligned)
    expect_true(smoke$gates$heterogeneous_features)
    expect_length(smoke$gates$complete_case_exclusions, 0L)
    expect_true(all(smoke$gates$missing_projection_id_rejected))
    expect_false(smoke$gates$production_strategy_registered)
})

test_that("stage1_candidate_smoke is deterministic apart from elapsed timing", {
    first <- stage1_candidate_smoke()
    second <- stage1_candidate_smoke()
    compare <- setdiff(names(first$results), "elapsed_sec")
    expect_equal(first$results[, compare], second$results[, compare])
})

test_that("the smoke generator uses sample-map identities, not assay order", {
    smoke <- stage1_candidate_smoke()
    std <- smoke$control
    maps <- as.data.frame(sampleMap(std), stringsAsFactors = FALSE)
    layer1 <- maps$colname[maps$assay == "layer1"]
    layer2 <- maps$colname[maps$assay == "layer2"]
    expect_false(identical(layer1, layer2))
    expect_error(stage1_candidate_smoke(1002L), class = "stage1_prototype_error")
})
