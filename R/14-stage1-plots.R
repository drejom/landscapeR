# Stage 1 diagnostic plot functions for StateTransitionData

utils::globalVariables(c("coord", "sample_ord", ".data", "x", "sv", "layer"))
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
        "Components shown in decomposition order; add colour_by to overlay metadata"
    } else if (is.numeric(meta_col)) {
        sprintf(
            "Components shown in decomposition order; continuous %s colours the rug",
            colour_by
        )
    } else {
        sprintf(
            "Components shown in decomposition order; %s groups densities and rugs",
            colour_by
        )
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
        p <- p +
            ggplot2::geom_density(
                fill = "grey85", colour = "grey35", alpha = 0.55,
                linewidth = 0.5
            ) +
            ggplot2::geom_rug(
                ggplot2::aes(colour = .data[["metadata_value"]]),
                alpha = 0.75,
                sides = "b"
            ) +
            ggplot2::scale_colour_viridis_c(na.value = "grey70")
    } else {
        p <- ggplot2::ggplot(
            df,
            ggplot2::aes(
                x = coord,
                fill = .data[["metadata_value"]],
                colour = .data[["metadata_value"]]
            )
        ) +
            ggplot2::geom_density(alpha = 0.35, linewidth = 0.5) +
            ggplot2::geom_rug(alpha = 0.55, sides = "b") +
            ggplot2::scale_fill_viridis_d(na.value = "grey70") +
            ggplot2::scale_colour_viridis_d(na.value = "grey70")
    }

    p +
        ggplot2::geom_vline(
            xintercept = 0, linetype = "dotted",
            colour = "grey60", linewidth = 0.4
        ) +
        ggplot2::facet_wrap(~ component, scales = "free") +
        ggplot2::labs(
            title = sprintf("Stage 1 component gallery \u2014 layer %d", idx),
            subtitle = subtitle,
            x = "Coordinate",
            y = "Density",
            fill = colour_by,
            colour = colour_by
        ) +
        ggplot2::theme_bw(base_size = 10) +
        ggplot2::theme(legend.position = "bottom")
}

.component_gallery_metadata <- function(std, layer, colour_by) {
    if (is.null(colour_by)) return(NULL)
    if (!is.character(colour_by) || length(colour_by) != 1L ||
        is.na(colour_by) || !nzchar(colour_by)) {
        .stop_landscapeR_validation(
            "plot_components(): colour_by must be NULL or one non-empty column name"
        )
    }

    cd_s4 <- colData(std)
    field_idx <- which(names(cd_s4) == colour_by)
    if (!length(field_idx)) {
        .stop_landscapeR_validation(sprintf(
            "plot_components(): colour_by '%s' was not found in MAE-level colData",
            colour_by
        ))
    }
    if (length(field_idx) > 1L) {
        .stop_landscapeR_validation(sprintf(
            "plot_components(): colour_by '%s' is ambiguous in MAE-level colData",
            colour_by
        ))
    }
    cd <- as.data.frame(cd_s4)

    expt_list <- as.list(experiments(std))
    layer_name <- names(expt_list)[[layer]]
    assay_samples <- colnames(expt_list[[layer]])
    sm <- as.data.frame(sampleMap(std), stringsAsFactors = FALSE)
    layer_map <- sm[as.character(sm$assay) == layer_name, , drop = FALSE]
    mapped_samples <- as.character(layer_map$colname)
    map_idx <- match(assay_samples, mapped_samples)
    if (anyNA(map_idx)) {
        .stop_landscapeR_validation(sprintf(
            paste0(
                "plot_components(): missing canonical sample mapping for layer ",
                "'%s' observation '%s'"
            ),
            layer_name,
            assay_samples[[which(is.na(map_idx))[[1L]]]]
        ))
    }
    duplicate_samples <- unique(mapped_samples[duplicated(mapped_samples)])
    ambiguous <- assay_samples %in% duplicate_samples
    if (any(ambiguous)) {
        .stop_landscapeR_validation(sprintf(
            paste0(
                "plot_components(): ambiguous canonical sample mapping for layer ",
                "'%s' observation '%s'"
            ),
            layer_name,
            assay_samples[[which(ambiguous)[[1L]]]]
        ))
    }

    primary <- as.character(layer_map$primary[map_idx])
    primary_rows <- rownames(cd)
    if (anyDuplicated(primary_rows) > 0L) {
        .stop_landscapeR_validation(
            "plot_components(): MAE-level colData has ambiguous primary sample IDs"
        )
    }
    cd_idx <- match(primary, primary_rows)
    if (anyNA(cd_idx)) {
        .stop_landscapeR_validation(sprintf(
            "plot_components(): MAE-level colData is missing primary sample '%s'",
            primary[[which(is.na(cd_idx))[[1L]]]]
        ))
    }
    cd[[field_idx]][cd_idx]
}

# ---------------------------------------------------------------------------
# plot_spectrum(): singular value spectrum per layer + BBP threshold
# ---------------------------------------------------------------------------

