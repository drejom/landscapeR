# Stage 0 K=1 independent acceptance aggregation and figures

utils::globalVariables(c(
    "complete_cell", "n", "p", "rate", "replicate_pass_rate",
    "subjects_per_condition", "mean_target_loading_cosine",
    "mean_target_index_recurrence", "mean_identifiability_completion_rate",
    "p_label"
))

setOldClass(c("K1AcceptanceSummary", "list"))

.k1_acceptance_wilson_lower <- function(
    successes,
    trials,
    confidence = 0.95,
    artifact_version = "2"
) {
    if (trials < 1L) return(NA_real_)
    z <- stats::qnorm(1 - (1 - confidence) / 2)
    estimate <- successes / trials
    denominator <- 1 + z^2 / trials
    centre <- estimate + z^2 / (2 * trials)
    radius <- z * sqrt(
        estimate * (1 - estimate) / trials + z^2 / (4 * trials^2)
    )
    value <- (centre - radius) / denominator
    if (identical(artifact_version, "1")) value else round(value, digits = 15L)
}

.k1_acceptance_replicate_pass <- function(result, protocol) {
    if (!identical(result$status, "success")) return(FALSE)
    metrics <- result$metrics
    if (identical(result$control, "generic_double_well")) {
        thresholds <- protocol$thresholds$generic_double_well
        return(
            isTRUE(metrics$n_wells_found == thresholds$required_wells) &&
            isTRUE(metrics$n_barriers_found == thresholds$required_barriers) &&
            isTRUE(metrics$subspace_angle_deg <=
                thresholds$maximum_subspace_angle_degrees) &&
            isTRUE(metrics$well_error <=
                thresholds$maximum_mean_well_location_error) &&
            isTRUE(metrics$barrier_error <=
                thresholds$maximum_barrier_location_error) &&
            isTRUE(metrics$barrier_height_error <=
                thresholds$maximum_barrier_height_error)
        )
    }
    if (result$control %in% c("pure_noise", "single_well")) {
        return(
            identical(metrics$false_double_well, FALSE) &&
            identical(metrics$false_target_selection, FALSE)
        )
    }
    if (identical(result$control, "shared_baseline_missing_cells")) {
        thresholds <- protocol$thresholds$shared_baseline_missing_cells
        return(
            identical(
                metrics$abstention_reason,
                thresholds$required_abstention_reason
            ) &&
            identical(
                metrics$missing_control_time_cells,
                thresholds$required_missing_control_time_cells
            ) &&
            identical(
                metrics$unique_control_observations,
                thresholds$required_unique_control_observations
            ) &&
            identical(
                metrics$total_observations,
                thresholds$required_total_observations
            )
        )
    }
    if (identical(result$control, "aml_synchronized")) {
        thresholds <- protocol$thresholds$aml_synchronized
        metrics <- result$metrics
        return(
            isTRUE(metrics$target_loading_cosine >=
                thresholds$minimum_target_loading_cosine) &&
            isTRUE(metrics$target_subspace_angle_deg <=
                thresholds$maximum_target_subspace_angle_degrees) &&
            identical(metrics$target_component,
                thresholds$required_target_component) &&
            identical(metrics$nuisance_component,
                thresholds$required_nuisance_component) &&
            identical(metrics$target_proposal_rank,
                thresholds$required_proposal_rank) &&
            isTRUE(metrics$target_index_recurrence >=
                thresholds$minimum_target_index_recurrence) &&
            isTRUE(metrics$mean_matched_loading_cosine >=
                thresholds$minimum_mean_matched_loading_cosine) &&
            isTRUE(metrics$identifiability_completion_rate >=
                thresholds$minimum_resample_completion_rate) &&
            isTRUE(metrics$stage2_ineligible)
        )
    }
    FALSE
}

.k1_acceptance_expected_replicates <- function(protocol, control) {
    protocol$seed_plan$replicates_per_grid_cell[
        protocol$seed_plan$control == control
    ][[1L]]
}

