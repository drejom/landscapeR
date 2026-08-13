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

test_that("high-dimensional assessment separates scientific and execution evidence", {
    assessment <- run_k1_high_dimensional_calibration(
        regime_ids = c("fixed_sparse", "null_near_null"),
        feature_counts = 100L, signal_ratios = c(0, 1.25),
        replicates = 1L, informative_features = 8L,
        axis_resamples = 2L, seed = 19103L,
        sequential_internal = TRUE
    )

    expect_s3_class(assessment, "K1HighDimensionalAssessment")
    expect_identical(assessment$execution$account$n_requested, 3L)
    expect_identical(assessment$execution$account$n_completed, 3L)
    expect_named(assessment$replicates, c(
        "task_id", "replicate_index", "regime_id", "regime_label",
        "boundary_position", "n", "p", "informative_feature_count",
        "informative_feature_fraction", "loading_norm", "covariance_regime",
        "signal_strength", "noise_sd", "recovery_boundary",
        "execution_completed", "target_loading_cosine", "recovery_evaluable",
        "recovery_met", "nominated_component", "proposal_available",
        "axis_mean_absolute_similarity", "axis_refits_requested",
        "axis_refits_completed", "downstream_estimable", "diagnostic"
    ))
    expect_true(all(is.finite(
        assessment$replicates$recovery_boundary
    )))
    expect_true(all(
        assessment$replicates$axis_refits_completed <=
            assessment$replicates$axis_refits_requested
    ))
    expect_match(assessment$digest, "^[0-9a-f]{64}$")
    expect_invisible(
        landscapeR:::.validate_k1_high_dimensional_assessment(assessment)
    )
})

test_that("high-dimensional operating evidence is exact and captioned", {
    assessment <- run_k1_high_dimensional_calibration(
        regime_ids = c("fixed_sparse", "growing_coherent"),
        feature_counts = c(40L, 80L), signal_ratios = c(0.75, 1.25),
        replicates = 1L, informative_features = 8L,
        axis_resamples = 1L, seed = 19104L,
        sequential_internal = TRUE
    )
    plot <- plot_k1_high_dimensional_calibration(assessment)
    display <- attr(plot, "landscapeR_k1_high_dimensional_map_data")
    caption <- scientific_caption(plot)

    expect_s3_class(plot, "ggplot")
    expect_setequal(as.character(display$panel), c(
        "A  Target-axis recovery", "B  Axis identifiability"
    ))
    expect_true(all(c("p", "effective_signal_ratio", "value") %in%
        names(display)))
    expect_identical(nrow(assessment$cells), 8L)
    expect_match(caption, "fixed sparse informative set", ignore.case = TRUE)
    expect_match(caption, "analytic white-noise reference")
    expect_match(caption, "independent synthetic biological observation")
    expect_false(grepl(caption,
        paste(capture.output(print(plot)), collapse = "\n"), fixed = TRUE))
})

test_that("high-dimensional artifacts replay and targets stay backend-neutral", {
    skip_if_not_installed("targets")
    testthat::local_mocked_bindings(
        .k1_calibration_runtime_identity = function() list(
            source_revision = strrep("1", 40L), r_version = "4.5",
            package_versions = c(landscapeR = "0.0.0.9000")
        ), .package = "landscapeR"
    )
    assessment <- run_k1_high_dimensional_calibration(
        regime_ids = c("fixed_total_spike", "growing_coherent"),
        feature_counts = 40L, signal_ratios = c(0.75, 1.25),
        replicates = 1L, informative_features = 8L,
        axis_resamples = 1L, seed = 19105L,
        sequential_internal = TRUE
    )
    root <- tempfile("k1-high-dimensional-artifacts-")
    dir.create(root)
    artifact <- publish_k1_high_dimensional_calibration(root, assessment)

    expect_true(verify_k1_high_dimensional_calibration(artifact))
    expect_true(all(file.exists(file.path(artifact, c(
        "assessment.rds", "replicates.csv", "cell-summary.csv",
        "operating-map-data.csv", "operating-map.png",
        "operating-map-caption.txt", "environment.rds", "MANIFEST.tsv"
    )))))
    graph <- k1_high_dimensional_calibration_targets(
        artifact_root = normalizePath(root),
        controller = "gemini-high-dimensional",
        regime_ids = "fixed_sparse", feature_counts = 40L,
        signal_ratios = 0.75, replicates = 1L, axis_resamples = 1L
    )
    expect_identical(
        vapply(graph, function(target) target$settings$name, character(1L)),
        c("k1_high_dimensional_assessment", "k1_high_dimensional_artifact")
    )
    expect_identical(graph[[1L]]$settings$deployment, "worker")
})

test_that("high-dimensional calibration is deterministic and preserves caller RNG", {
    arguments <- list(
        regime_ids = "fixed_sparse", feature_counts = 40L,
        signal_ratios = c(0.75, 1.25), replicates = 1L,
        informative_features = 8L, axis_resamples = 1L,
        seed = 19106L, sequential_internal = TRUE
    )
    set.seed(9191L)
    before <- .Random.seed
    first <- do.call(run_k1_high_dimensional_calibration, arguments)
    expect_identical(.Random.seed, before)
    second <- do.call(run_k1_high_dimensional_calibration, arguments)
    expect_identical(first$replicates, second$replicates)
    expect_identical(first$digest, second$digest)
})
