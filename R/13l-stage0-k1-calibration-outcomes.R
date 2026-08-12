# Stage 0 K=1 disclosed-calibration outcome assessment

utils::globalVariables(c(
    "outcome", "subjects_per_condition", "p", "recovery_rate",
    "downstream_estimability_rate", "outcome_label"
))

.k1_calibration_outcome_levels <- c(
    "recovered_and_estimable",
    "recovered_downstream_nonestimable",
    "recovery_below_threshold",
    "recovery_not_evaluable",
    "execution_failure"
)

.k1_calibration_semantics_version <- "k1-calibration-outcomes-v1"

.k1_calibration_scientific_context <- function() {
    list(
        experiment_label = "AML-shaped synthetic longitudinal calibration",
        target_field = "condition",
        oriented_levels = c("control", "disease"),
        sampling_unit = "complete synthetic mouse trajectory",
        time_field = "collection time",
        time_unit = "weeks",
        nuisance_fields = "batch"
    )
}

setOldClass(c("K1CalibrationOutcomeAssessment", "list"))

.k1_calibration_runtime_identity <- function() {
    identity <- tryCatch(
        .k1_acceptance_worker_identity(),
        landscapeR_worker_preflight_error = function(condition) NULL
    )
    if (!is.null(identity)) return(identity)
    source_root <- tryCatch(
        getNamespaceInfo(asNamespace("landscapeR"), "path"),
        error = function(condition) ""
    )
    git_root <- tryCatch(
        system2("git", c("-C", source_root, "rev-parse", "--show-toplevel"),
            stdout = TRUE, stderr = FALSE),
        error = function(condition) character()
    )
    status <- if (length(git_root) == 1L &&
            identical(normalizePath(git_root), normalizePath(source_root))) {
        tryCatch(
            system2("git", c("-C", source_root, "status", "--porcelain"),
                stdout = TRUE, stderr = FALSE),
            error = function(condition) "unavailable"
        )
    } else {
        "unavailable"
    }
    revision <- if (!length(status)) {
        tryCatch(
            system2("git", c("-C", source_root, "rev-parse", "HEAD"),
                stdout = TRUE, stderr = FALSE),
            error = function(condition) character()
        )
    } else {
        character()
    }
    if (length(revision) != 1L ||
            !grepl("^[0-9a-f]{40}$", revision)) {
        .k1_acceptance_runner_abort(
            paste(
                "calibration publication requires either revision-stamped",
                "package metadata or a clean landscapeR Git source revision"
            )
        )
    }
    packages <- c(
        "landscapeR", "digest", "ggplot2", "lme4", "clue",
        "future", "future.apply"
    )
    versions <- vapply(packages, function(package) {
        if (identical(package, "landscapeR")) {
            description <- utils::packageDescription("landscapeR")
            return(as.character(description$Version))
        }
        as.character(utils::packageVersion(package))
    }, character(1L))
    list(
        source_revision = revision,
        r_version = paste(R.version$major, R.version$minor, sep = "."),
        package_versions = versions
    )
}

.k1_calibration_model_states <- function(metrics, component) {
    provenance <- metrics$acceptance_provenance
    models <- provenance$atlas$time_course_models
    selected <- Filter(function(model) {
        is.list(model) && length(model$component) == 1L &&
            isTRUE(model$component == component)
    }, models)
    if (length(selected) != 1L) return(character())
    model <- selected[[1L]]
    c(model$unadjusted$status, model$adjusted$status)
}

