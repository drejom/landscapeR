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
    s2 <- metadata(std)$stage2
    if (is.null(s2))
        stop("Stage 2 has not been run on this object. Call estimate_dynamics() first.")

    # Expected stage2 structure (set by the DynamicsEstimator contract):
    #   s2$x         numeric vector -- state-transition axis grid
    #   s2$U         numeric vector -- quasi-potential values on grid
    #   s2$wells     numeric vector -- x positions of stable critical points
    #   s2$barriers  numeric vector -- x positions of unstable critical points
    required <- c("x", "U", "wells", "barriers")
    missing_fields <- setdiff(required, names(s2))
    if (length(missing_fields))
        stop(sprintf("metadata()$stage2 is missing: %s",
                     paste(missing_fields, collapse = ", ")))

    curve_df <- data.frame(x = s2$x, U = s2$U)

    # Critical-point annotations (guard against empty wells/barriers)
    cp_rows <- list()
    if (length(s2$wells) > 0L)
        cp_rows[[1]] <- data.frame(x = s2$wells,
                                    U = approx(s2$x, s2$U, s2$wells)$y,
                                    type = "well", stringsAsFactors = FALSE)
    if (length(s2$barriers) > 0L)
        cp_rows[[2]] <- data.frame(x = s2$barriers,
                                    U = approx(s2$x, s2$U, s2$barriers)$y,
                                    type = "barrier", stringsAsFactors = FALSE)
    cp_df <- if (length(cp_rows)) do.call(rbind, cp_rows) else
        data.frame(x = numeric(0), U = numeric(0), type = character(0),
                   stringsAsFactors = FALSE)

    # Barrier-height segments
    seg_rows <- list()
    for (b in s2$barriers) {
        U_b   <- approx(s2$x, s2$U, b)$y
        wells_left  <- s2$wells[s2$wells < b]
        wells_right <- s2$wells[s2$wells > b]
        if (length(wells_left))  {
            U_wl <- approx(s2$x, s2$U, max(wells_left))$y
            seg_rows[[length(seg_rows)+1]] <- data.frame(
                x = max(wells_left), xend = max(wells_left),
                y = U_wl, yend = U_b)
        }
        if (length(wells_right)) {
            U_wr <- approx(s2$x, s2$U, min(wells_right))$y
            seg_rows[[length(seg_rows)+1]] <- data.frame(
                x = min(wells_right), xend = min(wells_right),
                y = U_wr, yend = U_b)
        }
    }

    # Sample rug — component-aware with fallback (#14 + #16)
    s1 <- metadata(std)$stage1
    rug_df <- NULL
    layer_indices <- integer()
    comp <- s2$params$component %||% 1L
    if (!is.null(s1)) {
        if (length(dr_coords_k(s1))) {
            if (isTRUE(s2$params$pool_layers)) {
                layer_indices <- seq_along(dr_coords_k(s1))
                rug_x <- unlist(lapply(
                    dr_coords_k(s1),
                    function(m) drop(m[, comp])
                ))
            } else {
                layer_idx <- s2$params$layer %||% 1L
                layer_indices <- layer_idx
                rug_x <- drop(dr_coords_k(s1)[[layer_idx]][, comp])
            }
        } else if (length(dr_coords(s1))) {
            warning("Using coords fallback for rug positions (coords_k empty)")
            layer_indices <- 1L
            rug_x <- dr_coords(s1)[[1L]]
        } else {
            warning("No coordinate data available for rug")
            rug_x <- NULL
        }
        if (!is.null(rug_x)) {
            rug_df <- data.frame(x = rug_x, stringsAsFactors = FALSE)
            if (!is.null(colour_by)) {
                aligned_metadata <- lapply(
                    layer_indices,
                    function(layer) {
                        .component_gallery_metadata(
                            std,
                            layer,
                            colour_by,
                            caller = "plot_potential"
                        )
                    }
                )
                rug_df[[colour_by]] <- unlist(
                    aligned_metadata, use.names = FALSE
                )
                rug_df$.primary_sample <- unlist(
                    lapply(aligned_metadata, names), use.names = FALSE
                )
            }
        }
    }

    palette <- landscapeR_palette("semantic")
    p <- ggplot2::ggplot(curve_df, ggplot2::aes(x = x, y = U)) +
        ggplot2::geom_line(linewidth = 1, colour = unname(palette[["ink"]])) +
        ggplot2::labs(
            title = "Quasi-potential landscape  U(x) = -log p(x)",
            x = "State-transition coordinate",
            y = "U(x)"
        ) +
        theme_landscapeR() +
        ggplot2::theme(legend.position = "bottom")

    if (isTRUE(show_critical_points)) {
        p <- p +
            ggplot2::geom_point(
                data = cp_df,
                ggplot2::aes(shape = type),
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

    # Barrier-height segments
    if (isTRUE(show_critical_points) && length(seg_rows)) {
        seg_df <- do.call(rbind, seg_rows)
        p <- p + ggplot2::geom_segment(
            data = seg_df,
            ggplot2::aes(x = x, xend = xend, y = y, yend = yend),
            linetype = "dotted",
            colour = unname(palette[["nuisance"]]), linewidth = 0.7,
            inherit.aes = FALSE)
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
                    sides = "b", alpha = 0.4, colour = "grey40",
                    inherit.aes = FALSE)
        }
    }

    context <- .plot_caption_context(
        std,
        if (length(layer_indices)) layer_indices else seq_along(experiments(std))
    )
    metadata_values <- if (
        !is.null(rug_df) &&
            !is.null(colour_by) &&
            colour_by %in% colnames(rug_df)
    ) {
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
    critical_encoding <- if (!isTRUE(show_critical_points)) {
        "Critical-point symbols and barrier-height segments are omitted"
    } else if (!nrow(cp_df) && !length(seg_rows)) {
        paste0(
            "Critical-point overlays were requested, but no stored wells, ",
            "barriers, or barrier-height segments are available"
        )
    } else {
        c(
            if (any(cp_df$type == "well")) {
                "Exploratory downward triangles mark stored wells"
            },
            if (any(cp_df$type == "barrier")) {
                "Exploratory upward triangles mark stored barriers"
            },
            if (length(seg_rows)) {
                paste0(
                    "Dotted vertical segments show point-estimate barrier ",
                    "heights"
                )
            }
        )
    }
    missingness <- if (!is.null(metadata_values) && anyNA(metadata_values)) {
        missing_units <- unique(
            rug_df$.primary_sample[is.na(metadata_values)]
        )
        sprintf(
            "Dashed rug marks %d observations with missing %s",
            length(missing_units), colour_by
        )
    } else {
        NULL
    }
    view <- .new_scientific_caption_view(
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
                "stored density estimate for component ", comp
            ),
            rug_encoding,
            critical_encoding
        ),
        estimand = "the density-derived quasi-potential along the selected component",
        uncertainty = if (
            isTRUE(show_critical_points) &&
                (nrow(cp_df) || length(seg_rows))
        ) {
            paste0(
                "Critical-point classifications and barrier heights are point ",
                "estimates without uncertainty"
            )
        } else {
            NA_character_
        },
        missingness = missingness,
        threshold = "No calibrated critical-point or barrier threshold is applied",
        claim_boundary = paste0(
            "The landscape is an exploratory description and does not by ",
            "itself establish a biological state transition"
        ),
        state = "uncalibrated"
    )
    .with_scientific_caption(p, .build_scientific_caption(view))
}