.k1_acceptance_cell_summary <- function(results, tasks, protocol) {
    groups <- split(seq_len(nrow(tasks)), tasks$canonical_cell)
    rows <- lapply(groups, function(indices) {
        cell_tasks <- tasks[indices, , drop = FALSE]
        cell_results <- results[indices]
        control <- cell_tasks$control[[1L]]
        requested <- nrow(cell_tasks)
        completed <- sum(vapply(
            cell_results,
            function(result) identical(result$status, "success"),
            logical(1L)
        ))
        passed <- sum(vapply(
            cell_results,
            .k1_acceptance_replicate_pass,
            logical(1L),
            protocol = protocol
        ))
        pass_rate <- passed / requested
        wilson_lower <- .k1_acceptance_wilson_lower(
            passed,
            requested,
            artifact_version = protocol$artifact_version
        )
        false_well <- if (control %in% c("pure_noise", "single_well")) {
            sum(vapply(cell_results, function(result) {
                identical(result$metrics$false_double_well, TRUE)
            }, logical(1L))) / requested
        } else NA_real_
        false_target <- if (control %in% c("pure_noise", "single_well")) {
            sum(vapply(cell_results, function(result) {
                identical(result$metrics$false_target_selection, TRUE)
            }, logical(1L))) / requested
        } else NA_real_
        metric_mean <- function(name) {
            values <- vapply(cell_results, function(result) {
                value <- result$metrics[[name]]
                if (is.null(value)) NA_real_ else as.numeric(value)
            }, numeric(1L))
            if (all(is.na(values))) NA_real_ else mean(values, na.rm = TRUE)
        }
        metric_rate <- function(name, predicate) {
            values <- vapply(cell_results, function(result) {
                value <- result$metrics[[name]]
                if (is.null(value) || is.na(value)) NA else predicate(value)
            }, logical(1L))
            if (all(is.na(values))) NA_real_ else mean(values, na.rm = TRUE)
        }
        expected <- .k1_acceptance_expected_replicates(protocol, control)
        complete_cell <- requested == expected &&
            identical(sort(cell_tasks$replicate_index), seq_len(expected))
        rate_gate <- pass_rate >= protocol$pass_rules$minimum_cell_pass_rate &&
            wilson_lower >= protocol$pass_rules$minimum_cell_wilson_95_lower_bound
        negative_gate <- if (control %in% c("pure_noise", "single_well")) {
            false_well <= protocol$thresholds$negative_controls$
                maximum_false_double_well_rate_per_control_cell &&
            false_target <= protocol$thresholds$negative_controls$
                maximum_false_target_selection_rate_per_control_cell
        } else TRUE
        stage2_rate <- if (identical(control, "aml_synchronized")) {
            sum(vapply(cell_results, function(result) {
                identical(result$metrics$stage2_ineligible, TRUE)
            }, logical(1L))) / requested
        } else {
            metric_mean("stage2_ineligible")
        }
        aml_stage2_gate <- if (identical(control, "aml_synchronized")) {
            isTRUE(stage2_rate == protocol$thresholds$aml_synchronized$
                required_stage2_ineligibility_rate)
        } else TRUE
        data.frame(
            canonical_cell = cell_tasks$canonical_cell[[1L]],
            control = control,
            n = cell_tasks$n[[1L]],
            p = cell_tasks$p[[1L]],
            subjects_per_condition =
                cell_tasks$subjects_per_condition[[1L]],
            n_requested = as.integer(requested),
            n_completed = as.integer(completed),
            n_passed = as.integer(passed),
            replicate_pass_rate = pass_rate,
            wilson_95_lower = wilson_lower,
            false_double_well_rate = false_well,
            false_target_selection_rate = false_target,
            mean_target_loading_cosine =
                metric_mean("target_loading_cosine"),
            mean_target_subspace_angle_deg =
                metric_mean("target_subspace_angle_deg"),
            mean_bootstrap_subspace_angle_deg =
                metric_mean("mean_bootstrap_subspace_angle_deg"),
            mean_q95_bootstrap_subspace_angle_deg =
                metric_mean("q95_bootstrap_subspace_angle_deg"),
            mean_target_unadjusted_estimate =
                metric_mean("target_unadjusted_estimate"),
            mean_target_adjusted_estimate =
                metric_mean("target_adjusted_estimate"),
            mean_nuisance_unadjusted_estimate =
                metric_mean("nuisance_unadjusted_estimate"),
            mean_nuisance_adjusted_estimate =
                metric_mean("nuisance_adjusted_estimate"),
            target_rank_one_rate = metric_rate(
                "target_proposal_rank",
                function(value) value == 1L
            ),
            mean_target_index_recurrence =
                metric_mean("target_index_recurrence"),
            mean_matched_loading_cosine =
                metric_mean("mean_matched_loading_cosine"),
            mean_identifiability_completion_rate =
                metric_mean("identifiability_completion_rate"),
            stage2_ineligibility_rate = stage2_rate,
            mean_orientation_recurrence =
                metric_mean("orientation_recurrence"),
            mean_rank_one_fraction = metric_mean("rank_one_fraction"),
            mean_matched_fraction = metric_mean("matched_fraction"),
            complete_cell = complete_cell,
            cell_pass = complete_cell && rate_gate && negative_gate &&
                aml_stage2_gate,
            stringsAsFactors = FALSE
        )
    })
    cells <- do.call(rbind, rows)
    rownames(cells) <- NULL
    if (!"aml_synchronized" %in% tasks$control) {
        aml_only_columns <- c(
            "subjects_per_condition", "mean_target_loading_cosine",
            "mean_target_subspace_angle_deg", "target_rank_one_rate",
            "mean_bootstrap_subspace_angle_deg",
            "mean_q95_bootstrap_subspace_angle_deg",
            "mean_target_unadjusted_estimate",
            "mean_target_adjusted_estimate",
            "mean_nuisance_unadjusted_estimate",
            "mean_nuisance_adjusted_estimate",
            "mean_target_index_recurrence", "mean_matched_loading_cosine",
            "mean_identifiability_completion_rate",
            "stage2_ineligibility_rate", "mean_orientation_recurrence",
            "mean_rank_one_fraction", "mean_matched_fraction"
        )
        cells <- cells[, !names(cells) %in% aml_only_columns, drop = FALSE]
    }
    cells[order(
        cells$control,
        if ("subjects_per_condition" %in% names(cells)) {
            cells$subjects_per_condition
        } else {
            rep(NA_integer_, nrow(cells))
        },
        cells$n,
        cells$p,
        na.last = TRUE
    ), , drop = FALSE]
}

