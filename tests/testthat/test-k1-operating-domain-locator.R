locator_fixture <- local({
    cached <- NULL
    function() {
        if (!is.null(cached)) return(cached)
    independent <- run_k1_independent_time_course_calibration(
        template_ids = c("balanced_1", "balanced_3"),
        replicates = 1L, p = 20L, seed = 19201L,
        sequential_internal = TRUE
    )
    signal <- run_k1_high_dimensional_calibration(
        regime_ids = "fixed_sparse", feature_counts = c(20L, 40L),
        signal_ratios = c(0.75, 1.25), replicates = 1L,
        n = 24L, informative_features = 8L, axis_resamples = 1L,
        seed = 19202L, sequential_internal = TRUE
    )
        cached <<- list(independent = independent, signal = signal)
        cached
    }
})

test_that("an in-domain experiment is linked to exact supporting cells", {
    fixture <- locator_fixture()
    diagnostics <- k1_experiment_diagnostics(
        feature_count = 20L,
        spectral_signal = fixture$signal$cells$signal_strength[[1L]],
        noise_reference = fixture$signal$cells$recovery_boundary[[1L]],
        covariance_regime = "independent-gaussian",
        signal_regime = "fixed_sparse",
        design = list(
            minimum_cell_size = 1,
            maximum_cell_size = 1,
            mean_retained_per_declared_cell = 1
        )
    )
    location <- locate_k1_operating_domain(
        independent_time_course("collection_time", "days"),
        fixture$independent, fixture$signal, diagnostics
    )

    expect_s3_class(location, "K1OperatingDomainLocation")
    expect_identical(location$status, "located_point")
    expect_identical(location$design_cells$template_id, "balanced_1")
    expect_identical(nrow(location$signal_cells), 1L)
    expect_identical(location$diagnostics_digest, diagnostics$digest)
})

test_that("an uncertainty region retains every supporting boundary cell", {
    fixture <- locator_fixture()
    sparse <- fixture$signal$cells[
        fixture$signal$cells$regime_id == "fixed_sparse", , drop = FALSE
    ]
    sparse_ratio <- sparse$signal_strength / sparse$recovery_boundary
    diagnostics <- k1_experiment_diagnostics(
        feature_count = c(20L, 40L),
        spectral_signal = c(0.8, 1),
        noise_reference = 1,
        covariance_regime = "independent-gaussian",
        signal_regime = "fixed_sparse",
        design = list(
            minimum_cell_size = c(1, 3),
            maximum_cell_size = c(1, 3),
            mean_retained_per_declared_cell = c(1, 3)
        )
    )
    location <- locate_k1_operating_domain(
        independent_time_course("collection_time", "days"),
        fixture$independent, fixture$signal, diagnostics
    )

    expect_identical(location$status, "located_region")
    expect_setequal(location$design_cells$template_id,
        c("balanced_1", "balanced_3"))
    expect_gt(nrow(location$signal_cells), 1L)
    expect_true(all(location$signal_cells$p %in% c(20L, 40L)))
    expect_true(all(location$signal_cells$effective_signal_ratio %in%
        sparse_ratio))
})

test_that("sampling designs cannot borrow incompatible calibration evidence", {
    fixture <- locator_fixture()
    diagnostics <- k1_experiment_diagnostics(
        feature_count = 20L, spectral_signal = 1, noise_reference = 1,
        covariance_regime = "independent-gaussian",
        signal_regime = "fixed_sparse",
        design = list(
            n_subjects = 8,
            n_retained = 32,
            minimum_subject_observations = 4
        )
    )
    location <- locate_k1_operating_domain(
        longitudinal("mouse_id", "weeks", "weeks"),
        fixture$independent, fixture$signal, diagnostics
    )

    expect_identical(location$status, "out_of_domain")
    expect_identical(location$reason, "incompatible_sampling_design")
    expect_identical(nrow(location$design_cells), 0L)
    expect_identical(nrow(location$signal_cells), 0L)
    plot <- plot_k1_operating_domain(location)
    expect_silent(ggplot2::ggplot_build(plot))
    plot_data <- attr(plot, "landscapeR_k1_operating_domain_data")
    expect_identical(names(plot_data), c(
        "calibration_points", "support_points", "experiment_bounds",
        "domain_bands"
    ))
    expect_identical(nrow(plot_data$domain_bands), 0L)
    expect_identical(nrow(plot_data$experiment_bounds), 2L)
    expect_true(all(plot_data$experiment_bounds$clipped == "inside"))
    caption <- scientific_caption(plot)
    expect_match(gsub("[[:space:]]+", " ", caption),
        "no compatible calibration domain can be shown", ignore.case = TRUE)
    expect_match(gsub("[[:space:]]+", " ", caption),
        "declared diagnostic position on an uncalibrated axis",
        ignore.case = TRUE)
    expect_false(grepl("nearest calibrated boundary", caption,
        ignore.case = TRUE))
})

