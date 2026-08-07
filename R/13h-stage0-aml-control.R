# Stage 0 — AML-shaped K=1 longitudinal confounder-separation control
#
# This is a disclosed calibration control for ADR 0016 / issue #67.  It uses
# the production SVD, repeated-subject association, proposal, and capability
# contracts; it does not encode acceptance thresholds or consume hidden seeds.

.aml_k1_default_times <- function() {
    c(0, 6, 10, 14.6, 19, 23.4, 27.6, 31.6, 34.7, 38.7, 43.6)
}

.aml_k1_control_validation <- function(
    subjects_per_condition, times, p, noise_sd, time_signal,
    disease_signal, seed
) {
    if (!.is_whole_number(subjects_per_condition, 3L))
        return("subjects_per_condition must be an integer of at least 3")
    if (!is.numeric(times) || length(times) < 3L ||
        any(!is.finite(times)) || anyDuplicated(times))
        return("times must contain at least three distinct finite numbers")
    if (!.is_whole_number(p, 2L))
        return("p must be a single integer greater than or equal to 2")
    for (argument in list(noise_sd = noise_sd,
                          time_signal = time_signal,
                          disease_signal = disease_signal)) {
        if (!is.numeric(argument) || length(argument) != 1L ||
            !is.finite(argument) || argument <= 0)
            return(paste0(names(argument),
                          " must be a single finite number greater than 0"))
    }
    if (time_signal <= disease_signal)
        return("time_signal must be greater than disease_signal")
    if (!.is_whole_number(seed, 0L, .Machine$integer.max - 3L))
        return(paste0(
            "seed must be a single integer between 0 and ",
            .Machine$integer.max - 3L
        ))
    NULL
}

.aml_k1_orthogonal_target <- function(condition, time) {
    condition <- as.numeric(condition == "CM")
    design <- cbind(1, as.numeric(time), condition)
    raw <- condition * as.numeric(time)
    residual <- raw - design %*% qr.solve(design, raw)
    as.numeric(residual / sqrt(sum(residual^2)))
}

