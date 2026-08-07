# Production Stage 1 evidence orchestration (ADR 0018; issue #135)
#
# Scientific functions remain independent of targets and crew. This module
# declares the durable graph and controller boundary only. Worker results are
# returned to the controlling process; immutable artifact publication happens
# on that process after every scientific dependency completes.

.stage1_orchestration_abort <- function(message) {
    stop(structure(
        list(message = message, call = NULL),
        class = c("stage1_orchestration_error", "error", "condition")
    ))
}

.stage1_require_namespace <- function(package) {
    if (!requireNamespace(package, quietly = TRUE)) {
        .stage1_orchestration_abort(sprintf(
            "Stage 1 evidence orchestration requires the optional package '%s'",
            package
        ))
    }
    invisible(TRUE)
}

.stage1_validate_controller_identity <- function(name, workers) {
    if (!.is_scalar_nonempty_text(name)) {
        .stage1_orchestration_abort("crew controller name must be non-empty text")
    }
    if (!is.numeric(workers) || length(workers) != 1L || is.na(workers) ||
            workers < 1 || workers != as.integer(workers)) {
        .stage1_orchestration_abort("crew workers must be one positive integer")
    }
    invisible(TRUE)
}

#' Construct a crew controller for Stage 1 evidence orchestration
#'
#' The controller is an operational dependency of a targets workflow, not a
#' scientific parameter. Scheduler resources are deliberately supplied by the
#' caller; landscapeR does not choose a project, queue, memory request, wall
#' time, or scheduler command.
#'
#' @param scheduler one of `"local"`, `"pbs"`, `"slurm"`, `"sge"`, or
#'   `"lsf"`.
#' @param name non-empty controller name used by `stage1_evidence_targets()`.
#' @param workers positive maximum number of crew workers.
#' @param options_cluster for scheduler controllers, an explicit matching
#'   `crew.cluster::crew_options_*()` object. Must be `NULL` for local work.
#' @param ... additional arguments passed to the selected crew controller.
#' @return a crew controller. Pass it to `targets::tar_option_set(controller =
#'   controller)` in the targets script that returns
#'   `stage1_evidence_targets()`.
#' @export
stage1_crew_controller <- function(
    scheduler = c("local", "pbs", "slurm", "sge", "lsf"),
    name = "stage1-evidence",
    workers = 1L,
    options_cluster = NULL,
    ...
) {
    supported <- c("local", "pbs", "slurm", "sge", "lsf")
    if (identical(scheduler, supported)) scheduler <- supported[[1L]]
    if (!is.character(scheduler) || length(scheduler) != 1L ||
        !scheduler %in% supported) {
        .stage1_orchestration_abort(
            "scheduler must be one of local, pbs, slurm, sge, or lsf"
        )
    }
    .stage1_validate_controller_identity(name, workers)
    .stage1_require_namespace("crew")
    dots <- list(...)
    common <- c(list(name = name, workers = as.integer(workers)), dots)
    if (identical(scheduler, "local")) {
        if (!is.null(options_cluster)) {
            .stage1_orchestration_abort(
                "options_cluster must be NULL for a local crew controller"
            )
        }
        return(do.call(crew::crew_controller_local, common))
    }
    .stage1_require_namespace("crew.cluster")
    expected <- paste0("crew_options_", scheduler)
    if (is.null(options_cluster) || !inherits(options_cluster, expected)) {
        .stage1_orchestration_abort(sprintf(
            "scheduler '%s' requires an explicit matching options_cluster object",
            scheduler
        ))
    }
    constructor <- getExportedValue(
        "crew.cluster",
        paste0("crew_controller_", scheduler)
    )
    do.call(constructor, c(common, list(options_cluster = options_cluster)))
}

.stage1_target_tasks <- function(task_set) {
    tasks <- task_set$tasks
    if (!is.data.frame(tasks) || !nrow(tasks)) {
        .stage1_orchestration_abort("Stage 1 target graph has no declared tasks")
    }
    lapply(seq_len(nrow(tasks)), function(index) tasks[index, , drop = FALSE])
}