.k1_calibration_outcome_row <- function(result, task, threshold) {
    base <- data.frame(
        task_id = task$task_id[[1L]],
        canonical_cell = task$canonical_cell[[1L]],
        control = task$control[[1L]],
        subjects_per_condition = task$subjects_per_condition[[1L]],
        p = task$p[[1L]],
        replicate_index = task$replicate_index[[1L]],
        execution_completed = identical(result$status, "success"),
        recovery_evaluable = FALSE,
        recovery_met = NA,
        downstream_estimable = NA,
        target_loading_cosine = NA_real_,
        target_subspace_angle_deg = NA_real_,
        target_component = NA_integer_,
        nuisance_component = NA_integer_,
        target_proposal_rank = NA_integer_,
        target_index_recurrence = NA_real_,
        mean_matched_loading_cosine = NA_real_,
        identifiability_completion_rate = NA_real_,
        target_unadjusted_estimate = NA_real_,
        target_adjusted_estimate = NA_real_,
        stage2_ineligible = NA,
        model_status = NA_character_,
        diagnostic = if (identical(result$status, "failure")) {
            result$reason
        } else {
            ""
        },
        outcome = "execution_failure",
        stringsAsFactors = FALSE
    )
    if (!base$execution_completed) return(base)

    metrics <- result$metrics
    target_component <- as.integer(metrics$target_component)
    nuisance_component <- as.integer(metrics$nuisance_component)
    component_identity_evaluable <-
        is.finite(target_component) &&
        is.finite(nuisance_component)
    recovery_evaluable <- is.finite(metrics$target_loading_cosine) &&
        component_identity_evaluable
    recovery_met <- if (recovery_evaluable) {
        target_component == threshold$required_target_component &&
            nuisance_component == threshold$required_nuisance_component &&
            metrics$target_loading_cosine >=
                threshold$minimum_target_loading_cosine
    } else {
        NA
    }
    model_states <- .k1_calibration_model_states(
        metrics,
        threshold$required_target_component
    )
    downstream_estimable <- length(model_states) == 2L &&
        all(model_states == "estimable") &&
        is.finite(metrics$target_unadjusted_estimate) &&
        is.finite(metrics$target_adjusted_estimate) &&
        is.finite(metrics$target_index_recurrence) &&
        is.finite(metrics$mean_matched_loading_cosine) &&
        is.finite(metrics$identifiability_completion_rate)
    downstream_diagnostic <- ""
    if (!downstream_estimable) {
        models <- metrics$acceptance_provenance$atlas$time_course_models
        selected <- Filter(function(model) {
            is.list(model) && length(model$component) == 1L &&
                isTRUE(model$component ==
                    threshold$required_target_component)
        }, models)
        diagnostics <- if (length(selected) == 1L) {
            unlist(lapply(selected[[1L]][c("unadjusted", "adjusted")],
                `[[`, "diagnostic"), use.names = FALSE)
        } else character()
        diagnostics <- unique(diagnostics[nzchar(diagnostics)])
        downstream_diagnostic <- if (length(diagnostics)) {
            paste(diagnostics, collapse = "; ")
        } else {
            "required downstream model or identifiability evidence unavailable"
        }
    }
    outcome <- if (!recovery_evaluable) {
        diagnostic <- if (!is.finite(metrics$target_loading_cosine)) {
            "canonical target-loading cosine unavailable"
        } else {
            "target or nuisance component identity unavailable"
        }
        "recovery_not_evaluable"
    } else if (!isTRUE(recovery_met)) {
        diagnostic <- if (
                target_component != threshold$required_target_component ||
                nuisance_component != threshold$required_nuisance_component
            ) {
            "component identity did not match the declared target and nuisance"
        } else {
            "target-loading cosine was below the recovery threshold"
        }
        "recovery_below_threshold"
    } else if (!downstream_estimable) {
        diagnostic <- downstream_diagnostic
        "recovered_downstream_nonestimable"
    } else {
        diagnostic <- ""
        "recovered_and_estimable"
    }
    base$recovery_evaluable <- recovery_evaluable
    base$recovery_met <- recovery_met
    base$downstream_estimable <- if (isTRUE(recovery_met)) {
        downstream_estimable
    } else {
        NA
    }
    base$target_loading_cosine <- metrics$target_loading_cosine
    base$target_subspace_angle_deg <- metrics$target_subspace_angle_deg
    base$target_component <- target_component
    base$nuisance_component <- nuisance_component
    base$target_proposal_rank <- metrics$target_proposal_rank
    base$target_index_recurrence <- metrics$target_index_recurrence
    base$mean_matched_loading_cosine <-
        metrics$mean_matched_loading_cosine
    base$identifiability_completion_rate <-
        metrics$identifiability_completion_rate
    base$target_unadjusted_estimate <- metrics$target_unadjusted_estimate
    base$target_adjusted_estimate <- metrics$target_adjusted_estimate
    base$stage2_ineligible <- metrics$stage2_ineligible
    base$model_status <- if (length(model_states)) {
        paste(unique(model_states), collapse = ";")
    } else {
        "unavailable"
    }
    base$diagnostic <- diagnostic
    base$outcome <- outcome
    base
}

