devtools::load_all(quiet = TRUE)

assessment <- run_k1_independent_time_course_calibration(
    template_ids = c(
        "balanced_1", "balanced_2", "balanced_3", "unequal_1_2_3",
        "isolated_library_failure", "missing_internal_cell"
    ),
    replicates = 5L,
    p = 100L,
    noise_sd = 0.15,
    time_signal = 8,
    condition_time_signal = 3,
    seed = 18900L,
    sequential_internal = TRUE
)
plot <- plot_k1_independent_time_course_calibration(assessment)
proof_root <- ".github/landing-proof/issue-189"
dir.create(proof_root, recursive = TRUE, showWarnings = FALSE)
ggplot2::ggsave(
    file.path(proof_root, "destructive-time-course-operating-map.png"),
    plot,
    width = 180,
    height = 100,
    units = "mm",
    dpi = 300,
    bg = "white"
)
utils::write.csv(
    attr(plot, "landscapeR_k1_operating_map_data"),
    file.path(proof_root, "destructive-time-course-operating-map.csv"),
    row.names = FALSE
)
writeLines(
    scientific_caption(plot),
    file.path(proof_root, "destructive-time-course-operating-map-caption.txt")
)
