# Stage 1 diagnostic plot functions for StateTransitionData

utils::globalVariables(c("coord", "sample_ord", ".data", "x", "sv", "layer"))

.plot_caption_context <- function(std, layers = seq_along(experiments(std))) {
    layer_names <- names(as.list(experiments(std)))[layers]
    dataset_id <- metadata(std)$dataset_id
    if (!.is_scalar_nonempty_text(dataset_id)) dataset_id <- NA_character_
    design <- std@sampling_design@kind
    sampling_unit <- switch(
        design,
        longitudinal = paste0(
            "biological observation nested within a complete subject trajectory"
        ),
        cross_sectional = "independent biological observation",
        independent_time_course = paste0(
            "independent biological observation at observed time"
        ),
        "biological observation"
    )
    time_field <- if (length(std@sampling_design@time_col)) {
        std@sampling_design@time_col
    } else {
        NA_character_
    }
    time_unit <- if (length(std@sampling_design@time_unit)) {
        std@sampling_design@time_unit
    } else {
        NA_character_
    }
    subject_field <- if (length(std@sampling_design@subject_id_col)) {
        std@sampling_design@subject_id_col
    } else {
        NA_character_
    }
    list(
        experiment_label = dataset_id,
        molecular_layer = paste(layer_names, collapse = ", "),
        molecular_layer_count = length(layer_names),
        sampling_unit = sampling_unit,
        design = design,
        time_field = time_field,
        time_unit = time_unit,
        subject_field = subject_field
    )
}

.plot_metadata_encoding <- function(values, field, marks) {
    if (is.null(values)) return(paste0(marks, " do not encode sample metadata"))
    type <- if (is.numeric(values)) "continuous" else "categorical"
    paste0(
        marks, " encode ", type, " ",
        .scientific_caption_label(field)
    )
}

.metadata_shape_values <- function(values) {
    levels <- sort(unique(as.character(values[!is.na(values)])))
    if (length(levels) > 8L) {
        .stop_plot_evidence_unavailable(
            "Categorical decomposition marks support at most 8 levels"
        )
    }
    shapes <- c(16, 17, 15, 18, 8, 3, 4, 7)
    stats::setNames(rep(shapes, length.out = length(levels)), levels)
}

.metadata_linetype_values <- function(values) {
    levels <- sort(unique(as.character(values[!is.na(values)])))
    if (length(levels) > 8L) {
        .stop_plot_evidence_unavailable(
            "Categorical density outlines support at most 8 levels"
        )
    }
    linetypes <- c(
        "solid", "dashed", "dotted", "dotdash",
        "longdash", "twodash", "11", "33"
    )
    stats::setNames(rep(linetypes, length.out = length(levels)), levels)
}

#
# All functions take a StateTransitionData object and return a ggplot.
# colour_by is always optional -- omit it for unlabelled exploratory plots,
# supply a colData column name to colour points by a sample covariate.
#
# Typical interactive use:
#
#   std <- synthetic_control(n=40, p=500, K=2, signal=30, seed=1)
#   std2 <- decompose(get_strategy("Decomposer","hogsvd_averaged")(), std)@value
#   plot_spectrum(std2)
#   plot_decomposition(std2, colour_by = "group")
#
# In vignettes and @examples, assign the returned ggplot and print it.
#
# Component gallery workflow (typical for real data):
#
#   std2 <- decompose(get_strategy("Decomposer","hogsvd_averaged")(), std)@value
#   plot_components(std2, colour_by = "condition")
#
# The gallery is descriptive. Association scoring, proposal ranking, and human
# confirmation belong to the metadata-atlas workflow rather than this plot.

# ---------------------------------------------------------------------------
# plot_components(): descriptive gallery of k Stage 1 components
# ---------------------------------------------------------------------------

