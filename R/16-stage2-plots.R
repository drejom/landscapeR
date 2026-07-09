# Stage 2 diagnostic plot functions for StateTransitionData

utils::globalVariables(c("U", "type", "xend", "y", "yend", ".data"))

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
    # Two-stage fallback: try coords first, then coords_k.
    s1 <- metadata(std)$stage1
    rug_df <- NULL
    if (!is.null(s1)) {
        if (length(dr_coords(s1))) {
            rug_x <- dr_coords(s1)[[1L]]
        } else if (length(dr_coords_k(s1))) {
            warning("Using coords_k fallback for rug positions")
            comp  <- if (!is.null(s2$params$component)) as.integer(s2$params$component) else 1L
            rug_x <- dr_coords_k(s1)[[1L]][, comp, drop = TRUE]
        } else {
            warning("No coordinate data available for rug")
            rug_x <- NULL
        }
        if (!is.null(rug_x)) {
            # Use first-experiment colData to match coord length
            cd_rug <- as.data.frame(colData(as.list(experiments(std))[[1L]]))
            rug_df <- data.frame(x = rug_x, stringsAsFactors = FALSE)
            if (!is.null(colour_by) && colour_by %in% colnames(cd_rug))
                rug_df[[colour_by]] <- cd_rug[[colour_by]]
        }
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
