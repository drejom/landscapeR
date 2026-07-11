test_that("project_into() sets a length-1 sigma for the projected secondary cohort", {
    std_primary   <- synthetic_control(n = 40L, p = 500L, K = 2L, signal = 30, seed = 1L)
    std_secondary <- synthetic_control(n = 30L, p = 500L, K = 2L, signal = 30, seed = 2L)

    std_primary2 <- suppressWarnings(
        decompose(get_strategy("Decomposer", "hogsvd_averaged")(), std_primary))@value

    result <- project_into(std_primary2, std_secondary)

    s1 <- metadata(result)$stage1
    expect_s4_class(s1, "DecompositionResult")

    # sigma must be length 1, matching nrow(sigma_k) -- the projected object
    # has exactly one "layer" (the projected secondary layer), not k
    # per-component values.
    expect_length(dr_sigma(s1), 1L)
    expect_equal(dr_sigma(s1), dr_sigma_k(s1)[, 1L])
    expect_equal(nrow(dr_sigma_k(s1)), length(dr_sigma(s1)))
})

test_that("project_into() output passes DecompositionResult validity", {
    std_primary   <- synthetic_control(n = 40L, p = 500L, K = 2L, signal = 30, seed = 3L)
    std_secondary <- synthetic_control(n = 25L, p = 500L, K = 2L, signal = 30, seed = 4L)

    std_primary2 <- suppressWarnings(
        decompose(get_strategy("Decomposer", "hogsvd_averaged")(), std_primary))@value

    result <- project_into(std_primary2, std_secondary)
    s1 <- metadata(result)$stage1

    expect_true(validObject(s1))
    expect_equal(dim(dr_coords_k(s1)[[1L]]), c(25L, dr_k(s1)))
})