.k1_acceptance_expected_cell_count <- function(protocol, controls) {
    generic <- protocol$grids$generic_double_well$varying
    negative <- protocol$grids$negative_controls$varying
    shared <- if (is.null(protocol$grids$shared_baseline_missing_cells)) {
        0L
    } else {
        length(
            protocol$grids$shared_baseline_missing_cells$varying$design_cell
        )
    }
    aml <- protocol$grids$aml_synchronized$varying
    sum(c(
        if ("generic_double_well" %in% controls)
            length(generic$n) * length(generic$p) else 0L,
        if ("pure_noise" %in% controls)
            length(negative$n) * length(negative$p) else 0L,
        if ("single_well" %in% controls)
            length(negative$n) * length(negative$p) else 0L,
        if ("shared_baseline_missing_cells" %in% controls) shared else 0L,
        if ("aml_synchronized" %in% controls)
            length(aml$subjects_per_condition) * length(aml$p) else 0L
    ))
}

.k1_acceptance_supported_minimum <- function(cells, protocol) {
    controls <- c("generic_double_well", "pure_noise", "single_well")
    candidates <- Reduce(
        intersect,
        list(
            protocol$grids$generic_double_well$varying$n,
            protocol$grids$negative_controls$varying$n
        )
    )
    p_count <- length(protocol$grids$negative_controls$varying$p)
    for (candidate in candidates) {
        subset <- cells[cells$n == candidate & cells$control %in% controls, ]
        if (nrow(subset) == length(controls) * p_count &&
                identical(sort(unique(subset$control)), sort(controls)) &&
                all(subset$cell_pass)) {
            return(candidate)
        }
    }
    NA_integer_
}

#' Summarize frozen K=1 independent acceptance replicates
#'
#' Top-level failures remain in every denominator. Partial execution is
#' explicitly non-claiming: a cell cannot pass until all frozen replicate
#' indices are present.
#'
#' @param results list of `K1AcceptanceReplicate` objects.
#' @param tasks corresponding rows from a `K1AcceptanceManifest`.
#' @param protocol unmodified frozen K=1 protocol.
#' @return A digest-bound `K1AcceptanceSummary`.
#' @export
summarize_k1_acceptance <- function(
    results,
    tasks,
    protocol = k1_acceptance_protocol()
) {
    .k1_acceptance_public_boundary(
        .summarize_k1_acceptance_impl(results, tasks, protocol),
        "could not summarize K=1 acceptance results"
    )
}

.summarize_k1_acceptance_impl <- function(results, tasks, protocol) {
    validate_k1_acceptance_protocol(protocol)
    results <- .k1_acceptance_collect(results, tasks, protocol)
    cells <- .k1_acceptance_cell_summary(results, tasks, protocol)
    phase_b1_controls <- c(
        "generic_double_well", "pure_noise", "single_well"
    )
    if (!is.null(protocol$grids$shared_baseline_missing_cells)) {
        phase_b1_controls <- c(
            phase_b1_controls,
            "shared_baseline_missing_cells"
        )
    }
    observed_controls <- unique(tasks$control)
    aml_controls <- "aml_synchronized"
    exact_controls <- function(expected) {
        length(observed_controls) == length(expected) &&
            setequal(observed_controls, expected)
    }
    recognized_phase <- exact_controls(phase_b1_controls) ||
        exact_controls(aml_controls)
    complete_execution <- recognized_phase && all(cells$complete_cell) &&
        nrow(cells) == .k1_acceptance_expected_cell_count(
            protocol,
            observed_controls
        )
    supported <- if (complete_execution &&
            all(phase_b1_controls %in% observed_controls)) {
        .k1_acceptance_supported_minimum(cells, protocol)
    } else NA_integer_
    display_thresholds <- list(
        minimum_cell_pass_rate =
            protocol$pass_rules$minimum_cell_pass_rate,
        minimum_cell_wilson_95_lower_bound =
            protocol$pass_rules$minimum_cell_wilson_95_lower_bound,
        maximum_negative_false_positive_rate =
            protocol$thresholds$negative_controls$
                maximum_false_double_well_rate_per_control_cell
    )
    display_context <- NULL
    if ("aml_synchronized" %in% observed_controls) {
        aml_thresholds <- protocol$thresholds$aml_synchronized
        display_thresholds$minimum_target_loading_cosine <-
            aml_thresholds$minimum_target_loading_cosine
        display_thresholds$minimum_target_index_recurrence <-
            aml_thresholds$minimum_target_index_recurrence
        display_thresholds$minimum_resample_completion_rate <-
            aml_thresholds$minimum_resample_completion_rate
        display_thresholds$required_stage2_ineligibility_rate <-
            aml_thresholds$required_stage2_ineligibility_rate
        display_context <- list(
            experiment_label = "AML-shaped synthetic acceptance",
            target_field = protocol$execution_contracts$aml$target_field,
            reference_level =
                protocol$execution_contracts$aml$reference_level,
            comparison_level =
                protocol$execution_contracts$aml$comparison_level,
            nuisance_fields =
                protocol$execution_contracts$aml$nuisance_fields,
            sampling_unit = "complete synthetic mouse trajectory",
            time_field = "collection time",
            time_unit = "weeks",
            target_axis_label = "planted condition-by-time target axis",
            target_component = aml_thresholds$required_target_component,
            target_component_label = paste0(
                "PC", aml_thresholds$required_target_component
            )
        )
    }
    payload <- list(
        artifact_version = protocol$artifact_version,
        protocol_id = protocol$protocol_id,
        protocol_digest = protocol$digest,
        runner_contract = protocol$execution_contracts$version,
        claim_status = if (complete_execution &&
                exact_controls(aml_controls)) {
            "independent_aml_acceptance_summary"
        } else if (complete_execution) {
            "independent_acceptance_summary"
        } else {
            "incomplete_execution_summary"
        },
        n_requested = nrow(tasks),
        n_completed = sum(vapply(results, function(result) {
            identical(result$status, "success")
        }, logical(1L))),
        cells = cells,
        display_thresholds = display_thresholds,
        supported_minimum_n = supported,
        complete_execution = complete_execution
    )
    if (!is.null(display_context)) {
        payload$display_context <- display_context
    }
    summary <- c(payload, list(
        digest = digest::digest(payload, algo = "sha256")
    ))
    class(summary) <- c("K1AcceptanceSummary", "list")
    summary
}

