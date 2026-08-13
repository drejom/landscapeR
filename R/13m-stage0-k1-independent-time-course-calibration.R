# Stage 0 K=1 independent destructive-time-course calibration (#189)

.k1_independent_time_conditions <- c("CTL", "CM")
.k1_independent_time_default_times <- c(0, 1, 2, 3)
.k1_independent_time_template_version <-
    "k1-independent-time-course-templates-v1"

#' Ground truth for independent destructive-time-course calibration
#'
#' @export
setClass("K1IndependentTimeCourseGroundTruth",
    contains = "GroundTruth",
    representation(
        subspace = "SubspaceGroundTruth",
        sample_scores = "matrix",
        target_component = "integer",
        nuisance_component = "integer",
        target_orientation = "character"
    )
)

setValidity("K1IndependentTimeCourseGroundTruth", function(object) {
    errors <- character()
    if (ncol(object@sample_scores) != 2L ||
            any(!is.finite(object@sample_scores))) {
        errors <- c(errors, "sample_scores must be a finite two-column matrix")
    }
    if (!identical(object@target_component, 2L)) {
        errors <- c(errors, "target_component must be component 2")
    }
    if (!identical(object@nuisance_component, 1L)) {
        errors <- c(errors, "nuisance_component must be component 1")
    }
    if (!.is_scalar_nonempty_text(object@target_orientation)) {
        errors <- c(errors, "target_orientation must be one non-empty string")
    }
    if (length(errors)) errors else TRUE
})

.k1_independent_time_template_matrix <- function(values) {
    matrix(
        as.integer(values),
        nrow = 2L,
        byrow = TRUE,
        dimnames = list(
            .k1_independent_time_conditions,
            as.character(.k1_independent_time_default_times)
        )
    )
}

.k1_independent_time_template_payload <- function() {
    list(
        balanced_1 = list(
            label = "One animal per condition-time cell",
            intended = .k1_independent_time_template_matrix(rep(1L, 8L)),
            removals = data.frame(
                condition = character(), time = numeric(), replicate = integer(),
                reason = character(), stringsAsFactors = FALSE
            ),
            missingness = "complete"
        ),
        balanced_2 = list(
            label = "Two animals per condition-time cell",
            intended = .k1_independent_time_template_matrix(rep(2L, 8L)),
            removals = data.frame(
                condition = character(), time = numeric(), replicate = integer(),
                reason = character(), stringsAsFactors = FALSE
            ),
            missingness = "complete"
        ),
        balanced_3 = list(
            label = "Three animals per condition-time cell",
            intended = .k1_independent_time_template_matrix(rep(3L, 8L)),
            removals = data.frame(
                condition = character(), time = numeric(), replicate = integer(),
                reason = character(), stringsAsFactors = FALSE
            ),
            missingness = "complete"
        ),
        unequal_1_2_3 = list(
            label = "Unequal one-to-three-animal cells",
            intended = .k1_independent_time_template_matrix(c(
                1L, 2L, 3L, 2L,
                3L, 2L, 1L, 2L
            )),
            removals = data.frame(
                condition = character(), time = numeric(), replicate = integer(),
                reason = character(), stringsAsFactors = FALSE
            ),
            missingness = "unequal_declared_cells"
        ),
        isolated_library_failure = list(
            label = "Three-animal cells with one failed library",
            intended = .k1_independent_time_template_matrix(rep(3L, 8L)),
            removals = data.frame(
                condition = "CM", time = 2, replicate = 3L,
                reason = "sequencing_library_failure",
                stringsAsFactors = FALSE
            ),
            missingness = "isolated_library_failure"
        ),
        missing_internal_cell = list(
            label = "Two-animal cells with one internal cell absent",
            intended = .k1_independent_time_template_matrix(c(
                2L, 2L, 2L, 2L,
                2L, 2L, 0L, 2L
            )),
            removals = data.frame(
                condition = character(), time = numeric(), replicate = integer(),
                reason = character(), stringsAsFactors = FALSE
            ),
            missingness = "missing_internal_condition_time_cell"
        )
    )
}

.validate_k1_independent_time_template <- function(template) {
    required <- c(
        "version", "id", "label", "conditions", "times", "intended_cells",
        "retained_cells", "removed_observations", "missingness",
        "sampling_design", "biological_unit"
    )
    if (!inherits(template, "K1IndependentTimeCourseTemplate") ||
            !identical(names(template), required) ||
            !identical(template$version,
                .k1_independent_time_template_version) ||
            !.is_scalar_nonempty_text(template$id) ||
            !.is_scalar_nonempty_text(template$label) ||
            !identical(template$conditions,
                .k1_independent_time_conditions) ||
            !identical(template$times,
                .k1_independent_time_default_times) ||
            !is.matrix(template$intended_cells) ||
            !is.matrix(template$retained_cells) ||
            !identical(dim(template$intended_cells), c(2L, 4L)) ||
            !identical(dim(template$retained_cells), c(2L, 4L)) ||
            anyNA(template$intended_cells) ||
            anyNA(template$retained_cells) ||
            any(template$intended_cells < 0L) ||
            any(template$retained_cells < 0L) ||
            any(template$retained_cells > template$intended_cells) ||
            !is.data.frame(template$removed_observations) ||
            !identical(names(template$removed_observations),
                c("condition", "time", "replicate", "reason")) ||
            !.is_scalar_nonempty_text(template$missingness) ||
            !identical(template$sampling_design,
                "independent_time_course") ||
            !identical(template$biological_unit,
                "one independently collected animal")) {
        .stop_landscapeR_validation(
            "independent time-course sampling template is invalid"
        )
    }
    invisible(TRUE)
}

