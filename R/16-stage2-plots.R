# Stage 2 diagnostic plot functions for StateTransitionData

utils::globalVariables(c("U", "type", "xend", "y", "yend", ".data"))

# ---------------------------------------------------------------------------
# plot_potential(): Stage 2 quasi-potential curve
# ---------------------------------------------------------------------------

.stage2_critical_point_display <- function(cp_df, curve_df) {
    if (!is.data.frame(cp_df) || !nrow(cp_df)) {
        return(list(
            points = data.frame(
                x = numeric(), U = numeric(), type = character(),
                display_x = numeric(), display_U = numeric()
            ),
            connectors = data.frame(
                x = numeric(), y = numeric(), xend = numeric(), yend = numeric()
            )
        ))
    }
    x_values <- curve_df$x[is.finite(curve_df$x)]
    y_values <- curve_df$U[is.finite(curve_df$U)]
    x_span <- diff(range(x_values))
    y_span <- diff(range(y_values))
    if (!is.finite(x_span) || x_span <= 0) x_span <- 1
    if (!is.finite(y_span) || y_span <= 0) y_span <- 1
    order_index <- order(cp_df$x, cp_df$type)
    ranks <- integer(nrow(cp_df))
    ranks[order_index] <- seq_len(nrow(cp_df))
    offsets <- ranks - (nrow(cp_df) + 1) / 2
    display <- cp_df
    display$display_x <- cp_df$x + offsets * x_span * 0.035
    display$display_U <- cp_df$U + max(y_span * 0.06, 0.25)
    connectors <- data.frame(
        x = display$x,
        y = display$U,
        xend = display$display_x,
        yend = display$display_U
    )
    list(points = display, connectors = connectors)
}

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
#'   the rug of sample positions, or \code{NULL} (default \code{NULL})
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
            ggplot2::aes(x = x, xend = xend, y = y, yend = yend),
            linetype = "dotted",
            colour = unname(palette[["nuisance"]]), linewidth = 0.7,
            inherit.aes = FALSE
        )
    }
    p <- p + ggplot2::geom_line(
        linewidth = 1, colour = unname(palette[["ink"]])
    ) +
        ggplot2::labs(
            title = "Quasi-potential landscape  U(x) = -log p(x)",
            x = "State-transition coordinate",
            y = "U(x)"
        ) +
        theme_landscapeR() +
        ggplot2::theme(legend.position = "bottom")

    if (isTRUE(show_critical_points)) {
        critical_display <- .stage2_critical_point_display(cp_df, curve_df)
        p <- p +
            ggplot2::geom_segment(
                data = critical_display$connectors,
                ggplot2::aes(x = x, xend = xend, y = y, yend = yend),
                linetype = "dashed",
                linewidth = 0.4,
                colour = unname(palette[["nuisance"]]),
                inherit.aes = FALSE
            ) +
            ggplot2::geom_point(
                data = critical_display$points,
                ggplot2::aes(x = display_x, y = display_U, shape = type),
                size = 4,
                colour = unname(palette[["ink"]])
            ) +
            ggplot2::scale_shape_manual(
                values = c(well = 25, barrier = 24),
                labels = c(
                    well = "Stable (well)",
                    barrier = "Unstable (barrier)"
                )
            ) +
            ggplot2::labs(shape = "Critical point")
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
            p <- p +
                ggplot2::geom_rug(
                    data = observed_rug,
                    ggplot2::aes(x = x, colour = .data[[colour_by]]),
                    sides = "b", alpha = 0.6, inherit.aes = FALSE)
            if (is.numeric(rug_df[[colour_by]])) {
                p <- p + scale_colour_landscapeR(
                    "continuous",
                    name = colour_by
                )
            } else {
                p <- p + scale_colour_landscapeR(
                    "categorical",
                    name = colour_by
                )
            }
            if (nrow(missing_rug)) {
                p <- p +
                    ggplot2::geom_rug(
                        data = missing_rug,
                        ggplot2::aes(x = x),
                        sides = "b",
                        colour = unname(palette[["ink"]]),
                        linetype = "dashed",
                        linewidth = 0.7,
                        inherit.aes = FALSE
                    )
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
    if (!is.null(colour_by) && isTRUE(show_critical_points) && nrow(cp_df)) {
        p <- p +
            ggplot2::guides(
                colour = ggplot2::guide_legend(order = 1L),
                shape = ggplot2::guide_legend(order = 2L)
            ) +
            ggplot2::theme(legend.box = "vertical")
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
    } else {
        paste0(
            "Rug marks show observed sample coordinates; ",
            .plot_metadata_encoding(metadata_values, colour_by, "rug colours")
        )
    }
    cp_df <- displays$critical_points
    seg_df <- displays$barrier_segments
    critical_encoding <- if (!isTRUE(show_critical_points)) {
        "Critical-point symbols and barrier-height segments are omitted"
    } else if (!nrow(cp_df) && !nrow(seg_df)) {
        paste0(
            "Critical-point overlays were requested, but no stored wells, barriers, or barrier-height segments are available"
        )
    } else {
        c(
            if (any(cp_df$type == "well")) {
                paste(
                    "Exploratory downward triangles mark stored wells;",
                    "symbols are offset from their stored coordinates and",
                    "linked by dashed stems"
                )
            },
            if (any(cp_df$type == "barrier")) {
                paste(
                    "exploratory upward triangles mark stored barriers;",
                    "symbols are offset from their stored coordinates and",
                    "linked by dashed stems"
                )
            },
            if (nrow(seg_df)) {
                "Dotted vertical segments show point-estimate barrier heights"
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
            sprintf(
                "Dashed rug marks %d observations with missing %s",
                length(unique(rug_df$.primary_sample[is.na(metadata_values)])),
                colour_by
            )
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