#' @rdname visual_evidence
#' @export
setMethod("visual_evidence", "K1AcceptanceSummary", function(x) {
    payload <- unclass(x)
    observed_digest <- payload$digest
    payload$digest <- NULL
    if (!is.character(observed_digest) || length(observed_digest) != 1L ||
            !identical(
                observed_digest,
                digest::digest(payload, algo = "sha256")
            ) ||
            !isTRUE(x$complete_execution) ||
            !identical(unique(x$cells$control), "aml_synchronized") ||
            is.null(x$display_context)) {
        .stop_landscapeR_validation(
            "AML acceptance visual evidence requires a valid complete AML summary"
        )
    }
    cells <- x$cells
    feature_counts <- sort(unique(cells$p))
    panel_names <- stats::setNames(
        paste("Expression feature count", format(feature_counts, big.mark = ",")),
        LETTERS[seq_along(feature_counts)]
    )
    panel_labels <- paste0(
        "(", names(panel_names), ") p = ",
        format(feature_counts, big.mark = ",")
    )
    cells$p_label <- factor(
        paste0("p = ", format(cells$p, big.mark = ",")),
        levels = paste0("p = ", format(feature_counts, big.mark = ",")),
        labels = panel_labels
    )
    thresholds <- x$display_thresholds
    context <- x$display_context
    percent <- function(value) paste0(format(100 * value, trim = TRUE), "%")
    development_fixture <- identical(
        x$claim_status,
        "development_only_visual_fixture"
    )
    claim_boundary <- if (development_fixture) {
        paste(
            "Values are fabricated solely to demonstrate the figure",
            "structure and do not support a scientific acceptance claim."
        )
    } else {
        "Known-truth synthetic acceptance does not establish biological validity."
    }
    state <- "complete"
    pass_caption_view <- .new_scientific_caption_view(
        title = "Synchronized AML K=1 independent acceptance pass rates.",
        experiment_label = context$experiment_label,
        target_field = context$target_field,
        oriented_levels = c(context$reference_level, context$comparison_level),
        sampling_unit = context$sampling_unit,
        time_field = context$time_field,
        time_unit = context$time_unit,
        nuisance_fields = context$nuisance_fields,
        panels = panel_names,
        encodings = c(
            "Black points show the fraction of all requested replicates passing every prespecified AML criterion.",
            paste(
            "the red horizontal line marks the prespecified",
                percent(thresholds$minimum_cell_pass_rate),
                "cell pass-rate criterion."
            )
        ),
        estimand = "the replicate pass fraction within each subjects-per-condition and feature-count cell",
        uncertainty = paste(
            "Cell acceptance also requires a Wilson 95% lower bound of at least",
            paste0(percent(
                thresholds$minimum_cell_wilson_95_lower_bound
            ), ".")
        ),
        threshold = paste(
            paste(
                "Stage 2 must be correctly reported as inapplicable to",
                "longitudinal sampling in every replicate; the required",
                "cell rate is"
            ),
            paste0(percent(
                thresholds$required_stage2_ineligibility_rate
            ), ".")
        ),
        claim_boundary = claim_boundary,
        state = state
    )
    recovery_caption_view <- .new_scientific_caption_view(
        title = "Synchronized AML target-axis recovery and recurrence.",
        experiment_label = context$experiment_label,
        target_field = context$target_field,
        oriented_levels = c(context$reference_level, context$comparison_level),
        sampling_unit = context$sampling_unit,
        time_field = context$time_field,
        time_unit = context$time_unit,
        nuisance_fields = context$nuisance_fields,
        panels = panel_names,
        encodings = c(
            paste(
                "Horizontal position is mean absolute loading cosine with the",
                context$target_axis_label,
                sprintf("(%s).", context$target_component_label)
            ),
            paste(
                "vertical position is mean recurrence at reference component index",
                paste0(context$target_component, "; labels give mice per condition.")
            ),
            "point area is the mean fraction of requested complete-mouse bootstrap refits that completed."
        ),
        threshold = paste(
            "Red lines mark the prespecified loading-cosine and index-recurrence criteria of",
            percent(thresholds$minimum_target_loading_cosine),
            "and",
            paste0(percent(
                thresholds$minimum_target_index_recurrence
            ), ", respectively.")
        ),
        uncertainty = "Bootstrap enclosing-subspace angles and raw and adjusted association effects remain in the cell audit table.",
        claim_boundary = paste(
            claim_boundary,
            paste(
                "Orientation, proposal-rank, matching, and Stage 2",
                "ineligibility evidence are reported separately and do not",
                "substitute for the displayed criteria."
            )
        ),
        state = state
    )
    .new_visual_evidence_view(
        surface = "aml_acceptance",
        state = state,
        summaries = cells,
        diagnostics = cells[, c(
            "canonical_cell", "mean_bootstrap_subspace_angle_deg",
            "mean_q95_bootstrap_subspace_angle_deg",
            "mean_target_unadjusted_estimate",
            "mean_target_adjusted_estimate",
            "mean_nuisance_unadjusted_estimate",
            "mean_nuisance_adjusted_estimate", "stage2_ineligibility_rate"
        ), drop = FALSE],
        display_data = list(
            cells = cells,
            thresholds = thresholds,
            context = context,
            pass_rate_caption = .build_scientific_caption(pass_caption_view),
            recovery_caption = .build_scientific_caption(
                recovery_caption_view
            )
        ),
        caption_view = pass_caption_view
    )
})