#' Generate an AML-shaped repeated-subject K=1 calibration control
#'
#' The control has repeated synthetic mice in CTL and disease groups.  Its
#' first planted sample axis is a stronger AML-informed collection-time
#' confounder, while its second planted axis is a non-dominant condition-by-time
#' disease divergence.  Times are the irregular week values used by the
#' packaged GSE133642 sample-weeks mapping.  The resulting object is intended
#' for disclosed calibration only; it carries truth and provenance but no
#' scientific acceptance judgement.
#'
#' @param subjects_per_condition number of synthetic mice per condition
#' @param times irregular collection times in AML weeks
#' @param p number of expression features
#' @param noise_sd expression noise standard deviation
#' @param time_signal singular-score scale for the dominant time axis
#' @param disease_signal singular-score scale for the non-dominant target axis
#' @param dropout_subjects optional subject IDs whose final observation is
#'   removed
#' @param seed reproducibility seed
#' @return a repeated-subject \code{StateTransitionData} with
#'   \code{SubspaceGroundTruth} and AML control metadata
#' @export
synthetic_k1_aml_longitudinal_control <- function(
    subjects_per_condition = 12L,
    times = .aml_k1_default_times(),
    p = 100L,
    noise_sd = 0.03,
    time_signal = 8,
    disease_signal = 3,
    dropout_subjects = character(),
    seed = 42L
) {
    validation_message <- .aml_k1_control_validation(
        subjects_per_condition, times, p, noise_sd,
        time_signal, disease_signal, seed
    )
    if (!is.null(validation_message))
        .stop_landscapeR_validation(paste0(
            "synthetic_k1_aml_longitudinal_control(): ", validation_message
        ))
    if (!is.character(dropout_subjects) || anyNA(dropout_subjects))
        .stop_landscapeR_validation(
            "dropout_subjects must be a character vector without missing values"
        )

    setup_rng(seed)
    conditions <- c("CTL", "CM")
    subjects <- unlist(lapply(conditions, function(condition) {
        paste0(if (condition == "CTL") "ctl" else "cm",
               seq_len(subjects_per_condition))
    }), use.names = FALSE)
    unknown_dropout <- setdiff(dropout_subjects, subjects)
    if (length(unknown_dropout) > 0L)
        .stop_landscapeR_validation(paste0(
            "dropout_subjects contains unknown subject IDs: ",
            paste(unknown_dropout, collapse = ", ")
        ))
    subject_condition <- rep(conditions, each = subjects_per_condition)
    rows <- do.call(rbind, lapply(seq_along(subjects), function(i) {
        observed <- times
        if (subjects[[i]] %in% dropout_subjects) {
            if (length(observed) < 4L)
                .stop_landscapeR_validation(
                    "dropout requires at least four declared time points"
                )
            observed <- observed[-length(observed)]
        }
        data.frame(
            mouse_id = subjects[[i]],
            condition = subject_condition[[i]],
            weeks = observed,
            stringsAsFactors = FALSE
        )
    }))
    rows$condition <- factor(rows$condition, levels = conditions)
    n <- nrow(rows)

    time_score <- as.numeric(scale(rows$weeks, center = TRUE, scale = TRUE))
    subject_index <- match(rows$mouse_id, subjects)
    subject_within_condition <- ((subject_index - 1L) %%
        subjects_per_condition) + 1L
    centred_subject <- as.numeric(scale(
        subject_within_condition, center = TRUE, scale = TRUE
    ))
    time_intercept <- sin(1.7 * subject_within_condition)
    time_slope <- cos(0.9 * subject_within_condition)
    time_score <- time_score + 0.20 * time_intercept +
        0.18 * time_slope * time_score
    time_score <- as.numeric(time_score / sqrt(sum(time_score^2)))
    condition_numeric <- as.numeric(rows$condition == "CM")
    target_intercept <- cos(1.3 * subject_within_condition)
    target_slope <- sin(0.8 * subject_within_condition)
    target_raw <- condition_numeric * rows$weeks +
        2.00 * target_intercept +
        0.40 * target_slope * rows$weeks
    target_design <- cbind(1, rows$weeks, condition_numeric)
    target_score <- target_raw -
        target_design %*% qr.solve(target_design, target_raw)
    target_score <- as.numeric(target_score / sqrt(sum(target_score^2)))

    # Feature loadings are orthonormal, so the two planted sample axes remain
    # identifiable by the registered SVD while noise makes the case realistic.
    v_true <- qr.Q(qr(matrix(rnorm(p * 2L), p, 2L)))[, seq_len(2L), drop = FALSE]
    colnames(v_true) <- c("collection_time", "condition_by_time")
    scores <- cbind(time_signal * time_score, disease_signal * target_score)
    X <- scores %*% t(v_true) + matrix(rnorm(n * p, sd = noise_sd), n, p)
    sample_ids <- sprintf("sample_%03d", seq_len(n))
    assay_ids <- sprintf("rna_%03d", seq_len(n))
    feature_ids <- sprintf("gene_%04d", seq_len(p))
    rownames(v_true) <- feature_ids
    colnames(scores) <- colnames(v_true)
    rownames(scores) <- sample_ids
    expression <- t(X)
    dimnames(expression) <- list(feature_ids, assay_ids)
    experiment <- SummarizedExperiment::SummarizedExperiment(
        assays = list(logcounts = expression)
    )
    metadata_frame <- S4Vectors::DataFrame(
        condition = rows$condition,
        weeks = rows$weeks,
        mouse_id = rows$mouse_id,
        batch = factor(ifelse(subject_index %% 2L, "run_a", "run_b")),
        row.names = sample_ids
    )
    std <- StateTransitionData(
        experiments = list(rna = experiment),
        colData = metadata_frame,
        sampleMap = S4Vectors::DataFrame(
            assay = factor(rep("rna", n), levels = "rna"),
            primary = sample_ids,
            colname = assay_ids
        )
    )
    std <- declare_sampling_design(
        std,
        longitudinal("mouse_id", "weeks", "weeks")
    )
    truth <- new("SubspaceGroundTruth",
        shared = v_true,
        exclusive = list(),
        angles = c(0, 0)
    )
    std@ground_truth <- truth
    md <- metadata(std)
    md$aml_k1_control <- list(
        n = n,
        p = as.integer(p),
        K = 1L,
        subjects_per_condition = as.integer(subjects_per_condition),
        conditions = conditions,
        times = as.numeric(times),
        time_source = if (identical(as.numeric(times),
                                    .aml_k1_default_times())) {
            "inst/extdata/gse133642-sample-weeks.csv"
        } else {
            "user-supplied"
        },
        target_component = 2L,
        nuisance_component = 1L,
        target_axis = "condition-by-time disease divergence",
        nuisance_axis = "collection-time confounder",
        target_orientation = paste(
            "positive scores indicate greater CM-versus-CTL",
            "trajectory divergence"
        ),
        planted_sample_scores = scores,
        dropout_subjects = dropout_subjects,
        time_signal = time_signal,
        disease_signal = disease_signal,
        noise_sd = noise_sd,
        seed = as.integer(seed),
        calibration_only = TRUE,
        evidence_status = "non_evidentiary_calibration",
        claim_status = "non_evidentiary_calibration"
    )
    metadata(std) <- md
    record_provenance(
        std,
        stage = "generate_control",
        contract = "SyntheticControlGenerator",
        implementation = "k1_aml_longitudinal",
        params = md$aml_k1_control,
        rng = .generator_rng_identity(
            seed, "synthetic_k1_aml_longitudinal_control",
            c(expression = seed)
        ),
        input_hashes = c(
            specification = digest::digest(md$aml_k1_control, algo = "sha256")
        )
    )
}