#' Component gallery coloured by canonically aligned sample metadata
#'
#' Shows the sample-coordinate distribution for each of the first
#' \code{n_components} components as stored density and rug panels in decomposition
#' order. Metadata are read from MAE-level \code{colData} and aligned to the
#' selected assay through its canonical \code{sampleMap}; row position is never
#' treated as sample identity.
#'
#' Categorical metadata use colour and line type on grouped density outlines;
#' sample points at the density baseline repeat group identity through colour
#' and shape. Continuous metadata use colour and point size at the density
#' baseline. These encodings retain individual sample positions without adding
#' a second field of baseline stems. The gallery
#' rejects categorical fields with more than 8 observed levels rather than
#' assigning ambiguous marks. It does not calculate association scores or rank components; those
#' responsibilities belong to the metadata atlas and proposal workflow.
#'
#' @param std \code{StateTransitionData} with \code{metadata()$stage1} present
#' @param colour_by optional single MAE-level \code{colData} column name.
#'   Categorical and continuous fields are supported.
#' @param n_components integer number of components to show (default 6)
#' @param layer integer selected assay layer (default 1)
#' @return a \code{ggplot} object faceted over components in decomposition order
#'
#' @examples
#' std <- synthetic_control(n = 40L, p = 500L, K = 2L, signal = 30, seed = 1L)
#' ctor <- get_strategy("Decomposer", "hogsvd_averaged")
#' std2 <- suppressWarnings(decompose(ctor(), std))@value
#' plot_components(std2, colour_by = "planted_group")
#'
#' @export
plot_components <- function(std, colour_by = NULL, n_components = 6L, layer = 1L) {
    if (!is(std, "StateTransitionData"))
        .stop_landscapeR_validation(
            "plot_components(): std must be a StateTransitionData object"
        )
    view <- .stage_visual_evidence(
        std, "stage1", colour_by = colour_by, caller = "plot_components"
    )
    if (identical(visual_evidence_state(view), "missing")) {
        return(.render_unavailable_visual_evidence(view))
    }
    displays <- .visual_evidence_displays(view)
    if (is.null(displays$decomposition)) {
        return(.render_unavailable_visual_evidence(
            .stage_unavailable_visual_evidence(
                "stage1",
                paste0(
                    "Stage 1 component evidence is unavailable; run ",
                    "decompose() before plotting components"
                )
            )
        ))
    }
    coordinate_evidence <- displays$decomposition$coordinates
    evidence_layers <- unique(coordinate_evidence$layer)
    if (!is.numeric(layer) || length(layer) != 1L || !is.finite(layer) ||
        layer != as.integer(layer) || layer < 1L ||
        layer > length(evidence_layers) ||
        layer > displays$experiment_count) {
        .stop_landscapeR_validation(sprintf(
            "plot_components(): layer must be an integer from 1 to %d",
            min(length(evidence_layers), displays$experiment_count)
        ))
    }
    idx <- as.integer(layer)
    layer_name <- evidence_layers[[idx]]
    expt_idx <- match(layer_name, displays$experiment_names)
    if (is.na(expt_idx)) {
        .stop_plot_evidence_unavailable(sprintf(
            "Stored Stage 1 coordinates reference unknown layer '%s'",
            layer_name
        ))
    }
    coordinate_evidence <- coordinate_evidence[
        coordinate_evidence$layer == layer_name,
        ,
        drop = FALSE
    ]
    if (length(unique(coordinate_evidence$sample)) !=
        displays$experiment_observations[[layer_name]]) {
        .stop_landscapeR_validation(sprintf(
            paste0(
                "plot_components(): Stage 1 coordinates for layer %d do not ",
                "match the selected assay's observation count"
            ),
            idx
        ))
    }
    if (!is.numeric(n_components) || length(n_components) != 1L ||
        !is.finite(n_components) || n_components != as.integer(n_components) ||
        n_components < 1L) {
        .stop_landscapeR_validation(
            "plot_components(): n_components must be a positive integer"
        )
    }
    k_show <- min(
        as.integer(n_components),
        max(coordinate_evidence$component)
    )
    meta_col <- displays$aligned_metadata[[layer_name]]
    density_df <-
        displays$component_densities[[layer_name]]
    density_df <- density_df[
        density_df$component %in% sprintf("PC%d", seq_len(k_show)),
        ,
        drop = FALSE
    ]
    density_partition <- .partition_density_evidence(density_df)
    density_df <- density_partition$available

    df <- coordinate_evidence[
        coordinate_evidence$component <= k_show,
        c("sample", "coord", "component"),
        drop = FALSE
    ]
    df$component <- sprintf("PC%d", df$component)
    if (!is.null(meta_col)) {
        df$metadata_value <- meta_col[df$sample]
    }
    df$component <- factor(
        df$component,
        levels = sprintf("PC%d", seq_len(k_show))
    )
    component_names <- levels(df$component)
    component_letters <- .publication_panel_letters(k_show)
    component_labels <- stats::setNames(
        sprintf("(%s) %s", component_letters, component_names),
        component_names
    )

    subtitle <- if (is.null(meta_col)) {
        "Components shown in decomposition order"
    } else if (is.numeric(meta_col)) {
        sprintf(
            "Decomposition order; baseline-point colour and size show %s",
            .scientific_caption_label(colour_by)
        )
    } else {
        sprintf(
            "Decomposition order; colour shows %s",
            .scientific_caption_label(colour_by)
        )
    }

    p <- ggplot2::ggplot(df, ggplot2::aes(x = coord))
    if (is.null(meta_col)) {
        p <- p +
            ggplot2::geom_area(
                data = density_df,
                ggplot2::aes(x = .data$coord, y = .data$density),
                inherit.aes = FALSE,
                fill = .landscapeR_colour("structure"),
                colour = .landscapeR_colour("nuisance"),
                alpha = 0.55,
                linewidth = 0.5
            ) +
            ggplot2::geom_rug(
                colour = .landscapeR_colour("nuisance"),
                alpha = 0.45,
                sides = "b"
            )
    } else if (is.numeric(meta_col)) {
        observed <- df[!is.na(df$metadata_value), , drop = FALSE]
        missing <- df[is.na(df$metadata_value), , drop = FALSE]
        p <- p +
            ggplot2::geom_area(
                data = density_df,
                ggplot2::aes(x = .data$coord, y = .data$density),
                inherit.aes = FALSE,
                fill = .landscapeR_colour("structure"),
                colour = .landscapeR_colour("nuisance"),
                alpha = 0.55,
                linewidth = 0.5
            ) +
            ggplot2::geom_point(
                data = observed,
                ggplot2::aes(
                    y = 0,
                    colour = .data[["metadata_value"]],
                    size = .data[["metadata_value"]]
                ),
                alpha = 0.75
            ) +
            scale_colour_landscapeR("continuous") +
            ggplot2::scale_size_continuous(
                range = c(0.8, 2.2),
                name = paste0(
                    .scientific_caption_label(colour_by), " (point size)"
                )
            )
        if (nrow(missing)) {
            p <- p + ggplot2::geom_point(
                data = missing,
                ggplot2::aes(y = 0),
                colour = .landscapeR_colour("ink"),
                shape = 4,
                size = 1.4
            )
        }
    } else {
        observed <- df[!is.na(df$metadata_value), , drop = FALSE]
        missing <- df[is.na(df$metadata_value), , drop = FALSE]
        grouped_by_layer <-
            displays$component_group_densities[[layer_name]]
        grouped_density <- grouped_by_layer[[colour_by]]
        if (is.null(grouped_density)) {
            .stop_plot_evidence_unavailable(sprintf(
                "Stored Stage 1 grouped-density evidence lacks '%s'",
                colour_by
            ))
        }
        grouped_density <- grouped_density[
            grouped_density$component %in%
                sprintf("PC%d", seq_len(k_show)),
            ,
            drop = FALSE
        ]
        grouped_partition <- .partition_density_evidence(grouped_density)
        grouped_density <- grouped_partition$available
        p <- p +
            ggplot2::geom_area(
                data = grouped_density,
                ggplot2::aes(
                    x = .data$coord,
                    y = .data$density,
                    fill = .data$metadata_value,
                    colour = .data$metadata_value,
                    linetype = .data$metadata_value
                ),
                inherit.aes = FALSE,
                alpha = 0.35,
                linewidth = 0.5,
                position = "identity"
            ) +
            ggplot2::geom_point(
                data = observed,
                ggplot2::aes(
                    x = coord,
                    y = 0,
                    colour = .data[["metadata_value"]],
                    shape = .data[["metadata_value"]]
                ),
                alpha = 0.7,
                size = 1.3,
                inherit.aes = FALSE
            ) +
            scale_fill_landscapeR("categorical") +
            scale_colour_landscapeR("categorical") +
            ggplot2::scale_linetype_manual(
                values = .metadata_linetype_values(observed$metadata_value),
                name = .scientific_caption_label(colour_by)
            ) +
            ggplot2::scale_shape_manual(
                values = .metadata_shape_values(observed$metadata_value),
                name = .scientific_caption_label(colour_by)
            )
        if (nrow(missing)) {
            p <- p + ggplot2::geom_point(
                data = missing,
                ggplot2::aes(x = coord, y = 0),
                inherit.aes = FALSE,
                colour = .landscapeR_colour("ink"),
                shape = 4,
                size = 1.4
            )
        }
    }

    plot_labels <- list(
        title = "Stage 1 component distributions",
        subtitle = subtitle,
        x = "Coordinate",
        y = "Density"
    )
    if (!is.null(meta_col)) {
        plot_labels$colour <- .scientific_caption_label(colour_by)
        if (!is.numeric(meta_col)) {
            plot_labels$fill <- .scientific_caption_label(colour_by)
        }
    }

    p <- p +
        ggplot2::geom_vline(
            xintercept = 0, linetype = "dotted",
            colour = .landscapeR_colour("nuisance"), linewidth = 0.4
        ) +
        ggplot2::facet_wrap(
            ~ component,
            scales = "free",
            labeller = ggplot2::as_labeller(component_labels)
        ) +
        do.call(ggplot2::labs, plot_labels) +
        theme_landscapeR() +
        ggplot2::theme(
            legend.position = "bottom",
            legend.box = "vertical"
        )
    view <- .stage1_components_surface_view(
        view, layer_name, k_show, colour_by
    )
    .with_scientific_caption(p, visual_evidence_caption(view))
}

