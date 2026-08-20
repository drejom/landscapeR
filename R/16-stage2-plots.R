# Stage 2 diagnostic plot functions for StateTransitionData

utils::globalVariables(c("U", "type", "xend", "y", "yend", ".data"))

# ---------------------------------------------------------------------------
# plot_potential(): Stage 2 quasi-potential curve
# ---------------------------------------------------------------------------

#' Plot the quasi-potential landscape (Stage 2 output)
#'
#' Shows U(x) = -log p(x) along the state-transition axis. Point-estimate
#' critical-point classifications are omitted by default;
#' they require explicit diagnostic opt-in until uncertainty is available.
#' The returned scientific caption describes the selected component, plotted
#' encodings, missing observations, and exploratory claim boundary separately
#' from the graphic.
#'
#' @param std \code{StateTransitionData} with \code{metadata()$stage2} present
#' @param colour_by character column name in \code{colData(std)} to colour
#'   the displayed sample positions. Categorical and continuous sample
#'   positions use fine rugs without metadata stems. Declared binary reference
#'   and focal groups occupy the upper and lower margins, respectively;
#'   continuous metadata uses colour plus opacity. Use
#'   \code{NULL} (default) for an unlabelled rug.
#' @param reference_level optional declared reference level for binary
#'   categorical metadata. Supply together with \code{focal_level}; the
#'   reference is drawn in neutral grey.
#' @param focal_level optional declared focal level for binary categorical
#'   metadata. Supply together with \code{reference_level}; the focal group is
#'   drawn in the package focal red.
#' @param show_critical_points logical; explicitly opt in to point-estimate
#'   well/barrier classifications and fine dashed position guides. Defaults to
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
                           show_critical_points = FALSE,
                           reference_level = NULL, focal_level = NULL) {
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
    critical_y <- if (isTRUE(show_critical_points) && nrow(cp_df)) {
        cp_df$U
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
    if (isTRUE(show_critical_points) && nrow(cp_df)) {
        p <- p + ggplot2::geom_vline(
            data = cp_df,
            ggplot2::aes(xintercept = .data$x),
            colour = unname(palette[["nuisance"]]),
            linewidth = 0.25,
            linetype = "dashed",
            alpha = 0.7,
            inherit.aes = FALSE
        )
    }
    p <- p + ggplot2::geom_line(
        linewidth = 0.5, colour = unname(palette[["ink"]])
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
                size = 1.1,
                stroke = 0.3,
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
                        size = 1.7,
                        stroke = 0.35,
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
    binary_levels <- NULL
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
            categorical_metadata <- !is.numeric(rug_df[[colour_by]])
            binary_levels <- .declared_binary_plot_levels(
                rug_df[[colour_by]],
                reference_level = reference_level,
                focal_level = focal_level,
                caller = "plot_potential()"
            )
            if (!is.null(binary_levels)) {
                reference_rug <- observed_rug[
                    observed_rug[[colour_by]] == binary_levels[["reference"]],
                    , drop = FALSE
                ]
                focal_rug <- observed_rug[
                    observed_rug[[colour_by]] == binary_levels[["focal"]],
                    , drop = FALSE
                ]
                p <- p +
                    ggplot2::geom_rug(
                        data = reference_rug,
                        ggplot2::aes(
                            x = .data$x,
                            colour = .data[[colour_by]]
                        ),
                        inherit.aes = FALSE,
                        sides = "t",
                        length = grid::unit(2, "mm"),
                        linewidth = 0.3,
                        alpha = 0.75
                    ) +
                    ggplot2::geom_rug(
                        data = focal_rug,
                        ggplot2::aes(
                            x = .data$x,
                            colour = .data[[colour_by]]
                        ),
                        inherit.aes = FALSE,
                        sides = "b",
                        length = grid::unit(2, "mm"),
                        linewidth = 0.3,
                        alpha = 0.75
                    )
            } else if (categorical_metadata) {
                p <- p + ggplot2::geom_rug(
                    data = observed_rug,
                    ggplot2::aes(x = .data$x, colour = .data[[colour_by]]),
                    inherit.aes = FALSE,
                    sides = "b",
                    length = grid::unit(2, "mm"),
                    linewidth = 0.3,
                    alpha = 0.75
                )
            } else {
                p <- p + ggplot2::geom_rug(
                    data = observed_rug,
                    ggplot2::aes(
                        x = .data$x,
                        colour = .data[[colour_by]],
                        alpha = .data[[colour_by]]
                    ),
                    inherit.aes = FALSE,
                    sides = "b",
                    length = grid::unit(2, "mm"),
                    linewidth = 0.3
                ) + ggplot2::scale_alpha_continuous(
                    range = c(0.35, 0.9),
                    breaks = range(observed_rug[[colour_by]], na.rm = TRUE),
                    name = paste0(
                        .scientific_caption_label(colour_by),
                        " (rug opacity)"
                    )
                )
            }
            if (is.null(binary_levels)) {
                p <- p + scale_colour_landscapeR(
                    if (categorical_metadata) "categorical" else "continuous",
                    name = .scientific_caption_label(colour_by)
                )
            } else {
                p <- p + scale_colour_landscapeR(
                    "binary",
                    reference_level = binary_levels[["reference"]],
                    focal_level = binary_levels[["focal"]],
                    name = .scientific_caption_label(colour_by)
                )
            }
            if (nrow(missing_rug)) {
                p <- p + ggplot2::geom_rug(
                    data = missing_rug,
                    ggplot2::aes(x = .data$x),
                    inherit.aes = FALSE,
                    sides = "b",
                    length = grid::unit(2, "mm"),
                    linewidth = 0.3,
                    linetype = "dashed",
                    colour = unname(palette[["ink"]])
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
        view, colour_by, show_critical_points, binary_levels
    )
    categorical_metadata <- !is.null(rug_df) && !is.null(colour_by) &&
        !is.numeric(rug_df[[colour_by]])
    if (!is.null(colour_by) && isTRUE(show_critical_points) && nrow(cp_df)) {
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
    show_critical_points,
    binary_levels = NULL
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
            "Fine rug colour and opacity identify continuous ",
            .scientific_caption_label(colour_by)
        )
    } else if (all(is.na(metadata_values))) {
        paste0(
            "No observed values are available for categorical ",
            .scientific_caption_label(colour_by),
            "; dashed black rugs show sample coordinates with missing metadata"
        )
    } else {
        if (is.null(binary_levels)) {
            paste0(
                "Fine coloured rugs identify categorical ",
                .scientific_caption_label(colour_by),
                " and show individual sample coordinates"
            )
        } else {
            paste0(
                "Reference rugs occupy the upper margin and focal rugs the ",
                "lower margin; grey and red redundantly identify categorical ",
                .scientific_caption_label(colour_by)
            )
        }
    }
    cp_df <- displays$critical_points
    critical_y <- if (isTRUE(show_critical_points) && nrow(cp_df)) {
        cp_df$U
    } else {
        numeric()
    }
    critical_encoding <- if (!isTRUE(show_critical_points)) {
        "Critical-point symbols and position guides are omitted"
    } else if (!nrow(cp_df)) {
        paste0(
            "Critical-point overlays were requested, but no stored wells or barriers are available"
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
            "Fine grey dashed lines locate stored critical-point positions",
            if (length(critical_y)) {
                paste(
                    "The vertical display is focused on the stored critical-point",
                    "range; higher low-density tails continue",
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
            paste0(
                "Critical-point classifications are point estimates ",
                "without uncertainty"
            )
        } else if (identical(visual_evidence_state(view), "partial")) {
            "The quasi-potential curve is shown, but one or more supporting display elements are unavailable"
        } else {
            NA_character_
        },
        missingness = if (!is.null(metadata_values) && anyNA(metadata_values)) {
        if (!is.numeric(metadata_values)) {
            sprintf(
                "Dashed black rugs mark %d observations with missing %s",
                length(unique(rug_df$.primary_sample[is.na(metadata_values)])),
                .scientific_caption_label(colour_by)
            )
        } else {
            sprintf(
                "Dashed black rugs mark %d observations with missing %s",
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