#' Plot synchronized AML K=1 acceptance evidence
#'
#' @param summary complete AML-only object returned by
#'   [summarize_k1_acceptance()].
#' @param surface either `"pass_rate"` or `"recovery"`.
#' @return A caption-bearing `ggplot2` object.
#' @export
plot_k1_aml_acceptance_summary <- function(
    summary,
    surface = c("pass_rate", "recovery")
) {
    .k1_acceptance_public_boundary(
        .plot_k1_aml_acceptance_summary_impl(summary, surface),
        "could not plot AML K=1 acceptance summary"
    )
}

.plot_k1_aml_acceptance_summary_impl <- function(summary, surface) {
    surface <- match.arg(surface, c("pass_rate", "recovery"))
    view <- visual_evidence(summary)
    cells <- visual_evidence_display(view, "cells")
    thresholds <- visual_evidence_display(view, "thresholds")
    context <- visual_evidence_display(view, "context")
    palette <- landscapeR_palette("semantic")
    if (identical(surface, "pass_rate")) {
        threshold_labels <- unique(cells["p_label"])
        threshold_labels$x <- max(cells$subjects_per_condition)
        threshold_labels$y <- thresholds$minimum_cell_pass_rate
        threshold_labels$label <- paste(
            "Pass \u2265",
            .k1_acceptance_percent(thresholds$minimum_cell_pass_rate)
        )
        plot <- ggplot2::ggplot(
            cells,
            ggplot2::aes(
                x = subjects_per_condition,
                y = replicate_pass_rate,
                group = p_label
            )
        ) +
            ggplot2::geom_hline(
                yintercept = thresholds$minimum_cell_pass_rate,
                colour = unname(palette[["focal"]]),
                linewidth = 0.55
            ) +
            ggplot2::geom_line(
                colour = unname(palette[["ink"]]), linewidth = 0.55
            ) +
            ggplot2::geom_point(
                colour = unname(palette[["ink"]]), size = 1.8
            ) +
            ggplot2::geom_text(
                data = threshold_labels,
                ggplot2::aes(x = x, y = y, label = label),
                inherit.aes = FALSE,
                colour = unname(palette[["focal"]]),
                hjust = 1,
                vjust = -0.45,
                size = 2.3
            ) +
            ggplot2::facet_wrap(ggplot2::vars(p_label), nrow = 1L) +
            ggplot2::scale_x_continuous(
                breaks = sort(unique(cells$subjects_per_condition))
            ) +
            ggplot2::scale_y_continuous(
                limits = c(0, 1),
                labels = function(value) paste0(round(100 * value), "%")
            ) +
            ggplot2::labs(
                x = "Synthetic mice per condition",
                y = "Replicates meeting all prespecified criteria"
            ) +
            theme_landscapeR()
        return(.with_scientific_caption(
            plot,
            visual_evidence_display(view, "pass_rate_caption")
        ))
    }
    recovery_labels <- unique(cells["p_label"])
    loading_labels <- recovery_labels
    loading_labels$x <- thresholds$minimum_target_loading_cosine
    loading_labels$y <- 0.03
    loading_labels$label <- paste(
        "Loading \u2265",
        .k1_acceptance_percent(
            thresholds$minimum_target_loading_cosine
        )
    )
    recurrence_labels <- recovery_labels
    recurrence_labels$x <- 0.02
    recurrence_labels$y <- thresholds$minimum_target_index_recurrence
    recurrence_labels$label <- paste(
        "Index \u2265",
        .k1_acceptance_percent(
            thresholds$minimum_target_index_recurrence
        )
    )
    plot <- ggplot2::ggplot(
        cells,
        ggplot2::aes(
            x = mean_target_loading_cosine,
            y = mean_target_index_recurrence,
            size = mean_identifiability_completion_rate,
            label = subjects_per_condition
        )
    ) +
        ggplot2::geom_vline(
            xintercept = thresholds$minimum_target_loading_cosine,
            colour = unname(palette[["focal"]]), linewidth = 0.45
        ) +
        ggplot2::geom_hline(
            yintercept = thresholds$minimum_target_index_recurrence,
            colour = unname(palette[["focal"]]), linewidth = 0.45
        ) +
        ggplot2::geom_point(
            colour = unname(palette[["ink"]]), alpha = 0.85
        ) +
        ggplot2::geom_text(
            nudge_x = -0.035,
            hjust = 1,
            size = 2.6
        ) +
        ggplot2::geom_text(
            data = loading_labels,
            ggplot2::aes(x = x, y = y, label = label),
            inherit.aes = FALSE,
            colour = unname(palette[["focal"]]),
            angle = 90,
            hjust = 0,
            vjust = 1.3,
            size = 2.2
        ) +
        ggplot2::geom_text(
            data = recurrence_labels,
            ggplot2::aes(x = x, y = y, label = label),
            inherit.aes = FALSE,
            colour = unname(palette[["focal"]]),
            hjust = 0,
            vjust = 1.4,
            size = 2.2
        ) +
        ggplot2::facet_wrap(ggplot2::vars(p_label), nrow = 1L) +
        ggplot2::scale_x_continuous(
            limits = c(0, 1),
            breaks = c(0, 0.5, 1)
        ) +
        ggplot2::scale_y_continuous(limits = c(0, 1)) +
        ggplot2::scale_size_continuous(limits = c(0, 1), range = c(1.5, 4)) +
        ggplot2::labs(
            x = paste("Mean loading cosine with", context$target_axis_label),
            y = "Mean target-axis index recurrence",
            size = "Completed refits",
            label = "Mice per condition"
        ) +
        theme_landscapeR() +
        ggplot2::theme(panel.spacing.x = grid::unit(8, "pt"))
    .with_scientific_caption(
        plot,
        visual_evidence_display(view, "recovery_caption")
    )
}

