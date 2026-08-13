# Stage 0 K=1 incomplete repeated-subject calibration (#190)

.k1_repeated_conditions <- c("CTL", "CM")
.k1_repeated_times <- 0:3
.k1_repeated_template_version <- "k1-repeated-subject-templates-v1"
.k1_repeated_assessment_version <- "k1-repeated-subject-calibration-v1"

.k1_repeated_empty_removals <- function() data.frame(
    mouse_id = character(), condition = character(), weeks = numeric(),
    reason = character(), stringsAsFactors = FALSE
)

.k1_repeated_template_payload <- function() list(
    complete = list(
        label = "Complete trajectories",
        removals = .k1_repeated_empty_removals(),
        missingness = "complete"
    ),
    isolated_observation_loss = list(
        label = "One internal visit missing",
        removals = data.frame(
            mouse_id = "cm1", condition = "CM", weeks = 2,
            reason = "isolated_observation_loss", stringsAsFactors = FALSE
        ),
        missingness = "isolated_observation_loss"
    ),
    terminal_dropout = list(
        label = "One mouse drops out",
        removals = data.frame(
            mouse_id = c("cm1", "cm1"), condition = c("CM", "CM"),
            weeks = c(2, 3), reason = rep("terminal_dropout", 2L),
            stringsAsFactors = FALSE
        ),
        missingness = "terminal_dropout"
    ),
    condition_dependent_loss = list(
        label = "Two disease mice drop out",
        removals = data.frame(
            mouse_id = rep(c("cm1", "cm2"), each = 2L),
            condition = "CM", weeks = rep(c(2, 3), 2L),
            reason = "condition_dependent_terminal_dropout",
            stringsAsFactors = FALSE
        ),
        missingness = "condition_dependent_loss"
    )
)

.validate_k1_repeated_template <- function(template) {
    required <- c(
        "version", "id", "label", "conditions", "times",
        "subjects_per_condition", "intended_observations",
        "retained_observations", "removed_observations", "missingness",
        "sampling_design", "biological_unit", "resampling_unit"
    )
    expected_subjects <- c(paste0("ctl", 1:4), paste0("cm", 1:4))
    intended <- expand.grid(
        mouse_id = expected_subjects, weeks = .k1_repeated_times,
        KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
    )
    intended$condition <- ifelse(grepl("^ctl", intended$mouse_id), "CTL", "CM")
    intended <- intended[, c("mouse_id", "condition", "weeks")]
    if (!inherits(template, "K1RepeatedSubjectTemplate") ||
            !identical(names(template), required) ||
            !identical(template$version, .k1_repeated_template_version) ||
            !.is_scalar_nonempty_text(template$id) ||
            !.is_scalar_nonempty_text(template$label) ||
            !identical(template$conditions, .k1_repeated_conditions) ||
            !identical(template$times, .k1_repeated_times) ||
            !identical(template$subjects_per_condition, 4L) ||
            !identical(template$intended_observations, intended) ||
            !is.data.frame(template$retained_observations) ||
            !identical(names(template$retained_observations),
                c("mouse_id", "condition", "weeks")) ||
            !is.data.frame(template$removed_observations) ||
            !identical(names(template$removed_observations),
                c("mouse_id", "condition", "weeks", "reason")) ||
            !.is_scalar_nonempty_text(template$missingness) ||
            !identical(template$sampling_design, "longitudinal") ||
            !identical(template$biological_unit,
                "one repeatedly observed synthetic mouse") ||
            !identical(template$resampling_unit,
                "complete subject trajectory")) {
        .stop_landscapeR_validation(
            "repeated-subject sampling template is invalid"
        )
    }
    retained_keys <- with(template$retained_observations,
        paste(mouse_id, weeks, sep = "\r"))
    intended_keys <- with(template$intended_observations,
        paste(mouse_id, weeks, sep = "\r"))
    removed_keys <- with(template$removed_observations,
        paste(mouse_id, weeks, sep = "\r"))
    retained_condition <- ifelse(
        grepl("^ctl", template$retained_observations$mouse_id), "CTL", "CM"
    )
    removed_condition <- ifelse(
        grepl("^ctl", template$removed_observations$mouse_id), "CTL", "CM"
    )
    if (anyDuplicated(retained_keys) || anyDuplicated(removed_keys) ||
            !setequal(c(retained_keys, removed_keys), intended_keys) ||
            length(intersect(retained_keys, removed_keys)) ||
            any(template$retained_observations$condition !=
                retained_condition) ||
            any(template$removed_observations$condition !=
                removed_condition) ||
            any(!nzchar(template$removed_observations$reason))) {
        .stop_landscapeR_validation(
            "repeated-subject removals do not partition the intended design"
        )
    }
    invisible(TRUE)
}

#' Governed repeated-subject calibration templates
#'
#' Declares complete trajectories, an isolated missed visit, terminal dropout,
#' and condition-dependent terminal loss. Every retained observation remains
#' attached to its original mouse, condition, and observed time.
#'
#' @param id optional template identifier. With `NULL`, returns every template.
#' @return A `K1RepeatedSubjectTemplate`, or a named list of them.
#' @export
k1_repeated_subject_template <- function(id = NULL) {
    payload <- .k1_repeated_template_payload()
    subjects <- c(paste0("ctl", 1:4), paste0("cm", 1:4))
    intended <- expand.grid(
        mouse_id = subjects, weeks = .k1_repeated_times,
        KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
    )
    intended$condition <- ifelse(grepl("^ctl", intended$mouse_id), "CTL", "CM")
    intended <- intended[, c("mouse_id", "condition", "weeks")]
    templates <- lapply(names(payload), function(template_id) {
        specification <- payload[[template_id]]
        removal_keys <- with(specification$removals,
            paste(mouse_id, weeks, sep = "\r"))
        intended_keys <- with(intended, paste(mouse_id, weeks, sep = "\r"))
        retained <- intended[!intended_keys %in% removal_keys, , drop = FALSE]
        rownames(retained) <- NULL
        template <- structure(list(
            version = .k1_repeated_template_version,
            id = template_id,
            label = specification$label,
            conditions = .k1_repeated_conditions,
            times = .k1_repeated_times,
            subjects_per_condition = 4L,
            intended_observations = intended,
            retained_observations = retained,
            removed_observations = specification$removals,
            missingness = specification$missingness,
            sampling_design = "longitudinal",
            biological_unit = "one repeatedly observed synthetic mouse",
            resampling_unit = "complete subject trajectory"
        ), class = c("K1RepeatedSubjectTemplate", "list"))
        .validate_k1_repeated_template(template)
        template
    })
    names(templates) <- names(payload)
    if (is.null(id)) return(templates)
    if (!.is_scalar_nonempty_text(id) || !id %in% names(templates)) {
        .stop_landscapeR_validation(sprintf(
            "unknown repeated-subject template '%s'; choose one of: %s",
            paste(id, collapse = ""), paste(names(templates), collapse = ", ")
        ))
    }
    templates[[id]]
}