#' Governed destructive-time-course calibration templates
#'
#' Declares complete, thin, unequal, and damaged sampling designs. Each matrix
#' entry is the number of independently collected animals in one
#' condition-time cell. A failed sequencing library is retained as an explicit
#' removal from its intended design rather than being recast as a smaller
#' balanced experiment.
#'
#' @param id optional template identifier. With `NULL`, returns every template.
#' @return A `K1IndependentTimeCourseTemplate`, or a named list of them.
#' @export
k1_independent_time_course_template <- function(id = NULL) {
    payload <- .k1_independent_time_template_payload()
    templates <- lapply(names(payload), function(template_id) {
        specification <- payload[[template_id]]
        retained <- specification$intended
        removals <- specification$removals
        if (nrow(removals)) {
            for (index in seq_len(nrow(removals))) {
                condition <- removals$condition[[index]]
                time <- as.character(removals$time[[index]])
                retained[condition, time] <-
                    retained[condition, time] - 1L
            }
        }
        template <- structure(list(
            version = .k1_independent_time_template_version,
            id = template_id,
            label = specification$label,
            conditions = .k1_independent_time_conditions,
            times = .k1_independent_time_default_times,
            intended_cells = specification$intended,
            retained_cells = retained,
            removed_observations = removals,
            missingness = specification$missingness,
            sampling_design = "independent_time_course",
            biological_unit = "one independently collected animal"
        ), class = c("K1IndependentTimeCourseTemplate", "list"))
        .validate_k1_independent_time_template(template)
        template
    })
    names(templates) <- names(payload)
    if (is.null(id)) return(templates)
    if (!.is_scalar_nonempty_text(id) || !id %in% names(templates)) {
        .stop_landscapeR_validation(sprintf(
            "unknown independent time-course template '%s'; choose one of: %s",
            paste(id, collapse = ""), paste(names(templates), collapse = ", ")
        ))
    }
    templates[[id]]
}

.k1_independent_time_rows <- function(template) {
    rows <- list()
    for (condition in template$conditions) {
        for (time in template$times) {
            size <- template$intended_cells[condition, as.character(time)]
            if (size == 0L) next
            rows[[length(rows) + 1L]] <- data.frame(
                condition = condition,
                time = time,
                replicate = seq_len(size),
                stringsAsFactors = FALSE
            )
        }
    }
    result <- do.call(rbind, rows)
    if (nrow(template$removed_observations)) {
        removal_keys <- with(template$removed_observations,
            paste(condition, time, replicate, sep = "\r"))
        observed_keys <- with(result,
            paste(condition, time, replicate, sep = "\r"))
        if (!all(removal_keys %in% observed_keys)) {
            .stop_landscapeR_validation(
                "sampling template removes an observation outside its intended design"
            )
        }
        result <- result[!observed_keys %in% removal_keys, , drop = FALSE]
    }
    rownames(result) <- NULL
    result
}

.k1_independent_time_validate_generator <- function(
    template, p, noise_sd, time_signal, condition_time_signal, seed
) {
    .validate_k1_independent_time_template(template)
    if (!.is_whole_number(p, 2L)) return("p must be an integer of at least 2")
    numeric_arguments <- list(
        noise_sd = noise_sd,
        time_signal = time_signal,
        condition_time_signal = condition_time_signal
    )
    invalid <- names(numeric_arguments)[!vapply(numeric_arguments,
        function(value) is.numeric(value) && length(value) == 1L &&
            is.finite(value) && value > 0, logical(1L))]
    if (length(invalid)) {
        return(sprintf("%s must be one finite number greater than zero",
            invalid[[1L]]))
    }
    if (time_signal <= condition_time_signal) {
        return("time_signal must be greater than condition_time_signal")
    }
    if (!.is_whole_number(seed, 0L, .Machine$integer.max - 3L)) {
        return("seed must be a non-negative integer with three stream offsets available")
    }
    NULL
}

