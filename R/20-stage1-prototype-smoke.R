# Stage 0 — frozen Stage 1 heterogeneous-feature smoke harness
#
# This file deliberately contains prototype estimators only. They are not
# registered Decomposer strategies and do not change the Issue #24 production
# contract. See ADR 0011 and docs/specs/stage1-candidate-protocol.md.

.stage1_proto_abort <- function(message) {
    stop(structure(list(message = message, call = NULL),
                   class = c("stage1_prototype_error", "error", "condition")))
}

.centered_orthonormal <- function(n, rank, reference = NULL) {
    if (n <= rank + if (is.null(reference)) 0L else ncol(reference))
        .stage1_proto_abort("sample count must exceed prototype rank")
    reference <- if (is.null(reference)) matrix(numeric(0), n, 0L) else reference
    basis <- qr.Q(qr(cbind(rep(1, n), reference, matrix(rnorm(n * rank), n, rank))))
    start <- 2L + ncol(reference)
    basis[, start:(start + rank - 1L), drop = FALSE]
}

.projector <- function(x) {
    q <- qr.Q(qr(x))
    q %*% t(q)
}

.frobenius <- function(x) sqrt(sum(x^2))

#' Generate the frozen Stage 1 heterogeneous-feature smoke control
#'
#' Generates the one seed/stratum fixed by protocol `stage1-heterogeneous-v1`:
#' two layers with 80 and 400 disjoint features, independent assay sample and
#' feature permutations, and shared/exclusive/confounder signal 24/12/12.
#' Its assays are deliberately connected through a MultiAssayExperiment sample
#' map rather than assay-column position.
#'
#' @param seed fixed smoke seed; defaults to 1001.
#' @return `StateTransitionData` with `HeterogeneousSubspaceGroundTruth`.
#' @keywords internal
.stage1_heterogeneous_control <- function(seed = 1001L, n = 20L,
                                          p = c(80L, 400L),
                                          signal = c(shared = 24, exclusive = 12, confounder = 12),
                                          noise_sd = 1, sample_permuted = TRUE,
                                          feature_permuted = TRUE) {
    setup_rng(seed)
    n <- as.integer(n)
    p <- as.integer(p)
    rank <- 2L
    if (length(p) < 2L || any(p < rank + 1L) || n < 3L ||
        !all(c("shared", "exclusive", "confounder") %in% names(signal)))
        .stage1_proto_abort("invalid heterogeneous control dimensions or signal")

    u_shared <- .centered_orthonormal(n, rank)
    remaining <- function(reference) {
        z <- matrix(rnorm(n * rank), n, rank)
        z <- z - reference %*% (crossprod(reference, z))
        q <- qr.Q(qr(z))
        q[, seq_len(rank), drop = FALSE]
    }
    u_exclusive <- lapply(seq_along(p), function(i) remaining(u_shared))
    u_confounder <- remaining(cbind(u_shared, u_exclusive[[1L]]))

    sample_ids <- paste0("d", seq_len(n))
    experiments_out <- vector("list", length(p))
    response <- vector("list", length(p))
    exclusive_response <- vector("list", length(p))
    confounder_response <- vector("list", length(p))
    for (i in seq_along(p)) {
        features <- paste0("layer", i, "_f", seq_len(p[[i]]))
        b_shared <- qr.Q(qr(matrix(rnorm(p[[i]] * rank), p[[i]], rank)))[, seq_len(rank), drop = FALSE]
        b_exclusive <- qr.Q(qr(matrix(rnorm(p[[i]] * rank), p[[i]], rank)))[, seq_len(rank), drop = FALSE]
        b_confounder <- qr.Q(qr(matrix(rnorm(p[[i]] * rank), p[[i]], rank)))[, seq_len(rank), drop = FALSE]
        x <- signal[["shared"]] * u_shared %*% t(b_shared) +
             signal[["exclusive"]] * u_exclusive[[i]] %*% t(b_exclusive) +
             signal[["confounder"]] * u_confounder %*% t(b_confounder) +
             matrix(rnorm(n * p[[i]], sd = noise_sd), n, p[[i]])
        sample_order <- sample.int(n)
        feature_order <- sample.int(p[[i]])
        if (!isTRUE(sample_permuted)) sample_order <- seq_len(n)
        if (!isTRUE(feature_permuted)) feature_order <- seq_len(p[[i]])
        response[[i]] <- signal[["shared"]] * b_shared[feature_order, , drop = FALSE]
        exclusive_response[[i]] <- signal[["exclusive"]] * b_exclusive[feature_order, , drop = FALSE]
        confounder_response[[i]] <- signal[["confounder"]] * b_confounder[feature_order, , drop = FALSE]
        rownames(response[[i]]) <- features[feature_order]
        rownames(exclusive_response[[i]]) <- features[feature_order]
        rownames(confounder_response[[i]]) <- features[feature_order]
        x <- x[sample_order, feature_order, drop = FALSE]
        rownames(x) <- sample_ids[sample_order]
        colnames(x) <- features[feature_order]
        experiments_out[[i]] <- SummarizedExperiment::SummarizedExperiment(
            assays = list(signal = t(x)))
    }
    names(experiments_out) <- paste0("layer", seq_along(p))

    truth <- new("HeterogeneousSubspaceGroundTruth",
        shared = u_shared,
        exclusive = u_exclusive,
        confounder = u_confounder,
        response = response,
        exclusive_response = exclusive_response,
        confounder_response = confounder_response,
        missing_block_mechanism = list(kind = "none", rate = 0, affected_samples = character())
    )
    std <- StateTransitionData(
        experiments = experiments_out,
        colData = S4Vectors::DataFrame(row.names = sample_ids),
        ground_truth = truth,
        sampling_design = cross_sectional()
    )
    md <- metadata(std)
    md$stage1_prototype_control <- list(
        protocol_id = "stage1-heterogeneous-v1", generator = "heterogeneous_shared_subspace_v1",
        seed = as.integer(seed), n = n, rank = rank, p = p, signal = signal, noise_sd = noise_sd
    )
    metadata(std) <- md
    std
}

