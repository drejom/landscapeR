# Stage 0 — full, frozen Stage 1 candidate evidence execution
#
# These functions execute and inspect the accepted v2 evidence protocol. They
# deliberately operate on prototype candidates only; they do not register a
# production Decomposer or change Issue #24's contract.

.stage1_evidence_abort <- function(message, execution = NULL) {
    stop(structure(list(message = message, call = NULL, execution = execution),
                   class = c("stage1_evidence_error", "error", "condition")))
}

.stage1_benchmark_strata <- function(manifest = stage1_benchmark_manifest()) {
    validate_stage1_benchmark_manifest(manifest)
    fields <- names(manifest$grid)
    strata <- do.call(expand.grid, c(manifest$grid,
        list(KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)))
    strata <- strata[do.call(order, strata[fields]), fields, drop = FALSE]
    rownames(strata) <- NULL
    strata
}

.stage1_gate_is_expected <- function(rows) {
    all((rows$gate_expected == "success" & rows$gate_observed == "success") |
        (rows$gate_expected == "typed_failure" & rows$gate_observed == "typed_failure"))
}

.stage1_require_results <- function(rows, split = NULL, selected = NULL) {
    required <- c("candidate", "seed", "split", "stratum_digest", "stratum",
                  "protocol_id", "generator", "protocol_digest", "generator_digest", "tier",
                  "gate_expected", "gate_observed", "gate_passed", "projection_case",
                  "shared_signal", "noise_sd", "shared_recovery_error",
                  "response_recovery_error", "exclusive_leakage", "projection_error",
                  "elapsed_sec", "peak_vcells_bytes")
    if (!is.data.frame(rows) || !all(required %in% names(rows)))
        .stage1_evidence_abort("benchmark rows have an invalid schema")
    if (!is.null(split) && (!all(rows$split == split)))
        .stage1_evidence_abort(sprintf("%s aggregation received rows from another split", split))
    if (!is.null(selected) && (!all(rows$candidate == selected)))
        .stage1_evidence_abort("holdout aggregation received an unselected candidate")
    if (anyNA(rows$stratum_digest) || anyNA(rows$seed) || anyDuplicated(rows[c("candidate", "stratum_digest", "seed")]))
        .stage1_evidence_abort("benchmark rows must be uniquely identified by candidate, stratum, and seed")
    if (length(unique(rows$protocol_id)) != 1L || length(unique(rows$generator)) != 1L ||
        length(unique(rows$protocol_digest)) != 1L || length(unique(rows$generator_digest)) != 1L)
        .stage1_evidence_abort("benchmark rows mix protocol or generator identities")
    invisible(TRUE)
}

.stage1_candidate_eligibility <- function(rows, candidate) {
    candidate_rows <- rows[rows$candidate == candidate, , drop = FALSE]
    length(candidate_rows) > 0L && all(candidate_rows$gate_passed) &&
        .stage1_gate_is_expected(candidate_rows)
}

.stage1_exact_rows <- function(rows) {
    exact <- rows[rows$projection_case == "exact_ids", , drop = FALSE]
    if (!nrow(exact) || any(!is.finite(as.matrix(exact[, c(
        "shared_recovery_error", "response_recovery_error", "exclusive_leakage",
        "projection_error", "elapsed_sec"
    )]))))
        .stage1_evidence_abort("exact-ID rows must contain finite numerical metrics")
    exact
}

.stage1_equal_stratum_mean <- function(rows, candidate, metric) {
    candidate_rows <- rows[rows$candidate == candidate, , drop = FALSE]
    by_stratum <- split(candidate_rows[[metric]], candidate_rows$stratum_digest)
    mean(vapply(by_stratum, mean, numeric(1L)))
}

.stage1_summary_measurements <- function(tasks, task_ids, shared_input, execution) {
    data.frame(
        requested_tasks = as.integer(length(tasks)),
        serialized_tasks_bytes = as.numeric(length(serialize(tasks, NULL))),
        serialized_task_ids_bytes = as.numeric(length(serialize(task_ids, NULL))),
        serialized_shared_input_bytes = as.numeric(length(serialize(shared_input, NULL))),
        serialized_values_bytes = as.numeric(length(serialize(execution$values, NULL))),
        serialized_provenance_bytes = as.numeric(length(serialize(execution$provenance, NULL))),
        serialized_execution_bytes = as.numeric(length(serialize(execution, NULL))),
        stringsAsFactors = FALSE
    )
}

