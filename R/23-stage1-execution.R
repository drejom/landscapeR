# Stage 0 — observable local execution for Stage 1 benchmark tiers
#
# Checkpoints are local operational state, never evidence artifacts.  Each
# deterministic stratum/seed task publishes one compact result payload; progress
# is derived by scanning those payloads, avoiding a shared worker-written ledger.

.stage1_execution_abort <- function(message) {
    stop(structure(list(message = message, call = NULL),
                   class = c("stage1_execution_error", "error", "condition")))
}

.stage1_optional_commit <- function() {
    commit <- suppressWarnings(tryCatch(system2("git", c("rev-parse", "HEAD"),
        stdout = TRUE, stderr = FALSE), error = function(e) NA_character_))
    if (length(commit) == 1L && grepl("^[0-9a-f]{40}$", commit)) commit else NA_character_
}

#' Construct the deterministic non-evidentiary Stage 1 development manifest
#'
#' This fractional design exercises all important benchmark contract branches
#' quickly. It is intentionally incompatible with candidate selection and
#' holdout acceptance.
#'
#' @return a versioned development-only benchmark manifest.
#' @export
stage1_development_manifest <- function() {
    parent <- stage1_benchmark_manifest()
    strata <- list(
        list(n = 20L, K = 2L, shared_signal = 24, exclusive_signal = 12,
             confounder_signal = 12, noise_sd = 1, missing_block_rate = 0,
             sample_order = "permuted", feature_order = "permuted", projection_case = "exact_ids"),
        list(n = 20L, K = 2L, shared_signal = 24, exclusive_signal = 12,
             confounder_signal = 12, noise_sd = 1, missing_block_rate = 0,
             sample_order = "permuted", feature_order = "permuted", projection_case = "missing_id"),
        list(n = 20L, K = 3L, shared_signal = 24, exclusive_signal = 12,
             confounder_signal = 12, noise_sd = 1, missing_block_rate = .20,
             sample_order = "canonical", feature_order = "permuted", projection_case = "exact_ids"),
        list(n = 60L, K = 2L, shared_signal = 12, exclusive_signal = 0,
             confounder_signal = 0, noise_sd = 2, missing_block_rate = 0,
             sample_order = "canonical", feature_order = "canonical", projection_case = "exact_ids"),
        list(n = 60L, K = 3L, shared_signal = 24, exclusive_signal = 0,
             confounder_signal = 12, noise_sd = 1, missing_block_rate = .20,
             sample_order = "permuted", feature_order = "canonical", projection_case = "missing_id")
    )
    list(
        artifact_version = "1",
        protocol_id = "stage1-heterogeneous-development-v1",
        tier = "development",
        evidence_eligible = FALSE,
        parent_protocol_id = parent$protocol_id,
        parent_protocol_digest = .protocol_digest(parent),
        generator = parent$generator,
        generator_digest = .generator_digest(),
        strata = strata,
        seeds = c(1001L, 1021L)
    )
}

.stage1_execution_identity <- function(tier, manifest, require_clean = FALSE) {
    commit <- if (isTRUE(require_clean)) .stage1_source_commit(TRUE) else .stage1_optional_commit()
    list(
        tier = tier,
        protocol_id = manifest$protocol_id,
        manifest_digest = digest::digest(manifest, algo = "sha256"),
        generator_digest = .generator_digest(),
        source_commit = commit
    )
}