#' Generate a K=1 independent destructive-time-course calibration control
#'
#' Generates a two-condition time course in which every retained observation
#' is a different biological animal. The first planted axis is collection time;
#' the second is the condition-by-time contrast. Declared missing cells and
#' library failures are applied before expression is generated, without
#' imputation, duplication, or balancing.
#'
#' @param template governed template or its identifier.
#' @param p number of expression features.
#' @param noise_sd independent Gaussian noise standard deviation.
#' @param time_signal scale of the dominant collection-time axis.
#' @param condition_time_signal scale of the target condition-by-time axis.
#' @param seed deterministic package seed.
#' @return A `StateTransitionData` with independent-time-course design, known
#'   feature-space truth, and a complete sampling audit.
#' @export
synthetic_k1_independent_time_course_control <- function(
    template = "balanced_3",
    p = 100L,
    noise_sd = 0.03,
    time_signal = 8,
    condition_time_signal = 3,
    seed = 42L
) {
    if (is.character(template)) {
        template <- k1_independent_time_course_template(template)
    }
    validation <- .k1_independent_time_validate_generator(
        template, p, noise_sd, time_signal, condition_time_signal, seed
    )
    if (!is.null(validation)) {
        .stop_landscapeR_validation(paste0(
            "synthetic_k1_independent_time_course_control(): ", validation
        ))
    }
    rows <- .k1_independent_time_rows(template)
    rows$condition <- factor(rows$condition, levels = template$conditions)
    rows$biological_unit <- sprintf("animal_%03d", seq_len(nrow(rows)))
    sample_ids <- sprintf("sample_%03d", seq_len(nrow(rows)))
    assay_ids <- sprintf("rna_%03d", seq_len(nrow(rows)))

    time_score <- as.numeric(scale(rows$time, center = TRUE, scale = TRUE))
    time_score <- time_score / sqrt(sum(time_score^2))
    condition <- as.numeric(rows$condition == "CM")
    target_raw <- condition * rows$time
    target_design <- cbind(1, rows$time, condition)
    target_score <- target_raw - target_design %*%
        qr.solve(target_design, target_raw)
    target_norm <- sqrt(sum(target_score^2))
    if (!is.finite(target_norm) || target_norm == 0) {
        .stop_landscapeR_validation(
            "sampling template cannot identify a condition-by-time target axis"
        )
    }
    target_score <- as.numeric(target_score / target_norm)

    setup_rng(seed)
    loadings <- qr.Q(qr(matrix(stats::rnorm(p * 2L), p, 2L)))[,
        seq_len(2L), drop = FALSE]
    colnames(loadings) <- c("collection_time", "condition_by_time")
    scores <- cbind(
        time_signal * time_score,
        condition_time_signal * target_score
    )
    colnames(scores) <- colnames(loadings)
    rownames(scores) <- sample_ids
    feature_ids <- sprintf("gene_%05d", seq_len(p))
    rownames(loadings) <- feature_ids
    expression <- t(scores %*% t(loadings) + matrix(
        stats::rnorm(nrow(rows) * p, sd = noise_sd), nrow(rows), p
    ))
    dimnames(expression) <- list(feature_ids, assay_ids)
    experiment <- SummarizedExperiment::SummarizedExperiment(
        assays = list(logcounts = expression)
    )
    metadata_frame <- S4Vectors::DataFrame(
        condition = rows$condition,
        collection_time = rows$time,
        biological_unit = rows$biological_unit,
        batch = factor(ifelse(seq_len(nrow(rows)) %% 2L, "run_a", "run_b")),
        row.names = sample_ids
    )
    std <- StateTransitionData(
        experiments = list(rna = experiment),
        colData = metadata_frame,
        sampleMap = S4Vectors::DataFrame(
            assay = factor(rep("rna", nrow(rows)), levels = "rna"),
            primary = sample_ids,
            colname = assay_ids
        )
    )
    std <- declare_sampling_design(
        std,
        independent_time_course("collection_time", "days")
    )
    std@ground_truth <- new("K1IndependentTimeCourseGroundTruth",
        subspace = new("SubspaceGroundTruth",
            shared = loadings, exclusive = list(), angles = c(0, 0)),
        sample_scores = scores,
        target_component = 2L,
        nuisance_component = 1L,
        target_orientation = paste(
            "positive planted scores indicate greater CM-versus-CTL",
            "change over collection time"
        )
    )
    sampling_audit <- list(
        template_version = template$version,
        template_id = template$id,
        template_label = template$label,
        intended_cells = template$intended_cells,
        retained_cells = template$retained_cells,
        removed_observations = template$removed_observations,
        missingness = template$missingness,
        n_intended = as.integer(sum(template$intended_cells)),
        n_retained = as.integer(sum(template$retained_cells)),
        effective_sampling_information = if (any(
                template$retained_cells == 0L)) 0 else
            1 / mean(1 / as.numeric(template$retained_cells)),
        sampling_design = template$sampling_design,
        biological_unit = template$biological_unit
    )
    md <- metadata(std)
    md$k1_independent_time_course_control <- list(
        n = nrow(rows), p = as.integer(p), K = 1L,
        conditions = template$conditions, times = template$times,
        target_component = 2L, nuisance_component = 1L,
        target_axis = "condition-by-time change",
        nuisance_axis = "collection time",
        noise_sd = noise_sd, time_signal = time_signal,
        condition_time_signal = condition_time_signal,
        seed = as.integer(seed), sampling = sampling_audit,
        calibration_only = TRUE,
        evidence_status = "disclosed_calibration",
        claim_status = "calibration_only_no_acceptance_claim"
    )
    metadata(std) <- md
    record_provenance(
        std,
        stage = "generate_control",
        contract = "SyntheticControlGenerator",
        implementation = "k1_independent_destructive_time_course_v1",
        params = md$k1_independent_time_course_control,
        rng = .generator_rng_identity(
            seed, "synthetic_k1_independent_time_course_control",
            c(expression = seed)
        ),
        input_hashes = c(
            template = digest::digest(template, algo = "sha256")
        )
    )
}

