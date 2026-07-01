test_that("plot_potential returns a ggplot after Stage 2 has run", {
    std <- synthetic_control(n = 40L, p = 500L, K = 2L, signal = 30, seed = 1L)
    std2 <- suppressWarnings(
        decompose(get_strategy("Decomposer", "hogsvd_averaged")(), std))@value
    std3 <- estimate_dynamics(
        get_strategy("DynamicsEstimator", "kde_logdensity")(), std2)@value
    expect_s3_class(plot_potential(std3), "gg")
})

test_that("plot_potential errors when Stage 2 is absent", {
    std <- synthetic_control(n = 10L, p = 20L, K = 2L, signal = 30, seed = 1L)
    expect_error(plot_potential(std), "Stage 2 has not been run")
})
