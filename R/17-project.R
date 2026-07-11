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
# One call projects exactly one secondary layer. A secondary cohort with its
# own multi-layer structure (e.g. a validation cohort that itself has a
# disease/control split) is projected with one project_into() call per layer.
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
#'   same feature space (genes) as the primary.
#' @param layer_primary integer — which layer of the primary object provides
#'   the \eqn{V^*} loadings (default 1).
#' @param layer_secondary integer — which single layer of the secondary
#'   object to project (default 1). \code{project_into()} always projects
#'   exactly one layer per call — a projected layer was never itself
#'   decomposed, so it carries no signal-strength information of its own to
#'   combine across layers. If the secondary cohort has its own multi-layer
#'   structure (e.g. its own disease/control split), call \code{project_into()}
#'   once per layer, varying \code{layer_secondary}.
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

    V_k <- dr_V_k(s1_p)      # p x k gene loading matrix from primary

    expt_sec <- as.list(experiments(std_secondary))
    idx_s    <- min(as.integer(layer_secondary), length(expt_sec))
    X_sec    <- t(assay(expt_sec[[idx_s]]))    # n_sec x p
    X_sec_c  <- scale(X_sec, center = TRUE, scale = FALSE)

    # Projected scores: n_sec x k
    proj <- X_sec_c %*% V_k   # (n x p) %*% (p x k) = n x k

    k <- ncol(V_k)

    # Build a stage1-compatible result. The projected object represents a
    # single "layer" (only layer_secondary was projected -- it was never
    # decomposed), so sigma_k has exactly one row (nrow = 1L). Everywhere
    # else in the codebase sigma is derived as sigma_k[, 1L] (see
    # .stage1_result() in R/12-stage1-hogsvd.R) -- it is not an independent
    # quantity, it is "this layer's own component-1 singular value". A
    # projected layer has no such value (it was never decomposed), so sigma
    # must be NA here too, consistent with sigma_k being NA -- carrying over
    # the primary layer's sigma would misrepresent it as the secondary
    # layer's own singular value.
    coords_k    <- list(proj)
    sigma_k_out <- matrix(NA_real_, nrow = 1L, ncol = k)
    s1_out <- DecompositionResult(
        V_star   = V_k[, 1L],
        sigma    = sigma_k_out[, 1L],
        coords   = list(drop(proj[, 1L])),
        warnings = c("Projected coordinates from primary state-space"),
        V_k      = V_k,
        sigma_k  = sigma_k_out,
        coords_k = coords_k,
        k        = as.integer(k)
    )

    md <- metadata(std_secondary)
    md$stage1 <- s1_out
    metadata(std_secondary) <- md

    std_secondary
}
