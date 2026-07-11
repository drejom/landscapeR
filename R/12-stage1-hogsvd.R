# Stage 1 — HO-GSVD decomposition strategies
#
# Two strategies registered under the "Decomposer" contract:
#
#   "hogsvd_averaged"    (default) — pre-reduce each layer to rank-(n-1) via
#                         thin SVD, then form each shared gene axis as a
#                         sigma^2-weighted average of per-layer right singular
#                         vectors.  Returns k_components components (default 6).
#
#   "hogsvd_prereduced"  (baseline) — same pre-reduction but selects a single
#                         best layer (max sigma_1) and returns its first
#                         k_components right singular vectors.  Use for
#                         debugging and as a per-layer diagnostic.
#
# Both strategies:
#   - Handle rank-deficient layers (p >> n) as the normal case
#   - Emit a warning (not error) when the dominant singular value is below the
#     BBP threshold  (n*p)^(1/4)
#   - Return a StageResult whose $value is the input StateTransitionData with
#     Stage 1 results stored in metadata()$stage1
#
# metadata()$stage1 structure (v0.2 — multi-component):
#
#   V_star   — p-vector: shared gene axis for component 1 (backwards compat)
#   sigma    — K-vector: first singular value per layer (backwards compat)
#   coords   — K-list of n-vectors: component 1 coordinates (backwards compat)
#   warnings — character vector
#   V_k      — p x k gene loading matrix; column j = shared gene axis j
#   sigma_k  — K x k matrix; sigma_k[i,j] = j-th SV of layer i
#   coords_k — K-list of n x k matrices; coords_k[[i]][,j] = layer i, component j
#   k        — integer: number of components returned

# ---------------------------------------------------------------------------
# Internal helpers (not exported)
# ---------------------------------------------------------------------------

.bbp_threshold <- function(n, p) (n * p)^0.25

.thin_svd <- function(X) {
    n <- nrow(X); p <- ncol(X)
    rank <- min(n - 1L, p)
    svd(X, nu = rank, nv = rank)
}

.preReduce <- function(layers, center = TRUE) {
    lapply(layers, function(X) {
        if (center) X <- scale(X, center = TRUE, scale = FALSE)
        .thin_svd(X)
    })
}

# Build the Stage 1 result as a DecompositionResult from a list of svd objects
# and the k shared gene axes (p x k matrix V_k).  Backwards-compatible fields
# for component 1 are kept alongside the new multi-component fields.
.stage1_result <- function(svds, V_k, k = 1L, warnings = character()) {
    K     <- length(svds)
    p     <- nrow(V_k)

    sigma_k  <- matrix(0, nrow = K, ncol = k)
    coords_k <- vector("list", K)

    for (i in seq_len(K)) {
        s     <- svds[[i]]
        k_eff <- min(k, length(s$d), ncol(s$v))

        if (k_eff < k) {
            msg <- paste0(
                "Layer ", i, ": only ", k_eff, " of ", k,
                " requested components available (rank-deficient)")
            warnings <- c(warnings, msg)
        }

        coords_i <- matrix(0, nrow = nrow(s$u), ncol = k)
        for (j in seq_len(k_eff)) {
            sigma_k[i, j] <- s$d[j]
            V_star_j      <- V_k[, j]
            overlap       <- drop(s$v[, j] %*% V_star_j)  # scalar alignment
            coords_i[, j] <- s$d[j] * overlap * s$u[, j]
        }
        coords_k[[i]] <- coords_i
    }

    DecompositionResult(
        V_star   = V_k[, 1L],
        sigma    = sigma_k[, 1L],
        coords   = lapply(coords_k, function(m) drop(m[, 1L])),
        warnings = warnings,
        V_k      = V_k,
        sigma_k  = sigma_k,
        coords_k = coords_k,
        k        = k
    )
}

# ---------------------------------------------------------------------------
# Strategy: hogsvd_averaged
# ---------------------------------------------------------------------------

#' @rdname decompose
#' @export
setClass("HogsvdAveraged",
    contains  = "Decomposer",
    representation(params = "list")
)

