#!/usr/bin/env Rscript

devtools::load_all(quiet = TRUE)

output_dir <- file.path(".github", "landing-proof", "issue-67")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

calibration <- suppressWarnings(k1_aml_longitudinal_calibration(
    subjects_per_condition = 12L,
    p = 100L,
    seed = 6700L,
    n_resamples = 49L,
    n_permutations = 0L
))
stopifnot(identical(calibration$status, "success"))

fitted <- calibration$decomposition@value
component_plot <- plot_components(
    fitted,
    colour_by = "condition",
    n_components = 2L
)
time_plot <- plot_components(
    fitted,
    colour_by = "weeks",
    n_components = 2L
)
identifiability_plot <- plot_component_identifiability(
    calibration$identifiability,
    view = "primary"
)

public_plots <- list(
    components_by_condition = component_plot,
    components_by_time = time_plot,
    identifiability = identifiability_plot
)
for (name in names(public_plots)) {
    save_landscapeR_plot(
        public_plots[[name]],
        file.path(output_dir, paste0(name, ".png")),
        width_mm = 100,
        height_mm = 100
    )
    writeLines(
        scientific_caption(public_plots[[name]]),
        file.path(output_dir, paste0(name, "-caption.txt"))
    )
}

coordinates <- dr_coords_k(stage_artifact(fitted, "stage1"))[[1L]]
design <- as.data.frame(colData(fitted))
trajectory_data <- rbind(
    data.frame(
        mouse_id = design$mouse_id,
        condition = design$condition,
        weeks = design$weeks,
        component = "PC1",
        score = coordinates[, 1L]
    ),
    data.frame(
        mouse_id = design$mouse_id,
        condition = design$condition,
        weeks = design$weeks,
        component = "PC2",
        score = coordinates[, 2L]
    )
)
trajectory_plot <- ggplot2::ggplot(
    trajectory_data,
    ggplot2::aes(
        x = weeks,
        y = score,
        group = mouse_id,
        colour = condition
    )
) +
    ggplot2::geom_line(linewidth = 0.35, alpha = 0.45) +
    ggplot2::geom_point(size = 0.8, alpha = 0.8) +
    ggplot2::facet_wrap(
        ggplot2::vars(component),
        ncol = 1L,
        scales = "free_y"
    ) +
    scale_colour_landscapeR(
        "binary",
        reference_level = "CTL",
        focal_level = "CM"
    ) +
    ggplot2::labs(
        x = "Collection time (weeks)",
        y = "Recovered component score",
        colour = "Condition"
    ) +
    theme_landscapeR()
save_landscapeR_plot(
    trajectory_plot,
    file.path(output_dir, "recovered-trajectories.png"),
    width_mm = 100,
    height_mm = 100
)
writeLines(
    paste(
        "Figure caption. Recovered subject trajectories for 12 synthetic mice",
        "per condition at the irregular AML-informed collection weeks. Lines",
        "join repeated observations from the same synthetic mouse. The upper",
        "panel shows the planted dominant collection-time direction; the lower",
        "panel shows the planted non-dominant CM-versus-CTL trajectory",
        "divergence. These data are a disclosed calibration control and do not",
        "constitute frozen acceptance evidence."
    ),
    file.path(output_dir, "recovered-trajectories-caption.txt")
)

effects <- atlas_associations(calibration$atlas)
effects <- effects[
    effects$evidence_variant == "repeated-time-course-adjusted",
    c("component", "estimate", "effect_magnitude", "proposal_eligible",
      "diagnostic", "evidence_status"),
    drop = FALSE
]
write.table(
    effects,
    file.path(output_dir, "adjusted-component-effects.tsv"),
    sep = "\t",
    quote = FALSE,
    row.names = FALSE
)
ranking <- calibration$proposal@ranking[
    , c("component", "component_label", "effect_magnitude", "proposal_rank"),
    drop = FALSE
]
write.table(
    ranking,
    file.path(output_dir, "proposal-ranking.tsv"),
    sep = "\t",
    quote = FALSE,
    row.names = FALSE
)
write.table(
    calibration$identifiability_evidence$target_recurrence,
    file.path(output_dir, "target-stability.tsv"),
    sep = "\t",
    quote = FALSE,
    row.names = FALSE
)
recovery <- data.frame(
    component = calibration$recovery$component,
    planted_axis = calibration$recovery$planted_axis,
    signed_loading_cosine = calibration$recovery$signed_loading_cosine,
    absolute_loading_cosine = calibration$recovery$absolute_loading_cosine,
    orientation = calibration$recovery$orientation,
    stringsAsFactors = FALSE
)
write.table(
    recovery,
    file.path(output_dir, "loading-recovery.tsv"),
    sep = "\t",
    quote = FALSE,
    row.names = FALSE
)
write.table(
    data.frame(
        principal_angle = seq_along(
            calibration$recovery$subspace_principal_angle_degrees
        ),
        degrees = calibration$recovery$subspace_principal_angle_degrees
    ),
    file.path(output_dir, "subspace-recovery.tsv"),
    sep = "\t",
    quote = FALSE,
    row.names = FALSE
)
writeLines(
    c(
        paste("Status:", calibration$stage2@status),
        paste("Reason:", calibration$stage2@reason),
        paste("Claim status:", calibration$evidence_status)
    ),
    file.path(output_dir, "stage2-boundary.txt")
)

saveRDS(calibration, file.path(output_dir, "calibration-result.rds"))
