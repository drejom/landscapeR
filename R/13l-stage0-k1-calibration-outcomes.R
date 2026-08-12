# Stage 0 K=1 disclosed-calibration outcome assessment

utils::globalVariables(c(
    "outcome", "subjects_per_condition", "p", "recovery_rate",
    "downstream_estimability_rate", "outcome_label"
))

.k1_calibration_outcome_levels <- c(
    "recovered_and_estimable",
    "recovered_downstream_nonestimable",
    "recovery_below_threshold",
    "execution_failure"
)

.k1_calibration_semantics_version <- "k1-calibration-outcomes-v1"

setOldClass(c("K1CalibrationOutcomeAssessment", "list"))

.k1_calibration_model_states <- function(metrics, component) {
    provenance <- metrics$acceptance_provenance
    models <- provenance$atlas$time_course_models
    selected <- Filter(function(model) {
        is.list(model) && identical(model$component, component)
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
    recovery_evaluable <- is.finite(metrics$target_loading_cosine) &&
        identical(metrics$target_component,
            threshold$required_target_component) &&
        identical(metrics$nuisance_component,
            threshold$required_nuisance_component)
    recovery_met <- recovery_evaluable &&
        metrics$target_loading_cosine >=
            threshold$minimum_target_loading_cosine
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
    diagnostic <- ""
    if (!downstream_estimable) {
        models <- metrics$acceptance_provenance$atlas$time_course_models
        selected <- Filter(function(model) {
            is.list(model) && identical(
                model$component,
                threshold$required_target_component
            )
        }, models)
        diagnostics <- if (length(selected) == 1L) {
            unlist(lapply(selected[[1L]][c("unadjusted", "adjusted")],
                `[[`, "diagnostic"), use.names = FALSE)
        } else character()
        diagnostics <- unique(diagnostics[nzchar(diagnostics)])
        diagnostic <- if (length(diagnostics)) {
            paste(diagnostics, collapse = "; ")
        } else {
            "required downstream model or identifiability evidence unavailable"
        }
    }
    outcome <- if (!recovery_evaluable || !recovery_met) {
        "recovery_below_threshold"
    } else if (!downstream_estimable) {
        "recovered_downstream_nonestimable"
    } else {
        "recovered_and_estimable"
    }
    base$recovery_evaluable <- recovery_evaluable
    base$recovery_met <- recovery_met
    base$downstream_estimable <- if (recovery_met) {
        downstream_estimable
    } else {
        NA
    }
    base$target_loading_cosine <- metrics$target_loading_cosine
    base$target_subspace_angle_deg <- metrics$target_subspace_angle_deg
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
        "replicates", "cells"
    )
    if (!identical(names(payload), required) ||
            !identical(payload$semantics_version,
                .k1_calibration_semantics_version) ||
            !identical(payload$claim_status,
                "retrospective_diagnostic_only") ||
            !identical(payload$outcome_levels,
                .k1_calibration_outcome_levels) ||
            !is.data.frame(payload$replicates) ||
            !is.data.frame(payload$cells) || !nrow(payload$replicates) ||
            anyDuplicated(payload$source_task_ids) ||
            !identical(payload$source_task_ids,
                payload$replicates$task_id) ||
            !all(as.character(payload$replicates$outcome) %in%
                .k1_calibration_outcome_levels)) {
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
        recovered_and_estimable = "Recovered and estimable",
        recovered_downstream_nonestimable =
            "Recovered; downstream not estimable",
        recovery_below_threshold = "Axis not recovered",
        execution_failure = "Execution failed"
    )
    display$outcome_label <- factor(
        labels[as.character(display$outcome)],
        levels = unname(labels)
    )
    caption_view <- .new_scientific_caption_view(
        title = "K=1 disclosed-calibration recovery and estimability.",
        experiment_label = "AML-shaped synthetic calibration",
        target_field = "condition",
        oriented_levels = c("CTL", "CM"),
        sampling_unit = "complete synthetic mouse trajectory",
        time_field = "collection time",
        time_unit = "weeks",
        nuisance_fields = "batch",
        encodings = c(
            paste(
                "Each symbol is one requested replicate positioned by",
                "mice per condition and expression feature count."
            ),
            paste(
                "Shape identifies recovered and estimable, recovered but",
                "downstream non-estimable, recovery below threshold, or",
                "execution failure outcomes."
            )
        ),
        estimand = paste(
            "axis recovery and downstream estimability use separate",
            "declared denominators"
        ),
        missingness = paste(
            "Missing downstream rates indicate no recovered axis;",
            "recovered but downstream interpretation was not estimable is",
            "retained separately from replicates that did not recover the planted axis."
        ),
        threshold = paste0(
            "Axis recovery uses one canonical rule: loading cosine ≥ ",
            format(assessment$canonical_recovery_threshold, trim = TRUE),
            "; its equivalent angle is descriptive."
        ),
        claim_boundary = paste(
            "This is retrospective diagnostic evidence from consumed",
            "acceptance results and cannot revise their historical claim or",
            "validate a new protocol."
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
            values = c(16, 1, 4, 3),
            drop = FALSE
        ) +
        ggplot2::scale_x_continuous(
            breaks = sort(unique(display$subjects_per_condition))
        ) +
        ggplot2::labs(
            x = "Synthetic mice per condition",
            y = "Expression features",
            shape = "Calibration outcome"
        ) +
        theme_landscapeR(square = FALSE) +
        ggplot2::theme(legend.position = "bottom")
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
    reproduced <- assess_k1_calibration_outcomes(results, tasks, protocol)
    if (!identical(assessment, reproduced)) {
        .k1_acceptance_runner_abort(
            "calibration artifact assessment does not reproduce"
        )
    }
    expected_environment <- list(
        semantics_version = assessment$semantics_version,
        claim_status = assessment$claim_status,
        source_protocol_digest = assessment$source_protocol_digest,
        source_results_digest = assessment$source_results_digest,
        source_tasks_digest = assessment$source_tasks_digest,
        assessment_digest = assessment$digest
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
            width = 140,
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
            assessment_digest = assessment$digest
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