.partition_density_evidence <- function(density_frame) {
    available <- if ("density_available" %in% names(density_frame)) {
        density_frame$density_available
    } else {
        rep(TRUE, nrow(density_frame))
    }
    list(
        available = density_frame[available, , drop = FALSE],
        unavailable = density_frame[!available, , drop = FALSE]
    )
}

.stage1_components_surface_view <- function(
    view,
    layer_name,
    k_show,
    colour_by
) {
    displays <- .visual_evidence_displays(view)
    meta_col <- displays$aligned_metadata[[layer_name]]
    density <- displays$component_densities[[layer_name]]
    density <- density[
        density$component %in% sprintf("PC%d", seq_len(k_show)),
        ,
        drop = FALSE
    ]
    unavailable_slices <- unique(
        .partition_density_evidence(density)$unavailable$component
    )
    missingness <- if (!is.null(meta_col) && anyNA(meta_col)) {
        sprintf(
            "Crosses at the baseline mark %d observations with missing %s",
            sum(is.na(meta_col)), .scientific_caption_label(colour_by)
        )
    } else {
        NULL
    }
    if (!is.null(meta_col) && !is.numeric(meta_col)) {
        status <- displays$component_group_density_status[[layer_name]][[colour_by]]
        unavailable <- status$metadata_value[!status$density_available]
        if (length(unavailable)) {
            missingness <- paste(
                c(
                    missingness,
                    sprintf(
                        "Levels with fewer than two observations (%s) appear as baseline points only",
                        paste(unavailable, collapse = ", ")
                    )
                ),
                collapse = "; "
            )
        }
        grouped <- displays$component_group_densities[[layer_name]][[colour_by]]
        grouped <- grouped[
            grouped$component %in% sprintf("PC%d", seq_len(k_show)),
            ,
            drop = FALSE
        ]
        unavailable_grouped <- .partition_density_evidence(grouped)$unavailable
        if (nrow(unavailable_grouped)) {
            unavailable_slices <- union(
                unavailable_slices,
                sprintf(
                    "%s (%s = %s)",
                    unavailable_grouped$component,
                    .scientific_caption_label(colour_by),
                    unavailable_grouped$metadata_value
                )
            )
        }
    }
    if (length(unavailable_slices)) {
        missingness <- paste(
            c(
                missingness,
                paste0(
                    "Numerically degenerate density slices (",
                    paste(unavailable_slices, collapse = ", "),
                    ") have insufficient coordinate spread for kernel-density ",
                    "estimation at sqrt(machine precision) x max(1, maximum ",
                    "absolute coordinate); those slices appear as baseline points only"
                )
            ),
            collapse = "; "
        )
    }
    context <- displays$caption_contexts[[layer_name]]
    metadata_marks <- if (!is.null(meta_col) && !is.numeric(meta_col)) {
        paste(
            "Categorical metadata is shown by density fills and outlines;",
            "outline line type and baseline-point shape repeat group identity."
        )
    } else if (!is.null(meta_col)) {
        paste(
            "Continuous metadata is shown by baseline-point colour and size."
        )
    } else {
        "Rug colours show the available sample metadata."
    }
    caption <- .new_scientific_caption_view(
        title = "Stage 1 component distributions",
        experiment_label = context$experiment_label,
        molecular_layer = context$molecular_layer,
        molecular_layer_count = context$molecular_layer_count,
        sampling_unit = context$sampling_unit,
        design = context$design,
        time_field = context$time_field,
        time_unit = context$time_unit,
        subject_field = context$subject_field,
        panels = stats::setNames(
            sprintf(
                "Component %d sample-coordinate distribution",
                seq_len(k_show)
            ),
            .publication_panel_letters(k_show)
        ),
        encodings = c(
            paste0(
                "Facets show components 1-", k_show,
                " in decomposition order; stored densities summarize sample-coordinate ",
                "distributions; baseline marks show sample coordinates; dotted vertical lines mark zero"
            ),
            metadata_marks
        ),
        estimand = "the descriptive distribution of sample coordinates",
        missingness = missingness,
        uncertainty = if (identical(visual_evidence_state(view), "partial")) {
            paste(
                "Available density slices and baseline sample coordinates are shown;",
                "unavailable slices remain explicit"
            )
        } else {
            NA_character_
        },
        threshold = "No component-selection threshold is applied",
        claim_boundary = paste0(
            "This descriptive gallery does not rank or nominate a biological coordinate"
        ),
        state = .visual_evidence_surface_state(view)
    )
    .replace_visual_evidence_caption(
        view,
        caption,
        display_data = list(
            surface_request = list(
                plot = "components",
                layer = layer_name,
                n_components = k_show,
                colour_by = colour_by
            )
        )
    )
}

