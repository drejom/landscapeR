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

.k1_high_dimensional_noise_reference <- function(
    regime, n, p, noise_sd, module_correlation
) {
    if (is.character(regime)) regime <- k1_high_dimensional_regime(regime)
    covariance_scale <- 1
    if (identical(regime$covariance_regime,
            "block-correlated-gaussian")) {
        module_size <- min(20L, as.integer(p))
        covariance_scale <- sqrt(1 + (module_size - 1) * module_correlation)
    }
    noise_sd * (n * p)^0.25 * covariance_scale
}

.k1_high_dimensional_child_seed <- function(stream, task_id) {
    if (!is.integer(stream) || length(stream) != 7L ||
            !.is_scalar_nonempty_text(task_id)) {
        .stop_landscapeR_validation("high-dimensional task stream is invalid")
    }
    hash <- digest::digest(list(stream = stream, task_id = task_id),
        algo = "sha256", serialize = TRUE)
    as.integer(strtoi(substr(hash, 1L, 7L), base = 16L))
}

#' Generate a governed high-dimensional K=1 control
#'
#' Separates total feature count from the number of biologically informative
#' features. The planted loading and covariance-aware noise reference are
#' retained as calibration evidence; neither constitutes a biological
#' sample-size rule.
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
    boundary <- .k1_high_dimensional_noise_reference(
        regime, n, p, noise_sd, module_correlation
    )
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
