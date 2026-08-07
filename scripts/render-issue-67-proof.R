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
ranking <- calibration$proposal@ranking[
    , c("component", "component_label", "effect_magnitude", "proposal_rank"),
    drop = FALSE
]
recovery <- data.frame(
    component = calibration$recovery$component,
    planted_axis = calibration$recovery$planted_axis,
    signed_loading_cosine = calibration$recovery$signed_loading_cosine,
    absolute_loading_cosine = calibration$recovery$absolute_loading_cosine,
    orientation = calibration$recovery$orientation,
    stringsAsFactors = FALSE
)
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

recovery_map_data <- merge(
    ranking[is.finite(ranking$effect_magnitude), ],
    recovery,
    by = "component",
    all = FALSE
)
recovery_map_data$is_target <-
    recovery_map_data$component == calibration$target_component
recovery_map_data$role <- factor(
    ifelse(
        recovery_map_data$is_target,
        "Nominated condition-by-time axis",
        "Collection-time nuisance axis"
    ),
    levels = c(
        "Collection-time nuisance axis",
        "Nominated condition-by-time axis"
    )
)
recovery_map_data$axis_label <- ifelse(
    recovery_map_data$is_target,
    "condition by time",
    "collection time"
)
recovery_map_data$label <- sprintf(
    "%s: %s\n|cosine| = %.3f; effect = %.2f",
    recovery_map_data$component_label,
    recovery_map_data$axis_label,
    recovery_map_data$absolute_loading_cosine,
    recovery_map_data$effect_magnitude
)
recovery_map_data$label_hjust <- ifelse(
    recovery_map_data$is_target,
    -0.08,
    1.08
)
recovery_map_data$label_vjust <- ifelse(
    recovery_map_data$is_target,
    1.15,
    -0.15
)
target_row <- recovery_map_data[recovery_map_data$is_target, , drop = FALSE]
nuisance_row <- recovery_map_data[!recovery_map_data$is_target, , drop = FALSE]
stopifnot(nrow(target_row) == 1L, nrow(nuisance_row) == 1L)
requested_refits <- calibration$identifiability_evidence$n_requested
completed_refits <- calibration$identifiability_evidence$n_completed
failed_refits <- calibration$identifiability_evidence$n_failed
stopifnot(requested_refits == completed_refits + failed_refits)
refit_summary <- sprintf(
    paste0(
        "Point positions summarize the discovery fit; %d of %d ",
        "complete-subject bootstrap refits completed the full assessment%s"
    ),
    completed_refits,
    requested_refits,
    if (failed_refits > 0L) sprintf("; %d failed", failed_refits) else ""
)
recovery_map <- ggplot2::ggplot(
    recovery_map_data,
    ggplot2::aes(x = absolute_loading_cosine, y = effect_magnitude)
) +
    ggplot2::geom_segment(
        ggplot2::aes(
            x = min(absolute_loading_cosine) - 0.0005,
            xend = absolute_loading_cosine,
            yend = effect_magnitude
        ),
        colour = "grey80",
        linewidth = 0.7
    ) +
    ggplot2::geom_point(
        ggplot2::aes(colour = role, shape = role),
        size = 3.2,
        stroke = 1
    ) +
    ggplot2::geom_text(
        ggplot2::aes(
            label = label,
            hjust = label_hjust,
            vjust = label_vjust
        ),
        size = 2.7,
        lineheight = 0.95
    ) +
    ggplot2::scale_colour_manual(
        values = c(
            "Collection-time nuisance axis" = "#222222",
            "Nominated condition-by-time axis" = "#C83E35"
        )
    ) +
    ggplot2::scale_shape_manual(
        values = c(
            "Collection-time nuisance axis" = 16,
            "Nominated condition-by-time axis" = 17
        )
    ) +
    ggplot2::guides(colour = "none", shape = "none") +
    ggplot2::coord_cartesian(
        xlim = range(recovery_map_data$absolute_loading_cosine) +
            c(-0.001, 0.001),
        ylim = c(-0.35, max(recovery_map_data$effect_magnitude) + 0.75)
    ) +
    ggplot2::labs(
        title = "Known-truth axis recovery",
        subtitle = "AML longitudinal calibration control",
        x = "Absolute cosine with planted loading",
        y = "Adjusted condition-by-time effect magnitude"
    ) +
    theme_landscapeR()
caption_view <- .new_scientific_caption_view(
    title = "Known-truth recovery separates the planted condition-by-time target from collection time",
    experiment_label = "AML longitudinal calibration control",
    molecular_layer = "synthetic expression",
    molecular_layer_count = 1L,
    target_field = "condition",
    oriented_levels = c("CTL", "CM"),
    sampling_unit = "a complete synthetic mouse trajectory",
    time_field = "collection time",
    time_unit = "weeks",
    subject_field = "mouse_id",
    nuisance_fields = "batch",
    encodings = c(
        "Horizontal position is absolute loading cosine with planted truth, with larger values indicating closer geometric recovery",
        "Vertical position is the batch-adjusted condition-by-time effect magnitude used for proposal ranking",
        sprintf(
            "The red triangle is nominated %s, which recovers the planted condition-by-time axis (absolute cosine %.3f; effect magnitude %.2f)",
            target_row$component_label,
            target_row$absolute_loading_cosine,
            target_row$effect_magnitude
        ),
        sprintf(
            "The black circle is %s, which recovers the planted collection-time axis (absolute cosine %.3f; effect magnitude %.2f)",
            nuisance_row$component_label,
            nuisance_row$absolute_loading_cosine,
            nuisance_row$effect_magnitude
        )
    ),
    estimand = "the batch-adjusted standardized condition-by-time effect magnitude",
    design = "repeated-subject longitudinal with irregular observation times",
    uncertainty = paste0(
        refit_summary,
        " and are reported in the companion identifiability audit"
    ),
    threshold = "No acceptance threshold is applied",
    claim_boundary = paste0(
        "This disclosed synthetic calibration control does not establish biological validity or independent acceptance"
    ),
    state = "uncalibrated"
)
recovery_map <- .with_scientific_caption(
    recovery_map,
    .build_scientific_caption(caption_view)
)
save_landscapeR_plot(
    recovery_map,
    file.path(output_dir, "calibration-recovery-map.png"),
    width_mm = 100,
    height_mm = 100
)
writeLines(
    scientific_caption(recovery_map),
    file.path(output_dir, "calibration-recovery-map-caption.txt")
)

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
raw_effects <- effects[
    effects$evidence_variant == "repeated-time-course-unadjusted",
    c("component", "estimate", "effect_magnitude", "proposal_eligible",
      "diagnostic", "evidence_status"),
    drop = FALSE
]
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
write.table(
    raw_effects,
    file.path(output_dir, "unadjusted-component-effects.tsv"),
    sep = "\t",
    quote = FALSE,
    row.names = FALSE
)
batch_structure <- as.data.frame(with(
    design,
    table(condition = condition, batch = batch)
))
names(batch_structure)[[3L]] <- "n_observations"
write.table(
    batch_structure,
    file.path(output_dir, "batch-structure.tsv"),
    sep = "\t",
    quote = FALSE,
    row.names = FALSE
)
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