.component_gallery_metadata <- function(
    std,
    layer,
    colour_by,
    caller = "plot_components"
) {
    if (is.null(colour_by)) return(NULL)
    .aligned_component_metadata(
        std,
        layer,
        colour_by,
        caller = caller,
        field_label = "colour_by"
    )
}

# ---------------------------------------------------------------------------
# plot_spectrum(): singular value spectrum per layer + BBP threshold
# ---------------------------------------------------------------------------

#' Plot singular value spectra with a BBP model reference
#'
#' Shows the top singular values of each raw, uncentred assay as a line plot,
#' preserving the legacy descriptive estimand separately from any centred or
#' pre-reduced spectrum used internally by the decomposition strategy. A
#' horizontal reference line at the Baik-Ben Arous-Peche (BBP) phase-transition
#' value \eqn{(n \cdot p)^{1/4}} computed from the first layer. This is a
#' model-based visual reference under spiked white-noise assumptions, not
#' empirical proof that a component is recoverable or biologically valid.
#'
#' Use the returned scientific caption to report the assumptions and claim
#' boundary alongside the figure.
#'
#' @param std \code{StateTransitionData} carrying stored Stage 1 plot evidence.
#'   Fresh legacy objects can be upgraded with
#'   \code{\link{prepare_plot_evidence}}.
#' @param n_sv integer number of singular values to show per layer (default 20)
#' @return a \code{ggplot} object
#'
#' @examples
#' std <- synthetic_control(n = 40L, p = 500L, K = 2L, signal = 30, seed = 1L)
#' std <- prepare_plot_evidence(std, stage = "stage1")
#' plot_spectrum(std)
#'
#' @export
plot_spectrum <- function(std, n_sv = 20L) {
    stopifnot(is(std, "StateTransitionData"))
    if (!is.numeric(n_sv) || length(n_sv) != 1L || !is.finite(n_sv) ||
        n_sv != as.integer(n_sv) || n_sv < 1L) {
        .stop_landscapeR_validation(
            "plot_spectrum(): n_sv must be a positive integer"
        )
    }
    view <- .stage_visual_evidence(std, "stage1")
    if (identical(visual_evidence_state(view), "missing")) {
        return(.render_unavailable_visual_evidence(view))
    }
    spectrum <- visual_evidence_display(view, "spectrum")
    n <- spectrum$n
    p <- spectrum$p
    bbp <- spectrum$bbp
    df <- spectrum$values[
        spectrum$values$rank <= as.integer(n_sv),
        ,
        drop = FALSE
    ]

    plot <- ggplot2::ggplot(
        df,
        ggplot2::aes(x = rank, y = sv, colour = layer, group = layer)
    ) +
        ggplot2::geom_line(linewidth = 0.8) +
        ggplot2::geom_point(size = 1.5) +
        ggplot2::geom_hline(yintercept = bbp, linetype = "dashed",
                             colour = .landscapeR_colour("nuisance"),
                             linewidth = 0.6) +
        ggplot2::annotate("text", x = max(df$rank) * 0.7, y = bbp,
                           label = sprintf("BBP = %.1f", bbp),
                           vjust = -0.5,
                           colour = .landscapeR_colour("nuisance"),
                           size = 3.2) +
        scale_colour_landscapeR("categorical") +
        ggplot2::labs(
            title   = "Singular value spectrum per layer",
            subtitle = sprintf(
                "n = %d, p = %d, %d layers",
                n, p, visual_evidence_display(view, "experiment_count")
            ),
            x       = "Rank",
            y       = "Singular value",
            colour  = "Layer"
        ) +
        theme_landscapeR()

    view <- .stage1_spectrum_surface_view(view, as.integer(n_sv))
    .with_scientific_caption(plot, visual_evidence_caption(view))
}

