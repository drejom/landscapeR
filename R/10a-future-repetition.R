# Future-backed repetition substrate (ADR 0018; issue #57)

.compute_tiers <- c("inspect", "standard", "evidence")
.legacy_compute_tiers <- c(
    "analytic-unadjusted", "analytic-adjusted", "standard-resampled"
)
.repetition_rng_kind <- "L'Ecuyer-CMRG"
.repetition_seed_scheme <- "sha256-lecuyer-rejection-state-v2"

.validate_compute_tier <- function(compute_tier) {
    if (!is.character(compute_tier) || length(compute_tier) != 1L ||
        is.na(compute_tier) || !compute_tier %in% .compute_tiers) {
        .stop_landscapeR_validation(paste0(
            "compute_tier must be one of: ",
            paste(.compute_tiers, collapse = ", ")
        ))
    }
    compute_tier
}

.derive_task_stream <- function(run_seed, task_id) {
    run_seed <- .validate_run_seed(run_seed)
    if (!.is_scalar_nonempty_text(task_id)) {
        .stop_landscapeR_validation("task identity must be non-empty text")
    }
    hash <- digest::digest(
        list(
            scheme = .repetition_seed_scheme,
            run_seed = run_seed,
            task_id = task_id
        ),
        algo = "sha256",
        serialize = TRUE
    )
    state <- vapply(seq_len(6L), function(i) {
        start <- (i - 1L) * 7L + 1L
        as.integer(strtoi(substr(hash, start, start + 6L), base = 16L) + 1L)
    }, integer(1L))
    # 10407 encodes L'Ecuyer-CMRG, Inversion normal generation, and the
    # current Rejection discrete sampler. 407 selects obsolete Rounding and
    # makes deterministic scientific tasks depend on the warning policy.
    c(10407L, state)
}

.with_rng_stream <- function(stream, operation) {
    if (!is.integer(stream) || length(stream) != 7L ||
            stream[[1L]] != 10407L) {
        .stop_landscapeR_validation("RNG stream must be a valid L'Ecuyer-CMRG state")
    }
    previous_kind <- RNGkind()
    had_seed <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
    if (had_seed) previous_seed <- get(".Random.seed", envir = .GlobalEnv)
    on.exit({
        do.call(RNGkind, as.list(previous_kind))
        if (had_seed) {
            assign(".Random.seed", previous_seed, envir = .GlobalEnv)
        } else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
            rm(".Random.seed", envir = .GlobalEnv)
        }
    }, add = TRUE)
    assign(".Random.seed", stream, envir = .GlobalEnv)
    operation()
}

.repetition_failure <- function(code, value = NULL) {
    if (!.is_scalar_nonempty_text(code)) {
        .stop_landscapeR_validation("repetition failure code must be non-empty text")
    }
    structure(list(code = code, value = value), class = "landscapeR_repetition_failure")
}

.repetition_condition_code <- function(condition) {
    if (inherits(condition, "landscapeR_validation_error")) {
        "validation-failure"
    } else {
        "task-error"
    }
}

.legacy_sequential_task_streams <- function(
    run_seed,
    tasks,
    task_ids,
    legacy_stream_advance
) {
    previous_kind <- RNGkind()
    had_seed <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
    if (had_seed) previous_seed <- get(".Random.seed", envir = .GlobalEnv)
    on.exit({
        do.call(RNGkind, as.list(previous_kind))
        if (had_seed) {
            assign(".Random.seed", previous_seed, envir = .GlobalEnv)
        } else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
            rm(".Random.seed", envir = .GlobalEnv)
        }
    }, add = TRUE)
    setup_rng(run_seed)
    lapply(seq_along(tasks), function(i) {
        stream <- get(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
        legacy_stream_advance(tasks[[i]], task_ids[[i]])
        stream
    })
}

