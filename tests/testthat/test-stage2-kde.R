test_that("kde_logdensity is registered under DynamicsEstimator", {
    strats <- list_strategies("DynamicsEstimator")
    expect_true("DynamicsEstimator:kde_logdensity" %in% strats)
})

test_that("estimate_dynamics returns StageResult with metadata()$stage2", {
    std_pot <- synthetic_potential_control(n = 100L, seed = 1L)
    x_samp <- colData(std_pot)$x_coord
    md <- metadata(std_pot)
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
    metadata(std_pot) <- md

    ctor <- get_strategy("DynamicsEstimator", "kde_logdensity")
    res  <- estimate_dynamics(ctor(), std_pot)

    expect_s4_class(res, "StageResult")
    expect_equal(res@status, "success")

    s2 <- metadata(res@value)$stage2
    expect_false(is.null(s2))
    expect_true(all(c("x", "U", "wells", "barriers") %in% names(s2)))
})

test_that("estimate_dynamics fails gracefully when stage1 is absent", {
    std_pot <- synthetic_potential_control(n = 50L, seed = 2L)
    ctor <- get_strategy("DynamicsEstimator", "kde_logdensity")
    res  <- estimate_dynamics(ctor(), std_pot)
    expect_equal(res@status, "failure")
    expect_match(res@reason, "Stage 1 has not been run")
})

test_that("Stage 2 detects 2 wells and 1 barrier on double-well potential", {
    std_pot <- synthetic_potential_control(n = 300L, beta = 2, seed = 42L)
    bm <- potential_recovery_benchmark(std_pot, "kde_logdensity")

    expect_gte(bm$n_wells_found, 2L)
    expect_gte(bm$n_barriers_found, 1L)
})

test_that("Stage 2 well positions within 0.15 of true wells", {
    std_pot <- synthetic_potential_control(n = 300L, beta = 2, seed = 42L)
    bm <- potential_recovery_benchmark(std_pot, "kde_logdensity")

    expect_false(is.na(bm$well_error))
    expect_lt(bm$well_error, 0.15)
})

test_that("Stage 2 barrier position within 0.30 of true barrier (x=0)", {
    # KDE with n=300 can place the barrier peak ~0.25 off centre due to
    # finite-sample asymmetry; 0.30 is the honest threshold at this scale.
    std_pot <- synthetic_potential_control(n = 300L, beta = 2, seed = 42L)
    bm <- potential_recovery_benchmark(std_pot, "kde_logdensity")

    expect_false(is.na(bm$barrier_error))
    expect_lt(bm$barrier_error, 0.30)
})

test_that("plot_potential does not error on stage2 output", {
    std_pot <- synthetic_potential_control(n = 100L, seed = 7L)
    x_samp <- colData(std_pot)$x_coord
    md <- metadata(std_pot)
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
    metadata(std_pot) <- md

    ctor <- get_strategy("DynamicsEstimator", "kde_logdensity")
    res  <- estimate_dynamics(ctor(), std_pot)

    expect_no_error(plot_potential(res@value))
})

test_that("plot_potential with colour_by does not error", {
    std_pot <- synthetic_potential_control(n = 100L, seed = 8L)
    x_samp <- colData(std_pot)$x_coord
    md <- metadata(std_pot)
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
    metadata(std_pot) <- md

    ctor <- get_strategy("DynamicsEstimator", "kde_logdensity")
    res  <- estimate_dynamics(ctor(), std_pot)

    expect_no_error(plot_potential(res@value, colour_by = "well"))
})

test_that("stage2 metadata$stage2$x and $U have equal length", {
    std_pot <- synthetic_potential_control(n = 100L, seed = 9L)
    x_samp <- colData(std_pot)$x_coord
    md <- metadata(std_pot)
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
    metadata(std_pot) <- md

    ctor <- get_strategy("DynamicsEstimator", "kde_logdensity")
    res  <- estimate_dynamics(ctor(), std_pot)

    s2 <- metadata(res@value)$stage2
    expect_equal(length(s2$x), length(s2$U))
})

test_that("synthetic_potential_control produces PotentialGroundTruth", {
    std_pot <- synthetic_potential_control(n = 50L, seed = 3L)
    expect_s4_class(std_pot@ground_truth, "PotentialGroundTruth")
    ctrl <- metadata(std_pot)$potential_control
    expect_false(is.null(ctrl))
    expect_equal(ctrl$true_wells, c(-1, 1))
    expect_equal(ctrl$true_barrier, 0)
    expect_equal(ctrl$true_barrier_height, 1)
})

test_that("estimate_dynamics fails with StageResult when schema_version is invalid (direct call)", {
    std <- empty_std()
    std@schema_version <- "99.0.0"
    ctor <- get_strategy("DynamicsEstimator", "kde_logdensity")
    result <- estimate_dynamics(ctor(), std)
    expect_s4_class(result, "StageResult")
    expect_equal(result@status, "failure")
})

