# Stage 2 diagnostic plot functions for StateTransitionData

utils::globalVariables(c("U", "type", "xend", "y", "yend", ".data"))

# ---------------------------------------------------------------------------
# plot_potential(): Stage 2 quasi-potential curve
# ---------------------------------------------------------------------------

#' Plot the quasi-potential landscape (Stage 2 output)
#'
#' Shows U(x) = -log p(x) along the state-transition axis. Point-estimate
#' critical-point classifications and barrier heights are omitted by default;
#' they require explicit diagnostic opt-in until uncertainty is available.
#' The returned scientific caption describes the selected component, plotted
#' encodings, missing observations, and exploratory claim boundary separately
#' from the graphic.
#'
#' @param std \code{StateTransitionData} with \code{metadata()$stage2} present
#' @param colour_by character column name in \code{colData(std)} to colour
#'   the displayed sample positions. Categorical sample positions use directly
#'   labelled baseline rows, so row position and text provide non-colour group
#'   identification without metadata stems. This view supports at most 4 observed
#'   levels. Continuous sample positions use colour and point size. Use
#'   \code{NULL} (default) for an unlabelled rug.
#' @param show_critical_points logical; explicitly opt in to point-estimate
#'   well/barrier classifications and barrier-height segments. Defaults to
#'   \code{FALSE} because current output does not estimate critical-point
#'   uncertainty; opt-in output is exploratory diagnostic information only.
#' @return a \code{ggplot} object
#'
#' @examples
#' \dontrun{
#' # Requires Stage 2 to have been run
#' plot_potential(std_with_stage2)
#' }
#'
#' @export
plot_potential <- function(std, colour_by = NULL,
                           show_critical_points = FALSE) {
    stopifnot(is(std, "StateTransitionData"))
    if (!is.logical(show_critical_points) ||
        length(show_critical_points) != 1L || is.na(show_critical_points))
        stop("show_critical_points must be a single non-missing logical")
    view <- .stage_visual_evidence(
        std, "stage2", colour_by = colour_by, caller = "plot_potential"
    )
    if (identical(visual_evidence_state(view), "missing")) {
        return(.render_unavailable_visual_evidence(view))
    }
    displays <- .visual_evidence_displays(view)
    curve_df <- displays$curve
    cp_df <- displays$critical_points
    seg_df <- displays$barrier_segments
    critical_y <- if (isTRUE(show_critical_points) && nrow(cp_df)) {
        c(cp_df$U, seg_df$y, seg_df$yend)
    } else {
        numeric()
    }

    # Sample rug — component-aware with fallback (#14 + #16)
    rug_df <- displays$rug
    if (!nrow(rug_df)) rug_df <- NULL
    layer_indices <- displays$layers
    comp <- displays$component
    if (!is.null(rug_df) && !is.null(colour_by)) {
        aligned_metadata <- lapply(
            layer_indices,
            function(layer) {
                displays$aligned_metadata[[displays$experiment_names[[layer]]]]
            }
        )
        rug_df[[colour_by]] <- unlist(
            aligned_metadata, use.names = FALSE
        )
        rug_df$.primary_sample <- unlist(
            lapply(aligned_metadata, names), use.names = FALSE
        )
    }

    palette <- landscapeR_palette("semantic")
    p <- ggplot2::ggplot(curve_df, ggplot2::aes(x = x, y = U))
    if (isTRUE(show_critical_points) && nrow(seg_df)) {
        p <- p + ggplot2::geom_segment(
            data = seg_df,
            ggplot2::aes(
                x = x, xend = xend, y = y, yend = yend,
                linetype = "Barrier height"
            ),
            colour = unname(palette[["nuisance"]]), linewidth = 0.7,
            inherit.aes = FALSE
        ) + ggplot2::scale_linetype_manual(
            name = NULL,
            values = c("Barrier height" = "dashed"),
            guide = ggplot2::guide_legend(order = 2L)
        )
    }
    p <- p + ggplot2::geom_line(
        linewidth = 0.8, colour = unname(palette[["ink"]])
    ) +
        ggplot2::labs(
            title = "Quasi-potential landscape",
            subtitle = "U(x) = -log p(x)",
            x = "State-transition coordinate",
            y = "U(x)"
        ) +
        theme_landscapeR() +
        ggplot2::theme(legend.position = "bottom")

    if (isTRUE(show_critical_points)) {
        p <- p +
            ggplot2::geom_point(
                data = cp_df,
                ggplot2::aes(x = x, y = U, shape = type, fill = type),
                size = 1.55,
                stroke = 0.4,
                colour = unname(palette[["ink"]])
            ) +
            ggplot2::scale_shape_manual(
                name = "Critical point",
                values = c(well = 21, barrier = 23),
                breaks = c("well", "barrier"),
                labels = c(
                    well = "Stable (well)",
                    barrier = "Unstable (barrier)"
                ),
                guide = ggplot2::guide_legend(
                    order = 1L,
                    override.aes = list(
                        size = 2.2,
                        stroke = 0.5,
                        fill = c(
                            unname(palette[["paper"]]),
                            unname(palette[["focal"]])
                        )
                    )
                )
            ) +
            ggplot2::scale_fill_manual(
                name = "Critical point",
                values = c(
                    well = unname(palette[["paper"]]),
                    barrier = unname(palette[["focal"]])
                ),
                labels = c(
                    well = "Stable (well)",
                    barrier = "Unstable (barrier)"
                ),
                breaks = c("well", "barrier"),
                guide = "none"
            )
    }

    # Sample rug
    if (!is.null(rug_df)) {
        if (!is.null(colour_by) && colour_by %in% colnames(rug_df)) {
            observed_rug <- rug_df[
                !is.na(rug_df[[colour_by]]),
                ,
                drop = FALSE
            ]
            missing_rug <- rug_df[
                is.na(rug_df[[colour_by]]),
                ,
                drop = FALSE
            ]
            marker_y <- min(curve_df$U, na.rm = TRUE)
            categorical_rows <- !is.numeric(rug_df[[colour_by]])
            if (categorical_rows) {
                row_levels <- sort(unique(as.character(
                    observed_rug[[colour_by]]
                )))
                if (length(row_levels) > 4L) {
                    .stop_plot_evidence_unavailable(
                        "Categorical baseline rows support at most 4 levels"
                    )
                }
                y_span <- if (length(critical_y)) {
                    diff(range(critical_y, na.rm = TRUE))
                } else {
                    diff(range(curve_df$U, na.rm = TRUE))
                }
                row_gap <- max(y_span * 0.06, 0.16)
                observed_rug$row_y <- marker_y - row_gap * match(
                    as.character(observed_rug[[colour_by]]), row_levels
                )
                x_span <- diff(range(curve_df$x, na.rm = TRUE))
                row_label_x <- min(curve_df$x, na.rm = TRUE) + x_span * 0.02
                row_labels <- data.frame(
                    x = rep(row_label_x, length(row_levels)),
                    row_y = marker_y - row_gap * seq_along(row_levels),
                    label = row_levels
                )
                row_labels[[colour_by]] <- row_levels
                p <- p + ggplot2::geom_point(
                    data = observed_rug,
                    ggplot2::aes(
                        x = x, y = .data$row_y,
                        colour = .data[[colour_by]]
                    ),
                    shape = 16,
                    size = 1.25,
                    alpha = 0.75,
                    inherit.aes = FALSE
                ) + ggplot2::geom_text(
                    data = row_labels,
                    ggplot2::aes(
                        x = .data$x, y = .data$row_y, label = .data$label,
                        colour = .data[[colour_by]]
                    ),
                    hjust = 0,
                    size = 2.2,
                    inherit.aes = FALSE
                ) + scale_colour_landscapeR(
                    "categorical",
                    name = .scientific_caption_label(colour_by)
                )
                if (nrow(missing_rug)) {
                    missing_y <- marker_y - row_gap * (length(row_levels) + 1L)
                    missing_rug$row_y <- missing_y
                    p <- p + ggplot2::geom_point(
                        data = missing_rug,
                        ggplot2::aes(x = x, y = .data$row_y),
                        shape = 4,
                        size = 1.25,
                        colour = unname(palette[["nuisance"]]),
                        inherit.aes = FALSE
                    ) + ggplot2::annotate(
                        "text",
                        x = row_label_x, y = missing_y,
                        label = "missing", hjust = 0, size = 2.2,
                        colour = unname(palette[["nuisance"]])
                    )
                }
            } else {
                observed_rug$row_y <- marker_y
                p <- p + ggplot2::geom_point(
                    data = observed_rug,
                    ggplot2::aes(
                        x = x, y = .data$row_y,
                        colour = .data[[colour_by]],
                        size = .data[[colour_by]]
                    ),
                    alpha = 0.7,
                    inherit.aes = FALSE
                ) + scale_colour_landscapeR(
                    "continuous",
                    name = .scientific_caption_label(colour_by)
                ) + ggplot2::scale_size_continuous(
                    range = c(0.8, 2.2),
                    name = paste0(
                        .scientific_caption_label(colour_by), " (point size)"
                    )
                )
                if (nrow(missing_rug)) {
                    missing_rug$row_y <- marker_y
                    p <- p + ggplot2::geom_point(
                        data = missing_rug,
                        ggplot2::aes(x = x, y = .data$row_y),
                        colour = unname(palette[["ink"]]),
                        shape = 4,
                        size = 1.4,
                        inherit.aes = FALSE
                    )
                }
            }
        } else {
            p <- p +
                ggplot2::geom_rug(
                    data = rug_df,
                    ggplot2::aes(x = x),
                    sides = "b", alpha = 0.4,
                    colour = .landscapeR_colour("nuisance"),
                    inherit.aes = FALSE)
        }
    }

    view <- .stage2_potential_surface_view(
        view, colour_by, show_critical_points
    )
    categorical_metadata <- !is.null(rug_df) && !is.null(colour_by) &&
        !is.numeric(rug_df[[colour_by]])
    if (categorical_metadata && isTRUE(show_critical_points) && nrow(cp_df)) {
        p <- p +
            ggplot2::guides(colour = "none") +
            ggplot2::theme(legend.box = "vertical")
    } else if (categorical_metadata) {
        p <- p + ggplot2::guides(colour = "none")
    } else if (!is.null(colour_by) && isTRUE(show_critical_points) && nrow(cp_df)) {
        p <- p + ggplot2::theme(legend.box = "vertical")
    } else if (!is.null(colour_by)) {
        p <- p + ggplot2::theme(legend.box = "vertical")
    }
    if (length(critical_y)) {
        critical_span <- diff(range(critical_y, na.rm = TRUE))
        critical_padding <- max(critical_span * 0.15, 0.25)
        p <- p + ggplot2::coord_cartesian(
            ylim = c(NA_real_, max(critical_y, na.rm = TRUE) + critical_padding)
        )
    }
    .with_scientific_caption(p, visual_evidence_caption(view))
}