#' Inspect an independent destructive-time-course control
#'
#' @param x generated control.
#' @return Versioned generator and sampling metadata.
#' @export
k1_independent_time_course_control_info <- function(x) {
    if (!is(x, "StateTransitionData") ||
            !identical(x@sampling_design@kind, "independent_time_course") ||
            !is(x@ground_truth, "K1IndependentTimeCourseGroundTruth")) {
        .stop_landscapeR_validation(paste(
            "x must be a K=1 independent destructive-time-course",
            "calibration control"
        ))
    }
    info <- metadata(x)$k1_independent_time_course_control
    if (!is.list(info)) {
        .stop_landscapeR_validation(
            "independent time-course control metadata is unavailable"
        )
    }
    info
}

.k1_independent_time_config <- function() {
    PipelineConfig(
        dataset = "synthetic_k1_independent_time_course",
        analysis = analysis_specification(
            id = "synthetic-k1-independent-time-course",
            target_field = "condition",
            target_type = "binary",
            reference_level = "CTL",
            comparison_level = "CM",
            nuisance_fields = "batch",
            claim_intent = "exploratory"
        ),
        strategies = list(
            Decomposer = "svd",
            DynamicsEstimator = "kde_logdensity"
        ),
        params = list(
            svd = list(k_components = 2L),
            kde_logdensity = list()
        )
    )
}

.k1_independent_time_assess_one <- function(
    template_id, p, noise_sd, time_signal, condition_time_signal,
    seed, recovery_threshold
) {
    control <- synthetic_k1_independent_time_course_control(
        template = template_id,
        p = p,
        noise_sd = noise_sd,
        time_signal = time_signal,
        condition_time_signal = condition_time_signal,
        seed = seed
    )
    info <- k1_independent_time_course_control_info(control)
    config <- .k1_independent_time_config()
    decomposition <- decompose(
        .aml_k1_strategy(config, "Decomposer"), control
    )
    base <- list(
        template_id = template_id,
        template_label = info$sampling$template_label,
        missingness = info$sampling$missingness,
        p = as.integer(p),
        n_intended = info$sampling$n_intended,
        n_retained = info$sampling$n_retained,
        minimum_cell_size = as.integer(min(info$sampling$retained_cells)),
        maximum_cell_size = as.integer(max(info$sampling$retained_cells)),
        effective_sampling_information = as.numeric(
            info$sampling$effective_sampling_information
        ),
        execution_completed = FALSE,
        target_loading_cosine = NA_real_,
        recovery_evaluable = FALSE,
        recovery_met = NA,
        downstream_estimable = NA,
        missing_cell_count = as.integer(sum(
            info$sampling$retained_cells == 0L
        )),
        diagnostic = decomposition@reason,
        outcome = "execution_failure"
    )
    if (!identical(decomposition@status, "success")) return(base)
    fitted <- decomposition@value
    loadings <- dr_V_k(stage_artifact(fitted, "stage1"))
    truth <- control@ground_truth@subspace@shared[, 2L]
    estimate <- loadings[, 2L]
    cosine <- abs(sum(truth * estimate) /
        sqrt(sum(truth^2) * sum(estimate^2)))
    recovery_evaluable <- is.finite(cosine)
    recovery_met <- recovery_evaluable && cosine >= recovery_threshold
    atlas <- tryCatch(
        associate_metadata(
            fitted,
            specification = config@analysis,
            non_analytical_fields = c("biological_unit", "batch"),
            n_resamples = 0L,
            seed = seed + 1L,
            sequential_internal = TRUE
        ),
        error = function(condition) condition
    )
    target_rows <- if (is(atlas, "MetadataAssociationAtlas")) {
        associations <- atlas_associations(atlas)
        associations[
            associations$component == 2L &
                associations$proposal_eligible,
            , drop = FALSE
        ]
    } else data.frame()
    downstream_estimable <- nrow(target_rows) > 0L &&
        any(is.finite(target_rows$effect_magnitude))
    diagnostic <- if (!recovery_evaluable) {
        "target-loading cosine unavailable"
    } else if (!recovery_met) {
        "target-loading cosine below the disclosed calibration threshold"
    } else if (!downstream_estimable) {
        if (inherits(atlas, "condition")) conditionMessage(atlas) else {
            provenance <- if (is(atlas, "MetadataAssociationAtlas")) {
                atlas_provenance(atlas)
            } else list()
            missing <- provenance$time_course_missing_cell_count %||%
                info$sampling$missingness
            paste("independent time-course estimand not supported;",
                "missing-cell evidence:", missing)
        }
    } else ""
    outcome <- if (!recovery_evaluable) {
        "recovery_not_evaluable"
    } else if (!recovery_met) {
        "recovery_below_threshold"
    } else if (!downstream_estimable) {
        "recovered_downstream_nonestimable"
    } else {
        "recovered_and_estimable"
    }
    base$execution_completed <- TRUE
    base$target_loading_cosine <- cosine
    base$recovery_evaluable <- recovery_evaluable
    base$recovery_met <- recovery_met
    base$downstream_estimable <- if (recovery_met) {
        downstream_estimable
    } else NA
    base$diagnostic <- diagnostic
    base$outcome <- outcome
    base
}