.stage1_require_summary_completion <- function(repetition, label) {
    if (repetition$execution$account$n_failed > 0L) {
        .stage1_evidence_abort(
            paste(label, "contains failed repetitions"),
            execution = repetition$execution
        )
    }
    invisible(repetition)
}

.stage1_paired_bootstrap <- function(
    exact_rows,
    metric,
    rules,
    sequential_internal = FALSE,
    future_scheduling = NULL
) {
    strata <- split(exact_rows, exact_rows$stratum_digest)
    paired <- lapply(strata, function(stratum) {
        c1 <- stratum[stratum$candidate == "C1_symmetric_consensus", c("seed", metric), drop = FALSE]
        c2 <- stratum[stratum$candidate == "C2_block_scaled_svd", c("seed", metric), drop = FALSE]
        c1 <- c1[order(c1$seed), , drop = FALSE]
        c2 <- c2[order(c2$seed), , drop = FALSE]
        if (!nrow(c1) || !identical(c1$seed, c2$seed))
            .stage1_evidence_abort("calibration candidates must be paired by seed in every stratum")
        c1[[metric]] - c2[[metric]]
    })
    tasks <- as.list(seq_len(rules$bootstrap_resamples))
    task_ids <- sprintf(
        "stage1-calibration:%s:paired-bootstrap:%05d",
        metric,
        seq_along(tasks)
    )
    repetition <- .future_numeric_repetition(
        tasks = tasks,
        task_ids = task_ids,
        run_seed = rules$bootstrap_seed,
        compute_tier = "evidence",
        worker = function(task, task_id, task_stream) {
            mean(vapply(
                paired,
                function(values) mean(sample(
                    values,
                    length(values),
                    replace = TRUE
                )),
                numeric(1L)
            ))
        },
        sequential_internal = sequential_internal,
        future_scheduling = future_scheduling,
        failure_code = "stage1-paired-bootstrap-failure",
        legacy_stream_advance = function(task, task_id) {
            lapply(paired, function(values) {
                sample(values, length(values), replace = TRUE)
            })
            invisible(NULL)
        }
    )
    .stage1_require_summary_completion(repetition, "paired bootstrap")
    list(
        interval = stats::quantile(
            repetition$values,
            probs = c(0.025, 0.975),
            names = FALSE,
            type = 7L
        ),
        execution = repetition$execution,
        measurements = .stage1_summary_measurements(
            tasks,
            task_ids,
            paired,
            repetition$execution
        )
    )
}

