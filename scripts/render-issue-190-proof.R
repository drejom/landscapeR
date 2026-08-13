devtools::load_all(quiet = TRUE)

assessment <- run_k1_repeated_subject_calibration(
    template_ids = c(
        "complete", "isolated_observation_loss", "terminal_dropout",
        "condition_dependent_loss"
    ),
    replicates = 5L,
    p = 100L,
    noise_sd = 0.15,
    time_signal = 8,
    condition_time_signal = 3,
    axis_resamples = 5L,
    seed = 19000L,
    sequential_internal = TRUE
)

plot <- plot_k1_repeated_subject_calibration(assessment)
proof_root <- ".github/landing-proof/issue-190"
dir.create(proof_root, recursive = TRUE, showWarnings = FALSE)
ggplot2::ggsave(
    file.path(proof_root, "repeated-subject-operating-map.png"),
    plot,
    width = 180,
    height = 100,
    units = "mm",
    dpi = 300,
    bg = "white"
)
utils::write.csv(
    attr(plot, "landscapeR_k1_repeated_map_data"),
    file.path(proof_root, "repeated-subject-operating-map.csv"),
    row.names = FALSE
)
writeLines(
    scientific_caption(plot),
    file.path(proof_root, "repeated-subject-operating-map-caption.txt")
)
