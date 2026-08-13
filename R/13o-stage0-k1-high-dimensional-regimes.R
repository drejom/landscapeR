# Stage 0 K=1 high-dimensional signal regimes (#191)

.k1_high_dimensional_regime_version <- "k1-high-dimensional-regimes-v1"

.k1_high_dimensional_regime_payload <- function() list(
    fixed_total_spike = list(
        label = "Fixed total signal with added noise features",
        information_rule = "unit-norm dense loading",
        covariance_regime = "independent-gaussian"
    ),
    fixed_sparse = list(
        label = "Fixed sparse informative set with added noise features",
        information_rule = "unit-norm sparse loading",
        covariance_regime = "independent-gaussian"
    ),
    growing_coherent = list(
        label = "Growing coherent informative set",
        information_rule = "coherent loading with growing norm",
        covariance_regime = "independent-gaussian"
    ),
    correlated_modules = list(
        label = "Correlated feature modules",
        information_rule = "unit-norm sparse loading in block noise",
        covariance_regime = "block-correlated-gaussian"
    ),
    null_near_null = list(
        label = "Null or near-null signal",
        information_rule = "unit-norm sparse loading with zero or weak signal",
        covariance_regime = "independent-gaussian"
    )
)

#' Governed high-dimensional K=1 signal regimes
#'
#' @param id optional regime identifier. With `NULL`, returns all regimes.
#' @return A governed regime list, or a named list of all regimes.
#' @export
k1_high_dimensional_regime <- function(id = NULL) {
    payload <- .k1_high_dimensional_regime_payload()
    regimes <- lapply(names(payload), function(regime_id) structure(list(
        version = .k1_high_dimensional_regime_version,
        id = regime_id,
        label = payload[[regime_id]]$label,
        information_rule = payload[[regime_id]]$information_rule,
        covariance_regime = payload[[regime_id]]$covariance_regime,
        claim_status = "disclosed_calibration_only"
    ), class = c("K1HighDimensionalRegime", "list")))
    names(regimes) <- names(payload)
    if (is.null(id)) return(regimes)
    if (!.is_scalar_nonempty_text(id) || !id %in% names(regimes)) {
        .stop_landscapeR_validation(sprintf(
            "unknown high-dimensional regime '%s'; choose one of: %s",
            paste(id, collapse = ""), paste(names(regimes), collapse = ", ")
        ))
    }
    regimes[[id]]
}

.k1_high_dimensional_boundary_position <- function(signal, boundary) {
    ratio <- signal / boundary
    if (ratio > 1.1) "above" else if (ratio >= 0.9) "near" else "below"
}

