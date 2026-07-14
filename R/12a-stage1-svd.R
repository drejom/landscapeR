# Stage 1 — single-layer SVD strategy
#
# K=1 is a first-class strategy with truthful provenance, not a degradation
# branch inside a multi-layer decomposer (ADR 0016).

#' @rdname decompose
#' @export
setClass("SvdDecomposer",
    contains = "Decomposer",
    representation(params = "list")
)

#' @rdname decompose
setMethod(".decompose_impl", signature("SvdDecomposer", "StateTransitionData"),
    function(strategy, data, ...) {
        input_hashes <- c(data = digest::digest(data))
        layers <- as.list(experiments(data))
        if (length(layers) != 1L)
            return(stage_failure("svd requires exactly 1 layer"))

        p_params <- modifyList(list(center = TRUE, k_components = 6L), strategy@params)
        if (!is.logical(p_params$center) || length(p_params$center) != 1L ||
            is.na(p_params$center))
            return(stage_failure(
                "svd center must be a single non-missing logical"
            ))

        requested_k <- p_params$k_components
        if (!is.numeric(requested_k) || length(requested_k) != 1L ||
            !is.finite(requested_k) || requested_k < 1L ||
            requested_k != as.integer(requested_k))
            return(stage_failure(
                "svd k_components must be a single positive integer"
            ))
        requested_k <- as.integer(requested_k)

        X <- t(assay(layers[[1L]]))
        if (!is.numeric(X) || any(!is.finite(X)))
            return(stage_failure(
                "svd requires a finite numeric assay matrix"
            ))
        if (isTRUE(p_params$center))
            X <- scale(X, center = TRUE, scale = FALSE)

        n <- nrow(X)
        p <- ncol(X)
        max_rank <- min(if (isTRUE(p_params$center)) n - 1L else n, p)
        if (max_rank < 1L)
            return(stage_failure(
                "svd requires at least one estimable component"
            ))
        decomposition <- tryCatch(
            svd(X, nu = max_rank, nv = max_rank),
            error = function(e) e
        )
        if (inherits(decomposition, "error"))
            return(stage_failure(sprintf(
                "svd decomposition failed: %s",
                conditionMessage(decomposition)
            )))
        k <- min(
            requested_k,
            length(decomposition$d),
            ncol(decomposition$u),
            ncol(decomposition$v)
        )
        V_k <- decomposition$v[, seq_len(k), drop = FALSE]

        warns <- character()
        threshold <- .bbp_threshold(n, p)
        if (decomposition$d[[1L]] < threshold)
            warns <- sprintf(
                paste0(
                    "Dominant singular value %.2f is below the BBP threshold %.2f ",
                    "(n=%d, p=%d). Signal may be indistinguishable from noise."
                ),
                decomposition$d[[1L]], threshold, n, p
            )

        result <- .stage1_result(
            svds = list(decomposition),
            V_k = V_k,
            k = k,
            warnings = warns
        )

        md <- metadata(data)
        md$stage1 <- result
        metadata(data) <- md

        data <- record_provenance(
            data,
            stage = "decompose",
            contract = "Decomposer",
            implementation = "svd",
            params = modifyList(
                strategy@params,
                list(
                    n = n,
                    p = p,
                    K = 1L,
                    k = k,
                    center = isTRUE(p_params$center),
                    k_components = requested_k
                )
            ),
            input_hashes = input_hashes
        )
        provenance <- data@provenance[[length(data@provenance)]]

        all_warns <- dr_warnings(result)
        if (length(all_warns)) for (warning_text in all_warns) warning(warning_text)
        stage_success(data, provenance = list(provenance))
    }
)

register_strategy("Decomposer", "svd",
    function(params = list()) new("SvdDecomposer", params = params))
