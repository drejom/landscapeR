# Stage 1 — HO-GSVD decomposition strategies
#
# Two legacy, equal-feature-space strategies are registered under the
# "Decomposer" contract. They remain useful baselines while heterogeneous and
# rank-deficient HO-GSVD candidates are evaluated under ADR 0001; neither
# adapter claims support for layers with different feature identities,
# dimensions, or order.
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

.validate_legacy_hogsvd <- function(strategy_name, layers, params) {
    if (length(layers) < 2L)
        return(stage_failure(sprintf(
            "%s requires at least 2 omic layers", strategy_name
        )))
    if (!is.logical(params$center) || length(params$center) != 1L ||
        is.na(params$center))
        return(stage_failure(sprintf(
            "%s center must be a single non-missing logical", strategy_name
        )))
    requested_k <- params$k_components
    if (!is.numeric(requested_k) || length(requested_k) != 1L ||
        !is.finite(requested_k) || requested_k < 1L ||
        requested_k > .Machine$integer.max ||
        requested_k != as.integer(requested_k))
        return(stage_failure(sprintf(
            "%s k_components must be a single positive integer", strategy_name
        )))

    matrices <- lapply(layers, function(layer) t(assay(layer)))
    finite_numeric <- vapply(matrices, function(X) {
        is.numeric(X) && all(is.finite(X))
    }, logical(1L))
    if (!all(finite_numeric))
        return(stage_failure(sprintf(
            "%s requires finite numeric omic-layer matrices", strategy_name
        )))
    feature_counts <- vapply(matrices, ncol, integer(1L))
    if (length(unique(feature_counts)) != 1L)
        return(stage_failure(sprintf(
            paste0(
                "%s does not support heterogeneous feature spaces; ",
                "all omic layers must have the same number of features"
            ),
            strategy_name
        )))
    feature_ids <- lapply(layers, rownames)
    valid_ids <- vapply(feature_ids, function(ids) {
        !is.null(ids) && length(ids) > 0L && !anyNA(ids) &&
            all(nzchar(ids)) && !anyDuplicated(ids)
    }, logical(1L))
    same_ids <- all(valid_ids) && all(vapply(feature_ids[-1L], function(ids) {
        identical(ids, feature_ids[[1L]])
    }, logical(1L)))
    if (!same_ids)
        return(stage_failure(sprintf(
            paste0(
                "%s requires identical, unique, ordered feature identifiers ",
                "across all omic layers"
            ),
            strategy_name
        )))
    max_ranks <- vapply(matrices, function(X) {
        min(if (isTRUE(params$center)) nrow(X) - 1L else nrow(X), ncol(X))
    }, integer(1L))
    if (any(max_ranks < 1L))
        return(stage_failure(sprintf(
            "%s requires at least one estimable component in every layer",
            strategy_name
        )))

    list(
        matrices = matrices,
        requested_k = as.integer(requested_k),
        n = nrow(matrices[[1L]]),
        p = feature_counts[[1L]]
    )
}

.legacy_hogsvd_axes <- function(svds, requested_k, p, mode) {
    if (identical(mode, "averaged")) {
        available <- vapply(svds, function(s) {
            min(length(s$d), ncol(s$u), ncol(s$v))
        }, integer(1L))
        k <- min(requested_k, min(available))
        V_k <- matrix(0, nrow = p, ncol = k)
        for (j in seq_len(k)) {
            sigma2_j <- vapply(svds, function(s) s$d[[j]]^2, numeric(1L))
            V_raw_j <- vapply(svds, function(s) s$v[, j], numeric(p))
            V_j <- drop(V_raw_j %*% sigma2_j)
            magnitude <- sqrt(sum(V_j^2))
            if (!is.finite(magnitude) || magnitude <= 0)
                stop("shared loading axis has zero or non-finite magnitude")
            V_k[, j] <- V_j / magnitude
        }
        return(list(V_k = V_k, k = k))
    }

    best_layer <- which.max(vapply(svds, function(s) s$d[[1L]], numeric(1L)))
    k <- min(
        requested_k,
        length(svds[[best_layer]]$d),
        ncol(svds[[best_layer]]$u),
        ncol(svds[[best_layer]]$v)
    )
    list(
        V_k = svds[[best_layer]]$v[, seq_len(k), drop = FALSE],
        k = k
    )
}