#' Generate a governed high-dimensional K=1 control
#'
#' Separates total feature count from the number of biologically informative
#' features. The planted loading and analytic white-noise reference are retained
#' as calibration evidence; neither constitutes a biological sample-size rule.
#'
#' @param regime governed regime or identifier.
#' @param n number of independent biological observations.
#' @param p total feature count.
#' @param informative_features size of the planted informative feature set.
#' @param signal_strength coefficient applied to the planted loading.
#' @param noise_sd Gaussian noise standard deviation.
#' @param module_correlation within-module correlation for correlated modules.
#' @param seed deterministic package seed.
#' @return A cross-sectional `StateTransitionData` with known truth.
#' @export
synthetic_k1_high_dimensional_control <- function(
    regime = "fixed_total_spike", n = 24L, p = 100L,
    informative_features = min(10L, p), signal_strength = 7,
    noise_sd = 1, module_correlation = 0.6, seed = 42L
) {
    if (is.character(regime)) regime <- k1_high_dimensional_regime(regime)
    valid_regime <- inherits(regime, "K1HighDimensionalRegime") &&
        identical(regime$version, .k1_high_dimensional_regime_version)
    if (!valid_regime || !.is_whole_number(n, 4L) ||
            !.is_whole_number(p, 2L) ||
            !.is_whole_number(informative_features, 1L, p) ||
            !is.numeric(signal_strength) || length(signal_strength) != 1L ||
            !is.finite(signal_strength) || signal_strength < 0 ||
            !is.numeric(noise_sd) || length(noise_sd) != 1L ||
            !is.finite(noise_sd) || noise_sd <= 0 ||
            !is.numeric(module_correlation) ||
            length(module_correlation) != 1L ||
            !is.finite(module_correlation) || module_correlation < 0 ||
            module_correlation >= 1 || !.is_whole_number(seed, 0L)) {
        .stop_landscapeR_validation(
            "high-dimensional control arguments are invalid"
        )
    }
    n <- as.integer(n)
    p <- as.integer(p)
    informative_features <- as.integer(informative_features)
    setup_rng(seed)
    group <- factor(rep(c("reference", "target"), length.out = n),
        levels = c("reference", "target"))
    score <- as.numeric(scale(as.numeric(group == "target"),
        center = TRUE, scale = FALSE))
    score <- score / sqrt(sum(score^2))
    loading <- numeric(p)
    if (identical(regime$id, "fixed_total_spike")) {
        loading[] <- 1 / sqrt(p)
        informative_features <- p
    } else {
        loading[seq_len(informative_features)] <-
            if (identical(regime$id, "growing_coherent")) 1 else
                1 / sqrt(informative_features)
    }
    if (identical(regime$id, "null_near_null") && signal_strength == 0) {
        effective_signal <- 0
    } else {
        effective_signal <- signal_strength * sqrt(sum(loading^2))
    }
    noise <- matrix(rnorm(n * p, sd = noise_sd), n, p)
    if (identical(regime$covariance_regime, "block-correlated-gaussian")) {
        module_size <- min(20L, p)
        for (start in seq.int(1L, p, by = module_size)) {
            index <- start:min(p, start + module_size - 1L)
            common <- rnorm(n, sd = noise_sd)
            noise[, index] <- sqrt(module_correlation) * common +
                sqrt(1 - module_correlation) * noise[, index]
        }
    }
    matrix_data <- signal_strength * outer(score, loading) + noise
    sample_ids <- sprintf("sample_%03d", seq_len(n))
    assay_ids <- sprintf("rna_%03d", seq_len(n))
    feature_ids <- sprintf("gene_%05d", seq_len(p))
    expression <- t(matrix_data)
    dimnames(expression) <- list(feature_ids, assay_ids)
    names(score) <- sample_ids
    names(loading) <- feature_ids
    boundary <- noise_sd * (n * p)^0.25
    experiment <- SummarizedExperiment::SummarizedExperiment(
        assays = list(logcounts = expression)
    )
    truth <- new("SubspaceGroundTruth",
        shared = matrix(loading / sqrt(sum(loading^2)), ncol = 1L,
            dimnames = list(feature_ids, "planted_target")),
        exclusive = list(), angles = numeric()
    )
    std <- StateTransitionData(
        experiments = list(rna = experiment),
        colData = S4Vectors::DataFrame(
            condition = group, row.names = sample_ids
        ),
        sampleMap = S4Vectors::DataFrame(
            assay = factor(rep("rna", n), levels = "rna"),
            primary = sample_ids, colname = assay_ids
        ),
        ground_truth = truth,
        sampling_design = cross_sectional()
    )
    info <- list(
        version = "k1-high-dimensional-control-v1",
        regime_id = regime$id, regime_label = regime$label,
        n = n, p = p,
        informative_feature_count = informative_features,
        informative_feature_fraction = informative_features / p,
        loading_norm = sqrt(sum(loading^2)),
        covariance_regime = regime$covariance_regime,
        module_correlation = module_correlation,
        signal_strength = signal_strength,
        effective_signal_strength = effective_signal,
        noise_sd = noise_sd,
        recovery_boundary = boundary,
        boundary_position = .k1_high_dimensional_boundary_position(
            effective_signal, boundary
        ),
        seed = as.integer(seed),
        planted_answer_key = list(
            informative_features = feature_ids[loading != 0],
            loading = loading, sample_score = score
        ),
        claim_status = "disclosed_calibration_only"
    )
    md <- metadata(std)
    md$k1_high_dimensional_control <- info
    metadata(std) <- md
    record_provenance(
        std, stage = "generate_control",
        contract = "SyntheticControlGenerator",
        implementation = "k1_high_dimensional_regimes_v1",
        params = info,
        rng = .generator_rng_identity(seed,
            "synthetic_k1_high_dimensional_control"),
        input_hashes = c(regime = digest::digest(regime, algo = "sha256"))
    )
}

#' Inspect a governed high-dimensional K=1 control
#'
#' @param x generated control.
#' @return Generator parameters, boundary reference, and planted answer key.
#' @export
k1_high_dimensional_control_info <- function(x) {
    if (!is(x, "StateTransitionData") ||
            !is.list(metadata(x)$k1_high_dimensional_control)) {
        .stop_landscapeR_validation(
            "x must contain a high-dimensional K=1 control declaration"
        )
    }
    metadata(x)$k1_high_dimensional_control
}

.k1_high_dimensional_config <- function() {
    PipelineConfig(
        dataset = "synthetic_k1_high_dimensional",
        analysis = analysis_specification(
            id = "synthetic-k1-high-dimensional",
            target_field = "condition", target_type = "binary",
            reference_level = "reference", comparison_level = "target",
            claim_intent = "exploratory"
        ),
        strategies = list(
            Decomposer = "svd", DynamicsEstimator = "kde_logdensity"
        ),
        params = list(
            svd = list(k_components = 3L), kde_logdensity = list()
        )
    )
}

