# project_into() — project a secondary cohort into a primary cohort's state-space
#
# Implements the Rockne2020 validation protocol:
#
#   PC_secondary = X_secondary · V*_primary
#
# The secondary object is returned with projected coordinates stored in
# metadata()$stage1$coords_k (same layout as a normal Stage 1 result), so all
# downstream functions (plot_components, estimate_dynamics) work unchanged.
#
# Typical use:
#
#   std_primary   <- readRDS("data-raw/aml_mrna_std.rds")
#   std_primary2  <- decompose(ctor(), std_primary)@value   # SVD on 2018
#   std_secondary <- project_into(std_primary2, std_secondary_raw)
#   plot_components(std_secondary, colour_by = "condition")
#
# The primary object is not modified.

#' Project a secondary cohort into the state-space of a primary cohort
#'
#' Implements the Rockne2020 validation projection:
#' \deqn{X_{\rm secondary} \cdot V^*_{\rm primary}}
#' which places secondary samples on the same coordinate axes as the primary,
#' without re-fitting the decomposition.
#'
#' The returned object is \code{std_secondary} augmented with
#' \code{metadata()$stage1} containing projected coordinates.  The primary
#' object is not modified.
#'
#' @param std_primary \code{StateTransitionData} with \code{metadata()$stage1}
#'   present — supplies the \eqn{V^*} loadings.
#' @param std_secondary \code{StateTransitionData} to project.  Must share the
#'   same feature space (genes) as the primary.  Only the first layer is used.
#' @param layer_primary integer — which layer of the primary object provides
#'   the \eqn{V^*} loadings (default 1).
#' @param layer_secondary integer — which layer of the secondary object to
#'   project (default 1).
#' @return \code{std_secondary} with \code{metadata()$stage1} written.
#'
#' @export
project_into <- function(std_primary, std_secondary,
                          layer_primary = 1L, layer_secondary = 1L) {
    stopifnot(is(std_primary,   "StateTransitionData"))
    stopifnot(is(std_secondary, "StateTransitionData"))

    s1_p <- metadata(std_primary)$stage1
    if (is.null(s1_p))
        stop("project_into: std_primary has no Stage 1 result. Run decompose() first.")
    if (is.null(s1_p$V_k))
        stop("project_into: std_primary Stage 1 result has no V_k — ",
             "re-run decompose() with a current version of hogsvd_averaged.")

    V_k <- s1_p$V_k      # p x k gene loading matrix from primary

    expt_sec <- as.list(experiments(std_secondary))
    idx_s    <- min(as.integer(layer_secondary), length(expt_sec))
    X_sec    <- t(assay(expt_sec[[idx_s]]))    # n_sec x p
    X_sec_c  <- scale(X_sec, center = TRUE, scale = FALSE)

    # Projected scores: n_sec x k
    proj <- X_sec_c %*% V_k   # (n x p) %*% (p x k) = n x k

    k <- ncol(V_k)

    # Build a stage1-compatible result
    coords_k <- list(proj)
    s1_out <- list(
        V_star   = V_k[, 1L],
        sigma    = s1_p$sigma_k[min(as.integer(layer_primary), nrow(s1_p$sigma_k)), ],
        coords   = list(drop(proj[, 1L])),
        warnings = c("Projected coordinates from primary state-space"),
        V_k      = V_k,
        sigma_k  = matrix(NA_real_, nrow = 1L, ncol = k),
        coords_k = coords_k,
        k        = k
    )

    md <- metadata(std_secondary)
    md$stage1 <- s1_out
    metadata(std_secondary) <- md

    std_secondary
}
