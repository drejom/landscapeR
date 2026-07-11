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

test_that("run_pipeline dispatches to hogsvd_prereduced when configured", {
    std <- synthetic_control(n = 20L, p = 50L, K = 2L, signal = 30, seed = 1L)
    cfg <- new("PipelineConfig",
        dataset    = "test",
        strategies = list(Decomposer = "hogsvd_prereduced"),
        params     = list()
    )
    result <- suppressWarnings(run_pipeline(std, cfg))
    expect_s4_class(result, "StageResult")
    expect_equal(result@status, "success")
    stage1 <- metadata(result@value)$stage1
    expect_false(is.null(stage1))
    expect_s4_class(stage1, "DecompositionResult")
})

test_that("run_pipeline recovers wells and barrier on a known double-well potential", {
    # n=300, beta=2, seed=42 matches the config already established as
    # reliable in test-stage2-kde.R's well/barrier-position recovery tests.
    std <- synthetic_potential_control(n = 300L, beta = 2, seed = 42L)

    # Stage 1 stub: coords are the raw x samples (same pattern as
    # potential_recovery_benchmark() -- Stage 2 is exercised directly on
    # planted 1-D coordinates, without running a real Decomposer).
    x_samp <- colData(std)$x_coord
    md <- metadata(std)
    md$stage1 <- DecompositionResult(
        V_star   = rep(1, 1L),
        sigma    = 1,
        coords   = list(x_samp),
        warnings = character(0),
        V_k      = matrix(1, nrow = 1L, ncol = 1L),
        sigma_k  = matrix(1, nrow = 1L, ncol = 1L),
        coords_k = list(matrix(x_samp, ncol = 1L)),
        k        = 1L
    )
    metadata(std) <- md

    cfg <- new("PipelineConfig",
        dataset    = "test",
        strategies = list(DynamicsEstimator = "kde_logdensity"),
        params     = list()
    )
    result <- suppressWarnings(run_pipeline(std, cfg))
    expect_s4_class(result, "StageResult")
    expect_equal(result@status, "success")

    s2 <- metadata(result@value)$stage2
    expect_false(is.null(s2))
    expect_gte(length(s2$wells), 2L)
    expect_gte(length(s2$barriers), 1L)

    # Barrier height magnitude accuracy is not yet reliable at this sample
    # size (empirically ranges ~0.06-1.3 across seeds at n=300) -- that is
    # exactly the [tbd] threshold ADR 0002 is waiting on. Only assert a
    # finite height was recovered, not a tolerance on its value.
    bh_found <- unlist(lapply(s2$barrier_heights, function(h) h[!is.na(h)]))
    expect_gte(length(bh_found), 1L)
    expect_true(all(is.finite(bh_found)))
})