#' Select the Stage 1 baseline from calibration evidence
#'
#' Applies the immutable `stage1-heterogeneous-v2` calibration rule. The input
#' must contain calibration rows only; it cannot inspect holdout evidence.
#'
#' @param calibration_rows one row per candidate/seed/stratum from the frozen
#'   calibration split.
#' @param manifest canonical Stage 1 benchmark manifest.
#' @param sequential_internal logical; set `TRUE` when this workflow already
#'   runs inside an outer future or workflow-orchestration task.
#' @param future_scheduling optional future.apply scheduling value; `NULL`
#'   leaves scheduling to the user-selected future backend.
#' @return a serializable selection record.
#' @export
select_stage1_candidate <- function(calibration_rows,
                                    manifest = stage1_benchmark_manifest(),
                                    sequential_internal = FALSE,
                                    future_scheduling = NULL) {
    validate_stage1_benchmark_manifest(manifest)
    .stage1_require_results(calibration_rows, split = "calibration")
    if (!isTRUE(all(calibration_rows$tier == "full")))
        .stage1_evidence_abort("non-evidentiary benchmark rows cannot select a candidate")
    if (!identical(sort(unique(calibration_rows$candidate)), sort(manifest$candidates)))
        .stage1_evidence_abort("calibration rows must contain exactly the frozen candidates")
    if (!identical(unique(calibration_rows$protocol_id), manifest$protocol_id) ||
        !identical(unique(calibration_rows$generator), manifest$generator) ||
        !identical(unique(calibration_rows$protocol_digest), .protocol_digest(manifest)) ||
        !identical(unique(calibration_rows$generator_digest), .generator_digest()))
        .stage1_evidence_abort("calibration rows do not match the frozen manifest or generator")

    eligible <- stats::setNames(vapply(manifest$candidates, function(candidate)
        .stage1_candidate_eligibility(calibration_rows, candidate), logical(1L)), manifest$candidates)
    exact <- .stage1_exact_rows(calibration_rows)
    rules <- manifest$selection_rules
    shared_difference <- .stage1_equal_stratum_mean(exact, "C1_symmetric_consensus",
        "shared_recovery_error") - .stage1_equal_stratum_mean(exact, "C2_block_scaled_svd",
        "shared_recovery_error")
    shared_bootstrap <- .stage1_paired_bootstrap(
        exact,
        "shared_recovery_error",
        rules,
        sequential_internal = sequential_internal,
        future_scheduling = future_scheduling
    )
    shared_ci <- shared_bootstrap$interval
    leakage_difference <- .stage1_equal_stratum_mean(exact, "C1_symmetric_consensus",
        "exclusive_leakage") - .stage1_equal_stratum_mean(exact, "C2_block_scaled_svd",
        "exclusive_leakage")
    projection_difference <- .stage1_equal_stratum_mean(exact, "C1_symmetric_consensus",
        "projection_error") - .stage1_equal_stratum_mean(exact, "C2_block_scaled_svd",
        "projection_error")
    elapsed_ratio <- stats::median(exact$elapsed_sec[exact$candidate == "C1_symmetric_consensus"]) /
        stats::median(exact$elapsed_sec[exact$candidate == "C2_block_scaled_svd"])
    # Runtime is an operational diagnostic, not a scientific gate.  The
    # elapsed ratio can legitimately differ across sequential, local, and
    # scheduler-backed execution while all scientific quantities are equal.
    # Keeping it out of the decision is therefore required by ADR 0018's
    # backend-invariant evidence contract.
    c1_conditions <- c(
        both_eligible = all(eligible),
        shared_advantage = shared_difference <= rules$shared_recovery_advantage,
        shared_ci_below_zero = shared_ci[[2L]] < 0,
        leakage_not_worse = leakage_difference <= rules$maximum_leakage_or_projection_disadvantage,
        projection_not_worse = projection_difference <= rules$maximum_leakage_or_projection_disadvantage
    )
    if (!identical(rules$runtime_gate, "diagnostic_only"))
        .stage1_evidence_abort("frozen protocol must declare runtime as diagnostic_only")
    selected <- if (all(c1_conditions)) "C1_symmetric_consensus" else if (eligible[["C2_block_scaled_svd"]])
        "C2_block_scaled_svd" else NA_character_
    list(
        protocol_id = manifest$protocol_id,
        protocol_digest = .protocol_digest(manifest),
        generator_digest = .generator_digest(),
        split = "calibration",
        decision = if (is.na(selected)) "no_eligible_candidate" else "selected",
        selected_candidate = selected,
        eligible = eligible,
        conditions = c1_conditions,
        shared_recovery_difference = shared_difference,
        shared_recovery_ci = stats::setNames(shared_ci, c("lower", "upper")),
        exclusive_leakage_difference = leakage_difference,
        projection_difference = projection_difference,
        elapsed_ratio = elapsed_ratio,
        elapsed_within_limit = elapsed_ratio <= rules$maximum_elapsed_ratio,
        runtime_note = "operational diagnostic only; not used for candidate selection",
        bootstrap_executions = list(
            shared_recovery_error = shared_bootstrap$execution
        ),
        bootstrap_measurements = list(
            shared_recovery_error = shared_bootstrap$measurements
        ),
        rules = rules
    )
}

.stage1_bootstrap_median_ci <- function(
    values,
    seed,
    rules,
    task_scope,
    sequential_internal = FALSE,
    future_scheduling = NULL
) {
    if (!.is_scalar_nonempty_text(task_scope)) {
        .stage1_evidence_abort("median bootstrap requires a stable task scope")
    }
    tasks <- as.list(seq_len(rules$bootstrap_resamples))
    task_ids <- sprintf(
        "stage1-holdout:%s:median-bootstrap:%05d",
        task_scope,
        seq_along(tasks)
    )
    repetition <- .future_numeric_repetition(
        tasks = tasks,
        task_ids = task_ids,
        run_seed = seed,
        compute_tier = "evidence",
        worker = function(task, task_id, task_stream) {
            stats::median(sample(
                values,
                length(values),
                replace = TRUE
            ))
        },
        sequential_internal = sequential_internal,
        future_scheduling = future_scheduling,
        failure_code = "stage1-median-bootstrap-failure",
        legacy_stream_advance = function(task, task_id) {
            sample(values, length(values), replace = TRUE)
            invisible(NULL)
        }
    )
    .stage1_require_summary_completion(repetition, "median bootstrap")
    list(
        interval = stats::quantile(
            repetition$values,
            probs = c(0.025, 0.975),
            names = FALSE,
            type = 7L
        ),
        execution = repetition$execution,
        measurements = .stage1_summary_measurements(
            tasks,
            task_ids,
            values,
            repetition$execution
        )
    )
}