.k1_high_dimensional_assess_one <- function(
    regime_id, n, p, informative_features, signal_ratio, noise_sd,
    module_correlation, axis_resamples, seed, recovery_threshold
) {
    boundary <- noise_sd * (n * p)^0.25
    signal_strength <- signal_ratio * boundary
    control <- synthetic_k1_high_dimensional_control(
        regime_id, n, p, informative_features, signal_strength,
        noise_sd, module_correlation, seed
    )
    info <- k1_high_dimensional_control_info(control)
    config <- .k1_high_dimensional_config()
    decomposition <- .evidence_decompose(control, config)
    if (!is(decomposition, "StageResult") ||
            !identical(decomposition@status, "success")) {
        stop(if (is(decomposition, "StageResult")) decomposition@reason else
            "decomposer did not return a StageResult")
    }
    fitted <- decomposition@value
    loadings <- dr_V_k(stage_artifact(fitted, "stage1"))
    truth <- control@ground_truth@shared[, 1L]
    cosines <- abs(drop(crossprod(truth, loadings))) /
        sqrt(sum(truth^2) * colSums(loadings^2))
    target_component <- as.integer(which.max(cosines))
    target_cosine <- cosines[[target_component]]
    atlas <- associate_metadata(
        fitted, specification = config@analysis,
        n_resamples = 0L, seed = seed + 1L, sequential_internal = TRUE
    )
    proposal <- if (is(atlas, "MetadataAssociationAtlas")) {
        propose_component(
            atlas, n_permutations = 0L, seed = seed + 2L,
            sequential_internal = TRUE
        )
    } else NULL
    nominated <- if (is(proposal, "ComponentProposal")) {
        proposal@recommended_component
    } else NA_integer_
    associations <- if (is(atlas, "MetadataAssociationAtlas")) {
        atlas_associations(atlas)
    } else data.frame()
    target_rows <- if (nrow(associations)) associations[
        associations$component == target_component &
            associations$metadata_field == "condition",
        , drop = FALSE
    ] else associations
    downstream_estimable <- nrow(target_rows) > 0L && any(
        target_rows$proposal_eligible & is.finite(target_rows$effect_magnitude)
    )
    plan <- .identifiability_resampling_plan(
        fitted, config@analysis, axis_resamples, seed + 3L
    )
    similarities <- vapply(seq_len(axis_resamples), function(index) {
        draw <- plan$draws[[index]]
        sampled <- .resample_state_transition_data(
            control, draw$source_primary, index, draw$replicate_subject
        )
        result <- .evidence_decompose(sampled, config)
        if (!is(result, "StageResult") ||
                !identical(result@status, "success")) return(NA_real_)
        replicate_loadings <- dr_V_k(stage_artifact(result@value, "stage1"))
        alignment <- .match_component_loadings(loadings, replicate_loadings)
        matched <- alignment$assignment[
            alignment$assignment$reference_component == target_component,
            , drop = FALSE
        ]
        matched$absolute_similarity[[1L]]
    }, numeric(1L))
    completed <- is.finite(similarities)
    row <- data.frame(
        regime_id = info$regime_id, regime_label = info$regime_label,
        boundary_position = info$boundary_position,
        n = info$n, p = info$p,
        informative_feature_count = info$informative_feature_count,
        informative_feature_fraction = info$informative_feature_fraction,
        loading_norm = info$loading_norm,
        covariance_regime = info$covariance_regime,
        signal_strength = info$signal_strength, noise_sd = info$noise_sd,
        recovery_boundary = info$recovery_boundary,
        execution_completed = TRUE,
        target_loading_cosine = target_cosine,
        recovery_evaluable = is.finite(target_cosine),
        recovery_met = is.finite(target_cosine) &&
            target_cosine >= recovery_threshold,
        nominated_component = nominated,
        proposal_available = is(proposal, "ComponentProposal"),
        axis_mean_absolute_similarity = if (any(completed)) {
            mean(similarities[completed])
        } else NA_real_,
        axis_refits_requested = as.integer(axis_resamples),
        axis_refits_completed = as.integer(sum(completed)),
        downstream_estimable = downstream_estimable,
        diagnostic = if (downstream_estimable) "" else
            "planted-target association was not estimable",
        stringsAsFactors = FALSE
    )
    evidence <- list(
        version = "k1-high-dimensional-replicate-v1",
        generator = info, target_component = target_component,
        bootstrap_plan_digest = plan$digest,
        bootstrap_similarities = similarities,
        row = row
    )
    list(row = row, evidence = evidence)
}

.k1_high_dimensional_cell_summary <- function(replicates) {
    key <- interaction(
        replicates$regime_id, replicates$p, replicates$signal_strength,
        drop = TRUE, lex.order = TRUE
    )
    rows <- lapply(split(seq_len(nrow(replicates)), key), function(index) {
        x <- replicates[index, , drop = FALSE]
        data.frame(
            regime_id = x$regime_id[[1L]],
            regime_label = x$regime_label[[1L]],
            boundary_position = x$boundary_position[[1L]],
            n = x$n[[1L]], p = x$p[[1L]],
            informative_feature_count = x$informative_feature_count[[1L]],
            informative_feature_fraction = x$informative_feature_fraction[[1L]],
            covariance_regime = x$covariance_regime[[1L]],
            signal_strength = x$signal_strength[[1L]],
            noise_sd = x$noise_sd[[1L]],
            recovery_boundary = x$recovery_boundary[[1L]],
            n_requested = nrow(x),
            n_execution_completed = sum(x$execution_completed),
            recovery_probability = if (any(x$recovery_evaluable)) {
                mean(x$recovery_met[x$recovery_evaluable])
            } else NA_real_,
            mean_axis_similarity = if (any(is.finite(
                x$axis_mean_absolute_similarity
            ))) mean(x$axis_mean_absolute_similarity, na.rm = TRUE) else
                NA_real_,
            proposal_probability = if (any(x$execution_completed)) {
                mean(x$proposal_available[x$execution_completed])
            } else NA_real_,
            downstream_estimability_probability = if (any(
                x$execution_completed
            )) mean(x$downstream_estimable[x$execution_completed]) else
                NA_real_, stringsAsFactors = FALSE
        )
    })
    result <- do.call(rbind, rows)
    rownames(result) <- NULL
    result
}