.stage1_target_identity <- function(manifest) {
    identity <- .stage1_execution_identity(
        "full",
        manifest,
        require_clean = TRUE
    )
    packages <- c(
        "landscapeR", "targets", "crew", "future", "future.apply", "digest"
    )
    identity$r_version <- paste(R.version$major, R.version$minor, sep = ".")
    identity$package_versions <- vapply(
        packages,
        function(package) as.character(utils::packageVersion(package)),
        character(1L)
    )
    identity
}

.stage1_target_worker_preflight <- function(identity) {
    observed_revision <- tryCatch(
        landscapeR_revision(),
        landscapeR_worker_preflight_error = function(condition) ""
    )
    packages <- names(identity$package_versions)
    installed <- vapply(
        packages,
        requireNamespace,
        logical(1L),
        quietly = TRUE
    )
    observed_versions <- stats::setNames(
        rep(NA_character_, length(packages)),
        packages
    )
    observed_versions[installed] <- vapply(
        packages[installed],
        function(package) as.character(utils::packageVersion(package)),
        character(1L)
    )
    observed_r <- paste(R.version$major, R.version$minor, sep = ".")
    mismatch <- !nzchar(observed_revision) ||
        !identical(observed_revision, identity$source_commit) ||
        !identical(observed_r, identity$r_version) ||
        any(!installed) ||
        !identical(observed_versions, identity$package_versions)
    if (mismatch) {
        diagnostics <- data.frame(
            worker_id = paste(Sys.info()[["nodename"]], Sys.getpid(), sep = ":"),
            expected_revision = identity$source_commit,
            observed_revision = observed_revision,
            expected_r = identity$r_version,
            observed_r = observed_r,
            expected_packages = paste(
                paste(names(identity$package_versions), identity$package_versions, sep = "="),
                collapse = ";"
            ),
            observed_packages = paste(
                paste(names(observed_versions), observed_versions, sep = "="),
                collapse = ";"
            ),
            stringsAsFactors = FALSE
        )
        .worker_preflight_error(
            "Stage 1 crew worker does not match the controlling evidence runtime",
            diagnostics
        )
    }
    invisible(TRUE)
}

.stage1_target_rows <- function(task, manifest, identity) {
    if (!is.data.frame(task) || nrow(task) != 1L) {
        .stage1_orchestration_abort(
            "each Stage 1 dynamic branch must contain exactly one declared task"
        )
    }
    .stage1_target_worker_preflight(identity)
    .stage1_run_task_rows("full", manifest, task)
}

.stage1_target_results <- function(rows, manifest, strata) {
    if (!is.list(rows) || !length(rows) ||
            any(!vapply(rows, is.data.frame, logical(1L)))) {
        .stage1_orchestration_abort(
            "Stage 1 target branches did not return complete result tables"
        )
    }
    results <- do.call(rbind, rows)
    rownames(results) <- NULL
    .stage1_assert_full_coverage(results, manifest, strata)
    results
}

.stage1_target_holdout <- function(selection, results, manifest) {
    if (is.na(selection$selected_candidate)) {
        return(list(
            protocol_id = manifest$protocol_id,
            protocol_digest = .protocol_digest(manifest),
            generator_digest = .generator_digest(),
            split = "holdout",
            selected_candidate = NA_character_,
            all_gates_passed = FALSE,
            thresholds_passed = FALSE,
            decision = "not_assessed_no_eligible_candidate",
            summary = data.frame(
                stratum_digest = character(),
                stratum = character(),
                projection_case = character(),
                shared_signal = numeric(),
                noise_sd = numeric(),
                metric = character(),
                estimate = numeric(),
                ci_lower = numeric(),
                ci_upper = numeric(),
                n = integer(),
                stringsAsFactors = FALSE
            ),
            bootstrap_executions = list(),
            bootstrap_measurements = list(),
            rules = manifest$reporting_rules
        ))
    }
    holdout <- results[
        results$split == "holdout" &
            results$candidate == selection$selected_candidate,
        ,
        drop = FALSE
    ]
    assess_stage1_holdout(
        selection$selected_candidate,
        holdout,
        manifest,
        sequential_internal = TRUE
    )
}

.stage1_scientific_results <- function(results) {
    operational <- intersect(
        c("elapsed_sec", "peak_vcells_bytes", "completed_at_utc"),
        names(results)
    )
    results[setdiff(names(results), operational)]
}