.k1_calibration_cell_rows <- function(replicates) {
    groups <- split(seq_len(nrow(replicates)), replicates$canonical_cell)
    rows <- lapply(groups, function(indices) {
        data <- replicates[indices, , drop = FALSE]
        n_recovery_evaluable <- sum(data$recovery_evaluable)
        n_recovered <- sum(data$recovery_met %in% TRUE)
        n_downstream_evaluable <- n_recovered
        n_recovered_and_estimable <- sum(
            data$outcome == "recovered_and_estimable"
        )
        data.frame(
            canonical_cell = data$canonical_cell[[1L]],
            control = data$control[[1L]],
            subjects_per_condition = data$subjects_per_condition[[1L]],
            p = data$p[[1L]],
            n_requested = nrow(data),
            n_execution_completed = sum(data$execution_completed),
            n_execution_failure = sum(!data$execution_completed),
            n_recovery_evaluable = n_recovery_evaluable,
            n_recovered = n_recovered,
            n_recovery_below_threshold = sum(
                data$outcome == "recovery_below_threshold"
            ),
            n_recovery_not_evaluable = sum(
                data$outcome == "recovery_not_evaluable"
            ),
            n_downstream_evaluable = n_downstream_evaluable,
            n_recovered_and_estimable = n_recovered_and_estimable,
            n_recovered_downstream_nonestimable = sum(
                data$outcome == "recovered_downstream_nonestimable"
            ),
            recovery_rate = if (n_recovery_evaluable) {
                n_recovered / n_recovery_evaluable
            } else {
                NA_real_
            },
            downstream_estimability_rate = if (n_downstream_evaluable) {
                n_recovered_and_estimable / n_downstream_evaluable
            } else {
                NA_real_
            },
            recovery_rate_denominator =
                "replicates with evaluable decomposition recovery",
            estimability_rate_denominator =
                "replicates whose target axis was recovered",
            stringsAsFactors = FALSE
        )
    })
    result <- do.call(rbind, rows)
    rownames(result) <- NULL
    result[order(result$p, result$subjects_per_condition), , drop = FALSE]
}

#' Assess typed outcomes from a disclosed K=1 calibration run
#'
#' Reinterprets valid AML-shaped acceptance replicates as non-claiming
#' diagnostic evidence. Historical acceptance summaries and protocol digests
#' remain unchanged. One-dimensional recovery is governed only by loading
#' cosine; the equivalent angle remains descriptive.
#'
#' @param results valid AML-shaped `K1AcceptanceReplicate` objects.
#' @param tasks corresponding manifest task rows.
#' @param protocol frozen protocol that produced `results`.
#' @return A digest-bound `K1CalibrationOutcomeAssessment` containing
#'   replicate outcomes and operating-map-ready cell summaries.
#' @export
assess_k1_calibration_outcomes <- function(
    results,
    tasks,
    protocol = k1_acceptance_protocol()
) {
    .k1_acceptance_public_boundary({
        validate_k1_acceptance_protocol(protocol)
        results <- .k1_acceptance_collect(results, tasks, protocol)
        if (!nrow(tasks) || !all(tasks$control == "aml_synchronized")) {
            .k1_acceptance_runner_abort(
                "calibration outcome assessment requires AML-shaped tasks"
            )
        }
        threshold <- protocol$thresholds$aml_synchronized
        rows <- lapply(seq_len(nrow(tasks)), function(index) {
            .k1_calibration_outcome_row(
                results[[index]],
                tasks[index, , drop = FALSE],
                threshold
            )
        })
        replicates <- do.call(rbind, rows)
        rownames(replicates) <- NULL
        outcome_levels <- .k1_calibration_outcome_levels
        replicates$outcome <- factor(
            replicates$outcome,
            levels = outcome_levels
        )
        payload <- list(
            semantics_version = .k1_calibration_semantics_version,
            source_protocol_id = protocol$protocol_id,
            source_protocol_digest = protocol$digest,
            source_results_digest = digest::digest(results, algo = "sha256"),
            source_tasks_digest = digest::digest(tasks, algo = "sha256"),
            source_task_ids = tasks$task_id,
            claim_status = "retrospective_diagnostic_only",
            canonical_recovery_criterion =
                "minimum_target_loading_cosine",
            canonical_recovery_threshold =
                threshold$minimum_target_loading_cosine,
            descriptive_recovery_fields =
                "target_subspace_angle_deg",
            gating_fields = c(
                "target_loading_cosine",
                "target_component",
                "nuisance_component"
            ),
            outcome_levels = outcome_levels,
            denominator_contract = list(
                recovery_rate =
                    "replicates with evaluable decomposition recovery",
                downstream_estimability_rate =
                    "replicates whose target axis was recovered",
                execution_completion_rate = "all requested replicates"
            ),
            scientific_context = .k1_calibration_scientific_context(),
            replicates = replicates,
            cells = .k1_calibration_cell_rows(replicates)
        )
        assessment <- c(payload, list(
            digest = digest::digest(payload, algo = "sha256")
        ))
        class(assessment) <- c("K1CalibrationOutcomeAssessment", "list")
        assessment
    }, "could not assess K=1 calibration outcomes")
}