.k1_high_dimensional_failure_row <- function(
    task, task_id, n, informative_features, noise_sd, axis_resamples,
    module_correlation, failure_code
) {
    regime <- k1_high_dimensional_regime(task$regime_id[[1L]])
    p <- as.integer(task$p[[1L]])
    informative <- if (identical(regime$id, "fixed_total_spike")) p else
        min(as.integer(informative_features), p)
    loading_norm <- if (identical(regime$id, "growing_coherent")) {
        sqrt(informative)
    } else 1
    boundary <- noise_sd * (n * p)^0.25
    signal <- task$signal_ratio[[1L]] * boundary
    data.frame(
        task_id = task_id,
        replicate_index = task$replicate_index[[1L]],
        regime_id = regime$id, regime_label = regime$label,
        boundary_position = .k1_high_dimensional_boundary_position(
            signal * loading_norm, boundary
        ),
        n = as.integer(n), p = p,
        informative_feature_count = informative,
        informative_feature_fraction = informative / p,
        loading_norm = loading_norm,
        covariance_regime = regime$covariance_regime,
        signal_strength = signal, noise_sd = noise_sd,
        recovery_boundary = boundary,
        execution_completed = FALSE,
        target_loading_cosine = NA_real_, recovery_evaluable = FALSE,
        recovery_met = NA, nominated_component = NA_integer_,
        proposal_available = NA,
        axis_mean_absolute_similarity = NA_real_,
        axis_refits_requested = as.integer(axis_resamples),
        axis_refits_completed = 0L, downstream_estimable = NA,
        diagnostic = failure_code, stringsAsFactors = FALSE
    )
}

.validate_k1_high_dimensional_assessment <- function(x) {
    expected_names <- c(
        "version", "claim_status", "recovery_threshold", "axis_resamples",
        "scientific_context", "execution", "replicates", "cells", "digest"
    )
    expected_rows <- c(
        "task_id", "replicate_index", "regime_id", "regime_label",
        "boundary_position", "n", "p", "informative_feature_count",
        "informative_feature_fraction", "loading_norm", "covariance_regime",
        "signal_strength", "noise_sd", "recovery_boundary",
        "execution_completed", "target_loading_cosine", "recovery_evaluable",
        "recovery_met", "nominated_component", "proposal_available",
        "axis_mean_absolute_similarity", "axis_refits_requested",
        "axis_refits_completed", "downstream_estimable", "diagnostic"
    )
    payload <- unclass(x)
    observed_digest <- payload$digest
    payload$digest <- NULL
    valid <- inherits(x, "K1HighDimensionalAssessment") &&
        identical(names(x), expected_names) &&
        identical(x$version, "k1-high-dimensional-assessment-v1") &&
        identical(x$claim_status, "disclosed_calibration_only") &&
        is.data.frame(x$replicates) && nrow(x$replicates) > 0L &&
        identical(names(x$replicates), expected_rows) &&
        !anyDuplicated(x$replicates$task_id) &&
        identical(x$execution$account$n_requested,
            as.integer(nrow(x$replicates))) &&
        identical(x$execution$account$completed,
            x$replicates$execution_completed) &&
        identical(x$execution$account$failure_codes == "",
            x$replicates$execution_completed) &&
        identical(x$execution$account$n_completed,
            as.integer(sum(x$replicates$execution_completed))) &&
        identical(x$execution$account$n_failed,
            as.integer(sum(!x$replicates$execution_completed))) &&
        identical(x$execution$provenance$task_ids,
            x$replicates$task_id) &&
        identical(x$execution$digest, digest::digest(
            x$execution[c("values", "account", "provenance")],
            algo = "sha256", serialize = TRUE
        )) &&
        all(is.finite(x$replicates$recovery_boundary)) &&
        all(x$replicates$recovery_boundary > 0) &&
        all(x$replicates$informative_feature_count <= x$replicates$p) &&
        all(x$replicates$informative_feature_fraction > 0 &
            x$replicates$informative_feature_fraction <= 1) &&
        all(x$replicates$axis_refits_completed >= 0L) &&
        all(x$replicates$axis_refits_completed <=
            x$replicates$axis_refits_requested) &&
        all(x$replicates$boundary_position %in% c("below", "near", "above")) &&
        identical(.k1_high_dimensional_cell_summary(x$replicates), x$cells) &&
        identical(observed_digest, digest::digest(payload, algo = "sha256"))
    if (!isTRUE(valid)) {
        .stop_landscapeR_validation(
            "high-dimensional calibration evidence contract is invalid"
        )
    }
    values_match <- vapply(seq_len(nrow(x$replicates)), function(index) {
        value <- x$execution$values[[index]]
        observed <- x$replicates[index, , drop = FALSE]
        if (!observed$execution_completed[[1L]]) return(is.null(value))
        if (!is.list(value) || !is.data.frame(value$row) ||
                !is.list(value$evidence)) return(FALSE)
        expected <- value$row
        rownames(expected) <- NULL
        rownames(observed) <- NULL
        similarities <- value$evidence$bootstrap_similarities
        completed <- is.finite(similarities)
        generator <- value$evidence$generator
        valid_generator <- is.list(generator) &&
            identical(generator$n, observed$n[[1L]]) &&
            identical(generator$p, observed$p[[1L]]) &&
            identical(generator$informative_feature_count,
                observed$informative_feature_count[[1L]]) &&
            identical(generator$loading_norm, observed$loading_norm[[1L]]) &&
            identical(generator$covariance_regime,
                observed$covariance_regime[[1L]]) &&
            identical(generator$signal_strength,
                observed$signal_strength[[1L]]) &&
            identical(generator$noise_sd, observed$noise_sd[[1L]]) &&
            identical(generator$recovery_boundary,
                observed$recovery_boundary[[1L]]) &&
            identical(generator$boundary_position,
                observed$boundary_position[[1L]]) &&
            is.list(generator$planted_answer_key)
        identical(expected, observed) && valid_generator &&
            identical(value$evidence$generator$regime_id,
                observed$regime_id[[1L]]) &&
            identical(as.integer(sum(completed)),
                observed$axis_refits_completed[[1L]]) &&
            identical(if (any(completed)) mean(similarities[completed]) else
                NA_real_, observed$axis_mean_absolute_similarity[[1L]])
    }, logical(1L))
    if (any(!values_match)) {
        .stop_landscapeR_validation(
            "high-dimensional replicate evidence does not match its summary"
        )
    }
    invisible(TRUE)
}