.k1_acceptance_control_labels <- c(
    generic_double_well = "(A) Double-well\nrecovery",
    pure_noise = "(B) Pure noise",
    single_well = "(C) Single well",
    shared_baseline_missing_cells = "(D) Shared-baseline\nsafety"
)

.k1_acceptance_percent <- function(value) {
    paste0(format(100 * value, trim = TRUE, scientific = FALSE), "%")
}

.k1_acceptance_line_data <- function(data, group_fields) {
    group <- interaction(data[group_fields], drop = TRUE)
    data[stats::ave(seq_along(group), group, FUN = length) > 1L, , drop = FALSE]
}

.k1_acceptance_pass_caption <- function(summary) {
    pass_gate <- .k1_acceptance_percent(
        summary$display_thresholds$minimum_cell_pass_rate
    )
    wilson_gate <- .k1_acceptance_percent(
        summary$display_thresholds$minimum_cell_wilson_95_lower_bound
    )
    panels <- c(
        A = "Double-well recovery.",
        B = "Pure-noise negative control.",
        C = "Single-well negative control."
    )
    if ("shared_baseline_missing_cells" %in% summary$cells$control) {
        panels <- c(
            panels,
            D = paste(
                "Shared-baseline missing-cell design; a pass indicates that",
                "the condition-by-time interaction was correctly reported",
                "as non-estimable."
            )
        )
    }
    development_fixture <- identical(
        summary$claim_status,
        "development_only_visual_fixture"
    )
    view <- .new_scientific_caption_view(
        title = "K=1 independent acceptance pass rates.",
        experiment_label = "K=1 synthetic acceptance",
        panels = panels,
        encodings = c(
            "Black points show replicate pass rates for each feature count.",
            "open points identify cells with incomplete simulation results.",
            paste(
                "the red horizontal line marks the prespecified",
                pass_gate, "pass-rate gate."
            )
        ),
        estimand = paste(
            "the fraction of all requested replicates that pass;",
            "replicates without a valid result count as unsuccessful"
        ),
        uncertainty = paste(
            "Cell adjudication additionally requires a Wilson 95% lower",
            "bound of at least", paste0(wilson_gate, ".")
        ),
        threshold = paste(
            "A complete cell passes only at", pass_gate,
            "or greater with a Wilson 95% lower bound of at least",
            paste0(wilson_gate, ".")
        ),
        missingness = if (summary$complete_execution) {
            NA_character_
        } else {
            "The displayed execution is incomplete and cannot establish acceptance."
        },
        claim_boundary = if (development_fixture) {
            paste(
                "Values are simulated solely to demonstrate the figure",
                "structure and do not support a scientific acceptance claim."
            )
        } else {
            paste(
                "This figure summarizes prespecified known-truth controls and does",
                "not by itself establish biological validity."
            )
        },
        state = if (summary$complete_execution) "complete" else "partial"
    )
    .build_scientific_caption(view)
}