.stage1_spectrum_surface_view <- function(view, n_sv) {
    context <- visual_evidence_display(view, "caption_context")
    spectrum <- visual_evidence_display(view, "spectrum")
    caption <- .new_scientific_caption_view(
        title = "Singular-value spectra",
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
                "Lines and points show ordered raw-assay singular values ",
                "for layer traces: ",
                paste(
                    .scientific_caption_label(
                        visual_evidence_display(view, "experiment_names")
                    ),
                    collapse = ", "
                )
            ),
            sprintf(
                "The dashed horizontal line marks the BBP reference at %.2f",
                spectrum$bbp
            )
        ),
        estimand = paste0(
            "the raw, uncentred assay singular-value spectrum of each ",
            "molecular layer"
        ),
        threshold = paste0(
            "The BBP line uses (n x p)^(1/4) from the first layer under a ",
            "spiked white-noise model; it is a model-based detectability ",
            "reference, not empirical proof"
        ),
        uncertainty = if (identical(visual_evidence_state(view), "partial")) {
            "The stored Stage 1 display evidence is incomplete; available spectrum values are shown"
        } else {
            NA_character_
        },
        claim_boundary = paste0(
            "Position relative to this reference does not establish recovery ",
            "or biological validity of an axis"
        ),
        state = .visual_evidence_surface_state(view)
    )
    .replace_visual_evidence_caption(
        view,
        caption,
        display_data = list(
            surface_request = list(plot = "spectrum", n_sv = n_sv)
        )
    )
}