#' Generate a governed incomplete repeated-subject control
#'
#' @param template governed template or its identifier.
#' @param p number of expression features.
#' @param noise_sd,time_signal,condition_time_signal generator parameters.
#' @param seed deterministic package seed.
#' @return A longitudinal `StateTransitionData` with an exact sampling audit.
#' @export
synthetic_k1_repeated_subject_control <- function(
    template = "complete", p = 100L, noise_sd = 0.03,
    time_signal = 8, condition_time_signal = 3, seed = 42L
) {
    if (is.character(template)) template <- k1_repeated_subject_template(template)
    .validate_k1_repeated_template(template)
    removals <- template$removed_observations[, c(
        "mouse_id", "weeks", "reason"
    ), drop = FALSE]
    control <- synthetic_k1_aml_longitudinal_control(
        subjects_per_condition = template$subjects_per_condition,
        times = template$times, p = p, noise_sd = noise_sd,
        time_signal = time_signal, disease_signal = condition_time_signal,
        removed_observations = removals, seed = seed
    )
    md <- metadata(control)
    md$k1_repeated_subject_control <- list(
        version = "k1-repeated-subject-control-v1",
        template = template,
        subject_field = "mouse_id",
        time_field = "weeks",
        condition_field = "condition",
        resampling_unit = template$resampling_unit,
        n_intended = as.integer(nrow(template$intended_observations)),
        n_retained = as.integer(nrow(template$retained_observations)),
        seed = as.integer(seed),
        claim_status = "non_evidentiary_calibration"
    )
    metadata(control) <- md
    record_provenance(
        control, stage = "generate_control",
        contract = "SyntheticControlGenerator",
        implementation = "k1_incomplete_repeated_subject_v1",
        params = md$k1_repeated_subject_control,
        rng = .generator_rng_identity(
            seed, "synthetic_k1_repeated_subject_control",
            c(expression = seed)
        ),
        input_hashes = c(
            template = digest::digest(template, algo = "sha256")
        )
    )
}

#' Inspect an incomplete repeated-subject control
#'
#' @param x generated control.
#' @return Versioned generator and exact sampling metadata.
#' @export
k1_repeated_subject_control_info <- function(x) {
    if (!is(x, "StateTransitionData")) {
        .stop_landscapeR_validation(
            "k1_repeated_subject_control_info(): x must be StateTransitionData"
        )
    }
    info <- metadata(x)$k1_repeated_subject_control
    if (!is.list(info)) {
        .stop_landscapeR_validation(
            "x does not contain a repeated-subject control declaration"
        )
    }
    info
}

.k1_repeated_config <- function() {
    config <- .aml_k1_calibration_config()
    config@dataset <- "synthetic_k1_incomplete_repeated_subject"
    config@params$svd$k_components <- 2L
    config
}

.k1_repeated_context <- function() list(
    experiment_label = "Synthetic repeated-subject time course",
    target_field = "condition",
    oriented_levels = c("CTL", "CM"),
    subject_field = "mouse_id",
    time_field = "weeks",
    time_unit = "synthetic study units",
    sampling_unit = "one repeatedly observed synthetic mouse",
    resampling_unit = "complete subject trajectory",
    nuisance_fields = "batch"
)

.k1_repeated_model_evidence <- function(atlas, target_component = 2L) {
    if (is(atlas, "AssociationAbstention")) {
        return(list(
            status = "not_estimable",
            diagnostic = association_abstention_diagnostic(atlas),
            effect_magnitude = NA_real_
        ))
    }
    if (!is(atlas, "MetadataAssociationAtlas")) {
        stop("associate_metadata() returned an unsupported result")
    }
    rows <- atlas_associations(atlas)
    rows <- rows[
        rows$component == target_component &
            rows$evidence_variant == "repeated-time-course-adjusted",
        , drop = FALSE
    ]
    estimable <- nrow(rows) == 1L &&
        isTRUE(rows$proposal_eligible[[1L]]) &&
        is.finite(rows$effect_magnitude[[1L]])
    list(
        status = if (estimable) "estimable" else "not_estimable",
        diagnostic = if (nrow(rows)) rows$diagnostic[[1L]] else
            "target component has no adjusted repeated-subject evidence row",
        effect_magnitude = if (estimable) rows$effect_magnitude[[1L]] else
            NA_real_
    )
}