.validate_k1_calibration_outcomes <- function(x) {
    if (!inherits(x, "K1CalibrationOutcomeAssessment") || !is.list(x)) {
        .stop_landscapeR_validation(
            "assessment must inherit from K1CalibrationOutcomeAssessment"
        )
    }
    payload <- unclass(x)
    observed <- payload$digest
    payload$digest <- NULL
    if (!is.character(observed) || length(observed) != 1L ||
            !identical(observed, digest::digest(payload, algo = "sha256"))) {
        .stop_landscapeR_validation(
            "calibration outcome assessment digest is invalid"
        )
    }
    required <- c(
        "semantics_version", "source_protocol_id", "source_protocol_digest",
        "source_results_digest", "source_tasks_digest", "source_task_ids",
        "claim_status", "canonical_recovery_criterion",
        "canonical_recovery_threshold", "descriptive_recovery_fields",
        "gating_fields", "outcome_levels", "denominator_contract",
        "scientific_context", "replicates", "cells"
    )
    expected_denominators <- list(
        recovery_rate =
            "replicates with evaluable decomposition recovery",
        downstream_estimability_rate =
            "replicates whose target axis was recovered",
        execution_completion_rate = "all requested replicates"
    )
    context_fields <- c(
        "experiment_label", "target_field", "oriented_levels",
        "sampling_unit", "time_field", "time_unit", "nuisance_fields"
    )
    replicate_fields <- c(
        "task_id", "canonical_cell", "control", "subjects_per_condition",
        "p", "replicate_index", "execution_completed",
        "recovery_evaluable", "recovery_met", "downstream_estimable",
        "target_loading_cosine", "target_subspace_angle_deg",
        "target_component", "nuisance_component",
        "target_proposal_rank", "target_index_recurrence",
        "mean_matched_loading_cosine", "identifiability_completion_rate",
        "target_unadjusted_estimate", "target_adjusted_estimate",
        "stage2_ineligible", "model_status", "diagnostic", "outcome"
    )
    cell_fields <- c(
        "canonical_cell", "control", "subjects_per_condition", "p",
        "n_requested", "n_execution_completed", "n_execution_failure",
        "n_recovery_evaluable", "n_recovered",
        "n_recovery_below_threshold", "n_recovery_not_evaluable",
        "n_downstream_evaluable", "n_recovered_and_estimable",
        "n_recovered_downstream_nonestimable", "recovery_rate",
        "downstream_estimability_rate", "recovery_rate_denominator",
        "estimability_rate_denominator"
    )
    character_replicates <- c(
        "task_id", "canonical_cell", "control", "model_status", "diagnostic"
    )
    logical_replicates <- c(
        "execution_completed", "recovery_evaluable", "recovery_met",
        "downstream_estimable", "stage2_ineligible"
    )
    numeric_replicates <- setdiff(
        replicate_fields,
        c(character_replicates, logical_replicates, "outcome")
    )
    protocol_version <- switch(
        payload$source_protocol_id,
        `k1-stage0-acceptance-v1` = "1",
        `k1-stage0-acceptance-v2` = "2",
        NA_character_
    )
    source_protocol <- if (!is.na(protocol_version)) {
        k1_acceptance_protocol(protocol_version)
    } else {
        NULL
    }
    source_threshold <- if (!is.null(source_protocol)) {
        source_protocol$thresholds$aml_synchronized$
            minimum_target_loading_cosine
    } else {
        NA_real_
    }
    source_target_component <- if (!is.null(source_protocol)) {
        source_protocol$thresholds$aml_synchronized$
            required_target_component
    } else {
        NA_integer_
    }
    source_nuisance_component <- if (!is.null(source_protocol)) {
        source_protocol$thresholds$aml_synchronized$
            required_nuisance_component
    } else {
        NA_integer_
    }
    required_logical_complete <- c(
        "execution_completed", "recovery_evaluable"
    )
    design_fields <- c(
        "subjects_per_condition", "p", "replicate_index"
    )
    replicate_schema_valid <- is.data.frame(payload$replicates) &&
        identical(names(payload$replicates), replicate_fields) &&
        nrow(payload$replicates) > 0L &&
        all(vapply(payload$replicates[character_replicates],
            is.character, logical(1L))) &&
        all(vapply(payload$replicates[logical_replicates],
            is.logical, logical(1L))) &&
        all(vapply(payload$replicates[numeric_replicates],
            is.numeric, logical(1L))) &&
        is.factor(payload$replicates$outcome) &&
        !anyNA(payload$replicates[required_logical_complete]) &&
        all(vapply(payload$replicates[design_fields], function(value) {
            !anyNA(value) && all(is.finite(value)) && all(value >= 1) &&
                identical(as.numeric(as.integer(value)), as.numeric(value))
        }, logical(1L))) &&
        all(is.na(payload$replicates$recovery_met) ==
            !payload$replicates$recovery_evaluable) &&
        all(payload$replicates$recovery_evaluable |
            is.na(payload$replicates$downstream_estimable)) &&
        all(payload$replicates$execution_completed |
            is.na(payload$replicates$stage2_ineligible))
    expected_recovery_evaluable <-
        payload$replicates$execution_completed &
        is.finite(payload$replicates$target_loading_cosine) &
        is.finite(payload$replicates$target_component) &
        is.finite(payload$replicates$nuisance_component)
    expected_recovery_met <- expected_recovery_evaluable &
        payload$replicates$target_component == source_target_component &
        payload$replicates$nuisance_component == source_nuisance_component &
        payload$replicates$target_loading_cosine >= source_threshold
    expected_recovery_met[!expected_recovery_evaluable] <- NA
    expected_downstream_applicable <-
        !is.na(expected_recovery_met) & expected_recovery_met
    expected_outcome <- ifelse(
        !payload$replicates$execution_completed,
        "execution_failure",
        ifelse(
            !payload$replicates$recovery_evaluable,
            "recovery_not_evaluable",
            ifelse(
                !payload$replicates$recovery_met,
                "recovery_below_threshold",
                ifelse(
                    payload$replicates$downstream_estimable,
                    "recovered_and_estimable",
                    "recovered_downstream_nonestimable"
                )
            )
        )
    )
    cell_schema_valid <- is.data.frame(payload$cells) &&
        identical(names(payload$cells), cell_fields)
    if (!identical(names(payload), required) ||
            !identical(payload$semantics_version,
                .k1_calibration_semantics_version) ||
            !identical(payload$claim_status,
                "retrospective_diagnostic_only") ||
            is.null(source_protocol) ||
            !identical(payload$source_protocol_digest,
                source_protocol$digest) ||
            !identical(payload$outcome_levels,
                .k1_calibration_outcome_levels) ||
            !identical(payload$canonical_recovery_criterion,
                "minimum_target_loading_cosine") ||
            !identical(payload$canonical_recovery_threshold,
                source_threshold) ||
            !identical(payload$descriptive_recovery_fields,
                "target_subspace_angle_deg") ||
            !identical(payload$gating_fields, c(
                "target_loading_cosine", "target_component",
                "nuisance_component"
            )) ||
            !identical(payload$denominator_contract,
                expected_denominators) ||
            !is.list(payload$scientific_context) ||
            !identical(names(payload$scientific_context), context_fields) ||
            !identical(payload$scientific_context,
                .k1_calibration_scientific_context()) ||
            any(!vapply(payload$scientific_context,
                is.character, logical(1L))) ||
            any(!nzchar(unlist(payload$scientific_context,
                use.names = FALSE))) ||
            any(!vapply(payload[c(
                "source_protocol_digest", "source_results_digest",
                "source_tasks_digest"
            )], function(value) {
                is.character(value) && length(value) == 1L &&
                    grepl("^[0-9a-f]{64}$", value)
            }, logical(1L))) ||
            !replicate_schema_valid || !cell_schema_valid ||
            !identical(payload$replicates$recovery_evaluable,
                expected_recovery_evaluable) ||
            !identical(payload$replicates$recovery_met,
                expected_recovery_met) ||
            !identical(!is.na(payload$replicates$downstream_estimable),
                expected_downstream_applicable) ||
            !identical(as.character(payload$replicates$outcome),
                expected_outcome) ||
            anyDuplicated(payload$source_task_ids) ||
            !identical(payload$source_task_ids,
                payload$replicates$task_id) ||
            !all(as.character(payload$replicates$outcome) %in%
                .k1_calibration_outcome_levels) ||
            !identical(levels(payload$replicates$outcome),
                .k1_calibration_outcome_levels) ||
            !identical(payload$cells,
                .k1_calibration_cell_rows(payload$replicates))) {
        .stop_landscapeR_validation(
            "calibration outcome assessment contract is invalid"
        )
    }
    invisible(TRUE)
}