.stage1_heterogeneous_smoke_control <- function(seed = 1001L, permute = TRUE) {
    .stage1_heterogeneous_control(seed = seed, n = 20L, p = c(80L, 400L),
        signal = c(shared = 24, exclusive = 12, confounder = 12), noise_sd = 1,
        sample_permuted = permute, feature_permuted = permute)
}

.prototype_complete_layers <- function(std) {
    sm <- as.data.frame(sampleMap(std), stringsAsFactors = FALSE)
    assay_names <- names(experiments(std))
    if (!all(c("assay", "primary", "colname") %in% names(sm)))
        .stage1_proto_abort("sampleMap must provide assay, primary, and colname")
    if (!all(assay_names %in% sm$assay))
        .stage1_proto_abort("every assay must have sample-map rows")

    by_assay <- lapply(assay_names, function(name) {
        rows <- sm[sm$assay == name, , drop = FALSE]
        if (anyDuplicated(rows$primary) || anyDuplicated(rows$colname))
            .stage1_proto_abort(sprintf("sampleMap must be one-to-one for assay '%s'", name))
        rows
    })
    common <- Reduce(intersect, lapply(by_assay, `[[`, "primary"))
    if (length(common) < 3L)
        .stage1_proto_abort("fewer than three complete paired observations")
    common <- rownames(colData(std))[rownames(colData(std)) %in% common]

    expts <- as.list(experiments(std))
    matrices <- Map(function(rows, expt) {
        idx <- match(common, rows$primary)
        cols <- rows$colname[idx]
        x <- t(assay(expt))
        if (anyNA(match(cols, rownames(x))))
            .stage1_proto_abort("sampleMap refers to an assay column that is absent")
        x[cols, , drop = FALSE]
    }, by_assay, expts)
    names(matrices) <- assay_names
    list(matrices = matrices, sample_ids = common,
         exclusions = setdiff(rownames(colData(std)), common))
}

.prototype_preprocess <- function(matrices) {
    lapply(matrices, function(x) {
        means <- colMeans(x)
        centred <- sweep(x, 2L, means, "-")
        block_scale <- .frobenius(centred)
        if (!is.finite(block_scale) || block_scale == 0)
            .stage1_proto_abort("a centred layer has zero Frobenius norm")
        list(x = centred / block_scale, means = means, block_scale = block_scale)
    })
}

.prototype_responses <- function(scores, prepared) {
    lapply(prepared, function(layer) {
        # r × p response on the scaled discovery matrix, then restore its
        # original block scale for interpretable reconstruction metrics.
        solve(crossprod(scores), crossprod(scores, layer$x)) * layer$block_scale
    })
}