test_that("malformed design assessments fail through the public boundary", {
    fixture <- locator_fixture()
    diagnostics <- k1_experiment_diagnostics(
        feature_count = 20L, spectral_signal = 1, noise_reference = 1,
        covariance_regime = "independent-gaussian",
        signal_regime = "fixed_sparse",
        design = list(
            minimum_cell_size = 1,
            maximum_cell_size = 1,
            mean_retained_per_declared_cell = 1
        )
    )

    expect_error(
        locate_k1_operating_domain(
            independent_time_course("collection_time", "days"),
            1, fixture$signal, diagnostics
        ),
        class = "landscapeR_validation_error"
    )
})

test_that("a repeated-subject experiment uses only repeated-subject cells", {
    repeated <- run_k1_repeated_subject_calibration(
        template_ids = "complete", replicates = 1L, p = 20L,
        axis_resamples = 1L, seed = 19203L,
        sequential_internal = TRUE
    )
    signal <- locator_fixture()$signal
    diagnostics <- k1_experiment_diagnostics(
        feature_count = 20L,
        spectral_signal = signal$cells$signal_strength[[1L]],
        noise_reference = signal$cells$recovery_boundary[[1L]],
        covariance_regime = "independent-gaussian",
        signal_regime = "fixed_sparse",
        design = list(
            n_subjects = repeated$cells$n_subjects[[1L]],
            n_retained = repeated$cells$n_retained[[1L]],
            minimum_subject_observations =
                repeated$cells$minimum_subject_observations[[1L]]
        )
    )
    location <- locate_k1_operating_domain(
        longitudinal("mouse_id", "weeks", "weeks"),
        repeated, signal, diagnostics
    )

    expect_identical(location$status, "located_point")
    expect_identical(location$design_cells$template_id, "complete")
    expect_identical(location$sampling_design$kind, "longitudinal")
})

test_that("out-of-range signal evidence is not extrapolated", {
    fixture <- locator_fixture()
    diagnostics <- k1_experiment_diagnostics(
        feature_count = 20L, spectral_signal = 10, noise_reference = 1,
        covariance_regime = "independent-gaussian",
        signal_regime = "fixed_sparse",
        design = list(
            minimum_cell_size = 1,
            maximum_cell_size = 1,
            mean_retained_per_declared_cell = 1
        )
    )
    location <- locate_k1_operating_domain(
        independent_time_course("collection_time", "days"),
        fixture$independent, fixture$signal, diagnostics
    )

    expect_identical(location$status, "out_of_domain")
    expect_identical(location$reason, "signal_noise_out_of_range")
    expect_true(is.na(location$recovery_probability))

    plot <- plot_k1_operating_domain(location)
    plot_data <- attr(plot, "landscapeR_k1_operating_domain_data")
    caption <- scientific_caption(plot)
    expect_s3_class(plot, "ggplot")
    expect_true(all(is.na(
        plot_data$calibration_points$experiment_probability
    )))
    expect_true(all(plot_data$experiment_bounds$clipped == "above"))
    expect_true(all(plot_data$experiment_bounds$actual_ratio == 10))
    expect_true(all(plot_data$experiment_bounds$plotted_ratio < 10))
    expect_identical(nrow(plot_data$domain_bands), 2L)
    expect_equal(
        range(ggplot2::ggplot_build(plot)$layout$panel_params[[1L]]$x.range),
        range(plot_data$domain_bands$xmin, plot_data$domain_bands$xmax),
        tolerance = 0.25
    )
    expect_match(caption, "does not extrapolate", ignore.case = TRUE)
    expect_match(caption, "10", fixed = TRUE)
    expect_match(gsub("[[:space:]]+", " ", caption),
        "not a biological state-space projection",
        ignore.case = TRUE)
})

test_that("plot data reproduce every visible operating-domain layer", {
    fixture <- locator_fixture()
    diagnostics <- k1_experiment_diagnostics(
        feature_count = c(20L, 40L), spectral_signal = c(0.8, 1),
        noise_reference = 1, covariance_regime = "independent-gaussian",
        signal_regime = "fixed_sparse",
        design = list(
            minimum_cell_size = c(1, 3),
            maximum_cell_size = c(1, 3),
            mean_retained_per_declared_cell = c(1, 3)
        )
    )
    location <- locate_k1_operating_domain(
        independent_time_course("collection_time", "days"),
        fixture$independent, fixture$signal, diagnostics
    )

    plot_data <- attr(
        plot_k1_operating_domain(location),
        "landscapeR_k1_operating_domain_data"
    )

    expect_identical(nrow(plot_data$calibration_points),
        2L * nrow(location$signal_domain_cells))
    expect_identical(nrow(plot_data$support_points),
        2L * nrow(location$signal_cells))
    expect_identical(nrow(plot_data$experiment_bounds), 4L)
    expect_identical(nrow(plot_data$domain_bands), 2L)
    expect_setequal(plot_data$experiment_bounds$actual_ratio, c(0.8, 1))
    expect_true(all(plot_data$experiment_bounds$clipped == "inside"))
})
