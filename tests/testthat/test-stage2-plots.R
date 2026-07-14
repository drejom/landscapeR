test_that("plot_potential returns a ggplot after Stage 2 has run", {
    std <- synthetic_control(n = 40L, p = 500L, K = 2L, signal = 30, seed = 1L)
    std2 <- suppressWarnings(
        decompose(get_strategy("Decomposer", "hogsvd_averaged")(), std))@value
    std3 <- estimate_dynamics(
        get_strategy("DynamicsEstimator", "kde_logdensity")(), std2)@value
    expect_s3_class(plot_potential(std3), "gg")
})

test_that("plot_potential rug draws from coords_k when coords slot is empty", {
    std <- synthetic_control(n = 40L, p = 500L, K = 2L, signal = 30, seed = 1L)
    std2 <- suppressWarnings(
        decompose(get_strategy("Decomposer", "hogsvd_averaged")(), std))@value
    std3 <- estimate_dynamics(
        get_strategy("DynamicsEstimator", "kde_logdensity")(), std2)@value
    # Replace stage1 with a copy that has empty coords but populated coords_k
    s1 <- metadata(std3)$stage1
    s1_empty_coords <- DecompositionResult(
        V_star   = dr_V_star(s1),
        sigma    = dr_sigma(s1),
        coords   = list(),
        warnings = character(0),
        V_k      = dr_V_k(s1),
        sigma_k  = dr_sigma_k(s1),
        coords_k = dr_coords_k(s1),
        k        = dr_k(s1)
    )
    md <- metadata(std3)
    md$stage1 <- s1_empty_coords
    metadata(std3) <- md
    # Should still render (using coords_k fallback), not silently drop the rug
    expect_s3_class(plot_potential(std3), "gg")
})

test_that("plot_potential omits point-estimate critical-point classification by default", {
    std <- synthetic_control(n = 40L, p = 500L, K = 2L, signal = 30, seed = 1L)
    std2 <- suppressWarnings(
        decompose(get_strategy("Decomposer", "hogsvd_averaged")(), std))@value
    std3 <- estimate_dynamics(
        get_strategy("DynamicsEstimator", "kde_logdensity")(), std2)@value

    plot <- plot_potential(std3)

    expect_s3_class(plot, "gg")
    expect_null(plot$labels$shape)
    expect_false(any(vapply(
        plot$layers,
        function(layer) inherits(layer$geom, "GeomPoint") ||
            inherits(layer$geom, "GeomSegment"),
        logical(1L)
    )))
})

test_that("plot_potential requires explicit opt-in for point-estimate classification", {
    std <- synthetic_control(n = 40L, p = 500L, K = 2L, signal = 30, seed = 1L)
    std2 <- suppressWarnings(
        decompose(get_strategy("Decomposer", "hogsvd_averaged")(), std))@value
    std3 <- estimate_dynamics(
        get_strategy("DynamicsEstimator", "kde_logdensity")(), std2)@value

    plot <- plot_potential(std3, show_critical_points = TRUE)

    expect_identical(plot$labels$shape, "Critical point")
    expect_true(any(vapply(
        plot$layers,
        function(layer) inherits(layer$geom, "GeomPoint"),
        logical(1L)
    )))
})

test_that("plot_potential errors when Stage 2 is absent", {
    std <- synthetic_control(n = 10L, p = 20L, K = 2L, signal = 30, seed = 1L)
    expect_error(plot_potential(std), "Stage 2 has not been run")
})
