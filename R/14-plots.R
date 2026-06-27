# Diagnostic plot functions for StateTransitionData
#
# All functions take a StateTransitionData object and return a ggplot.
# colour_by is always optional — omit it for unlabelled exploratory plots,
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

# ---------------------------------------------------------------------------
# plot_spectrum(): singular value spectrum per layer + BBP threshold
# ---------------------------------------------------------------------------

#' Plot singular value spectra with the BBP detectability threshold
#'
#' Shows the top singular values for each omic layer as a line plot, with a
#' horizontal reference line at the Baik-Ben Arous-Péché (BBP) phase-transition
#' threshold \eqn{(n \cdot p)^{1/4}}.  Signal components above the threshold
#' are detectable; those below are indistinguishable from noise.
#'
#' Call this before running Stage 1 to confirm that the disease axis is
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
# plot_decomposition(): sample biplot on the Stage 1 disease axis
# ---------------------------------------------------------------------------

#' Plot sample coordinates on the recovered disease axis (Stage 1 output)
#'
#' Shows each layer's sample coordinates along the shared disease axis
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
#' @return a \code{ggplot} object
#'
#' @examples
#' std <- synthetic_control(n = 40L, p = 500L, K = 2L, signal = 30, seed = 1L)
#' ctor <- get_strategy("Decomposer", "hogsvd_averaged")
#' std2 <- suppressWarnings(decompose(ctor(), std))@value
#' plot_decomposition(std2)
#'
#' @export
plot_decomposition <- function(std, colour_by = NULL) {
    stopifnot(is(std, "StateTransitionData"))
    s1 <- metadata(std)$stage1
    if (is.null(s1))
        stop("Stage 1 has not been run on this object. Call decompose() first.")

    n_layers <- length(s1$coords)
    layer_nms <- names(experiments(std))

    # Build a long data frame: one row per sample per layer
    cd <- as.data.frame(colData(std))

    rows <- lapply(seq_len(n_layers), function(i) {
        coord <- s1$coords[[i]]
        df <- data.frame(
            sample = seq_along(coord),
            layer  = layer_nms[i],
            coord  = coord,
            stringsAsFactors = FALSE
        )
        if (!is.null(colour_by) && colour_by %in% colnames(cd))
            df[[colour_by]] <- cd[[colour_by]]
        df
    })
    df <- do.call(rbind, rows)

    # Subspace angle annotation (synthetic data only)
    angle_label <- NULL
    if (!is.null(std@ground_truth) &&
        is(std@ground_truth, "SubspaceGroundTruth")) {
        v_true <- std@ground_truth@shared[, 1L]
        v_hat  <- s1$V_star
        cos_a  <- min(1, abs(sum(v_true * v_hat) /
                             (sqrt(sum(v_true^2)) * sqrt(sum(v_hat^2)))))
        angle_label <- sprintf("angle to v_true = %.1f°", acos(cos_a) * 180 / pi)
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
            title    = "Sample coordinates on the shared disease axis",
            subtitle = if (!is.null(angle_label)) angle_label else
                       "Supply synthetic_control() output to annotate ground-truth angle",
            x        = "Sample (rank-ordered by coordinate)",
            y        = "Disease-axis coordinate",
            colour   = colour_by
        ) +
        ggplot2::theme_bw(base_size = 11) +
        ggplot2::theme(legend.position = "bottom")

    if (!is.null(colour_by) && colour_by %in% colnames(df))
        p <- p + ggplot2::scale_colour_brewer(palette = "Set1", na.value = "grey70")

    p
}

# ---------------------------------------------------------------------------
# plot_potential(): Stage 2 quasi-potential curve
# ---------------------------------------------------------------------------

