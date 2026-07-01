test_that("kde_logdensity is registered under DynamicsEstimator", {
    strats <- list_strategies("DynamicsEstimator")
    expect_true("DynamicsEstimator:kde_logdensity" %in% strats)
})

test_that("estimate_dynamics returns StageResult with metadata()$stage2", {
    std_pot <- synthetic_potential_control(n = 100L, seed = 1L)
    x_samp <- colData(std_pot)$x_coord
    md <- metadata(std_pot)
    md$stage1 <- list(V_star = matrix(1, nrow = 1L), sigma = 1,
                      coords = list(x_samp), warnings = character(0))
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

    expect_equal(bm$n_wells_found, 2L)
    expect_equal(bm$n_barriers_found, 1L)
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
    md$stage1 <- list(V_star = matrix(1, nrow = 1L), sigma = 1,
                      coords = list(x_samp), warnings = character(0))
    metadata(std_pot) <- md

    ctor <- get_strategy("DynamicsEstimator", "kde_logdensity")
    res  <- estimate_dynamics(ctor(), std_pot)

    expect_no_error(plot_potential(res@value))
})

test_that("plot_potential with colour_by does not error", {
    std_pot <- synthetic_potential_control(n = 100L, seed = 8L)
    x_samp <- colData(std_pot)$x_coord
    md <- metadata(std_pot)
    md$stage1 <- list(V_star = matrix(1, nrow = 1L), sigma = 1,
                      coords = list(x_samp), warnings = character(0))
    metadata(std_pot) <- md

    ctor <- get_strategy("DynamicsEstimator", "kde_logdensity")
    res  <- estimate_dynamics(ctor(), std_pot)

    expect_no_error(plot_potential(res@value, colour_by = "well"))
})

test_that("stage2 metadata$stage2$x and $U have equal length", {
    std_pot <- synthetic_potential_control(n = 100L, seed = 9L)
    x_samp <- colData(std_pot)$x_coord
    md <- metadata(std_pot)
    md$stage1 <- list(V_star = matrix(1, nrow = 1L), sigma = 1,
                      coords = list(x_samp), warnings = character(0))
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

test_that("pool_layers=FALSE uses single layer", {
    std_pot <- synthetic_potential_control(n = 100L, seed = 4L)
    x_samp <- colData(std_pot)$x_coord
    md <- metadata(std_pot)
    md$stage1 <- list(V_star = matrix(1, nrow = 1L), sigma = 1,
                      coords = list(x_samp, x_samp), warnings = character(0))
    metadata(std_pot) <- md

    ctor <- get_strategy("DynamicsEstimator", "kde_logdensity")
    res  <- estimate_dynamics(ctor(params = list(pool_layers = FALSE, layer = 1L)),
                               std_pot)
    expect_equal(res@status, "success")
    s2 <- metadata(res@value)$stage2
    expect_equal(s2$n_obs, length(x_samp))
})
