# Diagnostic plot functions for StateTransitionData

utils::globalVariables(c("coord", "sample_ord", ".data", "x", "U", "type",
                          "xend", "y", "yend", "sv", "layer"))
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
# Component plots workflow (typical for real data):
#
#   std2 <- decompose(get_strategy("Decomposer","hogsvd_averaged")(), std)@value
#   plot_components(std2, colour_by = "condition")   # inspect component plots
#   # decide component 2 is the state-transition axis, pass to Stage 2:
#   dyn <- estimate_dynamics(get_strategy("DynamicsEstimator","kde_logdensity")(),
#                             std2, component = 2L)

# ---------------------------------------------------------------------------
# plot_components(): component plots of k Stage 1 components with separation scores
# ---------------------------------------------------------------------------

#' Component plots: all Stage 1 components coloured by a metadata variable
#'
#' Shows the sample coordinate distribution for each of the top \code{n_components}
#' components as a panel of ridge/violin plots.  Each panel is labelled with an
#' eta-squared separation score for categorical \code{colour_by}
#' variables, or |r| for continuous ones.  Panels are sorted
#' highest-score-first so the most informative component is top-left.
#'
#' Use this immediately after Stage 1 to decide which component feeds into
#' Stage 2.  The paper-reported state-transition axis is not always component 1:
#' in Rockne2020 it is PC2 (age dominates PC1).
#'
#' @param std \code{StateTransitionData} with \code{metadata()$stage1} present
#' @param colour_by character -- colData column name to separate samples by.
#'   Can be categorical (eta-squared reported) or continuous (|r| reported).
#' @param n_components integer number of components to show (default 6)
#' @param layer integer -- which layer's coordinates to use (default 1)
#' @return a \code{ggplot} object (facet_wrap over components)
#'
#' @examples
#' std <- synthetic_control(n = 40L, p = 500L, K = 2L, signal = 30, seed = 1L)
#' ctor <- get_strategy("Decomposer", "hogsvd_averaged")
#' std2 <- suppressWarnings(decompose(ctor(), std))@value
#' plot_components(std2, colour_by = "group")
#'
#' @export
plot_components <- function(std, colour_by = NULL, n_components = 6L, layer = 1L) {
    stopifnot(is(std, "StateTransitionData"))
    s1 <- metadata(std)$stage1
    if (is.null(s1))
        stop("Stage 1 has not been run on this object. Call decompose() first.")

    idx     <- min(as.integer(layer), length(dr_coords_k(s1)))
    cmat    <- dr_coords_k(s1)[[idx]]
    k_avail <- ncol(cmat)

    k_show   <- min(as.integer(n_components), k_avail)
    expt_list <- as.list(experiments(std))
    cd        <- as.data.frame(colData(expt_list[[idx]]))
    meta_col  <- if (!is.null(colour_by) && colour_by %in% colnames(cd))
        cd[[colour_by]] else NULL

    # Bimodality coefficient (Freeman & Dale 2013)
    # BC = (skew^2 + 1) / (excess_kurtosis + 3*(n-1)^2/((n-2)*(n-3)))
    # BC > 0.555 suggests bimodality; used as primary sort key.
    .bc <- function(x) {
        n  <- length(x)
        if (n < 4L) return(NA_real_)
        m2 <- mean((x - mean(x))^2)
        m3 <- mean((x - mean(x))^3)
        m4 <- mean((x - mean(x))^4)
        sk <- m3 / m2^1.5
        ku <- m4 / m2^2 - 3          # excess kurtosis
        correction <- 3 * (n - 1L)^2 / ((n - 2L) * (n - 3L))
        (sk^2 + 1) / (ku + correction)
    }

    # Secondary: separation score from metadata (\u03b7\u00b2 categorical, |r| continuous)
    .eta2 <- function(x, g) {
        g <- as.factor(g)
        if (nlevels(g) < 2L) return(NA_real_)
        ss_total <- var(x) * (length(x) - 1L)
        if (ss_total == 0) return(NA_real_)
        gm <- mean(x)
        ss_between <- sum(tapply(x, g, function(xi)
            length(xi) * (mean(xi) - gm)^2))
        ss_between / ss_total
    }

    .sep <- function(x, meta) {
        if (is.null(meta)) return(NA_real_)
        if (is.numeric(meta)) return(abs(cor(x, meta, use = "complete.obs")))
        .eta2(x, meta)
    }

    rows <- lapply(seq_len(k_show), function(j) {
        coord <- cmat[, j]
        bc    <- .bc(coord)
        sep   <- .sep(coord, meta_col)
        # Panel label: PC index + BC; secondary sep score if available
        label <- if (!is.na(sep))
            sprintf("PC%d  BC=%.2f  %s=%.2f", j, bc,
                    if (is.numeric(meta_col)) "|r|" else "eta^2", sep)
        else
            sprintf("PC%d  BC=%.2f", j, bc)
        df <- data.frame(
            coord     = coord,
            component = label,
            bc        = bc,
            stringsAsFactors = FALSE
        )
        if (!is.null(meta_col)) df[[colour_by]] <- meta_col
        df
    })

    # Sort by bimodality coefficient (primary), sep score (secondary tiebreak)
    bc_scores  <- vapply(rows, function(d) d$bc[1L],  numeric(1L))
    rows <- rows[order(bc_scores, decreasing = TRUE)]
    df   <- do.call(rbind, rows)
    df$component <- factor(df$component,
                            levels = unique(df$component))

    sep_label <- if (!is.null(meta_col) && is.numeric(meta_col)) "|r|" else "eta^2"
    subtitle <- if (!is.null(colour_by))
        sprintf("Sorted by bimodality coefficient (BC); %s(%s) overlaid",
                sep_label, colour_by)
    else
        "Sorted by bimodality coefficient (BC > 0.555 = bimodal) -- add colour_by to overlay metadata"

    aes_base <- if (!is.null(colour_by) && colour_by %in% colnames(df))
        ggplot2::aes(x = coord, fill = .data[[colour_by]], colour = .data[[colour_by]])
    else
        ggplot2::aes(x = coord)

    p <- ggplot2::ggplot(df, aes_base) +
        ggplot2::geom_density(alpha = 0.4, linewidth = 0.5) +
        ggplot2::geom_rug(alpha = 0.4, sides = "b") +
        ggplot2::geom_vline(xintercept = 0, linetype = "dotted",
                             colour = "grey60", linewidth = 0.4) +
        ggplot2::facet_wrap(~ component, scales = "free") +
        ggplot2::labs(
            title    = sprintf("Component component plots -- layer %d", idx),
            subtitle = subtitle,
            x        = "Coordinate",
            y        = "Density",
            fill     = colour_by,
            colour   = colour_by
        ) +
        ggplot2::theme_bw(base_size = 10) +
        ggplot2::theme(legend.position = "bottom")

    if (!is.null(colour_by) && colour_by %in% colnames(df))
        p <- p + ggplot2::scale_fill_brewer(palette = "Set1", na.value = "grey70") +
                 ggplot2::scale_colour_brewer(palette = "Set1", na.value = "grey70")
    p
}

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

    n_layers <- length(dr_coords(s1))
    layer_nms <- names(experiments(std))

    # Per-experiment colData (correct sample count per layer)
    expt_list <- as.list(experiments(std))

    rows <- lapply(seq_len(n_layers), function(i) {
        coord <- dr_coords(s1)[[i]]
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
        v_true <- std@ground_truth@shared[, 1L]
        v_hat  <- dr_V_star(s1)
        cos_a  <- min(1, abs(sum(v_true * v_hat) /
                             (sqrt(sum(v_true^2)) * sqrt(sum(v_hat^2)))))
        angle_label <- sprintf("angle to v_true = %.1f\u00b0", acos(cos_a) * 180 / pi)
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
            title    = "Sample coordinates on the shared state-transition axis",
            subtitle = if (!is.null(angle_label)) angle_label else
                       "Supply synthetic_control() output to annotate ground-truth angle",
            x        = "Sample (rank-ordered by coordinate)",
            y        = "State-transition coordinate",
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
#' Shows U(x) = -log p(x) along the state-transition axis, with stable critical points
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

    # Sample rug (first layer coordinates if available from stage1)
    s1 <- metadata(std)$stage1
    if (!is.null(s1) && length(dr_coords(s1))) {
        rug_x  <- dr_coords(s1)[[1L]]
        # Use first-experiment colData to match coord length
        cd_rug <- as.data.frame(colData(as.list(experiments(std))[[1L]]))
        rug_df <- data.frame(x = rug_x, stringsAsFactors = FALSE)
        if (!is.null(colour_by) && colour_by %in% colnames(cd_rug))
            rug_df[[colour_by]] <- cd_rug[[colour_by]]
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
            title  = "Quasi-potential landscape  U(x) = -log p(x)",
            x      = "State-transition coordinate",
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
