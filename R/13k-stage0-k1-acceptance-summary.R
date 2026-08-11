# Stage 0 K=1 independent acceptance aggregation and figures

utils::globalVariables(c(
    "complete_cell", "n", "p", "rate", "replicate_pass_rate"
))

.k1_acceptance_wilson_lower <- function(successes, trials, confidence = 0.95) {
    if (trials < 1L) return(NA_real_)
    z <- stats::qnorm(1 - (1 - confidence) / 2)
    estimate <- successes / trials
    denominator <- 1 + z^2 / trials
    centre <- estimate + z^2 / (2 * trials)
    radius <- z * sqrt(
        estimate * (1 - estimate) / trials + z^2 / (4 * trials^2)
    )
    (centre - radius) / denominator
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
        wilson_lower <- .k1_acceptance_wilson_lower(passed, requested)
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
        data.frame(
            canonical_cell = cell_tasks$canonical_cell[[1L]],
            control = control,
            n = cell_tasks$n[[1L]],
            p = cell_tasks$p[[1L]],
            n_requested = as.integer(requested),
            n_completed = as.integer(completed),
            n_passed = as.integer(passed),
            replicate_pass_rate = pass_rate,
            wilson_95_lower = wilson_lower,
            false_double_well_rate = false_well,
            false_target_selection_rate = false_target,
            complete_cell = complete_cell,
            cell_pass = complete_cell && rate_gate && negative_gate,
            stringsAsFactors = FALSE
        )
    })
    cells <- do.call(rbind, rows)
    rownames(cells) <- NULL
    cells[order(cells$control, cells$n, cells$p), , drop = FALSE]
}

.k1_acceptance_expected_cell_count <- function(protocol) {
    generic <- protocol$grids$generic_double_well$varying
    negative <- protocol$grids$negative_controls$varying
    shared <- if (is.null(protocol$grids$shared_baseline_missing_cells)) {
        0L
    } else {
        length(
            protocol$grids$shared_baseline_missing_cells$varying$design_cell
        )
    }
    length(generic$n) * length(generic$p) +
        2L * length(negative$n) * length(negative$p) +
        shared
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
    required_controls <- c(
        "generic_double_well", "pure_noise", "single_well"
    )
    if (!is.null(protocol$grids$shared_baseline_missing_cells)) {
        required_controls <- c(
            required_controls,
            "shared_baseline_missing_cells"
        )
    }
    complete_execution <- all(cells$complete_cell) &&
        all(required_controls %in% cells$control) &&
        nrow(cells) == .k1_acceptance_expected_cell_count(protocol)
    supported <- if (complete_execution) {
        .k1_acceptance_supported_minimum(cells, protocol)
    } else NA_integer_
    payload <- list(
        artifact_version = protocol$artifact_version,
        protocol_id = protocol$protocol_id,
        protocol_digest = protocol$digest,
        runner_contract = protocol$execution_contracts$version,
        claim_status = if (complete_execution) {
            "independent_acceptance_summary"
        } else {
            "incomplete_execution_summary"
        },
        n_requested = nrow(tasks),
        n_completed = sum(vapply(results, function(result) {
            identical(result$status, "success")
        }, logical(1L))),
        cells = cells,
        display_thresholds = list(
            minimum_cell_pass_rate =
                protocol$pass_rules$minimum_cell_pass_rate,
            minimum_cell_wilson_95_lower_bound =
                protocol$pass_rules$minimum_cell_wilson_95_lower_bound,
            maximum_negative_false_positive_rate =
                protocol$thresholds$negative_controls$
                    maximum_false_double_well_rate_per_control_cell
        ),
        supported_minimum_n = supported,
        complete_execution = complete_execution
    )
    summary <- c(payload, list(
        digest = digest::digest(payload, algo = "sha256")
    ))
    class(summary) <- c("K1AcceptanceSummary", "list")
    summary
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
            breaks = seq(0, rate_upper, length.out = 5L),
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