# ---------------------------------------------------------------------------
# plot_decomposition(): sample biplot on the Stage 1 state-transition axis
# ---------------------------------------------------------------------------

#' Plot sample coordinates on the recovered state-transition axis (Stage 1 output)
#'
#' Shows each layer's sample coordinates along the shared state-transition axis
#' recovered by Stage 1.  When the object carries a \code{SubspaceGroundTruth}
#' (synthetic data), the angle between the recovered axis and the true axis is
#' annotated.
#'
#' This is a descriptive display. It neither selects a component nor confirms
#' biological separation.
#'
#' @param std \code{StateTransitionData} with \code{metadata()$stage1} present
#' @param colour_by character column name in \code{colData(std)} to colour
#'   samples by, or \code{NULL} for unlabelled points (default \code{NULL}).
#'   Categorical fields additionally encode shape (up to 8 observed levels);
#'   continuous fields additionally encode point size.
#' @param component integer -- which component column to plot from each layer's
#'   coordinate matrix (default \code{1L}). Use \code{plot_components()} to
#'   inspect descriptive distributions; scientific selection requires the
#'   atlas/proposal and confirmation workflow.
#' @return a \code{ggplot} object
#'
#' @examples
#' std <- synthetic_control(n = 40L, p = 500L, K = 2L, signal = 30, seed = 1L)
#' ctor <- get_strategy("Decomposer", "hogsvd_averaged")
#' std2 <- suppressWarnings(decompose(ctor(), std))@value
#' plot_decomposition(std2)
#'
#' @export
plot_decomposition <- function(std, colour_by = NULL, component = 1L) {
    stopifnot(is(std, "StateTransitionData"))
    view <- .stage_visual_evidence(
        std, "stage1", colour_by = colour_by, caller = "plot_decomposition"
    )
    if (identical(visual_evidence_state(view), "missing")) {
        return(.render_unavailable_visual_evidence(view))
    }
    displays <- .visual_evidence_displays(view)
    if (is.null(displays$decomposition)) {
        return(.render_unavailable_visual_evidence(
            .stage_unavailable_visual_evidence(
                "stage1",
                paste0(
                    "Stage 1 decomposition evidence is unavailable; run ",
                    "decompose() before plotting decomposition coordinates"
                )
            )
        ))
    }
    decomposition <- displays$decomposition
    coordinates <- decomposition$coordinates
    layer_nms <- unique(coordinates$layer)
    n_layers <- length(layer_nms)
    if (!is.numeric(component) || length(component) != 1L ||
        !is.finite(component) || component != as.integer(component) ||
        component < 1L) {
        .stop_landscapeR_validation(
            "plot_decomposition(): component must be a positive integer"
        )
    }
    comp_idx <- as.integer(component)

    # Effective component index: clip to minimum k across all layers and warn once.
    k_min <- min(vapply(layer_nms, function(layer_name) {
        max(coordinates$component[coordinates$layer == layer_name])
    }, integer(1L)))
    plot_idx <- min(comp_idx, k_min)
    if (comp_idx > k_min)
        warning(paste0("component ", comp_idx, " requested but only ",
                       k_min, " available; plotting component ", k_min))

    df <- coordinates[
        coordinates$component == plot_idx,
        ,
        drop = FALSE
    ]
    rows <- lapply(seq_len(n_layers), function(i) {
        layer_df <- df[df$layer == layer_nms[i], , drop = FALSE]
        if (!is.null(colour_by)) {
            experiment_index <- match(
                layer_nms[[i]],
                displays$experiment_names
            )
            if (is.na(experiment_index)) {
                .stop_plot_evidence_unavailable(sprintf(
                    "Stored Stage 1 coordinates reference unknown layer '%s'",
                    layer_nms[[i]]
                ))
            }
            layer_df[[colour_by]] <-
                displays$aligned_metadata[[layer_nms[[i]]]]
        }
        layer_df
    })
    df <- do.call(rbind, rows)

    angle_label <- NULL
    angle_row <- decomposition$truth_angles[
        decomposition$truth_angles$component == plot_idx,
        ,
        drop = FALSE
    ]
    if (nrow(angle_row)) {
        angle_label <- sprintf(
            "Stored ground-truth angle for component %d: %.1f\u00b0",
            plot_idx,
            angle_row$angle_degrees[[1L]]
        )
    }

    palette <- landscapeR_palette("semantic")
    p <- ggplot2::ggplot(
        df,
        ggplot2::aes(x = sample_ord, y = coord)
    ) +
        ggplot2::geom_hline(
            yintercept = 0,
            linetype = "dotted",
            colour = .landscapeR_colour("nuisance")
        ) +
        ggplot2::facet_wrap(
            ~ layer,
            scales = "free_x",
            labeller = ggplot2::as_labeller(.scientific_caption_label)
        ) +
        ggplot2::labs(
            title    = sprintf(
                "Component %d scores by molecular layer", plot_idx
            ),
            subtitle = if (!is.null(angle_label)) angle_label else
                "Layers show rank-ordered sample coordinates",
            x        = "Sample (rank-ordered by coordinate)",
            y        = sprintf("Component %d coordinate", plot_idx),
            colour   = if (!is.null(colour_by)) {
                .scientific_caption_label(colour_by)
            } else {
                NULL
            }
        ) +
        theme_landscapeR() +
        ggplot2::theme(
            legend.position = "bottom",
            legend.box = "vertical"
        )

    if (is.null(colour_by)) {
        p <- p + ggplot2::geom_point(size = 2, alpha = 0.75)
    } else {
        observed <- df[!is.na(df[[colour_by]]), , drop = FALSE]
        meta_col <- df[[colour_by]]
        if (is.numeric(meta_col)) {
            p <- p + ggplot2::geom_point(
                data = observed,
                ggplot2::aes(
                    colour = .data[[colour_by]],
                    size = .data[[colour_by]]
                ),
                shape = 16, alpha = 0.75
            ) + ggplot2::scale_size_continuous(
                range = c(1.4, 2.8),
            name = paste0(
                .scientific_caption_label(colour_by), " (point size)"
            )
            )
        } else {
            p <- p + ggplot2::geom_point(
                data = observed,
                ggplot2::aes(
                    colour = .data[[colour_by]],
                    shape = .data[[colour_by]]
                ),
                size = 2, alpha = 0.75
            ) + ggplot2::scale_shape_manual(
                values = .metadata_shape_values(meta_col),
            name = paste0(
                .scientific_caption_label(colour_by), " (shape)"
            )
            )
        }
        p <- p + scale_colour_landscapeR(
            if (is.numeric(meta_col)) "continuous" else "categorical",
            name = .scientific_caption_label(colour_by)
        )
        missing <- df[is.na(meta_col), , drop = FALSE]
        if (nrow(missing)) {
            p <- p + ggplot2::geom_point(
                data = missing, shape = 4,
                colour = unname(palette[["ink"]]),
                size = 2.4, stroke = 0.7
            )
        }
    }
    view <- .stage1_decomposition_surface_view(
        view, plot_idx, colour_by
    )
    .with_scientific_caption(p, visual_evidence_caption(view))
}