.k1_repeated_target_identifiability <- function(
    control, fitted, config, n_resamples, seed
) {
    if (n_resamples == 0L) {
        return(list(
            status = "not_requested", mean_absolute_similarity = NA_real_,
            n_requested = 0L, n_completed = 0L,
            resampling_method =
                "condition-stratified-subject-trajectory-bootstrap",
            resampling_unit = "complete-subject-trajectory",
            plan_digest = NULL, replicates = list(),
            reason = "axis resampling not requested"
        ))
    }
    reference <- stage_artifact(fitted, "stage1")
    reference_loadings <- dr_V_k(reference)
    plan <- .identifiability_resampling_plan(
        fitted, config@analysis, n_resamples, seed
    )
    replicates <- lapply(seq_len(n_resamples), function(index) {
        draw <- plan$draws[[index]]
        sampled <- .resample_state_transition_data(
            control, draw$source_primary, index, draw$replicate_subject
        )
        decomposition <- .evidence_decompose(sampled, config)
        if (!is(decomposition, "StageResult") ||
                !identical(decomposition@status, "success")) {
            return(list(
                replicate = as.integer(index), status = "execution_failure",
                target_absolute_similarity = NA_real_,
                target_replicate_component = NA_integer_,
                assignment_margin = NA_real_,
                source_primary = draw$source_primary,
                replicate_subject = draw$replicate_subject,
                diagnostic = if (is(decomposition, "StageResult")) {
                    decomposition@reason
                } else {
                    "decomposer did not return a StageResult"
                }
            ))
        }
        replicate_loadings <- dr_V_k(stage_artifact(
            decomposition@value, "stage1"
        ))
        alignment <- .match_component_loadings(
            reference_loadings, replicate_loadings
        )
        target <- alignment$assignment[
            alignment$assignment$reference_component == 2L,
            , drop = FALSE
        ]
        list(
            replicate = as.integer(index), status = "completed",
            target_absolute_similarity = target$absolute_similarity[[1L]],
            target_replicate_component = target$replicate_component[[1L]],
            assignment_margin = target$assignment_margin[[1L]],
            source_primary = draw$source_primary,
            replicate_subject = draw$replicate_subject,
            diagnostic = ""
        )
    })
    completed <- vapply(replicates, function(replicate) {
        identical(replicate$status, "completed") &&
            is.finite(replicate$target_absolute_similarity)
    }, logical(1L))
    similarities <- vapply(replicates, function(replicate) {
        replicate$target_absolute_similarity
    }, numeric(1L))
    list(
        status = if (all(completed)) {
            "estimable"
        } else if (any(completed)) {
            "partial"
        } else {
            "not_estimable"
        },
        mean_absolute_similarity = if (any(completed)) {
            mean(similarities[completed])
        } else {
            NA_real_
        },
        n_requested = as.integer(n_resamples),
        n_completed = as.integer(sum(completed)),
        resampling_method = plan$method,
        resampling_unit = plan$unit,
        plan_digest = digest::digest(list(
            method = plan$method,
            unit = plan$unit,
            n_requested = as.integer(n_resamples),
            draws = lapply(replicates, function(replicate) list(
                source_primary = replicate$source_primary,
                replicate_subject = replicate$replicate_subject
            ))
        ), algo = "sha256", serialize = TRUE),
        replicates = replicates,
        reason = if (any(completed)) "" else
            "no target-axis bootstrap decomposition completed"
    )
}

.k1_repeated_assess_one <- function(
    template_id, p, noise_sd, time_signal, condition_time_signal,
    seed, recovery_threshold, axis_resamples
) {
    control <- synthetic_k1_repeated_subject_control(
        template_id, p, noise_sd, time_signal, condition_time_signal, seed
    )
    info <- k1_repeated_subject_control_info(control)
    template <- info$template
    config <- .k1_repeated_config()
    decomposition <- decompose(.aml_k1_strategy(config, "Decomposer"), control)
    if (!identical(decomposition@status, "success")) {
        stop(decomposition@reason)
    }
    fitted <- decomposition@value
    loading <- dr_V_k(stage_artifact(fitted, "stage1"))[, 2L]
    truth <- control@ground_truth@subspace@shared[, 2L]
    cosine <- abs(sum(loading * truth) /
        sqrt(sum(loading^2) * sum(truth^2)))
    recovery_evaluable <- is.finite(cosine)
    recovery_met <- recovery_evaluable && cosine >= recovery_threshold
    atlas <- associate_metadata(
        fitted, specification = config@analysis,
        non_analytical_fields = c("mouse_id", "batch"),
        n_resamples = 0L, seed = seed + 1L, sequential_internal = TRUE
    )
    model <- .k1_repeated_model_evidence(atlas)
    proposal <- if (is(atlas, "MetadataAssociationAtlas")) {
        propose_component(
            atlas, n_permutations = 0L, seed = seed + 2L,
            sequential_internal = TRUE
        )
    } else {
        NULL
    }
    target_identifiability <- .k1_repeated_target_identifiability(
        control, fitted, config, axis_resamples, seed + 3L
    )
    nominated_component <- if (is(proposal, "ComponentProposal")) {
        proposal@recommended_component
    } else {
        NA_integer_
    }
    outcome <- if (!recovery_evaluable) {
        "recovery_not_evaluable"
    } else if (!recovery_met) {
        "recovery_below_threshold"
    } else if (!identical(model$status, "estimable")) {
        "recovered_downstream_nonestimable"
    } else {
        "recovered_and_estimable"
    }
    evidence <- structure(list(
        version = "k1-repeated-subject-replicate-evidence-v1",
        template = template,
        recovery = list(
            status = if (recovery_evaluable) "estimable" else "not_estimable",
            target_loading_cosine = cosine,
            threshold = recovery_threshold,
            met = recovery_met
        ),
        identifiability = target_identifiability,
        metadata_nomination = list(
            status = if (is(proposal, "ComponentProposal")) {
                "proposal"
            } else if (is(atlas, "MetadataAssociationAtlas")) {
                "abstention"
            } else {
                "not_estimable"
            },
            nominated_component = nominated_component,
            agrees_with_planted_target = if (is.na(nominated_component)) {
                NA
            } else {
                nominated_component == 2L
            }
        ),
        repeated_subject_model = model,
        outcome = outcome
    ), class = c("K1RepeatedSubjectReplicateEvidence", "list"))
    row <- data.frame(
        template_id = template$id,
        template_label = template$label,
        missingness = template$missingness,
        n_subjects = length(unique(template$intended_observations$mouse_id)),
        n_intended = nrow(template$intended_observations),
        n_retained = nrow(template$retained_observations),
        n_removed = nrow(template$removed_observations),
        minimum_subject_observations = min(table(
            template$retained_observations$mouse_id
        )),
        execution_completed = TRUE,
        target_loading_cosine = cosine,
        recovery_evaluable = recovery_evaluable,
        recovery_met = recovery_met,
        axis_identifiability_evaluable =
            is.finite(target_identifiability$mean_absolute_similarity),
        axis_mean_absolute_similarity =
            target_identifiability$mean_absolute_similarity,
        axis_refits_requested = target_identifiability$n_requested,
        axis_refits_completed = target_identifiability$n_completed,
        nominated_component = nominated_component,
        nomination_agrees_with_target = if (is.na(nominated_component)) {
            NA
        } else {
            nominated_component == 2L
        },
        model_estimable = identical(model$status, "estimable"),
        model_diagnostic = model$diagnostic %||%
            target_identifiability$reason %||% "",
        outcome = outcome,
        stringsAsFactors = FALSE
    )
    list(row = row, evidence = evidence)
}

