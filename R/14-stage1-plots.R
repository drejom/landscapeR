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
    paste0(marks, " encode ", type, " ", field)
}
#
# All functions take a StateTransitionData object and return a ggplot.
# colour_by is always optional -- omit it for unlabelled exploratory plots,
# supply a colData column name to colour points by a sample covariate.
#
# Typical interactive use:
#
#   std <- synthetic_control(n=40, p=500, K=2, signal=30, seed=1)
#   plot_spectrum(std)
#   std2 <- decompose(get_strategy("Decomposer","hogsvd_averaged")(), std)@value
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
#' \code{n_components} components as density and rug panels in decomposition
#' order. Metadata are read from MAE-level \code{colData} and aligned to the
#' selected assay through its canonical \code{sampleMap}; row position is never
#' treated as sample identity.
#'
#' Categorical metadata group the descriptive densities and rugs. Continuous
#' metadata colour the rug with a continuous gradient while retaining the
#' overall density. The gallery does not calculate association scores or rank
#' components; those responsibilities belong to the metadata atlas and proposal
#' workflow.
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
    s1 <- metadata(std)$stage1
    if (is.null(s1))
        .stop_landscapeR_validation(
            "Stage 1 has not been run on this object. Call decompose() first."
        )

    coords <- dr_coords_k(s1)
    expt_list <- as.list(experiments(std))
    if (!is.numeric(layer) || length(layer) != 1L || !is.finite(layer) ||
        layer != as.integer(layer) || layer < 1L || layer > length(coords) ||
        layer > length(expt_list)) {
        .stop_landscapeR_validation(sprintf(
            "plot_components(): layer must be an integer from 1 to %d",
            min(length(coords), length(expt_list))
        ))
    }
    idx <- as.integer(layer)
    cmat <- coords[[idx]]
    if (!is.matrix(cmat) || nrow(cmat) != ncol(expt_list[[idx]])) {
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
    k_show <- min(as.integer(n_components), ncol(cmat))
    meta_col <- .component_gallery_metadata(std, idx, colour_by)

    rows <- lapply(seq_len(k_show), function(j) {
        df <- data.frame(
            coord = cmat[, j],
            component = sprintf("PC%d", j),
            stringsAsFactors = FALSE
        )
        if (!is.null(meta_col)) df$metadata_value <- meta_col
        df
    })
    df <- do.call(rbind, rows)
    df$component <- factor(
        df$component,
        levels = sprintf("PC%d", seq_len(k_show))
    )

    subtitle <- if (is.null(meta_col)) {
        "Components shown in decomposition order"
    } else if (is.numeric(meta_col)) {
        sprintf("Decomposition order; rug colour shows %s", colour_by)
    } else {
        sprintf("Decomposition order; colour shows %s", colour_by)
    }

    p <- ggplot2::ggplot(df, ggplot2::aes(x = coord))
    if (is.null(meta_col)) {
        p <- p +
            ggplot2::geom_density(
                fill = "grey80", colour = "grey35", alpha = 0.55,
                linewidth = 0.5
            ) +
            ggplot2::geom_rug(colour = "grey35", alpha = 0.45, sides = "b")
    } else if (is.numeric(meta_col)) {
        observed <- df[!is.na(df$metadata_value), , drop = FALSE]
        missing <- df[is.na(df$metadata_value), , drop = FALSE]
        p <- p +
            ggplot2::geom_density(
                fill = "grey85", colour = "grey35", alpha = 0.55,
                linewidth = 0.5
            ) +
            ggplot2::geom_rug(
                data = observed,
                ggplot2::aes(colour = .data[["metadata_value"]]),
                alpha = 0.75,
                sides = "b"
            ) +
            scale_colour_landscapeR("continuous")
        if (nrow(missing)) {
            p <- p + ggplot2::geom_rug(
                data = missing,
                colour = "#111111",
                linetype = "dashed",
                linewidth = 0.7,
                sides = "b"
            )
        }
    } else {
        observed <- df[!is.na(df$metadata_value), , drop = FALSE]
        missing <- df[is.na(df$metadata_value), , drop = FALSE]
        p <- ggplot2::ggplot(
            observed,
            ggplot2::aes(
                x = coord,
                fill = .data[["metadata_value"]],
                colour = .data[["metadata_value"]]
            )
        ) +
            ggplot2::geom_density(alpha = 0.35, linewidth = 0.5) +
            ggplot2::geom_rug(alpha = 0.55, sides = "b") +
            scale_fill_landscapeR("categorical") +
            scale_colour_landscapeR("categorical")
        if (nrow(missing)) {
            p <- p + ggplot2::geom_rug(
                data = missing,
                ggplot2::aes(x = coord),
                inherit.aes = FALSE,
                colour = "#111111",
                linetype = "dashed",
                linewidth = 0.7,
                sides = "b"
            )
        }
    }

    missingness <- if (!is.null(meta_col) && anyNA(meta_col)) {
        sprintf(
            "Dashed rugs mark %d observations with missing %s",
            sum(is.na(meta_col)),
            colour_by
        )
    } else {
        NULL
    }

    p <- p +
        ggplot2::geom_vline(
            xintercept = 0, linetype = "dotted",
            colour = "grey60", linewidth = 0.4
        ) +
        ggplot2::facet_wrap(~ component, scales = "free") +
        ggplot2::labs(
            title = sprintf(
                "Stage 1 component gallery: %s",
                names(expt_list)[[idx]]
            ),
            subtitle = subtitle,
            x = "Coordinate",
            y = "Density",
            fill = colour_by,
            colour = colour_by
        ) +
        theme_landscapeR() +
        ggplot2::theme(legend.position = "bottom")

    context <- .plot_caption_context(std, idx)
    metadata_marks <- if (is.numeric(meta_col)) {
        "Rug colours"
    } else {
        "Density fills and rug colours"
    }
    view <- .new_scientific_caption_view(
        title = "Stage 1 component distributions",
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
                "Facets show components 1-", k_show,
                " in decomposition order; densities summarize sample-coordinate ",
                "distributions; rugs mark sample coordinates; dotted vertical ",
                "lines mark zero"
            ),
            .plot_metadata_encoding(
                meta_col, colour_by, metadata_marks
            )
        ),
        estimand = "the descriptive distribution of sample coordinates",
        missingness = missingness,
        threshold = "No component-selection threshold is applied",
        claim_boundary = paste0(
            "This descriptive gallery does not rank or nominate a biological ",
            "coordinate"
        ),
        state = "uncalibrated"
    )
    .with_scientific_caption(p, .build_scientific_caption(view))
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
#' Shows the top singular values for each omic layer as a line plot, with a
#' horizontal reference line at the Baik-Ben Arous-Peche (BBP) phase-transition
#' value \eqn{(n \cdot p)^{1/4}} computed from the first layer. This is a
#' model-based visual reference under spiked white-noise assumptions, not
#' empirical proof that a component is recoverable or biologically valid.
#'
#' Use the returned scientific caption to report the assumptions and claim
#' boundary alongside the figure.
#'
#' @param std \code{StateTransitionData}
#' @param n_sv integer number of singular values to show per layer (default 20)
#' @return a \code{ggplot} object
#'
#' @examples
#' std <- synthetic_control(n = 40L, p = 500L, K = 2L, signal = 30, seed = 1L)
#' plot_spectrum(std)
#'
#' @export
plot_spectrum <- function(std, n_sv = 20L) {
    stopifnot(is(std, "StateTransitionData"))
    expt_list <- as.list(experiments(std))
    n <- ncol(expt_list[[1L]])
    p <- nrow(expt_list[[1L]])
    bbp <- (as.numeric(n) * as.numeric(p))^0.25

    rows <- lapply(seq_along(expt_list), function(i) {
        X  <- t(assay(expt_list[[i]]))          # n x p
        sv <- svd(X, nu = 0L, nv = 0L)$d
        k  <- min(n_sv, length(sv))
        data.frame(
            layer = names(expt_list)[i],
            rank  = seq_len(k),
            sv    = sv[seq_len(k)],
            stringsAsFactors = FALSE
        )
    })
    df <- do.call(rbind, rows)

    plot <- ggplot2::ggplot(
        df,
        ggplot2::aes(x = rank, y = sv, colour = layer, group = layer)
    ) +
        ggplot2::geom_line(linewidth = 0.8) +
        ggplot2::geom_point(size = 1.5) +
        ggplot2::geom_hline(yintercept = bbp, linetype = "dashed",
                             colour = "grey40", linewidth = 0.6) +
        ggplot2::annotate("text", x = n_sv * 0.7, y = bbp,
                           label = sprintf("BBP = %.1f", bbp),
                           vjust = -0.5, colour = "grey40", size = 3.2) +
        scale_colour_landscapeR("categorical") +
        ggplot2::labs(
            title   = "Singular value spectrum per layer",
            subtitle = sprintf("n = %d, p = %d, %d layers", n, p, length(expt_list)),
            x       = "Rank",
            y       = "Singular value",
            colour  = "Layer"
        ) +
        theme_landscapeR()

    context <- .plot_caption_context(std)
    view <- .new_scientific_caption_view(
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
                "Lines and points show ordered singular values for layer traces: ",
                paste(names(expt_list), collapse = ", ")
            ),
            sprintf(
                "The dashed horizontal line marks the BBP reference at %.2f",
                bbp
            )
        ),
        estimand = "the singular-value spectrum of each molecular layer",
        threshold = paste0(
            "The BBP line uses (n x p)^(1/4) from the first layer under a ",
            "spiked white-noise model; it is a model-based detectability ",
            "reference, not empirical proof"
        ),
        claim_boundary = paste0(
            "Position relative to this reference does not establish recovery ",
            "or biological validity of an axis"
        ),
        state = "uncalibrated"
    )
    .with_scientific_caption(plot, .build_scientific_caption(view))
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
#'   samples by, or \code{NULL} for unlabelled points (default \code{NULL})
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
    s1 <- metadata(std)$stage1
    if (is.null(s1))
        stop("Stage 1 has not been run on this object. Call decompose() first.")

    comp_idx  <- as.integer(component)
    n_layers  <- length(dr_coords_k(s1))
    layer_nms <- names(experiments(std))

    # Effective component index: clip to minimum k across all layers and warn once.
    k_min    <- min(vapply(dr_coords_k(s1), ncol, integer(1L)))
    plot_idx <- min(comp_idx, k_min)
    if (comp_idx > k_min)
        warning(paste0("component ", comp_idx, " requested but only ",
                       k_min, " available; plotting component ", k_min))

    rows <- lapply(seq_len(n_layers), function(i) {
        cmat    <- dr_coords_k(s1)[[i]]
        coord   <- cmat[, plot_idx]
        df <- data.frame(
            sample = seq_along(coord),
            layer  = layer_nms[i],
            coord  = coord,
            stringsAsFactors = FALSE
        )
        if (!is.null(colour_by)) {
            df[[colour_by]] <- .component_gallery_metadata(
                std,
                i,
                colour_by,
                caller = "plot_decomposition"
            )
        }
        df
    })
    df <- do.call(rbind, rows)

    # Subspace angle annotation (synthetic data only)
    angle_label <- NULL
    if (!is.null(std@ground_truth) &&
        is(std@ground_truth, "SubspaceGroundTruth") &&
        plot_idx <= ncol(std@ground_truth@shared)) {
        v_true  <- std@ground_truth@shared[, plot_idx, drop = TRUE]
        v_hat   <- shared_axis(s1, j = plot_idx)
        cos_a   <- min(1, abs(sum(v_true * v_hat) /
                              (sqrt(sum(v_true^2)) * sqrt(sum(v_hat^2)))))
        angle_label <- sprintf(
            "Stored ground-truth angle for component %d: %.1f\u00b0",
            plot_idx,
            acos(cos_a) * 180 / pi
        )
    }

    # x-axis: sample index (rank-ordered within each layer for readability)
    df$sample_ord <- ave(df$coord, df$layer,
                         FUN = function(x) rank(x, ties.method = "first"))

    palette <- landscapeR_palette("semantic")
    p <- ggplot2::ggplot(
        df,
        ggplot2::aes(x = sample_ord, y = coord)
    ) +
        ggplot2::geom_hline(yintercept = 0, linetype = "dotted", colour = "grey60") +
        ggplot2::facet_wrap(~ layer, scales = "free_x") +
        ggplot2::labs(
            title    = sprintf("Sample coordinates on component %d", plot_idx),
            subtitle = if (!is.null(angle_label)) angle_label else
                "Layers show rank-ordered sample coordinates",
            x        = "Sample (rank-ordered by coordinate)",
            y        = sprintf("Component %d coordinate", plot_idx),
            colour   = colour_by
        ) +
        theme_landscapeR() +
        ggplot2::theme(legend.position = "bottom")

    missingness <- NULL
    if (is.null(colour_by)) {
        p <- p + ggplot2::geom_point(size = 2, alpha = 0.75)
        meta_col <- NULL
    } else {
        p <- p +
            ggplot2::geom_point(
                data = df[!is.na(df[[colour_by]]), , drop = FALSE],
                ggplot2::aes(colour = .data[[colour_by]]),
                size = 2, alpha = 0.75
            )
        meta_col <- df[[colour_by]]
        p <- p + scale_colour_landscapeR(
            if (is.numeric(meta_col)) "continuous" else "categorical",
            name = colour_by
        )
        missing <- df[is.na(meta_col), , drop = FALSE]
        if (nrow(missing)) {
            p <- p + ggplot2::geom_point(
                data = missing, shape = 4,
                colour = unname(palette[["ink"]]),
                size = 2.4, stroke = 0.7
            )
            missingness <- sprintf(
                "Crosses mark %d observations with missing %s",
                nrow(missing), colour_by
            )
        }
    }

    context <- .plot_caption_context(std)
    encodings <- c(
        paste0(
            "Facets identify molecular layers; points show component ", plot_idx,
            " sample coordinates rank-ordered within each layer; the dotted ",
            "horizontal line marks zero"
        ),
        .plot_metadata_encoding(meta_col, colour_by, "Point colours")
    )
    if (!is.null(angle_label)) {
        encodings <- c(
            encodings,
            paste0(
                "The subtitle reports the stored synthetic ground-truth angle ",
                "for component ", plot_idx
            )
        )
    }
    view <- .new_scientific_caption_view(
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
        missingness = missingness,
        threshold = "No component-selection threshold is applied",
        claim_boundary = paste0(
            "This display does not select a component or establish biological ",
            "interpretation"
        ),
        state = "uncalibrated"
    )
    .with_scientific_caption(p, .build_scientific_caption(view))
}