#' Assess frozen Stage 1 holdout evidence
#'
#' The input must contain only holdout rows from the calibration-selected
#' candidate. This function cannot select a candidate or retune the protocol.
#'
#' @param selected_candidate candidate name returned by the calibration selector.
#' @param holdout_rows one row per selected-candidate/seed/stratum from holdout.
#' @param manifest canonical Stage 1 benchmark manifest.
#' @param sequential_internal logical; set `TRUE` when this workflow already
#'   runs inside an outer future or workflow-orchestration task.
#' @param future_scheduling optional future.apply scheduling value; `NULL`
#'   leaves scheduling to the user-selected future backend.
#' @return a serializable holdout report.
#' @export
assess_stage1_holdout <- function(selected_candidate, holdout_rows,
                                  manifest = stage1_benchmark_manifest(),
                                  sequential_internal = FALSE,
                                  future_scheduling = NULL) {
    validate_stage1_benchmark_manifest(manifest)
    if (length(selected_candidate) != 1L || is.na(selected_candidate) ||
        !selected_candidate %in% manifest$candidates)
        .stage1_evidence_abort("holdout requires one eligible selected candidate")
    .stage1_require_results(holdout_rows, split = "holdout", selected = selected_candidate)
    if (!isTRUE(all(holdout_rows$tier == "full")))
        .stage1_evidence_abort("non-evidentiary benchmark rows cannot assess holdout evidence")
    if (!identical(unique(holdout_rows$protocol_id), manifest$protocol_id) ||
        !identical(unique(holdout_rows$generator), manifest$generator) ||
        !identical(unique(holdout_rows$protocol_digest), .protocol_digest(manifest)) ||
        !identical(unique(holdout_rows$generator_digest), .generator_digest()))
        .stage1_evidence_abort("holdout rows do not match the frozen manifest or generator")

    strata <- unique(holdout_rows[, c("stratum_digest", "stratum", "projection_case",
                                      "shared_signal", "noise_sd"), drop = FALSE])
    canonical <- .stage1_benchmark_strata(manifest)
    canonical_digests <- vapply(seq_len(nrow(canonical)), function(i)
        digest::digest(as.list(canonical[i, , drop = FALSE]), algo = "sha256"), character(1L))
    strata$canonical_index <- match(strata$stratum_digest, canonical_digests)
    if (anyNA(strata$canonical_index))
        .stage1_evidence_abort("holdout rows contain a stratum outside the frozen grid")
    strata <- strata[order(strata$canonical_index), , drop = FALSE]
    metrics <- c("shared_recovery_error", "response_recovery_error", "exclusive_leakage",
                 "projection_error", "elapsed_sec", "peak_vcells_bytes")
    summaries <- lapply(seq_len(nrow(strata)), function(i) {
        stratum <- strata[i, , drop = FALSE]
        rows <- holdout_rows[holdout_rows$stratum_digest == stratum$stratum_digest, , drop = FALSE]
        if (!all(rows$gate_passed) || !.stage1_gate_is_expected(rows))
            .stage1_evidence_abort("holdout contains a failed contract gate")
        if (identical(stratum$projection_case[[1L]], "missing_id")) {
            return(list(
                rows = data.frame(stratum_digest = stratum$stratum_digest, stratum = stratum$stratum,
                    projection_case = stratum$projection_case, shared_signal = stratum$shared_signal,
                    noise_sd = stratum$noise_sd, metric = "typed_control_pass_rate",
                    estimate = mean(rows$gate_observed == "typed_failure"), ci_lower = NA_real_,
                    ci_upper = NA_real_, n = nrow(rows), stringsAsFactors = FALSE),
                executions = list(),
                measurements = list()
            ))
        }
        metric_summaries <- lapply(metrics, function(metric) {
            values <- rows[[metric]]
            if (any(!is.finite(values))) .stage1_evidence_abort("exact-ID holdout metric is not finite")
            bootstrap <- .stage1_bootstrap_median_ci(values,
                manifest$reporting_rules$bootstrap_seed_start + stratum$canonical_index,
                manifest$reporting_rules,
                task_scope = paste(stratum$stratum_digest, metric, sep = ":"),
                sequential_internal = sequential_internal,
                future_scheduling = future_scheduling)
            list(
                row = data.frame(stratum_digest = stratum$stratum_digest, stratum = stratum$stratum,
                    projection_case = stratum$projection_case, shared_signal = stratum$shared_signal,
                    noise_sd = stratum$noise_sd, metric = metric, estimate = stats::median(values),
                    ci_lower = bootstrap$interval[[1L]], ci_upper = bootstrap$interval[[2L]],
                    n = nrow(rows), stringsAsFactors = FALSE),
                execution = bootstrap$execution,
                measurements = bootstrap$measurements
            )
        })
        names(metric_summaries) <- metrics
        list(
            rows = do.call(rbind, lapply(metric_summaries, `[[`, "row")),
            executions = lapply(metric_summaries, `[[`, "execution"),
            measurements = lapply(metric_summaries, `[[`, "measurements")
        )
    })
    summary <- do.call(rbind, lapply(summaries, `[[`, "rows"))
    bootstrap_executions <- unlist(
        lapply(seq_along(summaries), function(i) {
            stats::setNames(
                summaries[[i]]$executions,
                paste(strata$stratum_digest[[i]], names(summaries[[i]]$executions), sep = ":")
            )
        }),
        recursive = FALSE
    )
    bootstrap_measurements <- unlist(
        lapply(seq_along(summaries), function(i) {
            stats::setNames(
                summaries[[i]]$measurements,
                paste(strata$stratum_digest[[i]], names(summaries[[i]]$measurements), sep = ":")
            )
        }),
        recursive = FALSE
    )
    exact_required <- summary[summary$projection_case == "exact_ids" &
        summary$shared_signal == 24 & summary$noise_sd == 1 &
        summary$metric %in% c("shared_recovery_error", "projection_error"), , drop = FALSE]
    required_complete <- nrow(exact_required) > 0L &&
        all(table(exact_required$stratum_digest) == 2L)
    thresholds_pass <- required_complete && all(exact_required$estimate[
        exact_required$metric == "shared_recovery_error"] <= .25) &&
        all(exact_required$estimate[exact_required$metric == "projection_error"] <= .30)
    list(
        protocol_id = manifest$protocol_id,
        protocol_digest = .protocol_digest(manifest),
        generator_digest = .generator_digest(),
        split = "holdout",
        selected_candidate = selected_candidate,
        all_gates_passed = all(holdout_rows$gate_passed) && .stage1_gate_is_expected(holdout_rows),
        thresholds_passed = thresholds_pass,
        decision = if (all(holdout_rows$gate_passed) && thresholds_pass) "accepted" else "failed",
        summary = summary,
        bootstrap_executions = bootstrap_executions,
        bootstrap_measurements = bootstrap_measurements,
        rules = manifest$reporting_rules
    )
}