.k1_repeated_cell_summary <- function(replicates) {
    groups <- split(seq_len(nrow(replicates)), replicates$template_id)
    rows <- lapply(groups, function(index) {
        x <- replicates[index, , drop = FALSE]
        recovery_denominator <- sum(x$recovery_evaluable)
        recovered <- sum(x$recovery_met %in% TRUE)
        axis_denominator <- sum(x$axis_identifiability_evaluable)
        data.frame(
            template_id = x$template_id[[1L]],
            template_label = x$template_label[[1L]],
            missingness = x$missingness[[1L]],
            n_subjects = x$n_subjects[[1L]],
            n_intended = x$n_intended[[1L]],
            n_retained = x$n_retained[[1L]],
            n_removed = x$n_removed[[1L]],
            minimum_subject_observations =
                x$minimum_subject_observations[[1L]],
            n_requested = nrow(x),
            n_execution_completed = sum(x$execution_completed),
            n_execution_failure = sum(!x$execution_completed),
            n_axis_refits_requested = sum(x$axis_refits_requested),
            n_axis_refits_completed = sum(x$axis_refits_completed),
            recovery_probability = if (recovery_denominator) {
                recovered / recovery_denominator
            } else NA_real_,
            mean_axis_loading_similarity = if (axis_denominator) {
                mean(x$axis_mean_absolute_similarity[
                    x$axis_identifiability_evaluable
                ])
            } else NA_real_,
            model_estimability_probability = if (recovered) {
                sum(x$recovery_met %in% TRUE & x$model_estimable) / recovered
            } else NA_real_,
            stringsAsFactors = FALSE
        )
    })
    result <- do.call(rbind, rows)
    rownames(result) <- NULL
    result[match(unique(replicates$template_id), result$template_id), , drop = FALSE]
}

