devtools::load_all(quiet = TRUE)

assessment <- run_k1_high_dimensional_calibration(
    regime_ids = c(
        "fixed_total_spike", "fixed_sparse", "growing_coherent",
        "correlated_modules", "null_near_null"
    ),
    feature_counts = c(100L, 500L),
    signal_ratios = c(0, 0.75, 1.25),
    replicates = 3L,
    n = 24L,
    informative_features = 10L,
    axis_resamples = 3L,
    seed = 19100L,
    sequential_internal = TRUE
)

plot <- plot_k1_high_dimensional_calibration(assessment)
proof_root <- ".github/landing-proof/issue-191"
dir.create(proof_root, recursive = TRUE, showWarnings = FALSE)
ggplot2::ggsave(
    file.path(proof_root, "high-dimensional-operating-map.png"),
    plot,
    width = 160,
    height = 160,
    units = "mm",
    dpi = 300,
    bg = "white"
)
display <- attr(plot, "landscapeR_k1_high_dimensional_map_data")
display$panel <- as.character(display$panel)
display$regime_label <- as.character(display$regime_label)
display$regime_axis_label <- as.character(display$regime_axis_label)
utils::write.csv(
    display,
    file.path(proof_root, "high-dimensional-operating-map.csv"),
    row.names = FALSE
)
utils::write.csv(
    assessment$cells,
    file.path(proof_root, "high-dimensional-cell-summary.csv"),
    row.names = FALSE
)
writeLines(
    scientific_caption(plot),
    file.path(proof_root, "high-dimensional-operating-map-caption.txt")
)