.stage2_potential_surface_view <- function(
    view,
    colour_by,
    show_critical_points
) {
    displays <- .visual_evidence_displays(view)
    rug_df <- displays$rug
    if (!nrow(rug_df)) rug_df <- NULL
    if (!is.null(rug_df) && !is.null(colour_by)) {
        aligned_metadata <- lapply(
            displays$layers,
            function(layer) {
                displays$aligned_metadata[[displays$experiment_names[[layer]]]]
            }
        )
        rug_df[[colour_by]] <- unlist(aligned_metadata, use.names = FALSE)
        rug_df$.primary_sample <- unlist(
            lapply(aligned_metadata, names), use.names = FALSE
        )
    }
    metadata_values <- if (!is.null(rug_df) && !is.null(colour_by)) {
        rug_df[[colour_by]]
    } else {
        NULL
    }
    rug_encoding <- if (is.null(rug_df)) {
        "Sample-coordinate rug marks are omitted because Stage 1 coordinates are unavailable"
    } else if (is.null(metadata_values)) {
        "Grey rug marks show observed sample coordinates without metadata encoding"
    } else if (is.numeric(metadata_values)) {
        paste0(
            "Baseline-point colour and size identify continuous ",
            .scientific_caption_label(colour_by),
            "; no metadata stems are drawn"
        )
    } else if (all(is.na(metadata_values))) {
        paste0(
            "No observed values are available for categorical ",
            .scientific_caption_label(colour_by),
            "; crosses show sample coordinates in a directly labelled missing row; ",
            "no metadata stems are drawn"
        )
    } else {
        paste0(
            "Coloured points identify categorical ",
            .scientific_caption_label(colour_by),
            " and show sample coordinates in directly labelled baseline rows; ",
            "row position and text provide non-colour group identification; ",
            "no metadata stems are drawn"
        )
    }
    cp_df <- displays$critical_points
    seg_df <- displays$barrier_segments
    critical_y <- if (isTRUE(show_critical_points) && nrow(cp_df)) {
        c(cp_df$U, seg_df$y, seg_df$yend)
    } else {
        numeric()
    }
    critical_encoding <- if (!isTRUE(show_critical_points)) {
        "Critical-point symbols and barrier-height segments are omitted"
    } else if (!nrow(cp_df) && !nrow(seg_df)) {
        paste0(
            "Critical-point overlays were requested, but no stored wells, barriers, or barrier-height segments are available"
        )
    } else {
        c(
            if (any(cp_df$type == "well")) {
                "Small open circles mark stored stable wells directly on the curve"
            },
            if (any(cp_df$type == "barrier")) {
                paste0(
                    "Small red diamonds mark stored unstable barriers directly ",
                    "on the curve"
                )
            },
            if (nrow(seg_df)) {
                "Dashed vertical segments show point-estimate barrier heights"
            },
            if (length(critical_y)) {
                paste(
                    "The vertical display is focused on the stored critical-point",
                    "and barrier-height range; higher low-density tails continue",
                    "beyond the panel"
                )
            }
        )
    }
    context <- displays$caption_context
    caption <- .new_scientific_caption_view(
        title = "Density-derived quasi-potential landscape",
        experiment_label = context$experiment_label,
        molecular_layer = context$molecular_layer,
        molecular_layer_count = context$molecular_layer_count,
        sampling_unit = context$sampling_unit,
        design = context$design,
        time_field = context$time_field,
        time_unit = context$time_unit,
        subject_field = context$subject_field,
        encodings = c(
            paste0(
                "The black curve shows U(x) = -log p(x), derived from the ",
                "stored density estimate for component ", displays$component
            ),
            rug_encoding,
            critical_encoding
        ),
        estimand = "the density-derived quasi-potential along the selected component",
        uncertainty = if (isTRUE(show_critical_points) && nrow(cp_df)) {
            if (nrow(seg_df)) {
                paste0(
                    "Critical-point classifications and barrier heights are ",
                    "point estimates without uncertainty"
                )
            } else {
                paste0(
                    "Critical-point classifications are point estimates ",
                    "without uncertainty"
                )
            }
        } else if (identical(visual_evidence_state(view), "partial")) {
            "The quasi-potential curve is shown, but one or more supporting display elements are unavailable"
        } else {
            NA_character_
        },
        missingness = if (!is.null(metadata_values) && anyNA(metadata_values)) {
        if (!is.numeric(metadata_values)) {
            sprintf(
                "Crosses in the labelled missing row mark %d observations with missing %s",
                length(unique(rug_df$.primary_sample[is.na(metadata_values)])),
                .scientific_caption_label(colour_by)
            )
        } else {
            sprintf(
                "Crosses at the baseline mark %d observations with missing %s",
                length(unique(rug_df$.primary_sample[is.na(metadata_values)])),
                .scientific_caption_label(colour_by)
            )
        }
        } else {
            NULL
        },
        threshold = "No calibrated critical-point or barrier threshold is applied",
        claim_boundary = paste0(
            "The landscape is an exploratory description and does not by ",
            "itself establish a biological state transition"
        ),
        state = .visual_evidence_surface_state(view)
    )
    .replace_visual_evidence_caption(
        view,
        caption,
        display_data = list(
            surface_request = list(
                plot = "potential",
                colour_by = colour_by,
                show_critical_points = show_critical_points
            )
        )
    )
}