.validate_k1_repeated_assessment <- function(x) {
    if (!inherits(x, "K1RepeatedSubjectAssessment") || !is.list(x) ||
            !identical(names(x), c(
                "version", "claim_status", "recovery_threshold",
                "axis_resamples", "scientific_context", "sampling_audit",
                "execution", "replicates", "cells", "digest"
            ))) {
        .stop_landscapeR_validation(
            "repeated-subject calibration assessment is invalid"
        )
    }
    payload <- unclass(x)
    observed_digest <- payload$digest
    payload$digest <- NULL
    expected_rows <- c(
        "task_id", "replicate_index", "template_id", "template_label",
        "missingness", "n_subjects", "n_intended", "n_retained",
        "n_removed", "minimum_subject_observations", "execution_completed",
        "target_loading_cosine", "recovery_evaluable", "recovery_met",
        "axis_identifiability_evaluable", "axis_mean_absolute_similarity",
        "axis_refits_requested", "axis_refits_completed",
        "nominated_component", "nomination_agrees_with_target",
        "model_estimable",
        "model_diagnostic", "outcome"
    )
    if (!identical(x$version, .k1_repeated_assessment_version) ||
            !identical(x$claim_status, "disclosed_calibration_only") ||
            !is.numeric(x$recovery_threshold) ||
            length(x$recovery_threshold) != 1L ||
            !is.finite(x$recovery_threshold) ||
            x$recovery_threshold <= 0 || x$recovery_threshold > 1 ||
            !.is_whole_number(x$axis_resamples, 0L) ||
            !identical(x$scientific_context, .k1_repeated_context()) ||
            !identical(observed_digest,
                digest::digest(payload, algo = "sha256")) ||
            !is.list(x$sampling_audit) || !length(x$sampling_audit) ||
            !setequal(names(x$sampling_audit),
                unique(x$replicates$template_id)) ||
            any(!vapply(x$sampling_audit, function(template) {
                tryCatch({
                    .validate_k1_repeated_template(template)
                    TRUE
                }, error = function(condition) FALSE)
            }, logical(1L))) ||
            !is.data.frame(x$replicates) ||
            !identical(names(x$replicates), expected_rows) ||
            !nrow(x$replicates) || anyDuplicated(x$replicates$task_id) ||
            any(!as.character(x$replicates$outcome) %in%
                .k1_calibration_outcome_levels) ||
            !identical(.k1_repeated_cell_summary(x$replicates), x$cells) ||
            !is.list(x$execution) ||
            !identical(x$execution$account$n_requested,
                as.integer(nrow(x$replicates)))) {
        .stop_landscapeR_validation(
            "repeated-subject calibration evidence contract is invalid"
        )
    }
    execution_payload <- x$execution[c("values", "account", "provenance")]
    valid_identifiability <- function(evidence) {
        required <- c(
            "status", "mean_absolute_similarity", "n_requested",
            "n_completed", "resampling_method", "resampling_unit",
            "plan_digest", "replicates", "reason"
        )
        if (!is.list(evidence) ||
                !all(required %in% names(evidence)) ||
                !.is_whole_number(evidence$n_requested, 0L) ||
                !.is_whole_number(evidence$n_completed, 0L) ||
                evidence$n_completed > evidence$n_requested ||
                length(evidence$replicates) != evidence$n_requested ||
                !identical(evidence$resampling_method,
                    "condition-stratified-subject-trajectory-bootstrap") ||
                !identical(evidence$resampling_unit,
                    "complete-subject-trajectory")) return(FALSE)
        replicate_names <- c(
            "replicate", "status", "target_absolute_similarity",
            "target_replicate_component", "assignment_margin",
            "source_primary", "replicate_subject", "diagnostic"
        )
        valid_replicate <- vapply(seq_along(evidence$replicates), function(i) {
            replicate <- evidence$replicates[[i]]
            if (!is.list(replicate) ||
                    !identical(names(replicate), replicate_names) ||
                    !identical(replicate$replicate, as.integer(i)) ||
                    !replicate$status %in% c("completed", "execution_failure") ||
                    !is.character(replicate$source_primary) ||
                    !length(replicate$source_primary) ||
                    anyNA(replicate$source_primary) ||
                    !is.character(replicate$replicate_subject) ||
                    length(replicate$replicate_subject) !=
                        length(replicate$source_primary) ||
                    anyNA(replicate$replicate_subject) ||
                    !is.character(replicate$diagnostic) ||
                    length(replicate$diagnostic) != 1L ||
                    is.na(replicate$diagnostic)) return(FALSE)
            if (identical(replicate$status, "completed")) {
                is.numeric(replicate$target_absolute_similarity) &&
                    length(replicate$target_absolute_similarity) == 1L &&
                    is.finite(replicate$target_absolute_similarity) &&
                    replicate$target_absolute_similarity >= 0 &&
                    replicate$target_absolute_similarity <= 1 &&
                    .is_whole_number(replicate$target_replicate_component, 1L) &&
                    replicate$target_replicate_component <= 2L &&
                    is.numeric(replicate$assignment_margin) &&
                    length(replicate$assignment_margin) == 1L &&
                    is.finite(replicate$assignment_margin) &&
                    replicate$assignment_margin >= 0 &&
                    !nzchar(replicate$diagnostic)
            } else {
                is.na(replicate$target_absolute_similarity) &&
                    is.na(replicate$target_replicate_component) &&
                    is.na(replicate$assignment_margin) &&
                    nzchar(replicate$diagnostic)
            }
        }, logical(1L))
        if (any(!valid_replicate)) return(FALSE)
        completed <- vapply(evidence$replicates, function(replicate) {
            identical(replicate$status, "completed")
        }, logical(1L))
        observed_mean <- if (any(completed)) {
            mean(vapply(evidence$replicates[completed], function(replicate) {
                replicate$target_absolute_similarity
            }, numeric(1L)))
        } else {
            NA_real_
        }
        expected_status <- if (all(completed) && length(completed)) {
            "estimable"
        } else if (any(completed)) {
            "partial"
        } else if (!length(completed)) {
            "not_requested"
        } else {
            "not_estimable"
        }
        expected_plan_digest <- if (evidence$n_requested) {
            digest::digest(list(
                method = evidence$resampling_method,
                unit = evidence$resampling_unit,
                n_requested = evidence$n_requested,
                draws = lapply(evidence$replicates, function(replicate) list(
                    source_primary = replicate$source_primary,
                    replicate_subject = replicate$replicate_subject
                ))
            ), algo = "sha256", serialize = TRUE)
        } else {
            NULL
        }
        identical(evidence$status, expected_status) &&
            identical(evidence$plan_digest, expected_plan_digest) &&
            identical(evidence$n_completed, as.integer(sum(completed))) &&
            identical(evidence$mean_absolute_similarity, observed_mean)
    }
    completed_values_match <- vapply(seq_len(nrow(x$replicates)), function(i) {
        value <- x$execution$values[[i]]
        if (!x$replicates$execution_completed[[i]]) return(is.null(value))
        if (!is.list(value) || !is.data.frame(value$row) ||
                !inherits(value$evidence,
                    "K1RepeatedSubjectReplicateEvidence")) return(FALSE)
        expected <- value$row
        expected$outcome <- factor(
            expected$outcome, levels = .k1_calibration_outcome_levels
        )
        observed <- x$replicates[i, , drop = FALSE]
        rownames(expected) <- NULL
        rownames(observed) <- NULL
        template <- x$sampling_audit[[observed$template_id[[1L]]]]
        recovery <- value$evidence$recovery
        identifiability <- value$evidence$identifiability
        nomination <- value$evidence$metadata_nomination
        model <- value$evidence$repeated_subject_model
        identical(expected, observed) &&
            identical(value$evidence$template, template) &&
            identical(value$evidence$outcome,
                as.character(observed$outcome[[1L]])) &&
            identical(recovery$target_loading_cosine,
                observed$target_loading_cosine[[1L]]) &&
            identical(recovery$status == "estimable",
                observed$recovery_evaluable[[1L]]) &&
            identical(recovery$met, observed$recovery_met[[1L]]) &&
            identical(recovery$threshold, x$recovery_threshold) &&
            valid_identifiability(identifiability) &&
            identical(is.finite(identifiability$mean_absolute_similarity),
                observed$axis_identifiability_evaluable[[1L]]) &&
            identical(identifiability$mean_absolute_similarity,
                observed$axis_mean_absolute_similarity[[1L]]) &&
            identical(identifiability$n_requested,
                observed$axis_refits_requested[[1L]]) &&
            identical(identifiability$n_completed,
                observed$axis_refits_completed[[1L]]) &&
            identical(nomination$nominated_component,
                observed$nominated_component[[1L]]) &&
            identical(nomination$agrees_with_planted_target,
                observed$nomination_agrees_with_target[[1L]]) &&
            identical(model$status == "estimable",
                observed$model_estimable[[1L]]) &&
            identical(model$diagnostic %||% identifiability$reason %||% "",
                observed$model_diagnostic[[1L]])
    }, logical(1L))
    audit_matches <- vapply(names(x$sampling_audit), function(template_id) {
        template <- x$sampling_audit[[template_id]]
        rows <- x$replicates$template_id == template_id
        any(rows) &&
            all(x$replicates$template_label[rows] == template$label) &&
            all(x$replicates$missingness[rows] == template$missingness) &&
            all(x$replicates$n_subjects[rows] == length(unique(
                template$intended_observations$mouse_id
            ))) &&
            all(x$replicates$n_intended[rows] ==
                nrow(template$intended_observations)) &&
            all(x$replicates$n_retained[rows] ==
                nrow(template$retained_observations)) &&
            all(x$replicates$n_removed[rows] ==
                nrow(template$removed_observations))
    }, logical(1L))
    derived_outcome <- ifelse(
        !x$replicates$execution_completed, "execution_failure",
        ifelse(!x$replicates$recovery_evaluable, "recovery_not_evaluable",
            ifelse(!(x$replicates$recovery_met %in% TRUE),
                "recovery_below_threshold",
                ifelse(x$replicates$model_estimable %in% TRUE,
                    "recovered_and_estimable",
                    "recovered_downstream_nonestimable")))
    )
    if (!identical(x$execution$digest, digest::digest(
            execution_payload, algo = "sha256", serialize = TRUE
        )) ||
            !identical(x$execution$account$n_completed,
                as.integer(sum(x$replicates$execution_completed))) ||
            !identical(x$execution$account$n_failed,
                as.integer(sum(!x$replicates$execution_completed))) ||
            !identical(x$execution$account$completed,
                x$replicates$execution_completed) ||
            !identical(x$execution$account$failure_codes == "",
                x$replicates$execution_completed) ||
            !identical(x$execution$provenance$task_ids,
                x$replicates$task_id) ||
            any(!completed_values_match) || any(!audit_matches) ||
            !identical(as.character(x$replicates$outcome), derived_outcome)) {
        .stop_landscapeR_validation(
            "repeated-subject execution, audit, or outcome invariants are invalid"
        )
    }
    invisible(TRUE)
}