.aml_k1_calibration_config <- function() {
    specification <- analysis_specification(
        id = "synthetic-aml-k1-longitudinal",
        target_field = "condition",
        target_type = "binary",
        reference_level = "CTL",
        comparison_level = "CM",
        nuisance_fields = "batch",
        claim_intent = "exploratory"
    )
    PipelineConfig(
        dataset = "synthetic_aml_k1_longitudinal",
        analysis = specification,
        strategies = list(
            Decomposer = "svd",
            DynamicsEstimator = "kde_logdensity"
        ),
        params = list(
            svd = list(k_components = 6L),
            kde_logdensity = list()
        )
    )
}

.aml_k1_strategy <- function(config, contract) {
    implementation <- config@strategies[[contract]]
    if (is.null(implementation))
        .stop_landscapeR_validation(paste0(
            "config must declare a ", contract, " strategy"
        ))
    constructor <- get_strategy(contract, implementation)
    constructor(config@params[[implementation]] %||% list())
}

.aml_k1_recovery <- function(fitted, truth) {
    loadings <- dr_V_k(stage_artifact(fitted, "stage1"))
    expected <- truth@shared[, seq_len(2L), drop = FALSE]
    observed <- loadings[, seq_len(2L), drop = FALSE]
    signed_cosines <- vapply(seq_len(2L), function(i) {
        sum(expected[, i] * observed[, i]) /
            sqrt(sum(expected[, i]^2) * sum(observed[, i]^2))
    }, numeric(1L))
    angles <- .principal_angles(expected, observed) * 180 / pi
    list(
        component = c(1L, 2L),
        planted_axis = colnames(expected),
        signed_loading_cosine = signed_cosines,
        absolute_loading_cosine = abs(signed_cosines),
        orientation = ifelse(signed_cosines >= 0, "same", "reversed"),
        subspace_principal_angle_degrees = angles,
        claim_status = "non_evidentiary_calibration"
    )
}