.stage1_assert_full_coverage <- function(rows, manifest, strata) {
    .stage1_require_results(rows)
    expected_strata <- vapply(seq_len(nrow(strata)), function(i)
        digest::digest(as.list(strata[i, , drop = FALSE]), algo = "sha256"), character(1L))
    if (!setequal(unique(rows$stratum_digest), expected_strata) ||
        !identical(sort(unique(rows$seed)), sort(manifest$seeds$seed)) ||
        !identical(sort(unique(rows$candidate)), sort(manifest$candidates)))
        .stage1_evidence_abort("full benchmark does not cover the frozen grid, seeds, and candidates")
    expected_rows <- length(expected_strata) * nrow(manifest$seeds) * length(manifest$candidates)
    if (nrow(rows) != expected_rows)
        .stage1_evidence_abort("full benchmark row count is incomplete")
    expected_split <- manifest$seeds$split[match(rows$seed, manifest$seeds$seed)]
    if (!identical(as.character(rows$split), as.character(expected_split)))
        .stage1_evidence_abort("benchmark rows have an invalid calibration/holdout assignment")
    invisible(TRUE)
}

.stage1_payload_hashes <- function(artifact_dir) {
    paths <- list.files(artifact_dir, recursive = TRUE, full.names = FALSE,
                        include.dirs = FALSE)
    paths <- sort(paths[paths != "hashes.csv"])
    if (!length(paths)) .stage1_evidence_abort("artifact has no payload files")
    hashes <- vapply(paths, function(path)
        digest::digest(file.path(artifact_dir, path), file = TRUE, algo = "sha256"), character(1L))
    data.frame(file = paths, sha256 = unname(hashes), stringsAsFactors = FALSE)
}

.stage1_payload_digest <- function(hashes) {
    digest::digest(stats::setNames(as.character(hashes$sha256), as.character(hashes$file)), algo = "sha256")
}