.prototype_consensus <- function(prepared, rank = 2L) {
    score_layers <- lapply(prepared, function(layer) {
        svd(layer$x, nu = rank, nv = 0L)$u[, seq_len(rank), drop = FALSE]
    })
    consensus <- qr.Q(qr(Reduce(`+`, score_layers)))[, seq_len(rank), drop = FALSE]
    iterations <- 0L
    for (iter in seq_len(100L)) {
        aligned <- lapply(score_layers, function(scores) {
            s <- svd(crossprod(scores, consensus), nu = rank, nv = rank)
            scores %*% (s$u %*% t(s$v))
        })
        next_consensus <- qr.Q(qr(Reduce(`+`, aligned)))[, seq_len(rank), drop = FALSE]
        delta <- .frobenius(.projector(next_consensus) - .projector(consensus))
        consensus <- next_consensus
        iterations <- iter
        if (delta < 1e-8) break
    }
    list(scores = consensus, response = .prototype_responses(consensus, prepared),
         iterations = iterations)
}

.prototype_block_svd <- function(prepared, rank = 2L) {
    joined <- do.call(cbind, lapply(prepared, `[[`, "x"))
    scores <- svd(joined, nu = rank, nv = 0L)$u[, seq_len(rank), drop = FALSE]
    list(scores = scores, response = .prototype_responses(scores, prepared), iterations = NA_integer_)
}

.prototype_project <- function(holdout, fitted) {
    projected <- Map(function(x, response, prep) {
        expected <- names(prep$means)
        if (anyDuplicated(colnames(x)) || !setequal(expected, colnames(x)))
            .stage1_proto_abort("projection feature IDs must be unique and match discovery features exactly")
        x <- x[, expected, drop = FALSE]
        y <- sweep(x, 2L, prep$means, "-") / prep$block_scale
        b <- response / prep$block_scale
        y %*% t(b) %*% solve(b %*% t(b))
    }, holdout, fitted$response, fitted$prepared)
    qr.Q(qr(Reduce(`+`, projected)))[, seq_len(ncol(fitted$scores)), drop = FALSE]
}

.prototype_metrics <- function(fit, truth, holdout, holdout_truth) {
    r <- ncol(truth@shared)
    p_hat <- .projector(fit$scores)
    shared_error <- .frobenius(p_hat - .projector(truth@shared)) / sqrt(2 * r)
    leakage <- mean(vapply(truth@exclusive, function(u)
        .frobenius(p_hat %*% u) / sqrt(r), numeric(1L)))
    response_error <- mean(vapply(seq_along(fit$response), function(i) {
        response <- fit$response[[i]]
        target <- truth@response[[i]]
        .frobenius(fit$scores %*% response - truth@shared %*% t(target)) /
            .frobenius(truth@shared %*% t(target))
    }, numeric(1L)))
    projected <- .prototype_project(holdout, fit)
    projection_error <- .frobenius(.projector(projected) - .projector(holdout_truth)) / sqrt(2 * r)
    c(shared_recovery_error = shared_error, response_recovery_error = response_error,
      exclusive_leakage = leakage, projection_error = projection_error)
}

