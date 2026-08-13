#!/usr/bin/env Rscript

devtools::load_all(quiet = TRUE)

proof_dir <- file.path(".github", "landing-proof", "issue-192")
dir.create(proof_dir, recursive = TRUE, showWarnings = FALSE)

design_assessment <- run_k1_independent_time_course_calibration(
    template_ids = c("balanced_1", "balanced_3"),
    replicates = 2L, p = 20L, seed = 19211L,
    sequential_internal = TRUE
)
signal_assessment <- run_k1_high_dimensional_calibration(
    regime_ids = "fixed_sparse", feature_counts = c(20L, 40L),
    signal_ratios = c(0.75, 1.25), replicates = 2L,
    n = 24L, informative_features = 8L, axis_resamples = 2L,
    seed = 19212L, sequential_internal = TRUE
)
signal_cells <- signal_assessment$cells
signal_ratio <- signal_cells$signal_strength /
    signal_cells$recovery_boundary

region_diagnostics <- k1_experiment_diagnostics(
    feature_count = c(20L, 40L), spectral_signal = c(0.8, 1),
    noise_reference = 1,
    covariance_regime = "independent-gaussian",
    signal_regime = "fixed_sparse",
    design = list(
        minimum_cell_size = c(1, 3),
        maximum_cell_size = c(1, 3),
        mean_retained_per_declared_cell = c(1, 3)
    )
)
region <- locate_k1_operating_domain(
    independent_time_course("collection_time", "days"),
    design_assessment, signal_assessment, region_diagnostics
)

outside_diagnostics <- k1_experiment_diagnostics(
    feature_count = 20L, spectral_signal = max(signal_ratio) + 2,
    noise_reference = 1,
    covariance_regime = "independent-gaussian",
    signal_regime = "fixed_sparse",
    design = list(
        minimum_cell_size = 1,
        maximum_cell_size = 1,
        mean_retained_per_declared_cell = 1
    )
)
outside <- locate_k1_operating_domain(
    independent_time_course("collection_time", "days"),
    design_assessment, signal_assessment, outside_diagnostics
)

save_landscapeR_plot(
    plot_k1_operating_domain(region),
    file.path(proof_dir, "located-region.png"),
    width_mm = 180, height_mm = 100
)
save_landscapeR_plot(
    plot_k1_operating_domain(outside),
    file.path(proof_dir, "out-of-domain.png"),
    width_mm = 180, height_mm = 100
)
writeLines(
    scientific_caption(plot_k1_operating_domain(region)),
    file.path(proof_dir, "located-region-caption.txt")
)
writeLines(
    scientific_caption(plot_k1_operating_domain(outside)),
    file.path(proof_dir, "out-of-domain-caption.txt")
)
utils::write.csv(
    region$signal_cells,
    file.path(proof_dir, "located-region-supporting-cells.csv"),
    row.names = FALSE
)
utils::write.csv(
    outside$signal_domain_cells,
    file.path(proof_dir, "out-of-domain-compatible-domain.csv"),
    row.names = FALSE
)