.k1_acceptance_false_positive_caption <- function(summary) {
    false_positive_gate <- .k1_acceptance_percent(
        summary$display_thresholds$maximum_negative_false_positive_rate
    )
    view <- .new_scientific_caption_view(
        title = "K=1 negative-control false-positive rates.",
        experiment_label = "K=1 synthetic acceptance",
        panels = c(
            A = "False double-well topology in pure noise.",
            B = "False target selection in pure noise.",
            C = "False double-well topology in single-well data.",
            D = "False target selection in single-well data."
        ),
        encodings = c(
            "Black points show per-cell false-positive rates by feature count.",
            "open points identify cells with incomplete simulation results.",
            paste(
                "the red horizontal line marks the prespecified",
                false_positive_gate, "maximum."
            )
        ),
        estimand = paste(
            "the false-positive fraction among all requested replicates in",
            "each control and grid cell; replicates without a valid result",
            "remain in the denominator"
        ),
        uncertainty = paste(
            "Rates remain descriptive until every prespecified replicate is",
            "present and the prespecified cell-level criteria are applied."
        ),
        threshold = paste(
            "Both negative-control false-positive rates must not exceed",
            paste0(false_positive_gate, ".")
        ),
        missingness = if (summary$complete_execution) {
            NA_character_
        } else {
            "The displayed execution is incomplete and cannot establish acceptance."
        },
        claim_boundary = if (identical(
            summary$claim_status,
            "development_only_visual_fixture"
        )) {
            paste(
                "Values are simulated solely to demonstrate the figure",
                "structure and do not support a scientific acceptance claim."
            )
        } else {
            paste(
                "Negative controls measure false topology and false target",
                "selection; pure noise has no planted subspace recovery target."
            )
        },
        state = if (summary$complete_execution) "complete" else "partial"
    )
    .build_scientific_caption(view)
}

#' Plot K=1 independent acceptance summaries
#'
#' @param summary object returned by [summarize_k1_acceptance()].
#' @param surface either `"pass_rate"` or `"false_positive"`.
#' @return A publication-themed ggplot with a separate dynamic caption
#'   available through [scientific_caption()].
#' @export
plot_k1_acceptance_summary <- function(
    summary,
    surface = c("pass_rate", "false_positive")
) {
    .k1_acceptance_public_boundary(
        .plot_k1_acceptance_summary_impl(summary, surface),
        "could not plot K=1 acceptance summary"
    )
}