#' Plot disclosed K=1 calibration outcome states
#'
#' @param assessment object returned by [assess_k1_calibration_outcomes()].
#' @return A publication-themed `ggplot` with a separate scientific caption.
#' @export
plot_k1_calibration_outcomes <- function(assessment) {
    .validate_k1_calibration_outcomes(assessment)
    display <- assessment$replicates
    labels <- c(
        recovered_and_estimable = "Recovered, estimable",
        recovered_downstream_nonestimable =
            "Recovered, not estimable",
        recovery_below_threshold = "Not recovered",
        recovery_not_evaluable = "Recovery unavailable",
        execution_failure = "Execution failed"
    )
    display$outcome_label <- factor(
        labels[as.character(display$outcome)],
        levels = unname(labels)
    )
    caption_view <- .new_scientific_caption_view(
        title = "K=1 synthetic longitudinal recovery and estimability.",
        experiment_label = assessment$scientific_context$experiment_label,
        target_field = assessment$scientific_context$target_field,
        oriented_levels = assessment$scientific_context$oriented_levels,
        sampling_unit = assessment$scientific_context$sampling_unit,
        time_field = assessment$scientific_context$time_field,
        time_unit = assessment$scientific_context$time_unit,
        nuisance_fields = assessment$scientific_context$nuisance_fields,
        encodings = c(
            paste(
                "Each symbol is one requested replicate positioned by",
                "mice per condition and expression feature count"
            ),
            paste(
                "shape identifies recovered and estimable, recovered but",
                "downstream non-estimable, recovery below threshold,",
                "non-evaluable recovery, or execution failure outcomes."
            )
        ),
        estimand = paste(
            "the pair of separately reported rates for target-axis recovery",
            "and downstream estimability"
        ),
        missingness = paste(
            "Downstream estimability is not evaluated when the planted axis",
            "is not recovered or recovery itself is unavailable; recovered",
            "but downstream non-estimable replicates remain a distinct",
            "plotted state."
        ),
        threshold = paste0(
            "Axis recovery uses one canonical rule: loading cosine at least ",
            format(assessment$canonical_recovery_threshold, trim = TRUE),
            "; its equivalent angle is descriptive."
        ),
        claim_boundary = paste(
            "These known-truth synthetic results describe recovery under the",
            "tested settings only; they do not establish performance for",
            "biological data."
        ),
        state = "uncalibrated"
    )
    plot <- ggplot2::ggplot(display, ggplot2::aes(
        x = subjects_per_condition,
        y = factor(p, levels = sort(unique(p))),
        shape = outcome_label
    )) +
        ggplot2::geom_point(
            size = 3.1,
            stroke = 0.8,
            colour = unname(landscapeR_palette("semantic")[["ink"]]),
            position = ggplot2::position_jitter(
                width = 0.10,
                height = 0,
                seed = 188L
            )
        ) +
        ggplot2::scale_shape_manual(
            values = c(16, 1, 4, 0, 3),
            drop = FALSE
        ) +
        ggplot2::scale_x_continuous(
            breaks = sort(unique(display$subjects_per_condition))
        ) +
        ggplot2::labs(
            x = "Synthetic mice per condition",
            y = "Expression features",
            shape = NULL
        ) +
        theme_landscapeR(square = FALSE) +
        ggplot2::guides(shape = ggplot2::guide_legend(
            ncol = 2L,
            byrow = TRUE
        )) +
        ggplot2::theme(
            legend.position = "bottom",
            legend.text = ggplot2::element_text(size = 7)
        )
    .with_scientific_caption(
        plot,
        .build_scientific_caption(caption_view)
    )
}

