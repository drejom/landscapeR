# Package-owned design-preserving resampling policy (ADR 0020; issue #93)

.resampling_policy_version <- "1.0.0"

.resampling_policy_integer <- function(
    value,
    label,
    allow_na = FALSE
) {
    if (!is.numeric(value) || length(value) != 1L ||
        (is.na(value) && !allow_na) ||
        (!is.na(value) && (
            !is.finite(value) ||
            value < 0 ||
            value > .Machine$integer.max ||
            value != floor(value)
        ))) {
        .stop_landscapeR_validation(sprintf(
            "%s must be one non-negative whole number",
            label
        ))
    }
    invisible(TRUE)
}

.resampling_policy_with_seed <- function(seed, operation) {
    .resampling_policy_integer(seed, "resampling policy seed")
    .with_rng_stream(
        .derive_task_stream(as.integer(seed), "resampling-plan"),
        operation
    )
}

.resampling_policy_record <- function(
    lifecycle,
    method,
    unit,
    n_requested,
    seed,
    design,
    draws,
    replicate_seeds,
    status,
    diagnostic
) {
    lifecycles <- c("bootstrap", "permutation")
    statuses <- c(
        "not-requested", "planned", "complete", "partial",
        "not-identifiable", "insufficient-support"
    )
    if (!.is_scalar_nonempty_text(lifecycle) ||
        !lifecycle %in% lifecycles) {
        .stop_landscapeR_validation(
            "resampling policy lifecycle must be bootstrap or permutation"
        )
    }
    if (!.is_scalar_nonempty_text(method) ||
        !.is_scalar_nonempty_text(unit)) {
        .stop_landscapeR_validation(
            "resampling policy method and unit must be non-empty text"
        )
    }
    .resampling_policy_integer(
        n_requested,
        "resampling policy requested count"
    )
    .resampling_policy_integer(
        seed,
        "resampling policy seed",
        allow_na = identical(status, "not-requested")
    )
    if (!is.list(design) || !is.list(draws)) {
        .stop_landscapeR_validation(
            "resampling policy design and draws must be lists"
        )
    }
    if (!.is_scalar_nonempty_text(status) || !status %in% statuses) {
        .stop_landscapeR_validation(
            "resampling policy status is not supported"
        )
    }
    unavailable <- status %in% c(
        "not-identifiable", "insufficient-support"
    )
    if (identical(status, "planned") &&
        length(draws) != as.integer(n_requested)) {
        .stop_landscapeR_validation(
            "planned resampling draws must equal the requested count"
        )
    }
    if ((unavailable || identical(status, "not-requested")) &&
        length(draws)) {
        .stop_landscapeR_validation(
            "unavailable resampling policies cannot contain draws"
        )
    }
    if (unavailable && !.is_scalar_nonempty_text(diagnostic)) {
        .stop_landscapeR_validation(
            "unavailable resampling policy requires a diagnostic"
        )
    }
    if (length(replicate_seeds) &&
        length(replicate_seeds) != as.integer(n_requested)) {
        .stop_landscapeR_validation(
            "replicate seeds must equal the requested count"
        )
    }
    payload <- list(
        version = .resampling_policy_version,
        lifecycle = lifecycle,
        method = method,
        unit = unit,
        status = status,
        n_requested = as.integer(n_requested),
        seed = as.integer(seed),
        design = design,
        draws = draws,
        replicate_seeds = as.integer(replicate_seeds),
        diagnostic = as.character(diagnostic)
    )
    structure(
        c(
            payload,
            list(digest = digest::digest(
                payload,
                algo = "sha256",
                serialize = TRUE
            ))
        ),
        class = c("landscapeR_resampling_plan", "list")
    )
}

.resampling_policy_plan <- function(
    lifecycle,
    method,
    unit,
    n_requested,
    seed,
    design = list(),
    draw_factory = NULL,
    materialize_replicate_seeds = FALSE
) {
    .resampling_policy_integer(
        n_requested,
        "resampling policy requested count"
    )
    .resampling_policy_integer(seed, "resampling policy seed")
    n_requested <- as.integer(n_requested)
    if (!n_requested) {
        return(.resampling_policy_record(
            lifecycle, method, unit, 0L, seed, design,
            draws = list(),
            replicate_seeds = integer(),
            status = "not-requested",
            diagnostic = ""
        ))
    }
    if (!is.function(draw_factory)) {
        .stop_landscapeR_validation(
            "requested resampling policy requires a draw factory"
        )
    }
    generated <- .resampling_policy_with_seed(seed, function() {
        draws <- lapply(seq_len(n_requested), draw_factory)
        replicate_seeds <- if (isTRUE(materialize_replicate_seeds)) {
            sample.int(
                .Machine$integer.max,
                n_requested,
                replace = FALSE
            )
        } else {
            integer()
        }
        list(draws = draws, replicate_seeds = replicate_seeds)
    })
    .resampling_policy_record(
        lifecycle, method, unit, n_requested, seed, design,
        draws = generated$draws,
        replicate_seeds = generated$replicate_seeds,
        status = "planned",
        diagnostic = ""
    )
}

.resampling_policy_reframe <- function(
    policy,
    method,
    unit,
    design = policy$design
) {
    .validate_resampling_policy_plan(policy)
    .resampling_policy_record(
        policy$lifecycle,
        method,
        unit,
        policy$n_requested,
        policy$seed,
        design,
        policy$draws,
        policy$replicate_seeds,
        policy$status,
        policy$diagnostic
    )
}

