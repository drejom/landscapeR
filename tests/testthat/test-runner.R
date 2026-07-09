test_that("run_pipeline returns stage_success on synthetic data", {
    std  <- synthetic_control(n = 20L, p = 50L, K = 2L, signal = 30, seed = 1L)
    cfg  <- new("PipelineConfig",
        dataset    = "test",
        strategies = list(Decomposer = "hogsvd_averaged",
                          DynamicsEstimator = "kde_logdensity"),
        params     = list()
    )
    result <- suppressWarnings(run_pipeline(std, cfg))
    expect_s4_class(result, "StageResult")
    expect_equal(result@status, "success")
    expect_false(is.null(metadata(result@value)$stage1))
    expect_false(is.null(metadata(result@value)$stage2))
})

test_that("run_pipeline returns failure on schema mismatch before any stage runs", {
    std <- synthetic_control(n = 20L, p = 50L, K = 2L, signal = 30, seed = 1L)
    std@schema_version <- "99.99.99"  # synthetic sentinel — never a real version
    cfg <- new("PipelineConfig",
        dataset    = "test",
        strategies = list(Decomposer = "hogsvd_averaged"),
        params     = list()
    )
    result <- run_pipeline(std, cfg)
    expect_s4_class(result, "StageResult")
    expect_equal(result@status, "failure")
    expect_match(result@reason, "schema mismatch")
})

test_that("run_pipeline skips stages with no strategy configured", {
    std <- synthetic_control(n = 20L, p = 50L, K = 2L, signal = 30, seed = 1L)
    cfg <- new("PipelineConfig",
        dataset    = "test",
        strategies = list(Decomposer = "hogsvd_averaged"),
        params     = list()
    )
    result <- suppressWarnings(run_pipeline(std, cfg))
    expect_equal(result@status, "success")
    # Stage 2 was skipped (no DynamicsEstimator in strategies)
    expect_null(metadata(result@value)$stage2)
    expect_false(is.null(metadata(result@value)$stage1))
})
