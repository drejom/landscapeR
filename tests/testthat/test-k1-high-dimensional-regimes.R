test_that("high-dimensional regimes declare distinct information structures", {
    regimes <- k1_high_dimensional_regime()

    expect_identical(names(regimes), c(
        "fixed_total_spike", "fixed_sparse", "growing_coherent",
        "correlated_modules", "null_near_null"
    ))
    expect_identical(
        vapply(regimes, `[[`, character(1L), "covariance_regime"),
        c(
            fixed_total_spike = "independent-gaussian",
            fixed_sparse = "independent-gaussian",
            growing_coherent = "independent-gaussian",
            correlated_modules = "block-correlated-gaussian",
            null_near_null = "independent-gaussian"
        )
    )
    expect_true(all(vapply(regimes, function(regime) {
        identical(regime$claim_status, "disclosed_calibration_only")
    }, logical(1L))))
    expect_error(
        k1_high_dimensional_regime("unknown"),
        class = "landscapeR_validation_error"
    )
})

test_that("high-dimensional controls record the planted answer and boundary", {
    control <- synthetic_k1_high_dimensional_control(
        regime = "fixed_sparse", n = 24L, p = 100L,
        informative_features = 8L, signal_strength = 8,
        noise_sd = 1, seed = 19101L
    )
    info <- k1_high_dimensional_control_info(control)
    truth <- control@ground_truth

    expect_identical(info$regime_id, "fixed_sparse")
    expect_identical(info$n, 24L)
    expect_identical(info$p, 100L)
    expect_identical(info$informative_feature_count, 8L)
    expect_equal(info$informative_feature_fraction, 0.08)
    expect_equal(info$loading_norm, 1)
    expect_identical(info$covariance_regime, "independent-gaussian")
    expect_identical(info$signal_strength, 8)
    expect_identical(info$noise_sd, 1)
    expect_equal(info$recovery_boundary, (24 * 100)^0.25)
    expect_identical(info$boundary_position, "above")
    expect_identical(info$seed, 19101L)
    expect_s4_class(truth, "SubspaceGroundTruth")
    expect_identical(sum(truth@shared[, 1L] != 0), 8L)
})

test_that("fixed spike and coherent growth separate noise from information", {
    fixed_small <- k1_high_dimensional_control_info(
        synthetic_k1_high_dimensional_control(
            "fixed_total_spike", n = 24L, p = 100L,
            signal_strength = 6, seed = 19102L
        )
    )
    fixed_large <- k1_high_dimensional_control_info(
        synthetic_k1_high_dimensional_control(
            "fixed_total_spike", n = 24L, p = 1000L,
            signal_strength = 6, seed = 19102L
        )
    )
    coherent <- k1_high_dimensional_control_info(
        synthetic_k1_high_dimensional_control(
            "growing_coherent", n = 24L, p = 1000L,
            informative_features = 100L, signal_strength = 6,
            seed = 19102L
        )
    )

    expect_identical(fixed_small$signal_strength, fixed_large$signal_strength)
    expect_gt(fixed_large$recovery_boundary, fixed_small$recovery_boundary)
    expect_gt(coherent$effective_signal_strength, fixed_large$signal_strength)
})