.stage1_scientific_selection <- function(selection) {
    selection[c(
        "protocol_id", "protocol_digest", "generator_digest", "split",
        "decision", "selected_candidate", "eligible", "conditions",
        "shared_recovery_difference", "shared_recovery_ci",
        "exclusive_leakage_difference", "projection_difference",
        "bootstrap_measurements"
    )]
}

.stage1_scientific_holdout <- function(holdout) {
    operational_metrics <- c("elapsed_sec", "peak_vcells_bytes")
    summary <- holdout$summary
    if (is.data.frame(summary)) {
        summary <- summary[!summary$metric %in% operational_metrics, , drop = FALSE]
    }
    measurements <- holdout$bootstrap_measurements
    if (is.list(measurements) && length(measurements)) {
        measurements <- measurements[!grepl(
            paste(operational_metrics, collapse = "|"), names(measurements)
        )]
    }
    holdout[c(
        "protocol_id", "protocol_digest", "generator_digest", "split",
        "selected_candidate", "all_gates_passed", "thresholds_passed",
        "decision", "rules"
    )] |>
        c(list(summary = summary, bootstrap_measurements = measurements))
}

.stage1_target_publication <- function(
    artifact_root,
    manifest,
    results,
    selection,
    holdout,
    identity,
    controller
) {
    scientific_digest <- digest::digest(
        list(
            manifest = manifest,
            results = .stage1_scientific_results(results),
            selection = .stage1_scientific_selection(selection),
            holdout = .stage1_scientific_holdout(holdout)
        ),
        algo = "sha256",
        serialize = TRUE
    )
    artifact <- .stage1_write_full_artifact(
        artifact_root = artifact_root,
        manifest = manifest,
        results = results,
        selection = selection,
        holdout = holdout,
        workers = NA_integer_,
        source_commit = identity$source_commit,
        execution = list(
            engine = "targets-crew",
            controller = controller,
            parallelism_policy = "outer-crew-inner-future-sequential",
            package_versions = identity$package_versions,
            scientific_digest = scientific_digest
        )
    )
    artifact
}

.stage1_target_verified <- function(artifact) {
    verify_stage1_evidence_artifact(artifact)
    environment <- readRDS(file.path(artifact, "environment.rds"))
    if (!is.list(environment$execution) ||
        !is.character(environment$execution$package_versions) ||
        !length(environment$execution$package_versions)) {
        .stage1_orchestration_abort(
            "Stage 1 orchestration artifact has incomplete package provenance"
        )
    }
    artifact
}

.stage1_target_evidence <- function(artifact, verified, manifest, identity) {
    if (!identical(artifact, verified)) {
        .stage1_orchestration_abort(
            "Stage 1 evidence result requires the verified published artifact"
        )
    }
    environment <- readRDS(file.path(artifact, "environment.rds"))
    if (!is.list(environment$execution) ||
        !identical(environment$execution$package_versions, identity$package_versions)) {
        .stage1_orchestration_abort(
            "verified Stage 1 evidence has incomplete orchestration provenance"
        )
    }
    scientific_digest <- environment$execution$scientific_digest
    if (!.is_scalar_nonempty_text(scientific_digest)) {
        .stage1_orchestration_abort(
            "verified Stage 1 evidence has no scientific payload digest"
        )
    }
    structure(
        list(
            artifact = artifact,
            verified = TRUE,
            protocol_id = manifest$protocol_id,
            manifest_digest = identity$manifest_digest,
            scientific_digest = scientific_digest,
            source_commit = identity$source_commit
        ),
        class = c("stage1_evidence_workflow_result", "list")
    )
}

.stage1_worker_resources <- function(controller) {
    targets::tar_resources(
        crew = targets::tar_resources_crew(controller = controller)
    )
}

.stage1_worker_target <- function(name, command, controller, pattern = NULL) {
    targets::tar_target_raw(
        name = name,
        command = command,
        pattern = pattern,
        packages = "landscapeR",
        error = "continue",
        deployment = "worker",
        storage = "main",
        retrieval = "main",
        resources = .stage1_worker_resources(controller)
    )
}