.k1_calibration_governed_files <- function() {
    c(
        "protocol.rds", "source-results.rds", "source-tasks.rds",
        "assessment.rds", "replicates.csv", "cell-summary.csv",
        "outcome-map.png", "outcome-map-caption.txt", "environment.rds"
    )
}

.k1_calibration_verify_artifact <- function(artifact) {
    artifact <- path.expand(artifact)
    manifest_path <- file.path(artifact, "MANIFEST.tsv")
    if (!file.exists(manifest_path)) {
        .k1_acceptance_runner_abort(
            "calibration artifact has no MANIFEST.tsv"
        )
    }
    files <- utils::read.delim(manifest_path, stringsAsFactors = FALSE)
    if (!identical(names(files), c("file", "sha256")) ||
            !identical(files$file, .k1_calibration_governed_files()) ||
            anyNA(files) || anyDuplicated(files$file) ||
            any(grepl("(^|/)\\.\\.(/|$)|^/", files$file))) {
        .k1_acceptance_runner_abort(
            "calibration artifact file manifest is invalid"
        )
    }
    paths <- file.path(artifact, files$file)
    actual_files <- list.files(
        artifact,
        recursive = TRUE,
        all.files = TRUE,
        no.. = TRUE,
        include.dirs = FALSE
    )
    if (!setequal(actual_files, c("MANIFEST.tsv", files$file))) {
        .k1_acceptance_runner_abort(
            "calibration artifact contains undeclared files"
        )
    }
    if (any(!file.exists(paths))) {
        .k1_acceptance_runner_abort("calibration artifact is incomplete")
    }
    observed <- vapply(
        paths,
        .k1_acceptance_file_digest,
        character(1L)
    )
    if (!identical(unname(observed), files$sha256)) {
        .k1_acceptance_runner_abort(
            "calibration artifact digest verification failed"
        )
    }
    protocol <- readRDS(file.path(artifact, "protocol.rds"))
    results <- readRDS(file.path(artifact, "source-results.rds"))
    tasks <- readRDS(file.path(artifact, "source-tasks.rds"))
    assessment <- readRDS(file.path(artifact, "assessment.rds"))
    environment <- readRDS(file.path(artifact, "environment.rds"))
    .k1_acceptance_validate_identity(environment$runtime_identity)
    reproduced <- assess_k1_calibration_outcomes(results, tasks, protocol)
    if (!identical(assessment, reproduced)) {
        .k1_acceptance_runner_abort(
            "calibration artifact assessment does not reproduce"
        )
    }
    expected_replicates <- tempfile("k1-calibration-replicates-", fileext = ".csv")
    expected_cells <- tempfile("k1-calibration-cells-", fileext = ".csv")
    on.exit(unlink(c(expected_replicates, expected_cells)), add = TRUE)
    utils::write.csv(reproduced$replicates, expected_replicates,
        row.names = FALSE)
    utils::write.csv(reproduced$cells, expected_cells, row.names = FALSE)
    expected_caption <- strsplit(
        scientific_caption(plot_k1_calibration_outcomes(reproduced)),
        "\\n",
        fixed = FALSE
    )[[1L]]
    if (!identical(
            readLines(file.path(artifact, "replicates.csv"), warn = FALSE),
            readLines(expected_replicates, warn = FALSE)
        ) || !identical(
            readLines(file.path(artifact, "cell-summary.csv"), warn = FALSE),
            readLines(expected_cells, warn = FALSE)
        ) || !identical(
            readLines(file.path(artifact, "outcome-map-caption.txt"),
                warn = FALSE),
            expected_caption
        )) {
        .k1_acceptance_runner_abort(
            "calibration artifact derivatives do not reproduce"
        )
    }
    expected_environment <- list(
        semantics_version = assessment$semantics_version,
        claim_status = assessment$claim_status,
        source_protocol_digest = assessment$source_protocol_digest,
        source_results_digest = assessment$source_results_digest,
        source_tasks_digest = assessment$source_tasks_digest,
        assessment_digest = assessment$digest,
        runtime_identity = environment$runtime_identity
    )
    artifact_digest <- .k1_acceptance_artifact_digest(files)
    expected_name <- paste0(
        assessment$semantics_version,
        "-",
        substr(artifact_digest, 1L, 16L)
    )
    if (!identical(environment, expected_environment) ||
            !identical(basename(artifact), expected_name)) {
        .k1_acceptance_runner_abort(
            "calibration artifact address or provenance is inconsistent"
        )
    }
    invisible(TRUE)
}