.future_repetition <- function(
    tasks,
    task_ids,
    run_seed,
    compute_tier,
    worker,
    sequential_internal = FALSE,
    future_scheduling = NULL,
    legacy_stream_advance = NULL
) {
    compute_tier <- .validate_compute_tier(compute_tier)
    run_seed <- .validate_run_seed(run_seed)
    if (!is.list(tasks) || !is.character(task_ids) ||
        length(tasks) != length(task_ids) || anyNA(task_ids) ||
        any(!nzchar(task_ids)) || anyDuplicated(task_ids)) {
        .stop_landscapeR_validation(
            "repetition tasks require unique non-empty stable task identities"
        )
    }
    if (!is.function(worker) || !is.logical(sequential_internal) ||
        length(sequential_internal) != 1L || is.na(sequential_internal)) {
        .stop_landscapeR_validation(
            "repetition worker and sequential_internal declaration are invalid"
        )
    }
    if (!is.null(future_scheduling) &&
        (!is.numeric(future_scheduling) || length(future_scheduling) != 1L ||
            is.na(future_scheduling) || future_scheduling < 0)) {
        .stop_landscapeR_validation(
            "future_scheduling must be NULL or one non-negative number"
        )
    }
    if (!is.null(legacy_stream_advance) &&
            !is.function(legacy_stream_advance)) {
        .stop_landscapeR_validation(
            "legacy_stream_advance must be NULL or a function"
        )
    }
    if (is.null(legacy_stream_advance)) {
        task_streams <- lapply(
            task_ids,
            function(task_id) .derive_task_stream(run_seed, task_id)
        )
        seed_derivation <- .repetition_seed_scheme
    } else {
        task_streams <- .legacy_sequential_task_streams(
            run_seed,
            tasks,
            task_ids,
            legacy_stream_advance
        )
        seed_derivation <- "legacy-sequential-stream-v1"
    }
    stream_keys <- vapply(task_streams, paste, collapse = ":", character(1L))
    if (anyDuplicated(stream_keys)) {
        .stop_landscapeR_validation(
            "stable task identities produced colliding RNG streams"
        )
    }
    run_one <- function(i) {
            tryCatch(
                .with_rng_stream(task_streams[[i]], function() {
                    value <- worker(tasks[[i]], task_ids[[i]], task_streams[[i]])
                    if (inherits(value, "landscapeR_repetition_failure")) {
                        list(
                            completed = FALSE,
                            failure_code = value$code,
                            value = value$value
                        )
                    } else {
                        list(completed = TRUE, failure_code = "", value = value)
                    }
                }),
                error = function(condition) list(
                    completed = FALSE,
                    failure_code = .repetition_condition_code(condition),
                    value = NULL
                )
            )
    }
    if (sequential_internal) {
        raw <- lapply(seq_along(tasks), run_one)
    } else {
        future_args <- list(
            X = seq_along(tasks),
            FUN = run_one,
            future.seed = TRUE
        )
        if (!is.null(future_scheduling)) {
            future_args$future.scheduling <- future_scheduling
        }
        raw <- do.call(future.apply::future_lapply, future_args)
    }
    completed <- vapply(raw, `[[`, logical(1L), "completed")
    failure_codes <- vapply(raw, `[[`, character(1L), "failure_code")
    values <- lapply(raw, `[[`, "value")
    account <- list(
        denominator = "all-requested-tasks",
        n_requested = as.integer(length(tasks)),
        n_completed = as.integer(sum(completed)),
        n_failed = as.integer(sum(!completed)),
        completed = completed,
        failure_codes = failure_codes
    )
    provenance <- list(
        compute_tier = compute_tier,
        run_seed = run_seed,
        rng_kind = .repetition_rng_kind,
        seed_derivation = seed_derivation,
        task_ids = task_ids,
        task_streams = task_streams
    )
    payload <- list(values = values, account = account, provenance = provenance)
    structure(
        c(payload, list(digest = digest::digest(
            payload,
            algo = "sha256",
            serialize = TRUE
        ))),
        class = c("landscapeR_repetition_result", "list")
    )
}

.future_numeric_repetition <- function(
    tasks,
    task_ids,
    run_seed,
    compute_tier,
    worker,
    sequential_internal = FALSE,
    future_scheduling = NULL,
    failure_code = "non-estimable-refit",
    legacy_stream_advance = NULL
) {
    execution <- .future_repetition(
        tasks = tasks,
        task_ids = task_ids,
        run_seed = run_seed,
        compute_tier = compute_tier,
        worker = function(task, task_id, task_stream) {
            value <- worker(task, task_id, task_stream)
            if (!is.numeric(value) || length(value) != 1L ||
                !is.finite(value)) {
                .repetition_failure(failure_code, NA_real_)
            } else {
                as.numeric(value)
            }
        },
        sequential_internal = sequential_internal,
        future_scheduling = future_scheduling,
        legacy_stream_advance = legacy_stream_advance
    )
    list(
        values = vapply(execution$values, function(value) {
            if (is.numeric(value) && length(value) == 1L) value else NA_real_
        }, numeric(1L)),
        execution = execution
    )
}