#' Run governed high-dimensional K=1 calibration
#'
#' @param regime_ids governed regime identifiers.
#' @param feature_counts total feature counts.
#' @param signal_ratios planted per-loading coefficient relative to the
#'   analytic white-noise boundary. The effective signal also reflects loading
#'   norm, so it grows only in the coherent-information regime.
#' @param replicates deterministic repetitions per cell.
#' @param n biological observations per dataset.
#' @param informative_features informative features for sparse regimes.
#' @param noise_sd Gaussian noise scale.
#' @param module_correlation within-module noise correlation.
#' @param recovery_threshold disclosed loading-cosine threshold.
#' @param axis_resamples stratified biological-observation bootstrap refits.
#' @param seed package run seed.
#' @param sequential_internal execute in the current worker.
#' @param future_scheduling optional future.apply scheduling value.
#' @return Digest-bound `K1HighDimensionalAssessment`.
#' @export
run_k1_high_dimensional_calibration <- function(
    regime_ids = names(k1_high_dimensional_regime()),
    feature_counts = c(100L, 1000L, 10000L),
    signal_ratios = c(0, 0.75, 1, 1.25), replicates = 20L,
    n = 24L, informative_features = 10L, noise_sd = 1,
    module_correlation = 0.6, recovery_threshold = 0.9,
    axis_resamples = 19L, seed = 42L, sequential_internal = FALSE,
    future_scheduling = NULL
) {
    regimes <- k1_high_dimensional_regime()
    if (!is.character(regime_ids) || !length(regime_ids) ||
            any(!regime_ids %in% names(regimes)) ||
            !is.numeric(feature_counts) || !length(feature_counts) ||
            any(!vapply(feature_counts, .is_whole_number, logical(1L), 2L)) ||
            !is.numeric(signal_ratios) || !length(signal_ratios) ||
            any(!is.finite(signal_ratios)) || any(signal_ratios < 0) ||
            !.is_whole_number(replicates, 1L) ||
            !.is_whole_number(axis_resamples, 1L)) {
        .stop_landscapeR_validation(
            "high-dimensional calibration grid is invalid"
        )
    }
    grid <- expand.grid(
        regime_id = regime_ids, p = as.integer(feature_counts),
        signal_ratio = signal_ratios, replicate_index = seq_len(replicates),
        KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
    )
    grid <- grid[
        grid$regime_id != "null_near_null" | grid$signal_ratio <= 0.75,
        , drop = FALSE
    ]
    task_ids <- sprintf(
        "regime=%s;p=%d;ratio=%g;replicate=%04d",
        grid$regime_id, grid$p, grid$signal_ratio, grid$replicate_index
    )
    tasks <- split(grid, seq_len(nrow(grid)))
    execution <- .future_repetition(
        tasks, task_ids, seed, "standard",
        sequential_internal = sequential_internal,
        future_scheduling = future_scheduling,
        worker = function(task, task_id, stream) {
            count <- min(as.integer(informative_features), task$p[[1L]])
            result <- .k1_high_dimensional_assess_one(
                task$regime_id[[1L]], n, task$p[[1L]], count,
                task$signal_ratio[[1L]], noise_sd, module_correlation,
                axis_resamples, as.integer(stream[[2L]]), recovery_threshold
            )
            result$row <- cbind(
                task_id = task_id,
                replicate_index = task$replicate_index[[1L]],
                result$row, stringsAsFactors = FALSE
            )
            result
        }
    )
    rows <- lapply(seq_along(tasks), function(index) {
        if (execution$account$completed[[index]]) {
            return(execution$values[[index]]$row)
        }
        .k1_high_dimensional_failure_row(
            tasks[[index]], task_ids[[index]], n, informative_features,
            noise_sd, axis_resamples, module_correlation,
            execution$account$failure_codes[[index]]
        )
    })
    rows <- do.call(rbind, rows)
    rownames(rows) <- NULL
    payload <- list(
        version = "k1-high-dimensional-assessment-v1",
        claim_status = "disclosed_calibration_only",
        recovery_threshold = recovery_threshold,
        axis_resamples = as.integer(axis_resamples),
        scientific_context = list(
            sampling_unit = "independent synthetic biological observation",
            target_field = "condition",
            boundary = "noise_sd * (n * p)^(1/4) white-noise reference"
        ),
        execution = execution, replicates = rows,
        cells = .k1_high_dimensional_cell_summary(rows)
    )
    assessment <- structure(c(payload, list(
        digest = digest::digest(payload, algo = "sha256")
    )), class = c("K1HighDimensionalAssessment", "list"))
    .validate_k1_high_dimensional_assessment(assessment)
    assessment
}