.stage1_main_target <- function(name, command, pattern = NULL, ...) {
    targets::tar_target_raw(
        name = name,
        command = command,
        pattern = pattern,
        ...,
        deployment = "main",
        storage = "main",
        retrieval = "main"
    )
}

#' Declare the durable Stage 1 full-evidence targets graph
#'
#' This graph branches over the frozen benchmark task manifest, delegates those
#' branches to a named crew controller, reruns only invalid or failed branches,
#' and publishes a content-addressed artifact on the controlling process only
#' after all scientific dependencies complete. The manifest and its seed table
#' remain the authoritative RNG contract.
#'
#' Use this function as the final expression in a targets script. Configure a
#' matching controller with `targets::tar_option_set(controller = controller)`
#' and run with `targets::tar_make(use_crew = TRUE)`. Replacing a local
#' controller with a scheduler controller does not change the scientific graph.
#'
#' @param artifact_root absolute shared or controller-local directory in which
#'   the controlling process atomically publishes the verified artifact.
#' @param controller name of the crew controller assigned to worker targets.
#' @return a list of `targets` target objects suitable as the final expression
#'   of a targets script.
#' @export
stage1_evidence_targets <- function(
    artifact_root,
    controller = "stage1-evidence"
) {
    .stage1_require_namespace("targets")
    if (!.is_scalar_nonempty_text(artifact_root)) {
        .stage1_orchestration_abort("artifact_root must be one non-empty path")
    }
    if (!grepl("^/", path.expand(artifact_root))) {
        .stage1_orchestration_abort(
            "artifact_root must be absolute for portable targets/crew execution"
        )
    }
    if (!.is_scalar_nonempty_text(controller)) {
        .stage1_orchestration_abort("controller must be one non-empty crew name")
    }
    artifact_root <- path.expand(artifact_root)
    pipeline <- list(
        .stage1_main_target(
            "stage1_manifest",
            quote(landscapeR::stage1_benchmark_manifest())
        ),
        .stage1_main_target(
            "stage1_identity",
            quote(landscapeR:::.stage1_target_identity(stage1_manifest))
        ),
        .stage1_main_target(
            "stage1_tasks",
            quote(landscapeR:::.stage1_execution_tasks(
                "full",
                stage1_manifest
            ))
        ),
        .stage1_main_target(
            "stage1_task",
            quote(landscapeR:::.stage1_target_tasks(stage1_tasks)),
            iteration = "list"
        ),
        .stage1_worker_target(
            "stage1_rows",
            quote(landscapeR:::.stage1_target_rows(
                stage1_task,
                stage1_manifest,
                stage1_identity
            )),
            controller = controller,
            pattern = quote(map(stage1_task))
        ),
        .stage1_main_target(
            "stage1_results",
            quote(landscapeR:::.stage1_target_results(
                stage1_rows,
                stage1_manifest,
                stage1_tasks$strata
            ))
        ),
        .stage1_worker_target(
            "stage1_selection",
            quote(landscapeR::select_stage1_candidate(
                stage1_results[stage1_results$split == "calibration", , drop = FALSE],
                stage1_manifest,
                sequential_internal = TRUE
            )),
            controller = controller
        ),
        .stage1_worker_target(
            "stage1_holdout",
            quote(landscapeR:::.stage1_target_holdout(
                stage1_selection,
                stage1_results,
                stage1_manifest
            )),
            controller = controller
        ),
        .stage1_main_target(
            "stage1_artifact",
            substitute(
                landscapeR:::.stage1_target_publication(
                    ARTIFACT_ROOT,
                    stage1_manifest,
                    stage1_results,
                    stage1_selection,
                    stage1_holdout,
                    stage1_identity,
                    CONTROLLER
                ),
                list(
                    ARTIFACT_ROOT = artifact_root,
                    CONTROLLER = controller
                )
            )
        ),
        .stage1_main_target(
            "stage1_artifact_verified",
            quote(landscapeR:::.stage1_target_verified(stage1_artifact))
        ),
        .stage1_main_target(
            "stage1_evidence",
            quote(landscapeR:::.stage1_target_evidence(
                stage1_artifact,
                stage1_artifact_verified,
                stage1_manifest,
                stage1_identity
            ))
        )
    )
    pipeline
}