.k1_independent_time_cell_summary <- function(replicates) {
    groups <- split(seq_len(nrow(replicates)), replicates$template_id)
    rows <- lapply(groups, function(index) {
        x <- replicates[index, , drop = FALSE]
        recovery_denominator <- sum(x$recovery_evaluable)
        recovered <- sum(x$recovery_met %in% TRUE)
        data.frame(
            template_id = x$template_id[[1L]],
            template_label = x$template_label[[1L]],
            missingness = x$missingness[[1L]],
            p = x$p[[1L]],
            n_intended = x$n_intended[[1L]],
            n_retained = x$n_retained[[1L]],
            minimum_cell_size = x$minimum_cell_size[[1L]],
            maximum_cell_size = x$maximum_cell_size[[1L]],
            effective_sampling_information =
                x$effective_sampling_information[[1L]],
            n_requested = nrow(x),
            n_execution_completed = sum(x$execution_completed),
            n_execution_failure = sum(!x$execution_completed),
            n_recovery_evaluable = recovery_denominator,
            n_recovered = recovered,
            recovery_probability = if (recovery_denominator) {
                recovered / recovery_denominator
            } else NA_real_,
            n_downstream_evaluable = recovered,
            n_downstream_estimable = sum(
                x$outcome == "recovered_and_estimable"
            ),
            downstream_estimability_probability = if (recovered) {
                sum(x$outcome == "recovered_and_estimable") / recovered
            } else NA_real_,
            stringsAsFactors = FALSE
        )
    })
    result <- do.call(rbind, rows)
    rownames(result) <- NULL
    result[match(unique(replicates$template_id), result$template_id), , drop = FALSE]
}

.validate_k1_independent_time_assessment <- function(x) {
    if (!inherits(x, "K1IndependentTimeCourseAssessment") ||
            !is.list(x) || !identical(names(x), c(
                "version", "claim_status", "recovery_threshold",
                "scientific_context", "execution", "replicates", "cells",
                "digest"
            ))) {
        .stop_landscapeR_validation(
            "independent time-course calibration assessment is invalid"
        )
    }
    payload <- unclass(x)
    digest <- payload$digest
    payload$digest <- NULL
    if (!identical(digest, digest::digest(payload, algo = "sha256"))) {
        .stop_landscapeR_validation(
            "independent time-course calibration assessment digest is invalid"
        )
    }
    invisible(TRUE)
}

#' Run the governed destructive-time-course calibration map
#'
#' Executes the same scientific tasks under the caller's current future plan.
#' It reports target-axis recovery independently from support for the declared
#' condition-by-time estimand. Results are disclosed calibration evidence, not
#' an acceptance result or a universal sample-size recommendation.
#'
#' @param template_ids governed template identifiers.
#' @param replicates number of deterministic calibration replicates per design.
#' @param p expression feature count.
#' @param noise_sd,time_signal,condition_time_signal generator parameters.
#' @param recovery_threshold disclosed absolute loading-cosine threshold.
#' @param seed package run seed.
#' @param sequential_internal run in the current worker, for targets/crew tasks.
#' @param future_scheduling optional future.apply scheduling value.
#' @return Digest-bound `K1IndependentTimeCourseAssessment`.
#' @export
run_k1_independent_time_course_calibration <- function(
    template_ids = names(k1_independent_time_course_template()),
    replicates = 20L,
    p = 100L,
    noise_sd = 0.03,
    time_signal = 8,
    condition_time_signal = 3,
    recovery_threshold = 0.9,
    seed = 42L,
    sequential_internal = FALSE,
    future_scheduling = NULL
) {
    templates <- k1_independent_time_course_template()
    if (!is.character(template_ids) || !length(template_ids) ||
            anyNA(template_ids) || anyDuplicated(template_ids) ||
            any(!template_ids %in% names(templates))) {
        .stop_landscapeR_validation(
            "template_ids must be unique governed destructive-time-course templates"
        )
    }
    if (!.is_whole_number(replicates, 1L) ||
            !is.numeric(recovery_threshold) ||
            length(recovery_threshold) != 1L ||
            !is.finite(recovery_threshold) || recovery_threshold <= 0 ||
            recovery_threshold > 1) {
        .stop_landscapeR_validation(
            "replicates and recovery_threshold are invalid"
        )
    }
    tasks <- unlist(lapply(template_ids, function(template_id) {
        lapply(seq_len(replicates), function(replicate_index) list(
            template_id = template_id,
            replicate_index = replicate_index
        ))
    }), recursive = FALSE)
    task_ids <- vapply(tasks, function(task) sprintf(
        "template=%s;replicate=%04d", task$template_id,
        task$replicate_index
    ), character(1L))
    execution <- .future_repetition(
        tasks = tasks,
        task_ids = task_ids,
        run_seed = seed,
        compute_tier = "standard",
        sequential_internal = sequential_internal,
        future_scheduling = future_scheduling,
        worker = function(task, task_id, stream) {
            result <- .k1_independent_time_assess_one(
                task$template_id, p, noise_sd, time_signal,
                condition_time_signal,
                seed = as.integer(stream[[2L]]),
                recovery_threshold = recovery_threshold
            )
            c(list(task_id = task_id,
                replicate_index = task$replicate_index), result)
        }
    )
    rows <- lapply(seq_along(tasks), function(index) {
        if (execution$account$completed[[index]]) {
            return(as.data.frame(execution$values[[index]],
                stringsAsFactors = FALSE))
        }
        template <- templates[[tasks[[index]]$template_id]]
        data.frame(
            task_id = task_ids[[index]],
            replicate_index = tasks[[index]]$replicate_index,
            template_id = template$id, template_label = template$label,
            missingness = template$missingness, p = as.integer(p),
            n_intended = sum(template$intended_cells),
            n_retained = sum(template$retained_cells),
            minimum_cell_size = min(template$retained_cells),
            maximum_cell_size = max(template$retained_cells),
            effective_sampling_information = if (
                any(template$retained_cells == 0L)) 0 else
                1 / mean(1 / as.numeric(template$retained_cells)),
            execution_completed = FALSE,
            target_loading_cosine = NA_real_, recovery_evaluable = FALSE,
            recovery_met = NA, downstream_estimable = NA,
            missing_cell_count = sum(template$retained_cells == 0L),
            diagnostic = execution$account$failure_codes[[index]],
            outcome = "execution_failure", stringsAsFactors = FALSE
        )
    })
    replicate_rows <- do.call(rbind, rows)
    rownames(replicate_rows) <- NULL
    replicate_rows$outcome <- factor(
        replicate_rows$outcome, levels = .k1_calibration_outcome_levels
    )
    payload <- list(
        version = "k1-independent-time-course-calibration-v1",
        claim_status = "disclosed_calibration_only",
        recovery_threshold = recovery_threshold,
        scientific_context = list(
            experiment_label = "Synthetic independent destructive time course",
            target_field = "condition",
            oriented_levels = c("CTL", "CM"),
            sampling_unit = "one independently collected animal",
            time_field = "collection_time",
            time_unit = "days",
            nuisance_fields = "batch"
        ),
        execution = execution[c("account", "provenance", "digest")],
        replicates = replicate_rows,
        cells = .k1_independent_time_cell_summary(replicate_rows)
    )
    assessment <- structure(c(payload, list(
        digest = digest::digest(payload, algo = "sha256")
    )), class = c("K1IndependentTimeCourseAssessment", "list"))
    .validate_k1_independent_time_assessment(assessment)
    assessment
}