.stage1_write_figures <- function(artifact_dir, holdout) {
    exact <- holdout$summary[holdout$summary$projection_case == "exact_ids" &
        holdout$summary$metric %in% c("shared_recovery_error", "projection_error"), , drop = FALSE]
    figures <- file.path(artifact_dir, "figures")
    dir.create(figures, recursive = TRUE, showWarnings = FALSE)
    for (metric in c("shared_recovery_error", "projection_error")) {
        data <- exact[exact$metric == metric, , drop = FALSE]
        grDevices::png(file.path(figures, paste0(metric, ".png")), width = 1200L, height = 700L, res = 150L)
        if (!nrow(data)) {
            graphics::plot.new()
            graphics::title(main = paste("Stage 1 v2 holdout", metric),
                sub = "No eligible candidate; holdout was not assessed")
        } else {
            graphics::plot(
                seq_len(nrow(data)),
                data$estimate,
                pch = 16L,
                col = .landscapeR_colour("negative"),
                xlab = "Canonical holdout stratum", ylab = metric,
                main = paste("Stage 1 v2 holdout", metric))
            nonzero_ci <- data$ci_lower != data$ci_upper
            if (any(nonzero_ci)) graphics::arrows(which(nonzero_ci), data$ci_lower[nonzero_ci],
                which(nonzero_ci), data$ci_upper[nonzero_ci], angle = 90L, code = 3L, length = 0.03)
        }
        grDevices::dev.off()
    }
}

.stage1_source_commit <- function(require_clean = TRUE) {
    commit <- tryCatch(system2("git", c("rev-parse", "HEAD"), stdout = TRUE, stderr = FALSE),
                       error = function(e) character())
    if (length(commit) != 1L || !grepl("^[0-9a-f]{40}$", commit))
        .stage1_evidence_abort("full evidence artifact requires an exact committed source revision")
    if (isTRUE(require_clean)) {
        status <- tryCatch(system2("git", c("status", "--porcelain"), stdout = TRUE, stderr = FALSE),
            error = function(e) NA_character_)
        if (length(status) && any(nzchar(status)))
            .stage1_evidence_abort("full evidence execution requires a clean source worktree")
    }
    commit
}

.stage1_evidence_governed_files <- function() c(
    "manifest.rds", "seed-manifest.csv", "results.csv",
    "calibration-selection.rds", "holdout-report.rds",
    "holdout-summary.csv", "environment.rds",
    "figures/shared_recovery_error.png",
    "figures/projection_error.png"
)

.stage1_evidence_artifact_errors <- function() list(
    incomplete = "Stage 1 evidence artifact is incomplete",
    missing_manifest = "Stage 1 evidence artifact has no MANIFEST.tsv",
    missing_payload = "Stage 1 evidence artifact is incomplete",
    invalid = "Stage 1 evidence artifact manifest is invalid",
    undeclared = "Stage 1 evidence artifact contains undeclared files",
    digest = "Stage 1 evidence artifact payload hash mismatch",
    atomic = "could not atomically publish evidence artifact"
)

.stage1_evidence_identity_digest <- function(file_manifest, artifact_dir) {
    manifest <- readRDS(file.path(artifact_dir, "manifest.rds"))
    results <- utils::read.csv(
        file.path(artifact_dir, "results.csv"), stringsAsFactors = FALSE
    )
    selection <- readRDS(
        file.path(artifact_dir, "calibration-selection.rds")
    )
    holdout <- readRDS(file.path(artifact_dir, "holdout-report.rds"))
    environment <- readRDS(file.path(artifact_dir, "environment.rds"))
    stable_environment <- environment[
        c("commit", "r_version", "package_version")
    ]
    digest::digest(list(
        manifest = manifest,
        results = .stage1_scientific_results(results),
        selection = .stage1_scientific_selection(selection),
        holdout = .stage1_scientific_holdout(holdout),
        environment = stable_environment
    ), algo = "sha256")
}

.stage1_compare_derivatives <- function(artifact_dir, manifest, holdout) {
    expected <- tempfile("stage1-evidence-replay-")
    dir.create(expected, recursive = TRUE, showWarnings = FALSE)
    on.exit(unlink(expected, recursive = TRUE, force = TRUE), add = TRUE)
    utils::write.csv(
        manifest$seeds,
        file.path(expected, "seed-manifest.csv"),
        row.names = FALSE
    )
    utils::write.csv(
        holdout$summary,
        file.path(expected, "holdout-summary.csv"),
        row.names = FALSE
    )
    derivatives <- c("seed-manifest.csv", "holdout-summary.csv")
    matches <- vapply(derivatives, function(path) {
        identical(
            .artifact_file_digest(file.path(expected, path)),
            .artifact_file_digest(file.path(artifact_dir, path))
        )
    }, logical(1L))
    if (!all(matches)) {
        .stage1_evidence_abort(
            "Stage 1 evidence derivatives do not reproduce"
        )
    }
    invisible(TRUE)
}