#' Plot high-dimensional K=1 operating evidence
#'
#' @param assessment high-dimensional calibration assessment.
#' @return Publication-themed ggplot with exact displayed data and a separate
#'   dynamic scientific caption.
#' @export
plot_k1_high_dimensional_calibration <- function(assessment) {
    .validate_k1_high_dimensional_assessment(assessment)
    cells <- assessment$cells
    cells$effective_signal_ratio <-
        cells$signal_strength * ifelse(
            cells$regime_id == "growing_coherent",
            sqrt(cells$informative_feature_count), 1
        ) / cells$recovery_boundary
    display <- rbind(
        transform(cells, panel = "A  Target-axis recovery",
            value = recovery_probability),
        transform(cells, panel = "B  Axis identifiability",
            value = mean_axis_similarity)
    )
    display$panel <- factor(display$panel, levels = c(
        "A  Target-axis recovery", "B  Axis identifiability"
    ))
    display$regime_label <- factor(display$regime_label,
        levels = unique(cells$regime_label))
    regime_axis_labels <- c(
        fixed_total_spike = "Fixed total signal\nwith added noise",
        fixed_sparse = "Fixed sparse\ninformative set",
        growing_coherent = "Growing coherent\ninformation",
        correlated_modules = "Correlated feature\nmodules",
        null_near_null = "Null or near-null\nsignal"
    )
    display$regime_axis_label <- factor(
        unname(regime_axis_labels[display$regime_id]),
        levels = unname(regime_axis_labels[unique(cells$regime_id)])
    )
    display$state <- ifelse(is.finite(display$value),
        "Estimated", "Not estimable")
    display$plotted_value <- ifelse(is.finite(display$value),
        display$value, 0.03)
    semantic <- landscapeR_palette("semantic")
    plot <- ggplot2::ggplot(display, ggplot2::aes(
        x = .data$effective_signal_ratio, y = .data$plotted_value,
        group = interaction(.data$p, .data$regime_id)
    )) +
        ggplot2::geom_vline(xintercept = 1, colour = semantic[["structure"]],
            linewidth = 0.45) +
        ggplot2::geom_line(ggplot2::aes(linetype = factor(.data$p)),
            colour = semantic[["ink"]], linewidth = 0.35) +
        ggplot2::geom_point(ggplot2::aes(
            shape = .data$state, fill = .data$state
        ), colour = semantic[["ink"]], size = 2.1, stroke = 0.4) +
        ggplot2::facet_grid(.data$regime_axis_label ~ .data$panel) +
        ggplot2::scale_shape_manual(values = c(
            "Estimated" = 21, "Not estimable" = 4
        )) +
        ggplot2::scale_fill_manual(values = c(
            "Estimated" = semantic[["focal"]], "Not estimable" = NA
        )) +
        ggplot2::scale_linetype_discrete(labels = function(x) {
            format(as.integer(x), big.mark = ",")
        }) +
        ggplot2::scale_x_continuous(
            breaks = pretty(display$effective_signal_ratio, n = 4L)
        ) +
        ggplot2::scale_y_continuous(limits = c(0, 1),
            breaks = c(0, 0.5, 1)) +
        ggplot2::labs(
            x = "Effective signal relative to the recovery boundary",
            y = "Observed probability or similarity", linetype = "Features",
            shape = NULL, fill = NULL
        ) +
        theme_landscapeR(square = FALSE) +
        ggplot2::theme(
            legend.position = "bottom",
            strip.text.y = ggplot2::element_text(size = 5.5)
        )
    regimes <- unique(tolower(as.character(cells$regime_label)))
    caption_view <- .new_scientific_caption_view(
        title = "High-dimensional signal-recovery operating evidence",
        experiment_label = paste(regimes, collapse = "; "),
        target_field = assessment$scientific_context$target_field,
        oriented_levels = c("reference", "target"),
        sampling_unit = assessment$scientific_context$sampling_unit,
        panels = c(
            A = "Probability that the planted target loading was recovered",
            B = paste("Mean absolute loading cosine for the planted target",
                "under target-stratified biological-unit bootstrap")
        ),
        encodings = c(
            paste("Red circles show exact cell summaries and black lines join",
                "equal feature counts within a signal regime"),
            paste("The pale vertical line marks the analytic white-noise",
                "reference; crosses mark quantities that were not estimable")
        ),
        estimand = "recovery of a planted feature-loading direction",
        design = sprintf(
            "%d independent observations; feature count and information structure vary independently",
            unique(cells$n)[[1L]]
        ),
        uncertainty = sprintf(
            "%d outer executions and %d of %d target-axis refits completed",
            sum(cells$n_execution_completed),
            sum(cells$n_execution_completed * assessment$axis_resamples),
            sum(cells$n_requested * assessment$axis_resamples)
        ),
        threshold = sprintf(
            "Panel A uses an absolute loading-cosine threshold of %.2f",
            assessment$recovery_threshold
        ),
        missingness = paste(
            "Component nomination and downstream estimability remain in the",
            "exact cell table but are not repeated on this primary recovery map"
        ),
        claim_boundary = paste(
            "The analytic white-noise reference is a disclosed simulation",
            "coordinate, not a biological acceptance threshold or universal",
            "sample-size rule"
        ),
        state = if (assessment$execution$account$n_failed) "partial" else
            "calibrated"
    )
    plot <- .with_scientific_caption(plot,
        .build_scientific_caption(caption_view))
    attr(plot, "landscapeR_k1_high_dimensional_map_data") <- display
    plot
}