#' Run the frozen Stage 1 heterogeneous-feature smoke harness
#'
#' Runs only the single deterministic smoke stratum from
#' `stage1-heterogeneous-v1`. C1 and C2 are local prototype functions: neither
#' is registered as a production `Decomposer`, and this function does not make
#' a candidate-selection or biological claim.
#'
#' @param seed the frozen smoke seed, `1001`.
#' @return a list containing the control, a one-row-per-candidate metric table,
#'   and contract-gate results.
#' @export
stage1_candidate_smoke <- function(seed = 1001L, control = NULL) {
    if (is.null(control) && !identical(as.integer(seed), 1001L))
        .stage1_proto_abort("stage1-heterogeneous-v1 smoke tier requires seed 1001")
    std <- if (is.null(control)) .stage1_heterogeneous_smoke_control(seed) else control
    extracted <- .prototype_complete_layers(std)
    prepared <- .prototype_preprocess(extracted$matrices)
    truth <- std@ground_truth

    # Independent holdout scores retain discovery responses but are not used to
    # fit either candidate. The exact-ID control is followed by the required
    # missing-feature negative projection gate.
    setup_rng(as.integer(seed) + 1000L)
    n_holdout <- 60L
    r <- ncol(truth@shared)
    u_holdout <- .centered_orthonormal(n_holdout, r)
    u_holdout_exclusive <- lapply(seq_along(truth@response), function(i)
        .centered_orthonormal(n_holdout, r, u_holdout))
    u_holdout_confounder <- .centered_orthonormal(
        n_holdout, r, cbind(u_holdout, u_holdout_exclusive[[1L]]))
    holdout <- Map(function(response, exclusive_response, confounder_response,
                           u_exclusive, prep) {
        x <- u_holdout %*% t(response) +
             u_exclusive %*% t(exclusive_response) +
             u_holdout_confounder %*% t(confounder_response) +
             matrix(rnorm(n_holdout * length(prep$means)), n_holdout, length(prep$means))
        colnames(x) <- names(prep$means)
        x
    }, truth@response, truth@exclusive_response, truth@confounder_response,
       u_holdout_exclusive, prepared)

    fitters <- list(C1_symmetric_consensus = .prototype_consensus,
                    C2_block_scaled_svd = .prototype_block_svd)
    fits <- lapply(names(fitters), function(name) {
        gc(reset = TRUE)
        t0 <- proc.time()[["elapsed"]]
        fit <- fitters[[name]](prepared, rank = r)
        elapsed <- proc.time()[["elapsed"]] - t0
        peak_vcells_bytes <- as.numeric(gc()["Vcells", "max used"]) * 8
        fit$prepared <- prepared
        fit$elapsed_sec <- elapsed
        fit$peak_vcells_bytes <- peak_vcells_bytes
        fit
    })
    names(fits) <- names(fitters)
    rows <- lapply(names(fits), function(name) {
        fit <- fits[[name]]
        values <- .prototype_metrics(fit, truth, holdout, u_holdout)
        data.frame(candidate = name, t(values), elapsed_sec = fit$elapsed_sec,
                   peak_vcells_bytes = fit$peak_vcells_bytes,
                   typed_failure_rate = 0,
                   input_bytes = sum(vapply(extracted$matrices, utils::object.size, numeric(1L))),
                   iterations = fit$iterations, stringsAsFactors = FALSE)
    })

    missing_id_rejected <- vapply(fits, function(fit) {
        malformed <- holdout
        malformed[[1L]] <- malformed[[1L]][, -1L, drop = FALSE]
        inherits(try(.prototype_project(malformed, fit), silent = TRUE), "try-error")
    }, logical(1L))
    extra_id_rejected <- vapply(fits, function(fit) {
        malformed <- holdout
        malformed[[1L]] <- cbind(malformed[[1L]], extra = 0)
        inherits(try(.prototype_project(malformed, fit), silent = TRUE), "try-error")
    }, logical(1L))

    ctrl <- metadata(std)$stage1_prototype_control
    canonical <- .stage1_heterogeneous_control(
        seed = ctrl$seed, n = ctrl$n, p = ctrl$p, signal = ctrl$signal,
        noise_sd = ctrl$noise_sd, sample_permuted = FALSE, feature_permuted = FALSE)
    canonical_prepared <- .prototype_preprocess(.prototype_complete_layers(canonical)$matrices)
    canonical_fits <- lapply(fitters, function(fitter) fitter(canonical_prepared, rank = r))
    permutation_invariant <- mapply(function(permuted, canonical_fit)
        .frobenius(.projector(permuted$scores) - .projector(canonical_fit$scores)) < 1e-8,
        fits, canonical_fits)

    retained_fits <- lapply(fits, function(fit) list(
        scores = fit$scores, response = fit$response,
        means = lapply(fit$prepared, `[[`, "means"),
        block_scales = vapply(fit$prepared, `[[`, numeric(1L), "block_scale"),
        feature_ids = lapply(fit$prepared, function(x) names(x$means)),
        sample_ids = extracted$sample_ids, exclusions = extracted$exclusions
    ))
    list(
        protocol_id = "stage1-heterogeneous-v1",
        control = std,
        results = do.call(rbind, rows),
        fits = retained_fits,
        gates = list(
            sample_map_aligned = identical(extracted$sample_ids, rownames(colData(std))),
            heterogeneous_features = !identical(ncol(extracted$matrices[[1L]]), ncol(extracted$matrices[[2L]])),
            complete_case_exclusions = extracted$exclusions,
            missing_projection_id_rejected = missing_id_rejected,
            extra_projection_id_rejected = extra_id_rejected,
            permutation_invariant = permutation_invariant,
            production_strategy_registered = any(c("C1_symmetric_consensus", "C2_block_scaled_svd") %in%
                                                  list_strategies("Decomposer"))
        )
    )
}
