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

# Representative rendering fixture only. It exercises the AML acceptance
# summary surfaces without deriving or consuming any governed acceptance seed.
protocol <- k1_acceptance_protocol()
display_cells <- expand.grid(
    subjects_per_condition = c(4L, 7L, 12L),
    p = c(100L, 1000L, 10000L),
    replicate_index = seq_len(100L),
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
)
display_cells$n <- 2L * display_cells$subjects_per_condition * 11L
display_cells$control <- "aml_synchronized"
display_cells$canonical_cell <- sprintf(
    "control=aml_synchronized;subjects_per_condition=%d;p=%d",
    display_cells$subjects_per_condition,
    display_cells$p
)
display_cells$task_id <- sprintf("display-%04d", seq_len(nrow(display_cells)))
display_cells$seed_root <- NA_integer_
display_cells$stream_seeds <- replicate(
    nrow(display_cells),
    NA_integer_,
    simplify = FALSE
)
display_pass_rate <- with(
    display_cells,
    pmin(0.97, 0.42 + 0.035 * subjects_per_condition - 0.04 * log10(p / 100))
)
display_pass <- display_cells$replicate_index <=
    floor(100 * display_pass_rate)
display_results <- lapply(seq_len(nrow(display_cells)), function(index) {
    passes <- display_pass[[index]]
    subjects <- display_cells$subjects_per_condition[[index]]
    features <- display_cells$p[[index]]
    loading_cosine <- min(
        0.99,
        0.82 + 0.012 * subjects - 0.015 * log10(features / 100)
    )
    acceptance_provenance <- list(
        version = "1.0.0",
        evidence_status = "independent_acceptance",
        generator_and_decomposition = list(fixture = "fabricated"),
        atlas = list(fixture = "fabricated"),
        proposal = list(fixture = "fabricated"),
        identifiability = list(fixture = "fabricated"),
        stage2 = list(fixture = "fabricated")
    )
    structure(list(
        artifact_version = protocol$artifact_version,
        task_id = display_cells$task_id[[index]],
        control = "aml_synchronized",
        canonical_cell = display_cells$canonical_cell[[index]],
        replicate_index = display_cells$replicate_index[[index]],
        status = "success",
        reason = "",
        metrics = list(
            target_loading_cosine = if (passes) {
                max(0.91, loading_cosine)
            } else {
                min(0.89, loading_cosine)
            },
            target_subspace_angle_deg = if (passes) 12 else 25,
            mean_bootstrap_subspace_angle_deg = if (passes) 8 else 18,
            q95_bootstrap_subspace_angle_deg = if (passes) 12 else 28,
            target_component = 2L,
            nuisance_component = 1L,
            target_proposal_rank = if (passes) 1L else 2L,
            nuisance_proposal_rank = if (passes) 2L else 1L,
            target_unadjusted_estimate = -1.2,
            target_adjusted_estimate = -1.1,
            nuisance_unadjusted_estimate = 0.2,
            nuisance_adjusted_estimate = 0.1,
            target_unadjusted_status = "estimable-exploratory-only",
            target_adjusted_status = "estimable-exploratory-only",
            nuisance_unadjusted_status = "estimable-exploratory-only",
            nuisance_adjusted_status = "estimable-exploratory-only",
            target_index_recurrence = if (passes) {
                min(0.98, 0.76 + 0.018 * subjects)
            } else {
                0.72
            },
            mean_matched_loading_cosine = if (passes) 0.92 else 0.82,
            identifiability_completion_rate = if (passes) 0.96 else 0.84,
            stage2_ineligible = TRUE,
            orientation_recurrence = 0.55,
            rank_one_fraction = if (passes) 0.88 else 0.60,
            matched_fraction = if (passes) 0.95 else 0.78,
            acceptance_evidence_status = "independent_acceptance",
            acceptance_provenance = acceptance_provenance,
            acceptance_provenance_digest = digest::digest(
                acceptance_provenance,
                algo = "sha256"
            )
        ),
        protocol_digest = protocol$digest,
        runner_contract = protocol$execution_contracts$version
    ), class = c("K1AcceptanceReplicate", "list"))
})
display_summary <- summarize_k1_acceptance(
    display_results,
    display_cells,
    protocol
)
display_summary$claim_status <- "development_only_visual_fixture"
display_payload <- unclass(display_summary)
display_payload$digest <- NULL
display_summary$digest <- digest::digest(display_payload, algo = "sha256")
acceptance_plots <- list(
    aml_acceptance_pass_rate = plot_k1_aml_acceptance_summary(
        display_summary,
        "pass_rate"
    ),
    aml_acceptance_recovery = plot_k1_aml_acceptance_summary(
        display_summary,
        "recovery"
    )
)
for (name in names(acceptance_plots)) {
    save_landscapeR_plot(
        acceptance_plots[[name]],
        file.path(output_dir, paste0(name, ".png")),
        width_mm = 100,
        height_mm = 100
    )
    writeLines(
        scientific_caption(acceptance_plots[[name]]),
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
