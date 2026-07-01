test_that("plot_spectrum returns a ggplot on a fresh StateTransitionData", {
    std <- synthetic_control(n = 40L, p = 500L, K = 2L, signal = 30, seed = 1L)
    p <- plot_spectrum(std)
    expect_s3_class(p, "gg")
})

test_that("plot_components returns a ggplot after Stage 1 has run", {
    std <- synthetic_control(n = 40L, p = 500L, K = 2L, signal = 30, seed = 1L)
    ctor <- get_strategy("Decomposer", "hogsvd_averaged")
    std2 <- suppressWarnings(decompose(ctor(), std))@value
    p <- plot_components(std2, colour_by = "group")
    expect_s3_class(p, "gg")
})

test_that("plot_decomposition returns a ggplot after Stage 1 has run", {
    std <- synthetic_control(n = 40L, p = 500L, K = 2L, signal = 30, seed = 1L)
    ctor <- get_strategy("Decomposer", "hogsvd_averaged")
    std2 <- suppressWarnings(decompose(ctor(), std))@value
    p <- plot_decomposition(std2)
    expect_s3_class(p, "gg")
})

test_that("plot_decomposition with component=2 returns a ggplot", {
    std <- synthetic_control(n = 40L, p = 500L, K = 2L, signal = 30, seed = 1L)
    ctor <- get_strategy("Decomposer", "hogsvd_averaged")
    std2 <- suppressWarnings(decompose(ctor(), std))@value
    p <- plot_decomposition(std2, component = 2L)
    expect_s3_class(p, "gg")
})

test_that("plot_spectrum errors on empty StateTransitionData", {
    # plot_spectrum needs at least one experiment
    expect_error(plot_spectrum(empty_std()), regexp = NULL)
})

test_that("plot_decomposition errors when Stage 1 is absent", {
    std <- synthetic_control(n = 10L, p = 20L, K = 2L, signal = 30, seed = 1L)
    expect_error(plot_decomposition(std), "Stage 1 has not been run")
})

test_that("plot_components errors when Stage 1 is absent", {
    std <- synthetic_control(n = 10L, p = 20L, K = 2L, signal = 30, seed = 1L)
    expect_error(plot_components(std), "Stage 1 has not been run")
})