.stage1_verify_current_artifact <- function(artifact_dir) {
    artifact_dir <- path.expand(artifact_dir)
    files <- .artifact_verify_payload(
        artifact_dir,
        .stage1_evidence_governed_files(),
        .stage1_evidence_abort,
        .stage1_evidence_artifact_errors()
    )
    manifest <- tryCatch(
        readRDS(file.path(artifact_dir, "manifest.rds")),
        error = function(condition) {
            .stage1_evidence_abort("Stage 1 evidence manifest is invalid")
        }
    )
    validate_stage1_benchmark_manifest(manifest)
    results <- tryCatch(
        utils::read.csv(
            file.path(artifact_dir, "results.csv"),
            stringsAsFactors = FALSE
        ),
        error = function(condition) {
            .stage1_evidence_abort("Stage 1 evidence results are invalid")
        }
    )
    selection <- tryCatch(
        readRDS(file.path(artifact_dir, "calibration-selection.rds")),
        error = function(condition) {
            .stage1_evidence_abort(
                "Stage 1 calibration selection is invalid"
            )
        }
    )
    holdout <- tryCatch(
        readRDS(file.path(artifact_dir, "holdout-report.rds")),
        error = function(condition) {
            .stage1_evidence_abort("Stage 1 holdout report is invalid")
        }
    )
    .stage1_require_results(results)
    protocol_digest <- .protocol_digest(manifest)
    if (!is.list(selection) || !is.list(holdout) ||
            !identical(selection$protocol_digest, protocol_digest) ||
            !identical(holdout$protocol_digest, protocol_digest)) {
        .stage1_evidence_abort(
            "Stage 1 evidence artifact reports an inconsistent protocol digest"
        )
    }
    calibration <- results[
        results$split == "calibration", , drop = FALSE
    ]
    reproduced_selection <- select_stage1_candidate(calibration)
    holdout_rows <- results[
        results$split == "holdout" &
            results$candidate == selection$selected_candidate,
        ,
        drop = FALSE
    ]
    reproduced_holdout <- assess_stage1_holdout(
        selection$selected_candidate, holdout_rows
    )
    selection_matches <- isTRUE(all.equal(
        .stage1_scientific_selection(selection),
        .stage1_scientific_selection(reproduced_selection)
    ))
    holdout_matches <- isTRUE(all.equal(
        .stage1_scientific_holdout(holdout),
        .stage1_scientific_holdout(reproduced_holdout)
    ))
    if (!selection_matches || !holdout_matches) {
        .stage1_evidence_abort(
            "Stage 1 evidence selection or holdout does not reproduce"
        )
    }
    .stage1_compare_derivatives(artifact_dir, manifest, holdout)
    identity_digest <- .stage1_evidence_identity_digest(
        files, artifact_dir
    )
    expected_name <- paste0(
        manifest$protocol_id, "-", substr(identity_digest, 1L, 16L)
    )
    if (!identical(basename(artifact_dir), expected_name)) {
        .stage1_evidence_abort(
            "Stage 1 evidence artifact name does not match its payload digest"
        )
    }
    environment <- tryCatch(
        readRDS(file.path(artifact_dir, "environment.rds")),
        error = function(condition) {
            .stage1_evidence_abort(
                "Stage 1 evidence environment record is invalid"
            )
        }
    )
    if (!is.list(environment) ||
            !is.character(environment$commit) ||
            length(environment$commit) != 1L ||
            !grepl("^[0-9a-f]{40}$", environment$commit)) {
        .stage1_evidence_abort(
            "Stage 1 evidence artifact has no exact source commit"
        )
    }
    invisible(TRUE)
}

.stage1_write_full_artifact <- function(artifact_root, manifest, results, selection, holdout,
                                        workers, source_commit = .stage1_source_commit(FALSE),
                                        execution = NULL) {
    environment <- list(
        commit = source_commit,
        r_version = R.version.string,
        package_version = as.character(utils::packageVersion("landscapeR")),
        workers = workers
    )
    if (!is.null(execution)) environment$execution <- execution
    write_payload <- function(stage) {
        saveRDS(manifest, file.path(stage, "manifest.rds"))
        utils::write.csv(manifest$seeds,
            file.path(stage, "seed-manifest.csv"), row.names = FALSE)
        utils::write.csv(results,
            file.path(stage, "results.csv"), row.names = FALSE)
        saveRDS(selection, file.path(stage, "calibration-selection.rds"))
        saveRDS(holdout, file.path(stage, "holdout-report.rds"))
        utils::write.csv(holdout$summary,
            file.path(stage, "holdout-summary.csv"), row.names = FALSE)
        saveRDS(environment, file.path(stage, "environment.rds"))
        .stage1_write_figures(stage, holdout)
    }
    .artifact_publish(
        artifact_root = artifact_root,
        address_prefix = manifest$protocol_id,
        governed = .stage1_evidence_governed_files(),
        write_payload = write_payload,
        semantic_verifier = .stage1_verify_current_artifact,
        abort = .stage1_evidence_abort,
        messages = .stage1_evidence_artifact_errors(),
        staging_prefix = ".stage1-evidence-",
        preserve_condition = function(condition) {
            inherits(condition, "stage1_evidence_error")
        },
        identity_digest = .stage1_evidence_identity_digest
    )
}