.run_legacy_hogsvd <- function(strategy, data, strategy_name, mode) {
    input_hashes <- c(data = digest::digest(data))
    layers <- as.list(experiments(data))
    params <- modifyList(list(center = TRUE, k_components = 6L), strategy@params)
    validated <- .validate_legacy_hogsvd(strategy_name, layers, params)
    if (is(validated, "StageResult")) return(validated)

    computed <- tryCatch({
        svds <- .preReduce(validated$matrices, center = params$center)
        axes <- .legacy_hogsvd_axes(
            svds, validated$requested_k, validated$p, mode
        )
        list(svds = svds, V_k = axes$V_k, k = axes$k)
    }, error = function(e) e)
    if (inherits(computed, "error"))
        return(stage_failure(sprintf(
            "%s decomposition failed: %s",
            strategy_name, conditionMessage(computed)
        )))

    warns <- character()
    threshold <- .bbp_threshold(validated$n, validated$p)
    if (computed$svds[[1L]]$d[[1L]] < threshold)
        warns <- sprintf(
            paste0(
                "Dominant singular value %.2f is below the BBP threshold %.2f ",
                "(n=%d, p=%d). Signal may be indistinguishable from noise."
            ),
            computed$svds[[1L]]$d[[1L]], threshold,
            validated$n, validated$p
        )

    result <- tryCatch(
        .stage1_result(
            computed$svds, computed$V_k, k = computed$k, warnings = warns
        ),
        error = function(e) e
    )
    if (inherits(result, "error"))
        return(stage_failure(sprintf(
            "%s result construction failed: %s",
            strategy_name, conditionMessage(result)
        )))

    md <- metadata(data)
    md$stage1 <- result
    metadata(data) <- md
    data <- record_provenance(
        data, "decompose", "Decomposer", strategy_name,
        params = c(
            list(
                n = validated$n,
                p = validated$p,
                K = length(layers),
                k = computed$k
            ),
            strategy@params
        ),
        input_hashes = input_hashes
    )
    provenance <- data@provenance[[length(data@provenance)]]

    for (warning_text in dr_warnings(result))
        warning(warning_text, call. = FALSE)
    stage_success(data, provenance = list(provenance))
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

#' @rdname component_loading_geometry
setMethod("component_loading_geometry", "HogsvdAveraged",
    function(strategy) "feature-loading-cosine")

#' @rdname decompose
setMethod(".decompose_impl", signature("HogsvdAveraged", "StateTransitionData"),
    function(strategy, data, ...) {
        # `data` has already passed validate_boundary() -- enforced
        # structurally by the Decomposer-level decompose() method in
        # R/08-contracts.R. This strategy only implements its own logic.

        .run_legacy_hogsvd(strategy, data, "hogsvd_averaged", "averaged")
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

#' @rdname component_loading_geometry
setMethod("component_loading_geometry", "HogsvdPrereduced",
    function(strategy) "feature-loading-cosine")

#' @rdname decompose
setMethod(".decompose_impl", signature("HogsvdPrereduced", "StateTransitionData"),
    function(strategy, data, ...) {
        # `data` has already passed validate_boundary() -- enforced
        # structurally by the Decomposer-level decompose() method in
        # R/08-contracts.R. This strategy only implements its own logic.

        .run_legacy_hogsvd(strategy, data, "hogsvd_prereduced", "prereduced")
    }
)

# ---------------------------------------------------------------------------
# Registration (runs at package load)
# ---------------------------------------------------------------------------

register_strategy("Decomposer", "hogsvd_averaged",
    function(params = list()) new("HogsvdAveraged", params = params))

register_strategy("Decomposer", "hogsvd_prereduced",
    function(params = list()) new("HogsvdPrereduced", params = params))