.plot_k1_acceptance_summary_impl <- function(summary, surface) {
    if (!inherits(summary, "K1AcceptanceSummary")) {
        .k1_acceptance_runner_abort(
            "summary must inherit from K1AcceptanceSummary"
        )
    }
    surface <- match.arg(surface, c("pass_rate", "false_positive"))
    cells <- summary$cells
    palette <- landscapeR_palette("semantic")
    if (identical(surface, "pass_rate")) {
        cells$panel <- factor(
            unname(.k1_acceptance_control_labels[cells$control]),
            levels = unname(.k1_acceptance_control_labels)
        )
        line_data <- .k1_acceptance_line_data(cells, c("control", "p"))
        plot <- ggplot2::ggplot(
            cells,
            ggplot2::aes(
                x = n,
                y = replicate_pass_rate,
                group = factor(p),
                shape = factor(p),
                linetype = factor(p)
            )
        ) +
            ggplot2::geom_hline(
                yintercept = summary$display_thresholds$minimum_cell_pass_rate,
                colour = unname(palette[["focal"]]),
                linewidth = 0.4,
                linetype = 2
            ) +
            ggplot2::geom_line(
                data = line_data,
                colour = unname(palette[["nuisance"]]),
                linewidth = 0.35
            ) +
            ggplot2::geom_point(
                ggplot2::aes(fill = complete_cell),
                colour = unname(palette[["ink"]]),
                size = 1.8,
                stroke = 0.35
            ) +
            ggplot2::facet_wrap(~panel, nrow = 2L) +
            ggplot2::scale_fill_manual(
                values = c(
                    `TRUE` = unname(palette[["ink"]]),
                    `FALSE` = unname(palette[["paper"]])
                ),
                guide = "none"
            ) +
            ggplot2::scale_shape_manual(values = c(21, 24, 22, 23)) +
            ggplot2::scale_x_continuous(
                breaks = c(8, 24, 48, 96, 192),
                expand = ggplot2::expansion(mult = c(0.03, 0.03))
            ) +
            ggplot2::scale_y_continuous(
                limits = c(0, 1),
                breaks = seq(0, 1, 0.25),
                labels = function(value) paste0(round(100 * value), "%")
            ) +
            ggplot2::labs(
                x = "Independent biological observations (n)",
                y = "Replicate pass rate",
                shape = "Features (p)",
                linetype = "Features (p)"
            ) +
            theme_landscapeR(square = FALSE) +
            ggplot2::theme(
                aspect.ratio = 0.85,
                panel.spacing.x = grid::unit(5, "mm"),
                strip.text.x = ggplot2::element_text(
                    size = 7.5,
                    lineheight = 0.95
                )
            )
        return(.with_scientific_caption(
            plot,
            .k1_acceptance_pass_caption(summary)
        ))
    }
    negatives <- cells[cells$control %in% c("pure_noise", "single_well"), ]
    if (nrow(negatives)) {
        topology <- negatives
        topology$endpoint <- "False double-well topology"
        topology$rate <- topology$false_double_well_rate
        selection <- negatives
        selection$endpoint <- "False target selection"
        selection$rate <- selection$false_target_selection_rate
        display <- rbind(topology, selection)
    } else {
        display <- data.frame(
            control = rep(c("pure_noise", "single_well"), each = 2L),
            n = NA_integer_,
            p = NA_integer_,
            complete_cell = FALSE,
            endpoint = rep(
                c("False double-well topology", "False target selection"),
                times = 2L
            ),
            rate = NA_real_,
            stringsAsFactors = FALSE
        )
    }
    panel_key <- paste(display$control, display$endpoint, sep = "|")
    labels <- c(
        "pure_noise|False double-well topology" =
            "(A) Pure noise\nTopology",
        "pure_noise|False target selection" =
            "(B) Pure noise\nTarget selection",
        "single_well|False double-well topology" =
            "(C) Single well\nTopology",
        "single_well|False target selection" =
            "(D) Single well\nTarget selection"
    )
    display$panel <- factor(unname(labels[panel_key]), levels = unname(labels))
    observed <- display[is.finite(display$n) & is.finite(display$rate), ]
    line_data <- .k1_acceptance_line_data(
        observed,
        c("control", "endpoint", "p")
    )
    threshold <- summary$display_thresholds$
        maximum_negative_false_positive_rate
    finite_rates <- observed$rate[is.finite(observed$rate)]
    rate_upper <- min(
        1,
        max(
            0.10,
            2 * threshold,
            if (length(finite_rates)) 1.1 * max(finite_rates) else 0
        )
    )
    rate_breaks <- pretty(c(0, rate_upper), n = 5L)
    rate_upper <- min(1, max(rate_breaks))
    rate_breaks <- rate_breaks[
        rate_breaks >= 0 & rate_breaks <= rate_upper
    ]
    plot <- ggplot2::ggplot(
        display,
        ggplot2::aes(
            x = n,
            y = rate,
            group = factor(p),
            shape = factor(p),
            linetype = factor(p)
        )
    ) +
        ggplot2::geom_hline(
            yintercept = threshold,
            colour = unname(palette[["focal"]]),
            linewidth = 0.4,
            linetype = 2
        ) +
        ggplot2::geom_line(
            data = line_data,
            colour = unname(palette[["nuisance"]]),
            linewidth = 0.35
        ) +
        ggplot2::geom_point(
            data = observed,
            ggplot2::aes(fill = complete_cell),
            colour = unname(palette[["ink"]]),
            size = 1.8,
            stroke = 0.35
        ) +
        ggplot2::facet_wrap(~panel, nrow = 2L) +
        ggplot2::scale_fill_manual(
            values = c(
                `TRUE` = unname(palette[["ink"]]),
                `FALSE` = unname(palette[["paper"]])
            ),
            guide = "none"
        ) +
        ggplot2::scale_shape_manual(values = c(21, 24, 22, 23)) +
        ggplot2::scale_x_continuous(
            breaks = c(8, 24, 48, 96, 192),
            expand = ggplot2::expansion(mult = c(0.03, 0.03))
        ) +
        ggplot2::scale_y_continuous(
            limits = c(0, rate_upper),
            breaks = rate_breaks,
            labels = function(value) vapply(
                value,
                .k1_acceptance_percent,
                character(1L)
            )
        ) +
        ggplot2::labs(
            x = "Independent biological observations (n)",
            y = "False-positive rate",
            shape = "Features (p)",
            linetype = "Features (p)"
        ) +
        theme_landscapeR(square = FALSE) +
        ggplot2::theme(
            aspect.ratio = 0.85,
            panel.spacing.x = grid::unit(5, "mm"),
            strip.text.x = ggplot2::element_text(
                size = 7.5,
                lineheight = 0.95
            )
        )
    .with_scientific_caption(
        plot,
        .k1_acceptance_false_positive_caption(summary)
    )
}