#' @rdname decompose
setMethod(".decompose_impl", signature("HogsvdAveraged", "StateTransitionData"),
    function(strategy, data, ...) {
        # `data` has already passed validate_boundary() -- enforced
        # structurally by the Decomposer-level decompose() method in
        # R/08-contracts.R. This strategy only implements its own logic.

        layers <- as.list(experiments(data))
        if (length(layers) < 2L)
            return(stage_failure("hogsvd_averaged requires at least 2 layers"))

        p_params <- modifyList(list(center = TRUE, k_components = 6L), strategy@params)
        matrices <- lapply(layers, function(e) t(assay(e)))  # n x p per layer
        n <- nrow(matrices[[1L]])
        p <- ncol(matrices[[1L]])

        svds  <- .preReduce(matrices, center = p_params$center)
        warns <- character()

        sv1 <- svds[[1L]]$d[1L]
        thr <- .bbp_threshold(n, p)
        if (sv1 < thr)
            warns <- c(warns, sprintf(
                "Dominant singular value %.2f is below the BBP threshold %.2f
                 (n=%d, p=%d). Signal may be indistinguishable from noise.",
                sv1, thr, n, p))

        # Number of components: limited by minimum rank across all layers
        k <- min(p_params$k_components,
                 min(vapply(svds, function(s) length(s$d), integer(1L))))

        # Build shared gene axes: sigma^2-weighted average of per-layer v_j
        V_k <- matrix(0, nrow = p, ncol = k)
        for (j in seq_len(k)) {
            sigma2_j <- vapply(svds, function(s)
                if (j <= length(s$d)) s$d[j]^2 else 0, numeric(1L))
            V_raw_j  <- vapply(svds, function(s)
                if (j <= ncol(s$v)) s$v[, j] else rep(0, p), numeric(p))  # p x K
            V_j <- drop(V_raw_j %*% sigma2_j)
            V_k[, j] <- V_j / sqrt(sum(V_j^2))
        }

        res <- .stage1_result(svds, V_k, k = k, warns)

        md <- metadata(data)
        md$stage1 <- res
        metadata(data) <- md

        prov <- record_provenance(data, "decompose", "Decomposer", "hogsvd_averaged",
            params = c(list(n = n, p = p, K = length(layers), k = k), strategy@params))

        all_warns <- dr_warnings(res)
        if (length(all_warns)) for (w in all_warns) warning(w)
        stage_success(data, provenance = list(prov))
    }
)

# ---------------------------------------------------------------------------
# Strategy: hogsvd_prereduced
# ---------------------------------------------------------------------------

#' @rdname decompose
#' @export
setClass("HogsvdPrereduced",
    contains  = "Decomposer",
    representation(params = "list")
)

#' @rdname decompose
setMethod(".decompose_impl", signature("HogsvdPrereduced", "StateTransitionData"),
    function(strategy, data, ...) {
        # `data` has already passed validate_boundary() -- enforced
        # structurally by the Decomposer-level decompose() method in
        # R/08-contracts.R. This strategy only implements its own logic.

        layers  <- as.list(experiments(data))
        if (length(layers) < 2L)
            return(stage_failure("hogsvd_prereduced requires at least 2 layers"))

        p_params <- modifyList(list(center = TRUE, k_components = 6L), strategy@params)
        matrices <- lapply(layers, function(e) t(assay(e)))
        n <- nrow(matrices[[1L]])
        p <- ncol(matrices[[1L]])

        svds  <- .preReduce(matrices, center = p_params$center)
        warns <- character()

        sv1 <- svds[[1L]]$d[1L]
        thr <- .bbp_threshold(n, p)
        if (sv1 < thr)
            warns <- c(warns, sprintf(
                "Dominant singular value %.2f is below the BBP threshold %.2f
                 (n=%d, p=%d). Signal may be indistinguishable from noise.",
                sv1, thr, n, p))

        # Best layer = highest sigma_1; use its first k right singular vectors
        best_layer <- which.max(vapply(svds, function(s) s$d[1L], numeric(1L)))
        k <- min(p_params$k_components, length(svds[[best_layer]]$d))
        V_k <- svds[[best_layer]]$v[, seq_len(k), drop = FALSE]

        res <- .stage1_result(svds, V_k, k = k, warns)

        md <- metadata(data)
        md$stage1 <- res
        metadata(data) <- md

        prov <- record_provenance(data, "decompose", "Decomposer", "hogsvd_prereduced",
            params = c(list(n = n, p = p, K = length(layers), k = k), strategy@params))

        all_warns <- dr_warnings(res)
        if (length(all_warns)) for (w in all_warns) warning(w)
        stage_success(data, provenance = list(prov))
    }
)

# ---------------------------------------------------------------------------
# Registration (runs at package load)
# ---------------------------------------------------------------------------

register_strategy("Decomposer", "hogsvd_averaged",
    function(params = list()) new("HogsvdAveraged", params = params))

register_strategy("Decomposer", "hogsvd_prereduced",
    function(params = list()) new("HogsvdPrereduced", params = params))