#' Run the incomplete repeated-subject calibration map
#'
#' Executes target recovery, complete-subject bootstrap identifiability, and
#' the strict random-intercept-plus-slope model under the caller's future plan.
#' Scientific non-estimability remains distinct from execution failure.
#'
#' @param template_ids governed template identifiers.
#' @param replicates deterministic calibration replicates per template.
#' @param p expression feature count.
#' @param noise_sd,time_signal,condition_time_signal generator parameters.
#' @param recovery_threshold disclosed loading-cosine threshold.
#' @param axis_resamples complete-subject bootstrap refits per replicate.
#' @param seed package run seed.
#' @param sequential_internal run in the current worker for targets/crew tasks.
#' @param future_scheduling optional future.apply scheduling value.
#' @return Digest-bound `K1RepeatedSubjectAssessment`.
#' @export
run_k1_repeated_subject_calibration <- function(
    template_ids = names(k1_repeated_subject_template()),
    replicates = 20L, p = 100L, noise_sd = 0.03, time_signal = 8,
    condition_time_signal = 3, recovery_threshold = 0.9,
    axis_resamples = 19L, seed = 42L, sequential_internal = FALSE,
    future_scheduling = NULL
) {
    templates <- k1_repeated_subject_template()
    if (!is.character(template_ids) || !length(template_ids) ||
            anyNA(template_ids) || anyDuplicated(template_ids) ||
            any(!template_ids %in% names(templates)) ||
            !.is_whole_number(replicates, 1L) ||
            !.is_whole_number(axis_resamples, 0L) ||
            !is.numeric(recovery_threshold) || length(recovery_threshold) != 1L ||
            !is.finite(recovery_threshold) || recovery_threshold <= 0 ||
            recovery_threshold > 1) {
        .stop_landscapeR_validation(
            "repeated-subject calibration arguments are invalid"
        )
    }
    probe <- tryCatch(.with_rng_stream(
        .derive_task_stream(seed, "repeated-subject-argument-validation"),
        function() synthetic_k1_repeated_subject_control(
            templates[[template_ids[[1L]]]], p, noise_sd, time_signal,
            condition_time_signal, seed
        )
    ), error = identity)
    if (inherits(probe, "error")) stop(probe)
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
        tasks = tasks, task_ids = task_ids, run_seed = seed,
        compute_tier = "standard", sequential_internal = sequential_internal,
        future_scheduling = future_scheduling,
        worker = function(task, task_id, stream) {
            result <- .k1_repeated_assess_one(
                task$template_id, p, noise_sd, time_signal,
                condition_time_signal, as.integer(stream[[2L]]),
                recovery_threshold, axis_resamples
            )
            result$row <- cbind(
                task_id = task_id,
                replicate_index = task$replicate_index,
                result$row,
                stringsAsFactors = FALSE
            )
            result
        }
    )
    rows <- lapply(seq_along(tasks), function(index) {
        if (execution$account$completed[[index]]) {
            return(execution$values[[index]]$row)
        }
        template <- templates[[tasks[[index]]$template_id]]
        data.frame(
            task_id = task_ids[[index]],
            replicate_index = tasks[[index]]$replicate_index,
            template_id = template$id, template_label = template$label,
            missingness = template$missingness,
            n_subjects = length(unique(template$intended_observations$mouse_id)),
            n_intended = nrow(template$intended_observations),
            n_retained = nrow(template$retained_observations),
            n_removed = nrow(template$removed_observations),
            minimum_subject_observations = min(table(
                template$retained_observations$mouse_id
            )), execution_completed = FALSE,
            target_loading_cosine = NA_real_, recovery_evaluable = FALSE,
            recovery_met = NA, axis_identifiability_evaluable = FALSE,
            axis_mean_absolute_similarity = NA_real_, model_estimable = NA,
            axis_refits_requested = as.integer(axis_resamples),
            axis_refits_completed = 0L,
            nominated_component = NA_integer_,
            nomination_agrees_with_target = NA,
            model_diagnostic = execution$account$failure_codes[[index]],
            outcome = "execution_failure", stringsAsFactors = FALSE
        )
    })
    replicate_rows <- do.call(rbind, rows)
    rownames(replicate_rows) <- NULL
    replicate_rows$outcome <- factor(
        replicate_rows$outcome, levels = .k1_calibration_outcome_levels
    )
    payload <- list(
        version = .k1_repeated_assessment_version,
        claim_status = "disclosed_calibration_only",
        recovery_threshold = recovery_threshold,
        axis_resamples = as.integer(axis_resamples),
        scientific_context = .k1_repeated_context(),
        sampling_audit = templates[template_ids],
        execution = execution,
        replicates = replicate_rows,
        cells = .k1_repeated_cell_summary(replicate_rows)
    )
    assessment <- structure(c(payload, list(
        digest = digest::digest(payload, algo = "sha256")
    )), class = c("K1RepeatedSubjectAssessment", "list"))
    .validate_k1_repeated_assessment(assessment)
    assessment
}