.resampling_policy_unavailable <- function(
    lifecycle,
    method,
    unit,
    n_requested,
    seed,
    status,
    diagnostic,
    design = list()
) {
    if (!status %in% c("not-identifiable", "insufficient-support")) {
        .stop_landscapeR_validation(
            "unavailable resampling policy status must be not-identifiable or insufficient-support"
        )
    }
    .resampling_policy_record(
        lifecycle, method, unit, n_requested, seed, design,
        draws = list(),
        replicate_seeds = integer(),
        status = status,
        diagnostic = diagnostic
    )
}

.resampling_policy_account <- function(
    plan,
    completed,
    failure_codes = rep("", length(completed)),
    diagnostic = ""
) {
    .validate_resampling_policy_plan(plan)
    if (!is.logical(completed) || anyNA(completed) ||
        length(completed) != plan$n_requested) {
        .stop_landscapeR_validation(
            "completion flags must match the requested resampling count"
        )
    }
    if (!is.character(failure_codes) ||
        length(failure_codes) != plan$n_requested ||
        any(!completed & !nzchar(failure_codes))) {
        .stop_landscapeR_validation(
            "every failed resample requires a failure code"
        )
    }
    failure_codes[completed] <- ""
    n_completed <- as.integer(sum(completed))
    n_failed <- as.integer(plan$n_requested - n_completed)
    status <- if (plan$status %in% c(
        "not-identifiable", "insufficient-support"
    )) {
        if (n_completed) {
            .stop_landscapeR_validation(
                "unavailable resampling policy cannot contain completions"
            )
        }
        plan$status
    } else if (!plan$n_requested) {
        "not-requested"
    } else if (n_completed == plan$n_requested) {
        "complete"
    } else if (n_completed > 0L) {
        "partial"
    } else {
        "not-identifiable"
    }
    failure_counts <- table(factor(
        failure_codes[!completed],
        levels = sort(unique(failure_codes[!completed]))
    ))
    payload <- list(
        version = .resampling_policy_version,
        lifecycle = plan$lifecycle,
        method = plan$method,
        unit = plan$unit,
        plan_digest = plan$digest,
        seed = plan$seed,
        status = status,
        n_requested = plan$n_requested,
        n_completed = n_completed,
        n_failed = n_failed,
        failure_codes = failure_codes,
        failure_counts = as.integer(failure_counts),
        diagnostic = as.character(diagnostic)
    )
    names(payload$failure_counts) <- names(failure_counts)
    structure(
        c(payload, list(digest = digest::digest(
            payload,
            algo = "sha256",
            serialize = TRUE
        ))),
        class = c("landscapeR_resampling_account", "list")
    )
}

.reported_permutation_policy <- function(
    method,
    status,
    n_requested,
    seed,
    diagnostic
) {
    if (status %in% c("not-identifiable", "insufficient-support")) {
        return(.resampling_policy_unavailable(
            lifecycle = "permutation",
            method = if (identical(method, "none")) {
                "unavailable-permutation"
            } else {
                method
            },
            unit = "declared-exchangeability-unit",
            n_requested = n_requested,
            seed = seed,
            status = status,
            diagnostic = diagnostic
        ))
    }
    .resampling_policy_record(
        lifecycle = "permutation",
        method = if (identical(method, "none")) {
            "not-requested"
        } else {
            method
        },
        unit = "declared-exchangeability-unit",
        n_requested = n_requested,
        seed = seed,
        design = list(source = "reported-permutation-evidence"),
        draws = if (n_requested) as.list(seq_len(n_requested)) else list(),
        replicate_seeds = integer(),
        status = if (n_requested) "planned" else "not-requested",
        diagnostic = ""
    )
}

.permutation_resampling_account <- function(evidence) {
    account <- attr(evidence, "resampling_policy", exact = TRUE)
    .validate_resampling_policy_account(account)
    account
}

.validate_resampling_policy_plan <- function(plan) {
    required <- c(
        "version", "lifecycle", "method", "unit", "status",
        "n_requested", "seed", "design", "draws", "replicate_seeds",
        "diagnostic", "digest"
    )
    if (!inherits(plan, "landscapeR_resampling_plan") ||
        !identical(names(plan), required) ||
        !identical(plan$version, .resampling_policy_version)) {
        .stop_landscapeR_validation(
            "resampling policy plan has an unsupported schema"
        )
    }
    payload <- unclass(plan)[setdiff(required, "digest")]
    expected <- digest::digest(
        payload,
        algo = "sha256",
        serialize = TRUE
    )
    if (!identical(plan$digest, expected)) {
        .stop_landscapeR_validation(
            "resampling policy plan digest does not match its payload"
        )
    }
    invisible(TRUE)
}

.validate_resampling_policy_account <- function(account) {
    required <- c(
        "version", "lifecycle", "method", "unit", "plan_digest", "seed",
        "status", "n_requested", "n_completed", "n_failed",
        "failure_codes", "failure_counts", "diagnostic", "digest"
    )
    if (!inherits(account, "landscapeR_resampling_account") ||
        !identical(names(account), required) ||
        !identical(account$version, .resampling_policy_version) ||
        account$n_completed + account$n_failed != account$n_requested) {
        .stop_landscapeR_validation(
            "resampling policy account has an unsupported schema"
        )
    }
    payload <- unclass(account)[setdiff(required, "digest")]
    expected <- digest::digest(
        payload,
        algo = "sha256",
        serialize = TRUE
    )
    if (!identical(account$digest, expected)) {
        .stop_landscapeR_validation(
            "resampling policy account digest does not match its payload"
        )
    }
    invisible(TRUE)
}