#' Verify a full Stage 1 evidence artifact
#'
#' @param artifact_dir immutable artifact directory returned by the full executor.
#' @return `TRUE` when the complete payload and content-addressed name verify.
#' @export
verify_stage1_evidence_artifact <- function(artifact_dir) {
    if (file.exists(file.path(artifact_dir, "MANIFEST.tsv"))) {
        return(.stage1_verify_current_artifact(artifact_dir))
    }
    hash_path <- file.path(artifact_dir, "hashes.csv")
    if (!dir.exists(artifact_dir) || !file.exists(hash_path))
        .stage1_evidence_abort("Stage 1 evidence artifact hash manifest does not exist")
    hashes <- tryCatch(utils::read.csv(hash_path, stringsAsFactors = FALSE),
        error = function(e) .stage1_evidence_abort("Stage 1 evidence artifact hash manifest is invalid"))
    if (!identical(names(hashes), c("file", "sha256")) || !nrow(hashes) ||
        anyNA(hashes$file) || anyNA(hashes$sha256) || anyDuplicated(hashes$file) ||
        any(grepl("(^/|\\.\\.)", hashes$file)))
        .stage1_evidence_abort("Stage 1 evidence artifact hash manifest is malformed")
    actual <- sort(list.files(artifact_dir, recursive = TRUE, full.names = FALSE,
                              include.dirs = FALSE))
    expected <- sort(c(hashes$file, "hashes.csv"))
    if (!identical(actual, expected))
        .stage1_evidence_abort("Stage 1 evidence artifact contains missing or undeclared files")
    observed <- vapply(hashes$file, function(path)
        digest::digest(file.path(artifact_dir, path), file = TRUE, algo = "sha256"), character(1L))
    if (!identical(unname(observed), as.character(hashes$sha256)))
        .stage1_evidence_abort("Stage 1 evidence artifact payload hash mismatch")
    payload_digest <- .stage1_payload_digest(hashes)
    expected_name <- paste("stage1-heterogeneous-v2", payload_digest, sep = "-")
    if (!identical(basename(normalizePath(artifact_dir)), expected_name))
        .stage1_evidence_abort("Stage 1 evidence artifact name does not match its payload digest")
    environment <- tryCatch(readRDS(file.path(artifact_dir, "environment.rds")),
        error = function(e) .stage1_evidence_abort("Stage 1 evidence environment record is invalid"))
    if (!is.list(environment) || !is.character(environment$commit) || length(environment$commit) != 1L ||
        !grepl("^[0-9a-f]{40}$", environment$commit))
        .stage1_evidence_abort("Stage 1 evidence artifact has no exact source commit")
    invisible(TRUE)
}

#' Read a verified full Stage 1 evidence artifact
#'
#' @param artifact_dir immutable artifact directory.
#' @return manifest, rows, calibration selection, holdout report, and environment.
#' @export
read_stage1_evidence_artifact <- function(artifact_dir) {
    verify_stage1_evidence_artifact(artifact_dir)
    out <- list(
        manifest = readRDS(file.path(artifact_dir, "manifest.rds")),
        results = utils::read.csv(file.path(artifact_dir, "results.csv"), stringsAsFactors = FALSE),
        selection = readRDS(file.path(artifact_dir, "calibration-selection.rds")),
        holdout = readRDS(file.path(artifact_dir, "holdout-report.rds")),
        environment = readRDS(file.path(artifact_dir, "environment.rds"))
    )
    validate_stage1_benchmark_manifest(out$manifest)
    if (!identical(out$selection$protocol_digest, .protocol_digest(out$manifest)) ||
        !identical(out$holdout$protocol_digest, .protocol_digest(out$manifest)))
        .stage1_evidence_abort("Stage 1 evidence artifact reports an inconsistent protocol digest")
    out
}