#' Plot incomplete repeated-subject operating evidence
#'
#' @param assessment repeated-subject calibration assessment.
#' @return Publication-themed ggplot with exact displayed data and a separate
#'   dynamic scientific caption.
#' @export
plot_k1_repeated_subject_calibration <- function(assessment) {
    .validate_k1_repeated_assessment(assessment)
    cells <- assessment$cells
    display <- rbind(
        transform(cells, panel = "A  Target-axis recovery",
            probability = cells$recovery_probability),
        transform(cells, panel = "B  Axis identifiability",
            probability = cells$mean_axis_loading_similarity),
        transform(cells, panel = "C  Random-slope model estimability",
            probability = cells$model_estimability_probability)
    )
    display$panel <- factor(display$panel, levels = c(
        "A  Target-axis recovery", "B  Axis identifiability",
        "C  Random-slope model estimability"
    ))
    display$template_axis_label <- factor(
        sprintf("%s\n%d/%d retained",
            display$template_label, display$n_retained, display$n_intended),
        levels = rev(sprintf("%s\n%d/%d retained",
            cells$template_label, cells$n_retained, cells$n_intended))
    )
    display$state <- ifelse(is.finite(display$probability),
        "Estimated", "Not estimable")
    display$plotted_probability <- ifelse(
        is.finite(display$probability), display$probability, 0.04
    )
    display$execution_state <- ifelse(
        display$n_execution_failure > 0L |
            display$n_axis_refits_completed < display$n_axis_refits_requested,
        "Partial computation", "Complete"
    )
    semantic <- landscapeR_palette("semantic")
    plot <- ggplot2::ggplot(display, ggplot2::aes(
        x = .data$plotted_probability, y = .data$template_axis_label
    )) +
        ggplot2::geom_point(ggplot2::aes(
            shape = .data$state, fill = .data$state
        ), size = 2.5, stroke = 0.45, colour = semantic[["ink"]]) +
        ggplot2::geom_point(
            data = display[display$execution_state == "Partial computation", ,
                drop = FALSE],
            ggplot2::aes(x = -0.08, y = .data$template_axis_label),
            inherit.aes = FALSE, shape = 24, fill = semantic[["missing"]],
            colour = semantic[["ink"]], size = 2.5, stroke = 0.45
        ) +
        ggplot2::facet_wrap(~ .data$panel, ncol = 1L) +
        ggplot2::scale_shape_manual(values = c(
            "Estimated" = 21, "Not estimable" = 4
        )) +
        ggplot2::scale_fill_manual(values = c(
            "Estimated" = semantic[["focal"]], "Not estimable" = NA
        )) +
        ggplot2::scale_x_continuous(
            limits = c(-0.12, 1), breaks = c(0, 0.5, 1)
        ) +
        ggplot2::labs(
            x = "Value on a 0-1 scale",
            y = "Repeated-subject sampling template",
            shape = NULL, fill = NULL
        ) +
        theme_landscapeR(square = FALSE) +
        ggplot2::theme(legend.position = "bottom")
    removal_text <- paste(vapply(assessment$sampling_audit, function(template) {
        if (!nrow(template$removed_observations)) {
            return(paste0(template$label, " removes no observations"))
        }
        paste0(
            template$label, " removes ",
            paste(sprintf("%s at time %g",
                template$removed_observations$mouse_id,
                template$removed_observations$weeks), collapse = ", ")
        )
    }, character(1L)), collapse = "; ")
    caption_view <- .new_scientific_caption_view(
        title = "Operating evidence for incomplete repeated-subject time courses",
        experiment_label = assessment$scientific_context$experiment_label,
        target_field = assessment$scientific_context$target_field,
        oriented_levels = assessment$scientific_context$oriented_levels,
        sampling_unit = assessment$scientific_context$sampling_unit,
        time_field = paste0("weeks (times ",
            paste(.k1_repeated_times, collapse = ", "), ")"),
        time_unit = assessment$scientific_context$time_unit,
        nuisance_fields = assessment$scientific_context$nuisance_fields,
        panels = c(
            A = paste("Target loading recovery at the disclosed absolute",
                "cosine threshold"),
            B = paste("Mean absolute loading cosine for the planted target",
                "under condition-stratified complete-subject bootstrap"),
            C = paste("Estimability of the adjusted condition-by-time",
                "random-intercept-plus-slope model after target recovery")
        ),
        encodings = c(
            paste("Red circles are estimated values; panels A and C show",
                "outer-replicate probabilities and panel B shows mean cosine"),
            paste("crosses mark a scientific quantity that was not estimable",
                "and are positioned near zero without encoding a probability"),
            paste("hollow triangles at the left margin independently mark",
                "incomplete outer execution or target-axis refitting;",
                "finite values still summarize all completed refits")
        ),
        estimand = "standardized condition-by-time interaction",
        design = paste(
            "four CTL and four CM mice intended at each of four observed times;",
            "mouse identity, condition, and time remain explicit"
        ),
        missingness = paste(
            "No visit is imputed or treated as an independent animal.",
            removal_text
        ),
        threshold = sprintf(
            "Recovery uses an absolute loading-cosine threshold of %.2f",
            assessment$recovery_threshold
        ),
        uncertainty = sprintf(
            paste("%d deterministic outer replicates and %d complete-subject",
                "target-axis bootstrap refits per replicate were requested;",
                "%d of %d outer executions and %d of %d target-axis refits",
                "completed"),
            cells$n_requested[[1L]], assessment$axis_resamples,
            sum(cells$n_execution_completed), sum(cells$n_requested),
            sum(cells$n_axis_refits_completed),
            sum(cells$n_axis_refits_requested)
        ),
        claim_boundary = paste(
            "This is disclosed synthetic calibration evidence, not an",
            "acceptance result or universal sample-size rule"
        ),
        state = if (any(cells$n_execution_failure > 0L)) "partial" else "calibrated"
    )
    plot <- .with_scientific_caption(plot,
        .build_scientific_caption(caption_view))
    attr(plot, "landscapeR_k1_repeated_map_data") <- display
    plot
}

.k1_repeated_artifact_files <- function() c(
    "assessment.rds", "replicates.csv", "cell-summary.csv",
    "operating-map-data.csv", "operating-map.png",
    "operating-map-caption.txt", "environment.rds"
)