#' Plot destructive-time-course calibration operating evidence
#'
#' @param assessment calibration assessment.
#' @return Publication-themed ggplot with exact displayed data attached as
#'   `landscapeR_k1_operating_map_data` and a separate dynamic caption.
#' @export
plot_k1_independent_time_course_calibration <- function(assessment) {
    .validate_k1_independent_time_assessment(assessment)
    cells <- assessment$cells
    display <- rbind(
        transform(cells,
            evidence = "A  Target-axis recovery",
            probability = recovery_probability,
            denominator = n_recovery_evaluable),
        transform(cells,
            evidence = "B  Downstream estimability after recovery",
            probability = downstream_estimability_probability,
            denominator = n_downstream_evaluable)
    )
    display$evidence <- factor(display$evidence, levels = c(
        "A  Target-axis recovery",
        "B  Downstream estimability after recovery"
    ))
    display$template_label <- factor(
        display$template_label,
        levels = unique(cells$template_label)
    )
    display$template_axis_label <- sprintf(
        "%s\n%.2g effective",
        c(
            balanced_1 = "1 per cell",
            balanced_2 = "2 per cell",
            balanced_3 = "3 per cell",
            unequal_1_2_3 = "Unequal 1-3",
            isolated_library_failure = "One library lost",
            missing_internal_cell = "One cell absent"
        )[display$template_id],
        display$effective_sampling_information
    )
    display$template_axis_label <- factor(display$template_axis_label,
        levels = unique(display$template_axis_label))
    downstream_abstention <-
        display$evidence == "B  Downstream estimability after recovery" &
        display$n_downstream_evaluable > 0L &
        display$n_downstream_estimable == 0L
    display$state <- ifelse(
        display$n_execution_failure > 0L, "Incomplete execution",
        ifelse(display$denominator == 0L | downstream_abstention,
            "Not estimable", "Estimated")
    )
    display$plotted_probability <- display$probability
    display$plotted_probability[
        display$state == "Not estimable" &
            !is.finite(display$plotted_probability)
    ] <- 0.04
    semantic <- landscapeR_palette("semantic")
    plot <- ggplot2::ggplot(display, ggplot2::aes(
        x = plotted_probability,
        y = template_axis_label,
        group = evidence
    )) +
        ggplot2::geom_point(ggplot2::aes(shape = state, fill = state),
            size = 2.4, stroke = 0.45, colour = semantic[["ink"]]) +
        ggplot2::facet_wrap(~ evidence, nrow = 1L) +
        ggplot2::scale_shape_manual(values = c(
            "Estimated" = 21, "Not estimable" = 4,
            "Incomplete execution" = 24
        )) +
        ggplot2::scale_fill_manual(values = c(
            "Estimated" = semantic[["focal"]],
            "Not estimable" = NA, "Incomplete execution" = semantic[["missing"]]
        )) +
        ggplot2::scale_x_continuous(limits = c(0, 1),
            breaks = c(0, 0.5, 1)) +
        ggplot2::labs(
            x = "Probability across calibration replicates",
            y = "Declared sampling template and effective information",
            shape = NULL, fill = NULL
        ) +
        theme_landscapeR(square = FALSE) +
        ggplot2::theme(legend.position = "bottom")
    templates <- k1_independent_time_course_template()
    present_templates <- templates[unique(cells$template_id)]
    missingness_text <- paste(vapply(present_templates, function(template) {
        if (identical(template$id, "isolated_library_failure")) {
            removal <- template$removed_observations[1L, , drop = FALSE]
            return(sprintf(
                "%s removes replicate %d from %s at day %g",
                template$label, removal$replicate, removal$condition,
                removal$time
            ))
        }
        if (identical(template$id, "missing_internal_cell")) {
            zero <- which(template$retained_cells == 0L, arr.ind = TRUE)[1L, ]
            return(sprintf(
                "%s leaves %s at day %s absent",
                template$label, rownames(template$retained_cells)[zero[[1L]]],
                colnames(template$retained_cells)[zero[[2L]]]
            ))
        }
        template$label
    }, character(1L)), collapse = "; ")
    caption_view <- .new_scientific_caption_view(
        title = "Operating evidence for independent destructive time courses",
        experiment_label = assessment$scientific_context$experiment_label,
        target_field = assessment$scientific_context$target_field,
        oriented_levels = assessment$scientific_context$oriented_levels,
        sampling_unit = assessment$scientific_context$sampling_unit,
        time_field = paste0(
            assessment$scientific_context$time_field,
            " (days ", paste(.k1_independent_time_default_times,
                collapse = ", "), ")"
        ),
        time_unit = assessment$scientific_context$time_unit,
        nuisance_fields = assessment$scientific_context$nuisance_fields,
        panels = c(
            A = paste(
                "Target-axis recovery probability among replicates with",
                "evaluable loading cosine"
            ),
            B = paste(
                "Support for the independent condition-by-time estimand",
                "among replicates whose target axis was recovered"
            )
        ),
        encodings = c(
            "Red circles are estimated probabilities",
            "crosses mark designs with no eligible denominator",
            "grey triangles mark incomplete execution"
        ),
        estimand = "standardized condition-by-time interaction",
        design = paste(
            "different biological animals in every retained condition-time cell;",
            paste(unique(cells$missingness), collapse = ", ")
        ),
        missingness = paste(
            "Declared cell sizes and missing observations are retained without",
            "imputation or rebalancing.", missingness_text
        ),
        threshold = sprintf(
            "Recovery uses one absolute loading-cosine threshold of %.2f",
            assessment$recovery_threshold
        ),
        uncertainty = sprintf(
            "%d deterministic calibration replicates were requested per design",
            cells$n_requested[[1L]]
        ),
        claim_boundary = paste(
            "This is disclosed calibration evidence under the shown synthetic",
            "regime, not an acceptance result or universal sample-size rule"
        ),
        state = if (any(cells$n_execution_failure > 0L)) "partial" else "calibrated"
    )
    plot <- .with_scientific_caption(plot, .build_scientific_caption(caption_view))
    attr(plot, "landscapeR_k1_operating_map_data") <- display
    plot
}