#' Plot singular value spectra with the BBP detectability threshold
#'
#' Shows the top singular values for each omic layer as a line plot, with a
#' horizontal reference line at the Baik-Ben Arous-Peche (BBP) phase-transition
#' threshold \eqn{(n \cdot p)^{1/4}}.  Signal components above the threshold
#' are detectable; those below are indistinguishable from noise.
#'
#' Call this before running Stage 1 to confirm that the state-transition axis is
#' detectable at the current sample size.
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

    ggplot2::ggplot(df, ggplot2::aes(x = rank, y = sv,
                                      colour = layer, group = layer)) +
        ggplot2::geom_line(linewidth = 0.8) +
        ggplot2::geom_point(size = 1.5) +
        ggplot2::geom_hline(yintercept = bbp, linetype = "dashed",
                             colour = "grey40", linewidth = 0.6) +
        ggplot2::annotate("text", x = n_sv * 0.7, y = bbp,
                           label = sprintf("BBP = %.1f", bbp),
                           vjust = -0.5, colour = "grey40", size = 3.2) +
        ggplot2::scale_colour_brewer(palette = "Dark2") +
        ggplot2::labs(
            title   = "Singular value spectrum per layer",
            subtitle = sprintf("n = %d, p = %d, %d layers", n, p, length(expt_list)),
            x       = "Rank",
            y       = "Singular value",
            colour  = "Layer"
        ) +
        ggplot2::theme_bw(base_size = 11)
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
#' Call this after running Stage 1 to confirm that disease-group separation
#' was recovered before feeding coordinates into Stage 2.
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

    # Per-experiment colData (correct sample count per layer)
    expt_list <- as.list(experiments(std))

    # Effective component index: clip to minimum k across all layers and warn once.
    k_min    <- min(vapply(dr_coords_k(s1), ncol, integer(1L)))
    plot_idx <- min(comp_idx, k_min)
    if (comp_idx > k_min)
        warning(paste0("component ", comp_idx, " requested but only ",
                       k_min, " available; plotting component ", k_min))

    rows <- lapply(seq_len(n_layers), function(i) {
        cmat    <- dr_coords_k(s1)[[i]]
        k_avail <- ncol(cmat)
        j       <- min(comp_idx, k_avail)
        coord   <- cmat[, j]
        # Use per-experiment colData so row count matches coord length
        cd_i <- as.data.frame(colData(expt_list[[i]]))
        df <- data.frame(
            sample = seq_along(coord),
            layer  = layer_nms[i],
            coord  = coord,
            stringsAsFactors = FALSE
        )
        if (!is.null(colour_by) && colour_by %in% colnames(cd_i))
            df[[colour_by]] <- cd_i[[colour_by]]
        df
    })
    df <- do.call(rbind, rows)

    # Subspace angle annotation (synthetic data only)
    angle_label <- NULL
    if (!is.null(std@ground_truth) &&
        is(std@ground_truth, "SubspaceGroundTruth")) {
        gt_ncol <- ncol(std@ground_truth@shared)
        gt_j    <- min(comp_idx, gt_ncol)
        v_true  <- std@ground_truth@shared[, gt_j, drop = TRUE]
        v_hat   <- shared_axis(s1, j = comp_idx)
        cos_a   <- min(1, abs(sum(v_true * v_hat) /
                              (sqrt(sum(v_true^2)) * sqrt(sum(v_hat^2)))))
        angle_label <- sprintf("component %d angle to v_true = %.1f\u00b0",
                               comp_idx, acos(cos_a) * 180 / pi)
    }

    # x-axis: sample index (rank-ordered within each layer for readability)
    df$sample_ord <- ave(df$coord, df$layer,
                         FUN = function(x) rank(x, ties.method = "first"))

    aes_base <- if (!is.null(colour_by) && colour_by %in% colnames(df))
        ggplot2::aes(x = sample_ord, y = coord, colour = .data[[colour_by]])
    else
        ggplot2::aes(x = sample_ord, y = coord)

    p <- ggplot2::ggplot(df, aes_base) +
        ggplot2::geom_point(size = 2, alpha = 0.75) +
        ggplot2::geom_hline(yintercept = 0, linetype = "dotted", colour = "grey60") +
        ggplot2::facet_wrap(~ layer, scales = "free_x") +
        ggplot2::labs(
            title    = sprintf("Sample coordinates on component %d", plot_idx),
            subtitle = if (!is.null(angle_label)) angle_label else
                       "Supply synthetic_control() output to annotate ground-truth angle",
            x        = "Sample (rank-ordered by coordinate)",
            y        = sprintf("Component %d coordinate", plot_idx),
            colour   = colour_by
        ) +
        ggplot2::theme_bw(base_size = 11) +
        ggplot2::theme(legend.position = "bottom")

    if (!is.null(colour_by) && colour_by %in% colnames(df))
        p <- p + ggplot2::scale_colour_brewer(palette = "Set1", na.value = "grey70")

    p
}