.verify_k1_repeated_artifact <- function(artifact) {
    artifact <- path.expand(artifact)
    manifest_path <- file.path(artifact, "MANIFEST.tsv")
    if (!dir.exists(artifact) || !file.exists(manifest_path)) {
        .k1_acceptance_runner_abort(
            "repeated-subject calibration artifact is incomplete"
        )
    }
    manifest <- utils::read.delim(manifest_path,
        stringsAsFactors = FALSE, check.names = FALSE)
    governed <- .k1_repeated_artifact_files()
    actual <- list.files(artifact, recursive = TRUE, all.files = TRUE,
        no.. = TRUE, include.dirs = FALSE)
    if (!identical(names(manifest), c("file", "sha256")) ||
            !identical(manifest$file, governed) ||
            !setequal(actual, c("MANIFEST.tsv", governed)) ||
            !identical(unname(vapply(file.path(artifact, governed),
                .k1_acceptance_file_digest, character(1L))),
                manifest$sha256)) {
        .k1_acceptance_runner_abort(
            "repeated-subject artifact manifest or files are invalid"
        )
    }
    assessment <- readRDS(file.path(artifact, "assessment.rds"))
    environment <- readRDS(file.path(artifact, "environment.rds"))
    .validate_k1_repeated_assessment(assessment)
    .k1_acceptance_validate_identity(environment$runtime_identity)
    plot <- plot_k1_repeated_subject_calibration(assessment)
    expected_replicates <- tempfile(fileext = ".csv")
    expected_cells <- tempfile(fileext = ".csv")
    expected_display <- tempfile(fileext = ".csv")
    on.exit(unlink(c(expected_replicates, expected_cells, expected_display)),
        add = TRUE)
    utils::write.csv(assessment$replicates, expected_replicates,
        row.names = FALSE)
    utils::write.csv(assessment$cells, expected_cells, row.names = FALSE)
    display <- attr(plot, "landscapeR_k1_repeated_map_data")
    utils::write.csv(display, expected_display, row.names = FALSE)
    derivatives_reproduce <- function(expected, observed) identical(
        readLines(expected, warn = FALSE),
        readLines(observed, warn = FALSE)
    )
    caption <- paste(readLines(
        file.path(artifact, "operating-map-caption.txt"), warn = FALSE
    ), collapse = "\n")
    artifact_digest <- .k1_acceptance_artifact_digest(manifest)
    expected_environment <- list(
        assessment_digest = assessment$digest,
        runtime_identity = environment$runtime_identity,
        claim_status = assessment$claim_status
    )
    if (!derivatives_reproduce(expected_replicates,
            file.path(artifact, "replicates.csv")) ||
            !derivatives_reproduce(expected_cells,
                file.path(artifact, "cell-summary.csv")) ||
            !derivatives_reproduce(expected_display,
                file.path(artifact, "operating-map-data.csv")) ||
            !identical(caption, scientific_caption(plot)) ||
            !identical(environment, expected_environment) ||
            !identical(basename(artifact), paste0(
                assessment$version, "-", substr(artifact_digest, 1L, 16L)
            ))) {
        .k1_acceptance_runner_abort(
            "repeated-subject artifact derivatives do not reproduce"
        )
    }
    invisible(TRUE)
}

#' Publish incomplete repeated-subject calibration evidence
#'
#' @param artifact_root publication directory.
#' @param assessment output from [run_k1_repeated_subject_calibration()].
#' @return Verified content-addressed artifact path.
#' @export
publish_k1_repeated_subject_calibration <- function(
    artifact_root, assessment
) {
    .validate_k1_repeated_assessment(assessment)
    if (!.is_scalar_nonempty_text(artifact_root)) {
        .stop_landscapeR_validation("artifact_root must be one non-empty path")
    }
    artifact_root <- path.expand(artifact_root)
    dir.create(artifact_root, recursive = TRUE, showWarnings = FALSE)
    staging <- tempfile(".k1-repeated-tmp-", tmpdir = artifact_root)
    dir.create(staging, recursive = TRUE, showWarnings = FALSE)
    on.exit(if (dir.exists(staging)) unlink(staging, recursive = TRUE), add = TRUE)
    plot <- plot_k1_repeated_subject_calibration(assessment)
    saveRDS(assessment, file.path(staging, "assessment.rds"))
    utils::write.csv(assessment$replicates,
        file.path(staging, "replicates.csv"), row.names = FALSE)
    utils::write.csv(assessment$cells,
        file.path(staging, "cell-summary.csv"), row.names = FALSE)
    utils::write.csv(attr(plot, "landscapeR_k1_repeated_map_data"),
        file.path(staging, "operating-map-data.csv"), row.names = FALSE)
    ggplot2::ggsave(file.path(staging, "operating-map.png"), plot,
        width = 100, height = 100, units = "mm", dpi = 450, bg = "white")
    writeLines(scientific_caption(plot),
        file.path(staging, "operating-map-caption.txt"))
    saveRDS(list(
        assessment_digest = assessment$digest,
        runtime_identity = .k1_calibration_runtime_identity(),
        claim_status = assessment$claim_status
    ), file.path(staging, "environment.rds"))
    governed <- .k1_repeated_artifact_files()
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
        .verify_k1_repeated_artifact(artifact)
        return(artifact)
    }
    utils::write.table(file_manifest, file.path(staging, "MANIFEST.tsv"),
        sep = "\t", quote = FALSE, row.names = FALSE)
    if (!file.rename(staging, artifact)) {
        .k1_acceptance_runner_abort(
            "could not atomically publish repeated-subject artifact"
        )
    }
    .verify_k1_repeated_artifact(artifact)
    artifact
}

#' Verify incomplete repeated-subject calibration evidence
#'
#' @param artifact path returned by
#'   [publish_k1_repeated_subject_calibration()].
#' @return Invisibly `TRUE`, or an error for changed evidence.
#' @export
verify_k1_repeated_subject_calibration <- function(artifact) {
    .verify_k1_repeated_artifact(path.expand(artifact))
}

#' Declare the backend-neutral repeated-subject calibration graph
#'
#' @param artifact_root absolute shared publication directory.
#' @param controller named crew controller configured by the caller.
#' @param ... scientific arguments forwarded to
#'   [run_k1_repeated_subject_calibration()].
#' @return List of targets objects.
#' @export
k1_repeated_subject_calibration_targets <- function(
    artifact_root, controller = "k1-repeated-subject", ...
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
        list(quote(landscapeR::run_k1_repeated_subject_calibration)),
        arguments, list(sequential_internal = TRUE)
    ))
    list(
        .k1_acceptance_target(
            "k1_repeated_subject_assessment", run_call,
            deployment = "worker", controller = controller
        ),
        .k1_acceptance_target(
            "k1_repeated_subject_artifact",
            substitute(
                landscapeR::publish_k1_repeated_subject_calibration(
                    ROOT, k1_repeated_subject_assessment
                ),
                list(ROOT = path.expand(artifact_root))
            ),
            format = "file"
        )
    )
}