.k1_high_dimensional_artifact_files <- function() c(
    "assessment.rds", "replicates.csv", "cell-summary.csv",
    "operating-map-data.csv", "operating-map.png",
    "operating-map-caption.txt", "environment.rds"
)

.verify_k1_high_dimensional_artifact <- function(artifact) {
    artifact <- path.expand(artifact)
    manifest_path <- file.path(artifact, "MANIFEST.tsv")
    if (!dir.exists(artifact) || !file.exists(manifest_path)) {
        .k1_acceptance_runner_abort(
            "high-dimensional calibration artifact is incomplete"
        )
    }
    manifest <- utils::read.delim(manifest_path,
        stringsAsFactors = FALSE, check.names = FALSE)
    governed <- .k1_high_dimensional_artifact_files()
    actual <- list.files(artifact, recursive = TRUE, all.files = TRUE,
        no.. = TRUE, include.dirs = FALSE)
    valid_manifest <- identical(names(manifest), c("file", "sha256")) &&
        identical(manifest$file, governed) && !anyNA(manifest) &&
        !anyDuplicated(manifest$file) &&
        !any(grepl("(^|/)[.][.](/|$)|^/", manifest$file)) &&
        setequal(actual, c("MANIFEST.tsv", governed)) &&
        identical(unname(vapply(file.path(artifact, governed),
            .k1_acceptance_file_digest, character(1L))), manifest$sha256)
    if (!valid_manifest) {
        .k1_acceptance_runner_abort(
            "high-dimensional artifact manifest or files are invalid"
        )
    }
    assessment <- readRDS(file.path(artifact, "assessment.rds"))
    environment <- readRDS(file.path(artifact, "environment.rds"))
    .validate_k1_high_dimensional_assessment(assessment)
    .k1_acceptance_validate_identity(environment$runtime_identity)
    plot <- plot_k1_high_dimensional_calibration(assessment)
    temporary <- tempfile(fileext = c("-replicates.csv", "-cells.csv", "-map.csv"))
    on.exit(unlink(temporary), add = TRUE)
    utils::write.csv(assessment$replicates, temporary[[1L]], row.names = FALSE)
    utils::write.csv(assessment$cells, temporary[[2L]], row.names = FALSE)
    display <- attr(plot, "landscapeR_k1_high_dimensional_map_data")
    display$panel <- as.character(display$panel)
    display$regime_label <- as.character(display$regime_label)
    utils::write.csv(display, temporary[[3L]], row.names = FALSE)
    same_lines <- function(expected, observed) identical(
        readLines(expected, warn = FALSE), readLines(observed, warn = FALSE)
    )
    caption <- paste(readLines(file.path(
        artifact, "operating-map-caption.txt"
    ), warn = FALSE), collapse = "\n")
    expected_environment <- list(
        assessment_digest = assessment$digest,
        runtime_identity = environment$runtime_identity,
        claim_status = assessment$claim_status
    )
    artifact_digest <- .k1_acceptance_artifact_digest(manifest)
    valid_derivatives <-
        same_lines(temporary[[1L]], file.path(artifact, "replicates.csv")) &&
        same_lines(temporary[[2L]], file.path(artifact, "cell-summary.csv")) &&
        same_lines(temporary[[3L]], file.path(artifact, "operating-map-data.csv")) &&
        identical(caption, scientific_caption(plot)) &&
        identical(environment, expected_environment) &&
        identical(basename(artifact), paste0(
            assessment$version, "-", substr(artifact_digest, 1L, 16L)
        ))
    if (!valid_derivatives) {
        .k1_acceptance_runner_abort(
            "high-dimensional artifact derivatives do not reproduce"
        )
    }
    invisible(TRUE)
}