test_that("estimate_dynamics fails with typed StageResult for out-of-range component", {
    # Build a minimal synthetic control and run Stage 1
    std <- synthetic_control(n = 15L, p = 50L, K = 2L, signal = 40, seed = 99L)
    ctor_d <- get_strategy("Decomposer", "hogsvd_averaged")
    s1_result <- suppressWarnings(decompose(ctor_d(), std))
    std_with_s1 <- s1_result@value

    ctor_e <- get_strategy("DynamicsEstimator", "kde_logdensity")
    result <- estimate_dynamics(ctor_e(params = list(component = 99L)), std_with_s1)
    expect_s4_class(result, "StageResult")
    expect_equal(result@status, "failure")
    expect_match(result@reason, "component 99")
})

test_that("pool_layers=FALSE uses single layer", {
    std_pot <- synthetic_potential_control(n = 100L, seed = 4L)
    x_samp <- colData(std_pot)$x_coord
    md <- metadata(std_pot)
    md$stage1 <- DecompositionResult(
        V_star   = rep(1, 1L),
        sigma    = c(1, 1),
        coords   = list(x_samp, x_samp),
        warnings = character(0),
        V_k      = matrix(1, nrow = 1L, ncol = 1L),
        sigma_k  = matrix(c(1, 1), nrow = 2L, ncol = 1L),
        coords_k = list(matrix(x_samp, ncol = 1L), matrix(x_samp, ncol = 1L)),
        k        = 1L
    )
    metadata(std_pot) <- md

    ctor <- get_strategy("DynamicsEstimator", "kde_logdensity")
    res  <- estimate_dynamics(ctor(params = list(pool_layers = FALSE, layer = 1L)),
                               std_pot)
    expect_equal(res@status, "success")
    s2 <- metadata(res@value)$stage2
    expect_equal(s2$n_obs, length(x_samp))
})

test_that("barrier_heights is a named list of 2-element left/right vectors", {
    # Double-well with 1 barrier should yield a list of length 1, each element
    # a named numeric(2) with "left" and "right" heights.
    std_pot <- synthetic_potential_control(n = 300L, beta = 2, seed = 42L)
    x_samp <- colData(std_pot)$x_coord
    md <- metadata(std_pot)
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
    metadata(std_pot) <- md

    ctor <- get_strategy("DynamicsEstimator", "kde_logdensity")
    res  <- estimate_dynamics(ctor(), std_pot)
    expect_equal(res@status, "success")

    s2 <- metadata(res@value)$stage2
    bh <- s2$barrier_heights

    # Structure: named list, one element per barrier
    expect_true(is.list(bh))
    expect_equal(length(bh), length(s2$barriers))
    expect_equal(names(bh), paste0("barrier_", seq_along(s2$barriers)))

    # Each element is a named numeric(2) with "left" and "right"
    for (h in bh) {
        expect_true(is.numeric(h))
        expect_equal(length(h), 2L)
        expect_equal(names(h), c("left", "right"))
    }

    # For the symmetric double-well at n=300, both sides should be positive
    # (barrier is above both wells) and approximately equal
    if (length(bh) >= 1L) {
        h1 <- bh[[1L]]
        non_na <- h1[!is.na(h1)]
        expect_true(all(non_na > 0))
    }
})

# ---------------------------------------------------------------------------
# Issue #23: Provenance persistence
# ---------------------------------------------------------------------------

test_that("kde_logdensity: exactly one ProvenanceStep in StageResult@provenance", {
    std_pot <- synthetic_potential_control(n = 100L, seed = 1L)
    x_samp <- colData(std_pot)$x_coord
    md <- metadata(std_pot)
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
    metadata(std_pot) <- md

    ctor <- get_strategy("DynamicsEstimator", "kde_logdensity")
    res  <- estimate_dynamics(ctor(), std_pot)

    expect_equal(res@status, "success")
    expect_length(res@provenance, 1L)
    expect_true(is(res@provenance[[1L]], "ProvenanceStep"))
})

test_that("kde_logdensity: ProvenanceStep is also persisted in returned StateTransitionData@provenance", {
    std_pot <- synthetic_potential_control(n = 100L, seed = 1L)
    x_samp <- colData(std_pot)$x_coord
    md <- metadata(std_pot)
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
    metadata(std_pot) <- md

    ctor <- get_strategy("DynamicsEstimator", "kde_logdensity")
    res  <- estimate_dynamics(ctor(), std_pot)

    expect_equal(res@status, "success")
    prov <- res@value@provenance
    expect_length(prov, 1L)
    expect_true(is(prov[[1L]], "ProvenanceStep"))
    expect_equal(prov[[1L]]@stage, "estimate_dynamics")
    expect_equal(prov[[1L]]@implementation, "kde_logdensity")
    expect_equal(prov[[1L]]@status, "success")
})

test_that("kde_logdensity: StageResult@provenance is not a StateTransitionData", {
    std_pot <- synthetic_potential_control(n = 100L, seed = 1L)
    x_samp <- colData(std_pot)$x_coord
    md <- metadata(std_pot)
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
    metadata(std_pot) <- md

    ctor <- get_strategy("DynamicsEstimator", "kde_logdensity")
    res  <- estimate_dynamics(ctor(), std_pot)

    expect_equal(res@status, "success")
    expect_false(is(res@provenance[[1L]], "StateTransitionData"))
})