.k1_independent_time_artifact_files <- function() c(
    "assessment.rds", "replicates.csv", "cell-summary.csv",
    "operating-map-data.csv", "operating-map.png",
    "operating-map-caption.txt", "environment.rds"
)

.verify_k1_independent_time_artifact <- function(artifact) {
    manifest_path <- file.path(artifact, "MANIFEST.tsv")
    if (!dir.exists(artifact) || !file.exists(manifest_path)) {
        .k1_acceptance_runner_abort(
            "independent time-course calibration artifact is incomplete"
        )
    }
    manifest <- utils::read.delim(manifest_path,
        stringsAsFactors = FALSE, check.names = FALSE)
    governed <- .k1_independent_time_artifact_files()
    if (!identical(manifest$file, governed) ||
            !identical(names(manifest), c("file", "sha256"))) {
        .k1_acceptance_runner_abort(
            "independent time-course artifact manifest is invalid"
        )
    }
    observed <- unname(vapply(file.path(artifact, governed),
        .k1_acceptance_file_digest, character(1L)))
    if (!identical(observed, manifest$sha256)) {
        .k1_acceptance_runner_abort(
            "independent time-course artifact digest verification failed"
        )
    }
    assessment <- readRDS(file.path(artifact, "assessment.rds"))
    .validate_k1_independent_time_assessment(assessment)
    plot <- plot_k1_independent_time_course_calibration(assessment)
    expected_map <- attr(plot, "landscapeR_k1_operating_map_data")
    observed_map <- utils::read.csv(
        file.path(artifact, "operating-map-data.csv"),
        stringsAsFactors = FALSE
    )
    expected_map$evidence <- as.character(expected_map$evidence)
    expected_map$template_label <- as.character(expected_map$template_label)
    expected_map$template_axis_label <-
        as.character(expected_map$template_axis_label)
    if (!isTRUE(all.equal(observed_map, expected_map,
            check.attributes = FALSE)) ||
            !identical(
                readLines(file.path(artifact, "operating-map-caption.txt")),
                strsplit(scientific_caption(plot), "\n", fixed = TRUE)[[1L]]
            )) {
        .k1_acceptance_runner_abort(
            "independent time-course artifact derivatives do not reproduce"
        )
    }
    invisible(TRUE)
}