.stage1_execution_tasks <- function(tier, manifest) {
    if (identical(tier, "full")) {
        strata <- .stage1_benchmark_strata(manifest)
        seeds <- manifest$seeds$seed
    } else if (identical(tier, "development")) {
        strata <- do.call(rbind, lapply(manifest$strata, as.data.frame, stringsAsFactors = FALSE))
        seeds <- manifest$seeds
    } else {
        .stage1_execution_abort("unknown Stage 1 execution tier")
    }
    tasks <- expand.grid(stratum_index = seq_len(nrow(strata)), seed = as.integer(seeds),
        KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
    tasks$stratum <- lapply(tasks$stratum_index, function(i) as.list(strata[i, , drop = FALSE]))
    tasks$key <- vapply(seq_len(nrow(tasks)), function(i)
        digest::digest(list(tier = tier, seed = tasks$seed[[i]], stratum = tasks$stratum[[i]]),
            algo = "sha256"), character(1L))
    if (anyDuplicated(tasks$key))
        .stage1_execution_abort("Stage 1 execution task keys must be unique")
    list(tasks = tasks, strata = strata)
}

.stage1_workspace_metadata_path <- function(workspace) file.path(workspace, "run-metadata.rds")
.stage1_workspace_tasks_path <- function(workspace) file.path(workspace, "tasks")
.stage1_workspace_task_path <- function(workspace, key) file.path(.stage1_workspace_tasks_path(workspace), paste0(key, ".rds"))
.stage1_workspace_lock_path <- function(workspace) file.path(workspace, "coordinator.lock")

.stage1_claim_workspace <- function(workspace) {
    lock <- .stage1_workspace_lock_path(workspace)
    if (dir.create(lock, showWarnings = FALSE)) {
        saveRDS(list(pid = Sys.getpid(), claimed_at_utc = format(Sys.time(), tz = "UTC", usetz = TRUE)),
            file.path(lock, "owner.rds"))
        return(invisible(lock))
    }
    owner <- tryCatch(readRDS(file.path(lock, "owner.rds")), error = function(e) NULL)
    active <- !is.null(owner) && is.numeric(owner$pid) && length(owner$pid) == 1L &&
        if (.Platform$OS.type == "windows") TRUE else identical(system2("kill", c("-0", owner$pid),
            stdout = FALSE, stderr = FALSE), 0L)
    if (isTRUE(active)) .stage1_execution_abort("Stage 1 workspace already has an active coordinator")
    unlink(lock, recursive = TRUE, force = TRUE)
    if (!dir.create(lock, showWarnings = FALSE))
        .stage1_execution_abort("could not claim Stage 1 workspace coordinator lock")
    saveRDS(list(pid = Sys.getpid(), claimed_at_utc = format(Sys.time(), tz = "UTC", usetz = TRUE)),
        file.path(lock, "owner.rds"))
    invisible(lock)
}

.stage1_release_workspace <- function(workspace) {
    unlink(.stage1_workspace_lock_path(workspace), recursive = TRUE, force = TRUE)
    invisible(NULL)
}

.stage1_atomic_save_rds <- function(object, path) {
    temporary <- paste0(path, ".", Sys.getpid(), ".tmp")
    saveRDS(object, temporary)
    if (!file.rename(temporary, path)) {
        unlink(temporary, force = TRUE)
        .stage1_execution_abort("could not atomically publish Stage 1 task checkpoint")
    }
    invisible(path)
}

.stage1_init_workspace <- function(workspace, identity, tasks) {
    workspace <- if (is.null(workspace)) tempfile("landscapeR-stage1-", tmpdir = tempdir()) else workspace
    metadata_path <- .stage1_workspace_metadata_path(workspace)
    if (dir.exists(workspace)) {
        if (!file.exists(metadata_path))
            .stage1_execution_abort("existing Stage 1 workspace has no run metadata")
        metadata <- tryCatch(readRDS(metadata_path), error = function(e)
            .stage1_execution_abort("existing Stage 1 workspace metadata is invalid"))
        if (!identical(metadata$identity, identity) || !identical(metadata$task_keys, tasks$key))
            .stage1_execution_abort("existing Stage 1 workspace does not match this execution identity")
        if (identical(metadata$status, "finalized"))
            .stage1_execution_abort("existing Stage 1 workspace has already finalized")
        return(normalizePath(workspace))
    }
    if (!dir.create(workspace, recursive = TRUE, showWarnings = FALSE) ||
        !dir.create(.stage1_workspace_tasks_path(workspace), recursive = TRUE, showWarnings = FALSE))
        .stage1_execution_abort("could not create Stage 1 execution workspace")
    metadata <- list(identity = identity, task_keys = tasks$key, status = "running",
                     started_at_utc = format(Sys.time(), tz = "UTC", usetz = TRUE))
    .stage1_atomic_save_rds(metadata, metadata_path)
    normalizePath(workspace)
}

.stage1_read_task_checkpoint <- function(workspace, task, identity) {
    path <- .stage1_workspace_task_path(workspace, task$key)
    if (!file.exists(path)) return(NULL)
    checkpoint <- tryCatch(readRDS(path), error = function(e)
        .stage1_execution_abort("Stage 1 task checkpoint is unreadable"))
    if (!identical(checkpoint$key, task$key) || !identical(checkpoint$identity, identity) ||
        !identical(checkpoint$seed, as.integer(task$seed)) ||
        !identical(checkpoint$stratum, task$stratum[[1L]]))
        .stage1_execution_abort("Stage 1 task checkpoint does not match its declared task")
    checkpoint
}

.stage1_run_checkpoint_task <- function(workspace, task, tier, manifest, identity) {
    existing <- .stage1_read_task_checkpoint(workspace, task, identity)
    if (!is.null(existing)) {
        if (identical(existing$status, "complete")) return(list(key = task$key, resumed = TRUE))
        .stage1_execution_abort("Stage 1 workspace contains a failed task checkpoint")
    }
    started <- proc.time()[["elapsed"]]
    result <- tryCatch({
        if (identical(tier, "full")) {
            rows <- run_stage1_benchmark_replicate(manifest, seed = task$seed, stratum = task$stratum[[1L]])
        } else {
            parent <- stage1_benchmark_manifest()
            rows <- run_stage1_benchmark_replicate(parent, seed = task$seed, stratum = task$stratum[[1L]])
            rows$protocol_id <- manifest$protocol_id
            rows$protocol_digest <- digest::digest(manifest, algo = "sha256")
            rows$split <- "development"
            rows$tier <- "development"
        }
        list(status = "complete", rows = rows, failure_reason = NA_character_)
    }, error = function(e) list(status = "failed", rows = NULL, failure_reason = conditionMessage(e)))
    checkpoint <- c(list(key = task$key, identity = identity, seed = as.integer(task$seed),
                         stratum = task$stratum[[1L]], completed_at_utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
                         elapsed_sec = proc.time()[["elapsed"]] - started), result)
    .stage1_atomic_save_rds(checkpoint, .stage1_workspace_task_path(workspace, task$key))
    if (identical(checkpoint$status, "failed"))
        .stage1_execution_abort(paste("Stage 1 task failed:", checkpoint$failure_reason))
    list(key = task$key, resumed = FALSE)
}

#' Inspect local Stage 1 execution progress
#'
#' @param workspace a local workspace created by a Stage 1 executor.
#' @return counts, proportion, elapsed time, and ETA derived from task checkpoints.
#' @export
stage1_benchmark_progress <- function(workspace) {
    metadata_path <- .stage1_workspace_metadata_path(workspace)
    if (!dir.exists(workspace) || !file.exists(metadata_path))
        .stage1_execution_abort("Stage 1 execution workspace does not exist")
    metadata <- readRDS(metadata_path)
    paths <- list.files(.stage1_workspace_tasks_path(workspace), pattern = "\\.rds$", full.names = TRUE)
    checkpoints <- lapply(paths, function(path) tryCatch(readRDS(path), error = function(e) NULL))
    if (any(vapply(checkpoints, is.null, logical(1L))))
        .stage1_execution_abort("Stage 1 execution workspace contains a corrupt task checkpoint")
    keys <- vapply(checkpoints, `[[`, character(1L), "key")
    if (anyDuplicated(keys) || !all(keys %in% metadata$task_keys))
        .stage1_execution_abort("Stage 1 execution workspace contains an undeclared or duplicate task checkpoint")
    complete <- sum(vapply(checkpoints, function(x) identical(x$status, "complete"), logical(1L)))
    failed <- sum(vapply(checkpoints, function(x) !is.null(x) && identical(x$status, "failed"), logical(1L)))
    total <- length(metadata$task_keys)
    started <- as.POSIXct(metadata$started_at_utc, tz = "UTC")
    elapsed <- as.numeric(difftime(Sys.time(), started, units = "secs"))
    rate <- if (elapsed > 0) complete / elapsed else 0
    remaining <- if (rate > 0) (total - complete) / rate else NA_real_
    list(workspace = normalizePath(workspace), tier = metadata$identity$tier,
         status = metadata$status, completed = complete, failed = failed, total = total,
         proportion = complete / total, elapsed_sec = elapsed, rate_per_sec = rate,
         eta_sec = remaining)
}

.stage1_emit_progress <- function(progress, state) {
    if (identical(progress, "none")) return(invisible(NULL))
    line <- sprintf("Stage 1 %s: %d/%d (%.1f%%), elapsed %ss, rate %.2f tasks/min%s", state$tier,
        state$completed, state$total, 100 * state$proportion,
        format(round(state$elapsed_sec), trim = TRUE), 60 * state$rate_per_sec,
        if (is.na(state$eta_sec)) "" else paste0(", ETA ", format(round(state$eta_sec), trim = TRUE), "s"))
    if (identical(progress, "bar")) cat("\r", line, sep = "") else message(line)
    invisible(NULL)
}

.stage1_execute_checkpointed_tasks <- function(workspace, tasks, tier, manifest, identity,
                                               workers, progress) {
    workers <- as.integer(workers)
    if (length(workers) != 1L || is.na(workers) || workers < 1L)
        .stage1_execution_abort("workers must be one positive integer")
    if (workers > 1L && .Platform$OS.type == "windows")
        .stage1_execution_abort("parallel execution requires a Unix-like platform")
    completed <- vapply(seq_len(nrow(tasks)), function(i)
        !is.null(.stage1_read_task_checkpoint(workspace, tasks[i, , drop = FALSE], identity)), logical(1L))
    pending <- which(!completed)
    last_log_time <- -Inf
    emit <- function(force = FALSE) {
        state <- stage1_benchmark_progress(workspace)
        now <- as.numeric(Sys.time())
        if (!identical(progress, "log") || force || state$completed == state$total || now - last_log_time >= 5) {
            .stage1_emit_progress(progress, state)
            if (identical(progress, "log")) last_log_time <<- now
        }
        invisible(state)
    }
    emit(force = TRUE)
    runner <- function(index) .stage1_run_checkpoint_task(workspace, tasks[index, , drop = FALSE], tier, manifest, identity)
    if (workers == 1L) {
        for (index in pending) {
            runner(index)
            emit()
        }
    } else {
        active <- list()
        next_task <- 1L
        launch <- function(index) {
            job <- parallel::mcparallel(tryCatch(list(ok = TRUE, result = runner(index)),
                error = function(e) list(ok = FALSE, message = conditionMessage(e))), silent = TRUE)
            active[[as.character(job$pid)]] <<- job
        }
        while (next_task <= length(pending) || length(active)) {
            while (next_task <= length(pending) && length(active) < workers) {
                launch(pending[[next_task]])
                next_task <- next_task + 1L
            }
            Sys.sleep(.15)
            done <- parallel::mccollect(active, wait = FALSE)
            if (!is.null(done) && length(done)) {
                active[names(done)] <- NULL
                for (outcome in done) {
                    if (!is.list(outcome) || !isTRUE(outcome$ok))
                        .stage1_execution_abort(paste("parallel Stage 1 task failed:", outcome$message %||% "unknown error"))
                }
                emit()
            }
        }
    }
    if (identical(progress, "bar")) cat("\n")
    invisible(stage1_benchmark_progress(workspace))
}

.stage1_collect_checkpoint_rows <- function(workspace, tasks, identity) {
    rows <- lapply(seq_len(nrow(tasks)), function(i) {
        checkpoint <- .stage1_read_task_checkpoint(workspace, tasks[i, , drop = FALSE], identity)
        if (is.null(checkpoint) || !identical(checkpoint$status, "complete"))
            .stage1_execution_abort("Stage 1 execution is incomplete")
        checkpoint$rows
    })
    out <- do.call(rbind, rows)
    rownames(out) <- NULL
    out
}

.stage1_mark_workspace <- function(workspace, status) {
    metadata <- readRDS(.stage1_workspace_metadata_path(workspace))
    metadata$status <- status
    metadata[[paste0(status, "_at_utc")]] <- format(Sys.time(), tz = "UTC", usetz = TRUE)
    .stage1_atomic_save_rds(metadata, .stage1_workspace_metadata_path(workspace))
    invisible(NULL)
}

.stage1_finalize_workspace <- function(workspace, cleanup) {
    .stage1_mark_workspace(workspace, "finalized")
    if (isTRUE(cleanup)) unlink(workspace, recursive = TRUE, force = TRUE)
    invisible(NULL)
}

#' Run the fast non-evidentiary Stage 1 development tier
#'
#' @param workspace optional local checkpoint workspace; defaults under [tempdir()].
#' @param workers positive number of local worker processes.
#' @param progress one of `"auto"`, `"bar"`, `"log"`, or `"none"`.
#' @param keep_workspace retain local checkpoints after completion.
#' @return development results, with no candidate-selection or holdout claim.
#' @export
execute_stage1_benchmark_development <- function(workspace = NULL, workers = 1L,
                                                 progress = c("auto", "bar", "log", "none"),
                                                 keep_workspace = FALSE) {
    progress <- match.arg(progress)
    if (identical(progress, "auto")) progress <- if (interactive()) "bar" else "log"
    manifest <- stage1_development_manifest()
    task_set <- .stage1_execution_tasks("development", manifest)
    identity <- .stage1_execution_identity("development", manifest)
    workspace <- .stage1_init_workspace(workspace, identity, task_set$tasks)
    .stage1_claim_workspace(workspace)
    on.exit(.stage1_release_workspace(workspace), add = TRUE)
    finalized <- FALSE
    on.exit(if (!finalized && dir.exists(workspace)) .stage1_mark_workspace(workspace, "interrupted"), add = TRUE)
    .stage1_execute_checkpointed_tasks(workspace, task_set$tasks, "development", manifest,
        identity, workers, progress)
    rows <- .stage1_collect_checkpoint_rows(workspace, task_set$tasks, identity)
    .stage1_finalize_workspace(workspace, cleanup = !keep_workspace)
    finalized <- TRUE
    list(tier = "development", evidence_eligible = FALSE, results = rows,
         workspace = if (keep_workspace) workspace else NA_character_)
}

#' Execute the complete frozen Stage 1 evidence protocol
#'
#' This explicit long-running operation resumes only local temporary
#' checkpoints, then atomically publishes a hash-verified synthetic artifact.
#'
#' @param artifact_root directory in which to publish a new content-addressed artifact.
#' @param workers positive number of Unix worker processes; use `1` for sequential execution.
#' @param workspace optional local checkpoint workspace; defaults under [tempdir()].
#' @param progress one of `"auto"`, `"bar"`, `"log"`, or `"none"`.
#' @param keep_workspace retain local checkpoints after final artifact verification.
#' @return path to the immutable artifact directory.
#' @export
execute_stage1_benchmark_full <- function(artifact_root, workers = 1L, workspace = NULL,
                                          progress = c("auto", "bar", "log", "none"),
                                          keep_workspace = FALSE) {
    progress <- match.arg(progress)
    if (identical(progress, "auto")) progress <- if (interactive()) "bar" else "log"
    manifest <- stage1_benchmark_manifest()
    identity <- .stage1_execution_identity("full", manifest, require_clean = TRUE)
    task_set <- .stage1_execution_tasks("full", manifest)
    workspace <- .stage1_init_workspace(workspace, identity, task_set$tasks)
    .stage1_claim_workspace(workspace)
    on.exit(.stage1_release_workspace(workspace), add = TRUE)
    finalized <- FALSE
    on.exit(if (!finalized && dir.exists(workspace)) .stage1_mark_workspace(workspace, "interrupted"), add = TRUE)
    .stage1_execute_checkpointed_tasks(workspace, task_set$tasks, "full", manifest,
        identity, workers, progress)
    results <- .stage1_collect_checkpoint_rows(workspace, task_set$tasks, identity)
    .stage1_assert_full_coverage(results, manifest, task_set$strata)
    calibration <- results[results$split == "calibration", , drop = FALSE]
    selection <- select_stage1_candidate(calibration, manifest)
    if (is.na(selection$selected_candidate)) {
        report <- list(protocol_id = manifest$protocol_id, protocol_digest = .protocol_digest(manifest),
            generator_digest = .generator_digest(), split = "holdout", selected_candidate = NA_character_,
            all_gates_passed = FALSE, thresholds_passed = FALSE,
            decision = "not_assessed_no_eligible_candidate",
            summary = data.frame(stratum_digest = character(), stratum = character(), projection_case = character(),
                shared_signal = numeric(), noise_sd = numeric(), metric = character(), estimate = numeric(),
                ci_lower = numeric(), ci_upper = numeric(), n = integer(), stringsAsFactors = FALSE),
            rules = manifest$reporting_rules)
    } else {
        holdout <- results[results$split == "holdout" & results$candidate == selection$selected_candidate, , drop = FALSE]
        report <- assess_stage1_holdout(selection$selected_candidate, holdout, manifest)
    }
    artifact <- .stage1_write_full_artifact(artifact_root, manifest, results, selection, report, workers,
        source_commit = identity$source_commit)
    .stage1_finalize_workspace(workspace, cleanup = !keep_workspace)
    finalized <- TRUE
    artifact
}