#' Run the AML-shaped K=1 calibration workflow
#'
#' Runs registered \code{svd}, repeated-subject association, proposal ranking,
#' and the cross-sectional Stage 2 capability gate.  The returned list is
#' diagnostic evidence only and contains no threshold or acceptance decision.
#'
#' @inheritParams synthetic_k1_aml_longitudinal_control
#' @param n_resamples number of biological-unit bootstrap refits
#' @param n_permutations number of search-aware permutations
#' @param config optional code{PipelineConfig}; defaults to the disclosed SVD
#'   and KDE configuration for this control
#' @return named calibration diagnostics with the generated control, atlas,
#'   proposal, and typed Stage 2 ineligibility result
#' @export
k1_aml_longitudinal_calibration <- function(
    subjects_per_condition = 12L,
    times = .aml_k1_default_times(),
    p = 100L,
    noise_sd = 0.03,
    time_signal = 8,
    disease_signal = 3,
    dropout_subjects = character(),
    seed = 42L,
    n_resamples = 9L,
    n_permutations = 0L,
    config = NULL
) {
    if (!.is_whole_number(n_resamples, 0L))
        .stop_landscapeR_validation(
            "n_resamples must be a non-negative integer"
        )
    if (!.is_whole_number(n_permutations, 0L))
        .stop_landscapeR_validation(
            "n_permutations must be a non-negative integer"
        )
    if (is.null(config))
        config <- .aml_k1_calibration_config()
    if (!is(config, "PipelineConfig"))
        .stop_landscapeR_validation("config must be a PipelineConfig")
    std <- synthetic_k1_aml_longitudinal_control(
        subjects_per_condition = subjects_per_condition,
        times = times, p = p, noise_sd = noise_sd,
        time_signal = time_signal, disease_signal = disease_signal,
        dropout_subjects = dropout_subjects, seed = seed
    )
    decomposition <- decompose(
        .aml_k1_strategy(config, "Decomposer"), std
    )
    if (decomposition@status != "success") {
        return(list(
            status = "failure",
            evidence_status = "non_evidentiary_calibration",
            reason = decomposition@reason,
            control = std,
            decomposition = decomposition
        ))
    }
    fitted <- decomposition@value
    specification <- config@analysis
    atlas <- associate_metadata(
        fitted,
        specification = specification,
        non_analytical_fields = c("mouse_id", "batch"),
        # Association refits and decomposition alignment are separate
        # evidence layers.  Keep proposal ranking on the complete discovery
        # atlas; the identifiability assessment below owns decomposition
        # refits and loading alignment.
        n_resamples = 0L,
        seed = seed + 1L
    )
    proposal <- propose_component(
        atlas,
        n_permutations = n_permutations,
        seed = seed + 2L
    )
    identifiability <- if (n_resamples > 0L &&
                           is(proposal, "ComponentProposal")) {
        assess_component_identifiability(
            data = std,
            proposal = proposal,
            config = config,
            non_analytical_fields = c("mouse_id", "batch"),
            n_resamples = n_resamples,
            seed = seed + 3L
        )
    } else {
        NULL
    }
    stage2 <- estimate_dynamics(
        .aml_k1_strategy(config, "DynamicsEstimator"), fitted
    )
    recovery <- .aml_k1_recovery(fitted, std@ground_truth)
    list(
        status = "success",
        evidence_status = "non_evidentiary_calibration",
        control = std,
        decomposition = decomposition,
        atlas = atlas,
        proposal = proposal,
        config = config,
        identifiability = identifiability,
        identifiability_evidence = if (is(identifiability,
                                          "ComponentProposal")) {
            proposal_identifiability(identifiability)
        } else {
            NULL
        },
        recovery = recovery,
        stage2 = stage2,
        target_component = 2L,
        nuisance_component = 1L,
        seed = as.integer(seed)
    )
}
