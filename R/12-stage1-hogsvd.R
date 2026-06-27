# Stage 1 — HO-GSVD decomposition strategies
#
# Two strategies registered under the "Decomposer" contract:
#
#   "hogsvd_averaged"    (default) — pre-reduce each layer to rank-(n-1) via
#                         thin SVD, then form the shared disease axis as a
#                         sigma^2-weighted average of per-layer first right
#                         singular vectors.  Achieves 1/sqrt(K) improvement
#                         in angle recovery vs single-layer SVD when signal
#                         is above the BBP phase-transition threshold.
#
#   "hogsvd_prereduced"  (baseline) — same pre-reduction but selects a single
#                         best component via which.max(mean_sigma).  Equivalent
#                         to best-of-K single-layer SVD.  Use for debugging and
#                         as a per-layer diagnostic.
#
# Both strategies:
#   - Handle rank-deficient layers (p >> n) as the normal case
#   - Emit a warning (not error) when the dominant singular value is below the
#     BBP threshold  (n*p)^(1/4)
#   - Return a StageResult whose $value is the input StateTransitionData with
#     Stage 1 results stored in metadata()$stage1

# ---------------------------------------------------------------------------
# Internal helpers (not exported)
# ---------------------------------------------------------------------------

.bbp_threshold <- function(n, p) (n * p)^0.25

.thin_svd <- function(X) {
    n <- nrow(X); p <- ncol(X)
    rank <- min(n - 1L, p)
    svd(X, nu = rank, nv = rank)
}

# Core pre-reduction: thin SVD every layer; return list of svd objects + metadata
.preReduce <- function(layers) {
    lapply(layers, .thin_svd)
}

# Build the Stage 1 result list from a list of svd objects and the chosen
# shared gene axis.  Used by both strategies.
.stage1_result <- function(svds, V_star, warnings = character()) {
    sigma <- vapply(svds, function(s) s$d[1L], numeric(1L))
    # Per-layer sample coordinates along the shared disease axis:
    # X_i V_star ~ U_i Sigma_i (V_i' V_star); use first component approximation
    coords <- lapply(svds, function(s) {
        drop(s$d[1L] * (s$v[, 1L] %*% V_star)[1L] * s$u[, 1L])
    })
    list(
        V_star   = V_star,   # p-vector: shared gene-space disease axis
        sigma    = sigma,    # K-vector: dominant singular values per layer
        coords   = coords,   # K-list of n-vectors: sample coordinates
        warnings = warnings
    )
}

# ---------------------------------------------------------------------------
# Strategy: hogsvd_averaged
# ---------------------------------------------------------------------------

setClass("HogsvdAveraged",
    contains  = "Decomposer",
    representation(params = "list")
)

setMethod("decompose", signature("HogsvdAveraged", "StateTransitionData"),
    function(strategy, data, ...) {
        layers <- as.list(experiments(data))
        if (length(layers) < 2L)
            return(stage_failure("hogsvd_averaged requires at least 2 layers"))

        matrices <- lapply(layers, function(e) t(assay(e)))  # n x p per layer
        n <- nrow(matrices[[1L]])
        p <- ncol(matrices[[1L]])

        svds  <- .preReduce(matrices)
        warns <- character()

        # BBP check on the dominant singular value of the first layer
        sv1 <- svds[[1L]]$d[1L]
        thr <- .bbp_threshold(n, p)
        if (sv1 < thr)
            warns <- c(warns, sprintf(
                "Dominant singular value %.2f is below the BBP threshold %.2f
                 (n=%d, p=%d). Signal may be indistinguishable from noise.",
                sv1, thr, n, p))

        # sigma^2-weighted average of per-layer v_1
        sigma2 <- vapply(svds, function(s) s$d[1L]^2, numeric(1L))
        V_raw  <- vapply(svds, function(s) s$v[, 1L], numeric(p))  # p x K
        V_star <- drop(V_raw %*% sigma2)
        V_star <- V_star / sqrt(sum(V_star^2))

        res <- .stage1_result(svds, V_star, warns)

        md <- metadata(data)
        md$stage1 <- res
        metadata(data) <- md

        prov <- record_provenance(data, "decompose", "Decomposer", "hogsvd_averaged",
            params = c(list(n = n, p = p, K = length(layers)), strategy@params))

        if (length(warns)) for (w in warns) warning(w)
        stage_success(data, provenance = list(prov))
    }
)

# ---------------------------------------------------------------------------
# Strategy: hogsvd_prereduced
# ---------------------------------------------------------------------------

setClass("HogsvdPrereduced",
    contains  = "Decomposer",
    representation(params = "list")
)

setMethod("decompose", signature("HogsvdPrereduced", "StateTransitionData"),
    function(strategy, data, ...) {
        layers  <- as.list(experiments(data))
        if (length(layers) < 2L)
            return(stage_failure("hogsvd_prereduced requires at least 2 layers"))

        matrices <- lapply(layers, function(e) t(assay(e)))
        n <- nrow(matrices[[1L]])
        p <- ncol(matrices[[1L]])

        svds  <- .preReduce(matrices)
        warns <- character()

        sv1 <- svds[[1L]]$d[1L]
        thr <- .bbp_threshold(n, p)
        if (sv1 < thr)
            warns <- c(warns, sprintf(
                "Dominant singular value %.2f is below the BBP threshold %.2f
                 (n=%d, p=%d). Signal may be indistinguishable from noise.",
                sv1, thr, n, p))

        # Select the layer whose first SV is largest — its v_1 is the disease axis
        best_layer <- which.max(vapply(svds, function(s) s$d[1L], numeric(1L)))
        V_star <- svds[[best_layer]]$v[, 1L]

        res <- .stage1_result(svds, V_star, warns)

        md <- metadata(data)
        md$stage1 <- res
        metadata(data) <- md

        prov <- record_provenance(data, "decompose", "Decomposer", "hogsvd_prereduced",
            params = c(list(n = n, p = p, K = length(layers)), strategy@params))

        if (length(warns)) for (w in warns) warning(w)
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