.stage1_decomposition_surface_view <- function(view, plot_idx, colour_by) {
    displays <- .visual_evidence_displays(view)
    decomposition <- displays$decomposition
    df <- decomposition$coordinates[
        decomposition$coordinates$component == plot_idx,
        ,
        drop = FALSE
    ]
    meta_col <- NULL
    if (!is.null(colour_by)) {
        rows <- lapply(unique(df$layer), function(layer_name) {
            layer_df <- df[df$layer == layer_name, , drop = FALSE]
            layer_df[[colour_by]] <- displays$aligned_metadata[[layer_name]]
            layer_df
        })
        df <- do.call(rbind, rows)
        meta_col <- df[[colour_by]]
    }
    angle_row <- decomposition$truth_angles[
        decomposition$truth_angles$component == plot_idx,
        ,
        drop = FALSE
    ]
    context <- displays$caption_context
    encodings <- c(
        paste0(
            "Facets identify molecular layers; points show component ", plot_idx,
            " sample coordinates rank-ordered within each layer; the dotted horizontal line marks zero"
        ),
        .plot_metadata_encoding(
            meta_col, colour_by,
            if (is.numeric(meta_col)) {
                "Point colours and point sizes"
            } else {
                "Point colours and point shapes"
            }
        )
    )
    if (nrow(angle_row)) {
        encodings <- c(
            encodings,
            paste0(
                "The subtitle reports the stored synthetic ground-truth angle for component ",
                plot_idx
            )
        )
    }
    caption <- .new_scientific_caption_view(
        title = "Stage 1 decomposition coordinates",
        experiment_label = context$experiment_label,
        molecular_layer = context$molecular_layer,
        molecular_layer_count = context$molecular_layer_count,
        sampling_unit = context$sampling_unit,
        design = context$design,
        time_field = context$time_field,
        time_unit = context$time_unit,
        subject_field = context$subject_field,
        encodings = encodings,
        estimand = paste0(
            "the descriptive sample coordinate on component ", plot_idx
        ),
        missingness = if (!is.null(meta_col) && anyNA(meta_col)) {
            sprintf(
                "Crosses mark %d observations with missing %s",
                sum(is.na(meta_col)), .scientific_caption_label(colour_by)
            )
        } else {
            NULL
        },
        uncertainty = if (identical(visual_evidence_state(view), "partial")) {
            "The stored Stage 1 display evidence is incomplete; available sample coordinates are shown"
        } else {
            NA_character_
        },
        threshold = "No component-selection threshold is applied",
        claim_boundary = paste0(
            "This display does not select a component or establish biological ",
            "interpretation"
        ),
        state = .visual_evidence_surface_state(view)
    )
    .replace_visual_evidence_caption(
        view,
        caption,
        display_data = list(
            surface_request = list(
                plot = "decomposition",
                component = plot_idx,
                colour_by = colour_by
            )
        )
    )
}
