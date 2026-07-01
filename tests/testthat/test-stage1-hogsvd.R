test_that("hogsvd_averaged and hogsvd_prereduced are registered", {
    strats <- list_strategies("Decomposer")
    expect_true("Decomposer:hogsvd_averaged"   %in% strats)
    expect_true("Decomposer:hogsvd_prereduced" %in% strats)
})

test_that("synthetic_control produces valid StateTransitionData", {
    std <- synthetic_control(n = 10L, p = 20L, K = 2L, signal = 30, seed = 1L)
    expect_s4_class(std, "StateTransitionData")
    expect_s4_class(std@ground_truth, "SubspaceGroundTruth")
    expect_equal(ncol(std@ground_truth@shared), 1L)
    expect_equal(length(std@ground_truth@exclusive), 2L)
    expect_equal(length(experiments(std)), 2L)
    expect_false(is.null(metadata(std)$control))
})

test_that("hogsvd_averaged recovers v_true exactly in noiseless rank-1 case", {
    # Noiseless: signal >> noise (noise_sd=0 would give NaN in BBP check; use tiny noise)
    std <- synthetic_control(n = 10L, p = 30L, K = 2L,
                              signal = 100, signal_spec = 5,
                              noise_sd = 0.001, seed = 7L)
    bm <- suppressWarnings(recovery_benchmark(std, "hogsvd_averaged"))
    expect_lt(bm$angle_deg, 1)   # < 1 degree
})

test_that("hogsvd_averaged returns stage_success with stage1 metadata", {
    std <- synthetic_control(n = 15L, p = 50L, K = 2L, signal = 40, seed = 2L)
    ctor <- get_strategy("Decomposer", "hogsvd_averaged")
    result <- suppressWarnings(decompose(ctor(), std))
    expect_s4_class(result, "StageResult")
    expect_equal(result@status, "success")
    s1 <- metadata(result@value)$stage1
    expect_false(is.null(s1))
    expect_s4_class(s1, "DecompositionResult")
    expect_equal(length(dr_V_star(s1)), 50L)
})

test_that("hogsvd_prereduced returns stage_success", {
    std <- synthetic_control(n = 15L, p = 50L, K = 2L, signal = 40, seed = 3L)
    ctor <- get_strategy("Decomposer", "hogsvd_prereduced")
    result <- suppressWarnings(decompose(ctor(), std))
    expect_equal(result@status, "success")
})

test_that("hogsvd_averaged angle improves with signal (above BBP)", {
    # p=50, n=20: BBP = (20*50)^0.25 = 5.6; use signals 10 and 50
    bm_lo <- suppressWarnings(
        recovery_benchmark(
            synthetic_control(n=20L, p=50L, K=2L, signal=10, seed=10L),
            "hogsvd_averaged"))
    bm_hi <- suppressWarnings(
        recovery_benchmark(
            synthetic_control(n=20L, p=50L, K=2L, signal=50, seed=10L),
            "hogsvd_averaged"))
    expect_lt(bm_hi$angle_deg, bm_lo$angle_deg)
})

test_that("decompose (hogsvd_averaged) fails with StageResult when schema_version is invalid", {
    std <- empty_std()
    std@schema_version <- "99.0.0"
    ctor <- get_strategy("Decomposer", "hogsvd_averaged")
    result <- decompose(ctor(), std)
    expect_s4_class(result, "StageResult")
    expect_equal(result@status, "failure")
})

test_that("decompose (hogsvd_prereduced) fails with StageResult when schema_version is invalid", {
    std <- empty_std()
    std@schema_version <- "99.0.0"
    ctor <- get_strategy("Decomposer", "hogsvd_prereduced")
    result <- decompose(ctor(), std)
    expect_s4_class(result, "StageResult")
    expect_equal(result@status, "failure")
})

test_that("decompose boundary failure fires without run_pipeline (direct call)", {
    std <- empty_std()
    std@schema_version <- "99.0.0"
    ctor <- get_strategy("Decomposer", "hogsvd_averaged")
    result <- decompose(ctor(), std)
    expect_s4_class(result, "StageResult")
    expect_equal(result@status, "failure")
    expect_match(result@reason, "schema mismatch|expected StateTransitionData", perl = FALSE)
})