#' Publish independent destructive-time-course calibration evidence
#'
#' Writes the typed assessment, exact plotted data, separate caption, and
#' rendered operating map into a content-addressed, replay-verifiable artifact.
#'
#' @param artifact_root publication directory.
#' @param assessment output from
#'   [run_k1_independent_time_course_calibration()].
#' @return Verified content-addressed artifact path.
#' @export
publish_k1_independent_time_course_calibration <- function(
    artifact_root, assessment
) {
    .validate_k1_independent_time_assessment(assessment)
    if (!.is_scalar_nonempty_text(artifact_root)) {
        .stop_landscapeR_validation("artifact_root must be one non-empty path")
    }
    artifact_root <- path.expand(artifact_root)
    dir.create(artifact_root, recursive = TRUE, showWarnings = FALSE)
    staging <- tempfile(".k1-independent-time-tmp-", tmpdir = artifact_root)
    dir.create(staging, recursive = TRUE, showWarnings = FALSE)
    on.exit(if (dir.exists(staging)) unlink(staging, recursive = TRUE), add = TRUE)
    plot <- plot_k1_independent_time_course_calibration(assessment)
    saveRDS(assessment, file.path(staging, "assessment.rds"))
    utils::write.csv(assessment$replicates,
        file.path(staging, "replicates.csv"), row.names = FALSE)
    utils::write.csv(assessment$cells,
        file.path(staging, "cell-summary.csv"), row.names = FALSE)
    display <- attr(plot, "landscapeR_k1_operating_map_data")
    utils::write.csv(display,
        file.path(staging, "operating-map-data.csv"), row.names = FALSE)
    ggplot2::ggsave(file.path(staging, "operating-map.png"), plot,
        width = 180, height = 100, units = "mm", dpi = 450, bg = "white")
    writeLines(scientific_caption(plot),
        file.path(staging, "operating-map-caption.txt"))
    saveRDS(list(
        assessment_digest = assessment$digest,
        runtime_identity = .k1_calibration_runtime_identity(),
        claim_status = assessment$claim_status
    ), file.path(staging, "environment.rds"))
    governed <- .k1_independent_time_artifact_files()
    file_manifest <- data.frame(
        file = governed,
        sha256 = vapply(file.path(staging, governed),
            .k1_acceptance_file_digest, character(1L)),
        stringsAsFactors = FALSE
    )
    artifact_digest <- .k1_acceptance_artifact_digest(file_manifest)
    artifact <- file.path(artifact_root, paste0(
        assessment$version, "-", substr(artifact_digest, 1L, 16L)
    ))
    if (dir.exists(artifact)) {
        .verify_k1_independent_time_artifact(artifact)
        return(artifact)
    }
    utils::write.table(file_manifest, file.path(staging, "MANIFEST.tsv"),
        sep = "\t", quote = FALSE, row.names = FALSE)
    if (!file.rename(staging, artifact)) {
        .k1_acceptance_runner_abort(
            "could not atomically publish independent time-course artifact"
        )
    }
    .verify_k1_independent_time_artifact(artifact)
    artifact
}

#' Verify independent destructive-time-course calibration evidence
#'
#' @param artifact path returned by
#'   [publish_k1_independent_time_course_calibration()].
#' @return Invisibly `TRUE`, or an error for any changed evidence.
#' @export
verify_k1_independent_time_course_calibration <- function(artifact) {
    .verify_k1_independent_time_artifact(path.expand(artifact))
}

#' Declare the backend-neutral destructive-time-course calibration graph
#'
#' The complete scientific calibration call is one scheduler-owned worker
#' target. Callers may use local crew, hprcc Slurm controllers, or another crew
#' backend without changing seeds or scientific parameters.
#'
#' @param artifact_root absolute shared publication directory.
#' @param controller named crew controller configured by the caller.
#' @param ... scientific arguments forwarded to
#'   [run_k1_independent_time_course_calibration()].
#' @return List of targets objects.
#' @export
k1_independent_time_course_calibration_targets <- function(
    artifact_root, controller = "k1-independent-time-course", ...
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
        list(quote(landscapeR::run_k1_independent_time_course_calibration)),
        arguments,
        list(sequential_internal = TRUE)
    ))
    list(
        .k1_acceptance_target(
            "k1_independent_time_assessment",
            run_call,
            deployment = "worker",
            controller = controller
        ),
        .k1_acceptance_target(
            "k1_independent_time_artifact",
            substitute(
                landscapeR::publish_k1_independent_time_course_calibration(
                    ROOT, k1_independent_time_assessment
                ),
                list(ROOT = path.expand(artifact_root))
            ),
            format = "file"
        )
    )
}