#' Publish a replayable K=1 calibration outcome artifact
#'
#' Writes the source evidence and its typed, non-claiming interpretation to a
#' content-addressed directory. Use this after a disclosed calibration run when
#' readers need to inspect recovery failures separately from downstream model
#' abstentions. The historical acceptance artifact is not changed.
#'
#' @param artifact_root directory in which to publish the artifact.
#' @param results valid AML-shaped `K1AcceptanceReplicate` objects.
#' @param tasks corresponding manifest task rows.
#' @param protocol frozen protocol that produced `results`.
#' @return Path to the verified, content-addressed artifact directory.
#' @export
publish_k1_calibration_outcomes <- function(
    artifact_root,
    results,
    tasks,
    protocol = k1_acceptance_protocol()
) {
    .k1_acceptance_public_boundary({
        assessment <- assess_k1_calibration_outcomes(
            results,
            tasks,
            protocol
        )
        plot <- plot_k1_calibration_outcomes(assessment)
        runtime_identity <- .k1_calibration_runtime_identity()
        .k1_acceptance_validate_identity(runtime_identity)
        artifact_root <- path.expand(artifact_root)
        dir.create(artifact_root, recursive = TRUE, showWarnings = FALSE)
        staging <- tempfile(
            pattern = paste0(".", assessment$semantics_version, "-tmp-"),
            tmpdir = artifact_root
        )
        dir.create(staging, recursive = TRUE, showWarnings = FALSE)
        saveRDS(protocol, file.path(staging, "protocol.rds"))
        saveRDS(results, file.path(staging, "source-results.rds"))
        saveRDS(tasks, file.path(staging, "source-tasks.rds"))
        saveRDS(assessment, file.path(staging, "assessment.rds"))
        utils::write.csv(
            assessment$replicates,
            file.path(staging, "replicates.csv"),
            row.names = FALSE
        )
        utils::write.csv(
            assessment$cells,
            file.path(staging, "cell-summary.csv"),
            row.names = FALSE
        )
        ggplot2::ggsave(
            file.path(staging, "outcome-map.png"),
            plot,
            width = 100,
            height = 100,
            units = "mm",
            dpi = 450,
            bg = "white"
        )
        writeLines(
            scientific_caption(plot),
            file.path(staging, "outcome-map-caption.txt")
        )
        environment <- list(
            semantics_version = assessment$semantics_version,
            claim_status = assessment$claim_status,
            source_protocol_digest = assessment$source_protocol_digest,
            source_results_digest = assessment$source_results_digest,
            source_tasks_digest = assessment$source_tasks_digest,
            assessment_digest = assessment$digest,
            runtime_identity = runtime_identity
        )
        saveRDS(environment, file.path(staging, "environment.rds"))
        governed <- .k1_calibration_governed_files()
        file_manifest <- data.frame(
            file = governed,
            sha256 = vapply(
                file.path(staging, governed),
                .k1_acceptance_file_digest,
                character(1L)
            ),
            stringsAsFactors = FALSE
        )
        artifact_digest <- .k1_acceptance_artifact_digest(file_manifest)
        artifact <- file.path(
            artifact_root,
            paste0(
                assessment$semantics_version,
                "-",
                substr(artifact_digest, 1L, 16L)
            )
        )
        if (dir.exists(artifact)) {
            unlink(staging, recursive = TRUE)
            .k1_calibration_verify_artifact(artifact)
            return(artifact)
        }
        utils::write.table(
            file_manifest,
            file.path(staging, "MANIFEST.tsv"),
            sep = "\t",
            quote = FALSE,
            row.names = FALSE
        )
        if (!file.rename(staging, artifact)) {
            unlink(staging, recursive = TRUE)
            .k1_acceptance_runner_abort(
                "could not atomically publish calibration artifact"
            )
        }
        .k1_calibration_verify_artifact(artifact)
        artifact
    }, "could not publish K=1 calibration outcomes")
}

#' Verify a replayable K=1 calibration outcome artifact
#'
#' @param artifact path returned by `publish_k1_calibration_outcomes()`.
#' @return Invisibly `TRUE`, or throws `k1_acceptance_runner_error`.
#' @export
verify_k1_calibration_outcomes <- function(artifact) {
    .k1_acceptance_public_boundary(
        .k1_calibration_verify_artifact(artifact),
        "could not verify K=1 calibration outcomes"
    )
}