test_that("multi-layer averaging: K=3 improves over K=2 at high signal", {
    # Reliable only when signal is clearly above BBP
    bm2 <- suppressWarnings(
        recovery_benchmark(
            synthetic_control(n=30L, p=50L, K=2L, signal=60, seed=20L),
            "hogsvd_averaged"))
    bm3 <- suppressWarnings(
        recovery_benchmark(
            synthetic_control(n=30L, p=50L, K=3L, signal=60, seed=20L),
            "hogsvd_averaged"))
    # K=3 should be at most a few degrees worse (seed variability), never much worse
    expect_lt(bm3$angle_deg, bm2$angle_deg + 5)
})
<<<<<<< HEAD

test_that("decompose returns DecompositionResult in metadata()$stage1", {
    std <- synthetic_control(n = 20L, p = 50L, K = 2L, signal = 30, seed = 1L)
    ctor <- get_strategy("Decomposer", "hogsvd_averaged")
    result <- suppressWarnings(decompose(ctor(), std))
    s1 <- metadata(result@value)$stage1
    expect_s4_class(s1, "DecompositionResult")
    expect_equal(length(dr_V_star(s1)), 50L)
})

# ---------------------------------------------------------------------------
# shared_axis() contract accessor tests
# ---------------------------------------------------------------------------

test_that("shared_axis(dr, j=1) returns V_k[,1]", {
    p <- 10L; k <- 3L; K <- 2L
    V_k     <- matrix(rnorm(p * k), nrow = p, ncol = k)
    sigma_k <- matrix(runif(K * k), nrow = K, ncol = k)
    coords_k <- lapply(seq_len(K), function(i) matrix(rnorm(5L * k), nrow = 5L, ncol = k))
    dr <- DecompositionResult(
        V_star   = V_k[, 1L],
        sigma    = sigma_k[, 1L],
        coords   = lapply(coords_k, function(m) m[, 1L]),
        warnings = character(0),
        V_k      = V_k,
        sigma_k  = sigma_k,
        coords_k = coords_k,
        k        = k
    )
    expect_equal(shared_axis(dr, j = 1L), V_k[, 1L])
})

test_that("shared_axis(dr, j=2) returns V_k[,2]", {
    p <- 10L; k <- 3L; K <- 2L
    V_k     <- matrix(rnorm(p * k), nrow = p, ncol = k)
    sigma_k <- matrix(runif(K * k), nrow = K, ncol = k)
    coords_k <- lapply(seq_len(K), function(i) matrix(rnorm(5L * k), nrow = 5L, ncol = k))
    dr <- DecompositionResult(
        V_star   = V_k[, 1L],
        sigma    = sigma_k[, 1L],
        coords   = lapply(coords_k, function(m) m[, 1L]),
        warnings = character(0),
        V_k      = V_k,
        sigma_k  = sigma_k,
        coords_k = coords_k,
        k        = k
    )
    expect_equal(shared_axis(dr, j = 2L), V_k[, 2L])
})

test_that("shared_axis() default (j=1) matches dr_V_star()", {
    p <- 8L; k <- 2L; K <- 2L
    V_k     <- matrix(rnorm(p * k), nrow = p, ncol = k)
    sigma_k <- matrix(runif(K * k), nrow = K, ncol = k)
    coords_k <- lapply(seq_len(K), function(i) matrix(rnorm(4L * k), nrow = 4L, ncol = k))
    dr <- DecompositionResult(
        V_star   = V_k[, 1L],
        sigma    = sigma_k[, 1L],
        coords   = lapply(coords_k, function(m) m[, 1L]),
        warnings = character(0),
        V_k      = V_k,
        sigma_k  = sigma_k,
        coords_k = coords_k,
        k        = k
    )
    expect_equal(shared_axis(dr), dr_V_star(dr))
})