#' Plot the quasi-potential landscape (Stage 2 output)
#'
#' Shows U(x) = -log p(x) along the disease axis, with stable critical points
#' (wells) marked as triangles and unstable critical points (barriers) as
#' inverted triangles.  Barrier heights are annotated.
#'
#' @param std \code{StateTransitionData} with \code{metadata()$stage2} present
#' @param colour_by character column name in \code{colData(std)} to colour
#'   the rug of sample positions, or \code{NULL} (default \code{NULL})
#' @return a \code{ggplot} object
#'
#' @examples
#' \dontrun{
#' # Requires Stage 2 to have been run
#' plot_potential(std_with_stage2)
#' }
#'
#' @export
plot_potential <- function(std, colour_by = NULL) {
    stopifnot(is(std, "StateTransitionData"))
    s2 <- metadata(std)$stage2
    if (is.null(s2))
        stop("Stage 2 has not been run on this object. Call estimate_dynamics() first.")

    # Expected stage2 structure (set by the DynamicsEstimator contract):
    #   s2$x         numeric vector — disease-axis grid
    #   s2$U         numeric vector — quasi-potential values on grid
    #   s2$wells     numeric vector — x positions of stable critical points
    #   s2$barriers  numeric vector — x positions of unstable critical points
    required <- c("x", "U", "wells", "barriers")
    missing_fields <- setdiff(required, names(s2))
    if (length(missing_fields))
        stop(sprintf("metadata()$stage2 is missing: %s",
                     paste(missing_fields, collapse = ", ")))

    curve_df <- data.frame(x = s2$x, U = s2$U)

    # Critical-point annotations
    cp_df <- rbind(
        data.frame(x = s2$wells,    U = approx(s2$x, s2$U, s2$wells)$y,
                   type = "well",    stringsAsFactors = FALSE),
        data.frame(x = s2$barriers, U = approx(s2$x, s2$U, s2$barriers)$y,
                   type = "barrier", stringsAsFactors = FALSE)
    )

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

    # Sample rug (first layer coordinates if available from stage1)
    rug_aes <- NULL
    s1 <- metadata(std)$stage1
    if (!is.null(s1) && length(s1$coords)) {
        rug_x <- s1$coords[[1L]]
        cd    <- as.data.frame(colData(std))
        rug_df <- data.frame(x = rug_x, stringsAsFactors = FALSE)
        if (!is.null(colour_by) && colour_by %in% colnames(cd))
            rug_df[[colour_by]] <- cd[[colour_by]]
    } else {
        rug_df <- NULL
    }

    p <- ggplot2::ggplot(curve_df, ggplot2::aes(x = x, y = U)) +
        ggplot2::geom_line(linewidth = 1, colour = "#2166AC") +
        ggplot2::geom_point(data = cp_df,
                             ggplot2::aes(shape = type),
                             size = 4, colour = "#D6604D") +
        ggplot2::scale_shape_manual(
            values = c(well = 25, barrier = 24),
            labels = c(well = "Stable (well)", barrier = "Unstable (barrier)")
        ) +
        ggplot2::labs(
            title  = "Quasi-potential landscape  U(x) = −log p(x)",
            x      = "Disease-axis coordinate",
            y      = "U(x)",
            shape  = "Critical point"
        ) +
        ggplot2::theme_bw(base_size = 11) +
        ggplot2::theme(legend.position = "bottom")

    # Barrier-height segments
    if (length(seg_rows)) {
        seg_df <- do.call(rbind, seg_rows)
        p <- p + ggplot2::geom_segment(
            data = seg_df,
            ggplot2::aes(x = x, xend = xend, y = y, yend = yend),
            linetype = "dotted", colour = "#D6604D", linewidth = 0.7,
            inherit.aes = FALSE)
    }

    # Sample rug
    if (!is.null(rug_df)) {
        if (!is.null(colour_by) && colour_by %in% colnames(rug_df)) {
            p <- p +
                ggplot2::geom_rug(
                    data = rug_df,
                    ggplot2::aes(x = x, colour = .data[[colour_by]]),
                    sides = "b", alpha = 0.6, inherit.aes = FALSE) +
                ggplot2::scale_colour_brewer(palette = "Set1",
                                              na.value = "grey70",
                                              name = colour_by)
        } else {
            p <- p +
                ggplot2::geom_rug(
                    data = rug_df,
                    ggplot2::aes(x = x),
                    sides = "b", alpha = 0.4, colour = "grey40",
                    inherit.aes = FALSE)
        }
    }

    p
}