#' Publish high-dimensional K=1 calibration evidence
#'
#' @param artifact_root publication directory.
#' @param assessment output from [run_k1_high_dimensional_calibration()].
#' @return Verified content-addressed artifact path.
#' @export
publish_k1_high_dimensional_calibration <- function(artifact_root, assessment) {
    .validate_k1_high_dimensional_assessment(assessment)
    if (!.is_scalar_nonempty_text(artifact_root)) {
        .stop_landscapeR_validation("artifact_root must be one non-empty path")
    }
    artifact_root <- path.expand(artifact_root)
    dir.create(artifact_root, recursive = TRUE, showWarnings = FALSE)
    staging <- tempfile(".k1-high-dimensional-tmp-", tmpdir = artifact_root)
    dir.create(staging, recursive = TRUE, showWarnings = FALSE)
    on.exit(if (dir.exists(staging)) unlink(staging, recursive = TRUE), add = TRUE)
    plot <- plot_k1_high_dimensional_calibration(assessment)
    saveRDS(assessment, file.path(staging, "assessment.rds"))
    utils::write.csv(assessment$replicates,
        file.path(staging, "replicates.csv"), row.names = FALSE)
    utils::write.csv(assessment$cells,
        file.path(staging, "cell-summary.csv"), row.names = FALSE)
    display <- attr(plot, "landscapeR_k1_high_dimensional_map_data")
    display$panel <- as.character(display$panel)
    display$regime_label <- as.character(display$regime_label)
    utils::write.csv(display, file.path(staging, "operating-map-data.csv"),
        row.names = FALSE)
    ggplot2::ggsave(file.path(staging, "operating-map.png"), plot,
        width = 160, height = 160, units = "mm", dpi = 450, bg = "white")
    writeLines(scientific_caption(plot),
        file.path(staging, "operating-map-caption.txt"))
    saveRDS(list(
        assessment_digest = assessment$digest,
        runtime_identity = .k1_calibration_runtime_identity(),
        claim_status = assessment$claim_status
    ), file.path(staging, "environment.rds"))
    governed <- .k1_high_dimensional_artifact_files()
    manifest <- data.frame(
        file = governed,
        sha256 = vapply(file.path(staging, governed),
            .k1_acceptance_file_digest, character(1L)),
        stringsAsFactors = FALSE
    )
    artifact_digest <- .k1_acceptance_artifact_digest(manifest)
    artifact <- file.path(artifact_root, paste0(
        assessment$version, "-", substr(artifact_digest, 1L, 16L)
    ))
    if (dir.exists(artifact)) {
        .verify_k1_high_dimensional_artifact(artifact)
        return(artifact)
    }
    utils::write.table(manifest, file.path(staging, "MANIFEST.tsv"),
        sep = "\t", quote = FALSE, row.names = FALSE)
    if (!file.rename(staging, artifact)) {
        .k1_acceptance_runner_abort(
            "could not atomically publish high-dimensional artifact"
        )
    }
    .verify_k1_high_dimensional_artifact(artifact)
    artifact
}

#' Verify high-dimensional K=1 calibration evidence
#'
#' @param artifact path returned by
#'   [publish_k1_high_dimensional_calibration()].
#' @return Invisibly `TRUE`, or an error for changed evidence.
#' @export
verify_k1_high_dimensional_calibration <- function(artifact) {
    .verify_k1_high_dimensional_artifact(path.expand(artifact))
}

#' Declare the backend-neutral high-dimensional calibration graph
#'
#' @param artifact_root absolute shared publication directory.
#' @param controller named crew controller configured by the caller.
#' @param ... scientific arguments forwarded to
#'   [run_k1_high_dimensional_calibration()].
#' @return List of targets objects.
#' @export
k1_high_dimensional_calibration_targets <- function(
    artifact_root, controller = "k1-high-dimensional", ...
) {
    if (!requireNamespace("targets", quietly = TRUE)) {
        .stop_landscapeR_validation(
            "calibration orchestration requires optional package 'targets'"
        )
    }
    if (!.is_scalar_nonempty_text(artifact_root) ||
            !grepl("^/", path.expand(artifact_root)) ||
            !.is_scalar_nonempty_text(controller)) {
        .stop_landscapeR_validation(
            "artifact_root must be absolute and controller must be non-empty"
        )
    }
    arguments <- list(...)
    run_call <- as.call(c(
        list(quote(landscapeR::run_k1_high_dimensional_calibration)),
        arguments, list(sequential_internal = TRUE)
    ))
    list(
        .k1_acceptance_target(
            "k1_high_dimensional_assessment", run_call,
            deployment = "worker", controller = controller
        ),
        .k1_acceptance_target(
            "k1_high_dimensional_artifact",
            substitute(
                landscapeR::publish_k1_high_dimensional_calibration(
                    ROOT, k1_high_dimensional_assessment
                ), list(ROOT = path.expand(artifact_root))
            ), format = "file"
        )
    )
}
