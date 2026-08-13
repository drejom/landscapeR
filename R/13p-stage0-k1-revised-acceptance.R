# Revised Stage 0 K=1 acceptance execution (#193)

.k1_revised_acceptance_version <- "k1-revised-acceptance-runner-v1"

.k1_revised_acceptance_controls <- c(
    "independent_time_course", "repeated_subject",
    "high_dimensional_signal", "high_dimensional_null"
)

.k1_revised_acceptance_grid <- function(protocol) {
    grids <- protocol$grids
    independent <- expand.grid(
        design_id = grids$independent_time_course$template_ids,
        p = grids$independent_time_course$feature_counts,
        signal_ratio = NA_real_,
        KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
    )
    independent$control <- "independent_time_course"
    repeated <- expand.grid(
        design_id = grids$repeated_subject$template_ids,
        p = grids$repeated_subject$feature_counts,
        signal_ratio = NA_real_,
        KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
    )
    repeated$control <- "repeated_subject"
    signal <- expand.grid(
        design_id = grids$high_dimensional_signal$regime_ids,
        p = grids$high_dimensional_signal$feature_counts,
        signal_ratio = grids$high_dimensional_signal$signal_ratios,
        KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
    )
    signal$control <- "high_dimensional_signal"
    null <- expand.grid(
        design_id = grids$high_dimensional_null$regime_ids,
        p = grids$high_dimensional_null$feature_counts,
        signal_ratio = grids$high_dimensional_null$signal_ratios,
        KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
    )
    null$control <- "high_dimensional_null"
    grid <- do.call(rbind, lapply(
        list(independent, repeated, signal, null),
        function(x) x[, c("control", "design_id", "p", "signal_ratio")]
    ))
    rownames(grid) <- NULL
    grid
}

.k1_revised_canonical_cell <- function(control, design_id, p, signal_ratio) {
    values <- c(
        paste0("control=", control), paste0("design=", design_id),
        paste0("p=", as.integer(p))
    )
    if (is.finite(signal_ratio)) {
        values <- c(values, paste0("signal_ratio=", format(
            signal_ratio, scientific = FALSE, trim = TRUE
        )))
    }
    paste(values, collapse = ";")
}

.k1_revised_historical_rng <- function() {
    independent_ids <- unlist(lapply(c(
        "balanced_1", "balanced_2", "balanced_3", "unequal_1_2_3",
        "isolated_library_failure", "missing_internal_cell"
    ), function(id) sprintf("template=%s;replicate=%04d", id, 1:5)))
    repeated_ids <- unlist(lapply(c(
        "complete", "isolated_observation_loss", "terminal_dropout",
        "condition_dependent_loss"
    ), function(id) sprintf("template=%s;replicate=%04d", id, 1:5)))
    high_grid <- expand.grid(
        regime_id = c(
            "fixed_total_spike", "fixed_sparse", "growing_coherent",
            "correlated_modules", "null_near_null"
        ),
        p = c(100L, 500L), signal_ratio = c(0, 0.75, 1.25),
        replicate_index = 1:3,
        KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
    )
    high_grid <- high_grid[
        high_grid$regime_id != "null_near_null" |
            high_grid$signal_ratio <= 0.75,
        , drop = FALSE
    ]
    high_ids <- sprintf(
        "regime=%s;p=%d;ratio=%g;replicate=%04d",
        high_grid$regime_id, high_grid$p, high_grid$signal_ratio,
        high_grid$replicate_index
    )
    independent_streams <- lapply(
        independent_ids, function(id) .derive_task_stream(18900L, id)
    )
    repeated_streams <- lapply(
        repeated_ids, function(id) .derive_task_stream(19000L, id)
    )
    high_streams <- lapply(
        high_ids, function(id) .derive_task_stream(19100L, id)
    )
    high_children <- unlist(Map(function(stream, id) vapply(
        c("generator", "association", "proposal", "resampling"),
        function(child) .k1_high_dimensional_child_seed(
            stream, paste0(id, ":", child)
        ), integer(1L)
    ), high_streams, high_ids), use.names = FALSE)
    list(
        stream_keys = vapply(
            c(independent_streams, repeated_streams, high_streams),
            paste, collapse = ":", character(1L)
        ),
        scalar_seeds = unique(as.integer(c(
            vapply(independent_streams, `[[`, integer(1L), 2L),
            unlist(lapply(repeated_streams, function(x) x[[2L]] + 0:3)),
            high_children
        )))
    )
}

.k1_revised_seed_base <- function(protocol, merge_commit, total_tasks) {
    stride <- protocol$seed_derivation$block_stride
    minimum <- protocol$seed_derivation$minimum_seed_root
    maximum_start <- 2147483647 - total_tasks * stride
    input <- paste(
        protocol$protocol_id, protocol$digest, merge_commit, "seed-block",
        sep = "|"
    )
    hexadecimal <- digest::digest(input, algo = "sha256", serialize = FALSE)
    minimum + .k1_acceptance_hex_modulo(
        substr(hexadecimal, 1L, 13L), maximum_start - minimum + 1
    )
}

.k1_revised_manifest_payload <- function(
    phase_a_merge_commit, runner_revision, protocol
) {
    validate_k1_acceptance_protocol(protocol)
    if (!identical(protocol$artifact_version, "3")) {
        .k1_acceptance_runner_abort(
            "revised acceptance requires frozen protocol version 3"
        )
    }
    phase_a_merge_commit <- .k1_acceptance_validate_merge_commit(
        phase_a_merge_commit
    )
    runner_revision <- .k1_acceptance_validate_merge_commit(runner_revision)
    if (identical(phase_a_merge_commit, runner_revision)) {
        .k1_acceptance_runner_abort(
            "runner_revision must differ from the protocol merge revision"
        )
    }
    grid <- .k1_revised_acceptance_grid(protocol)
    replicate_count <- unique(protocol$seed_plan$replicates_per_grid_cell)
    if (!identical(replicate_count, 100L)) {
        .k1_acceptance_runner_abort(
            "version 3 requires exactly 100 replicates in every cell"
        )
    }
    cells <- vapply(seq_len(nrow(grid)), function(index) {
        .k1_revised_canonical_cell(
            grid$control[[index]], grid$design_id[[index]], grid$p[[index]],
            grid$signal_ratio[[index]]
        )
    }, character(1L))
    tasks <- grid[rep(seq_len(nrow(grid)), each = replicate_count), , drop = FALSE]
    tasks$replicate_index <- rep(seq_len(replicate_count), nrow(grid))
    tasks$canonical_cell <- rep(cells, each = replicate_count)
    tasks$task_ordinal <- seq_len(nrow(tasks))
    base <- .k1_revised_seed_base(protocol, phase_a_merge_commit, nrow(tasks))
    tasks$seed_root <- as.integer(
        base + (tasks$task_ordinal - 1L) * protocol$seed_derivation$block_stride
    )
    tasks$task_id <- vapply(seq_len(nrow(tasks)), function(index) paste0(
        tasks$canonical_cell[[index]], ";replicate=",
        sprintf("%04d", tasks$replicate_index[[index]])
    ), character(1L))
    tasks$stream_seeds <- lapply(
        tasks$seed_root, function(root) as.integer(root + 0:7)
    )
    tasks$task_stream <- Map(
        .derive_task_stream, tasks$seed_root, tasks$task_id
    )
    reference_p <- protocol$grids$high_dimensional_signal$
        signal_parameterization$reference_p
    tasks$signal_strength <- vapply(seq_len(nrow(tasks)), function(index) {
        if (!tasks$control[[index]] %in% c(
                "high_dimensional_signal", "high_dimensional_null")) {
            return(NA_real_)
        }
        regime <- k1_high_dimensional_regime(tasks$design_id[[index]])
        tasks$signal_ratio[[index]] * .k1_high_dimensional_noise_reference(
            regime, n = 24L, p = reference_p, noise_sd = 1,
            module_correlation = 0.6
        )
    }, numeric(1L))
    tasks <- tasks[, c(
        "task_id", "task_ordinal", "control", "design_id", "p",
        "signal_ratio", "signal_strength", "replicate_index", "seed_root",
        "canonical_cell", "stream_seeds", "task_stream"
    )]
    rownames(tasks) <- NULL
    historical <- .k1_revised_historical_rng()
    scalar_seeds <- unlist(tasks$stream_seeds, use.names = FALSE)
    task_stream_keys <- vapply(
        tasks$task_stream, paste, collapse = ":", character(1L)
    )
    historical_range <- protocol$separation$
        reserved_historical_acceptance_ranges
    collision <- anyDuplicated(scalar_seeds) ||
        anyDuplicated(task_stream_keys) ||
        any(scalar_seeds %in% historical$scalar_seeds) ||
        any(task_stream_keys %in% historical$stream_keys) ||
        any(scalar_seeds >= historical_range$first_stream &
            scalar_seeds <= historical_range$last_stream) ||
        any(scalar_seeds %in%
            protocol$separation$reserved_calibration_rng_streams)
    if (collision) {
        .k1_acceptance_runner_abort(
            "version 3 RNG blocks collide with reserved evidence streams"
        )
    }
    list(
        version = .k1_revised_acceptance_version,
        artifact_version = protocol$artifact_version,
        protocol_id = protocol$protocol_id,
        protocol_digest = protocol$digest,
        phase_a_merge_commit = phase_a_merge_commit,
        runner_revision = runner_revision,
        seed_derivation = protocol$seed_derivation$algorithm,
        historical_stream_authentication = list(
            source_scripts_sha256 = protocol$separation$
                calibration_stream_manifests$source_script_sha256,
            frozen_manifest_digests = protocol$separation$
                calibration_stream_manifests$stream_manifest_digest,
            frozen_manifest_serialization_schema = "not_recorded_in_v3",
            reconstructed_stream_digest = digest::digest(
                historical, algo = "sha256"
            ),
            authenticated_for_execution = FALSE,
            v4_requirement = paste(
                "freeze a self-describing manifest payload and validator",
                "before revealing version 4 seeds"
            )
        ),
        tasks = tasks
    )
}

#' Reveal the deterministic revised K=1 acceptance manifest
#'
#' @param phase_a_merge_commit reviewed version 3 protocol merge SHA-1.
#' @param runner_revision reviewed runner merge SHA-1.
#' @param protocol frozen version 3 protocol.
#' @return Digest-bound `K1RevisedAcceptanceManifest`.
#' @export
k1_revised_acceptance_manifest <- function(
    phase_a_merge_commit, runner_revision,
    protocol = k1_acceptance_protocol("3")
) {
    .k1_acceptance_public_boundary({
        payload <- .k1_revised_manifest_payload(
            phase_a_merge_commit, runner_revision, protocol
        )
        structure(c(payload, list(
            digest = digest::digest(payload, algo = "sha256")
        )), class = c("K1RevisedAcceptanceManifest", "list"))
    }, "could not construct revised K=1 acceptance manifest")
}

#' Validate a revised K=1 acceptance manifest
#'
#' @param manifest object returned by `k1_revised_acceptance_manifest()`.
#' @return Invisibly `TRUE`, or throws `k1_acceptance_runner_error`.
#' @export
validate_k1_revised_acceptance_manifest <- function(manifest) {
    .k1_acceptance_public_boundary({
        if (!inherits(manifest, "K1RevisedAcceptanceManifest")) {
            .k1_acceptance_runner_abort(
                "manifest must inherit from K1RevisedAcceptanceManifest"
            )
        }
        expected <- k1_revised_acceptance_manifest(
            manifest$phase_a_merge_commit, manifest$runner_revision,
            k1_acceptance_protocol("3")
        )
        if (!identical(manifest, expected)) {
            .k1_acceptance_runner_abort(
                "revised acceptance manifest differs from its frozen derivation"
            )
        }
        invisible(TRUE)
    }, "could not validate revised K=1 acceptance manifest")
}

.k1_revised_task_rows <- function(tasks) {
    if (!is.data.frame(tasks) || !nrow(tasks)) {
        .k1_acceptance_runner_abort("revised acceptance tasks are empty")
    }
    lapply(seq_len(nrow(tasks)), function(index) tasks[index, , drop = FALSE])
}

.k1_revised_assert_execution_authorized <- function(protocol) {
    validate_k1_acceptance_protocol(protocol)
    if (identical(protocol$artifact_version, "3")) {
        .k1_acceptance_runner_abort(paste(
            "version 3 acceptance execution is retired because manifest tasks",
            "were exercised during runner development; freeze and implement a",
            "new protocol version before scientific execution"
        ))
    }
    .k1_acceptance_runner_abort(
        "this runner does not implement the supplied acceptance protocol"
    )
}

.k1_revised_failure <- function(task, condition, runtime_identity = NULL) {
    structure(list(
        version = "k1-revised-acceptance-replicate-v1",
        task_id = task$task_id[[1L]], control = task$control[[1L]],
        status = "failure", outcome = "execution_failure",
        recovery = list(
            evaluable = FALSE, met = FALSE,
            absolute_loading_cosine = NA_real_
        ),
        downstream = list(estimable = NA, diagnostic = conditionMessage(condition)),
        scientific_evidence = NULL, runtime_identity = runtime_identity
    ), class = c("K1RevisedAcceptanceReplicate", "list"))
}

.k1_revised_execution_contract <- function(task, protocol) {
    control <- task$control[[1L]]
    seeds <- task$stream_seeds[[1L]]
    common <- list(
        control = control,
        task_id = task$task_id[[1L]],
        design_id = task$design_id[[1L]],
        p = task$p[[1L]],
        recovery_threshold =
            protocol$thresholds$target_axis_recovery$minimum,
        svd = protocol$execution_contracts$svd,
        internal_parallelism = protocol$execution_contracts$
            internal_parallelism
    )
    if (identical(control, "independent_time_course")) {
        return(c(common, list(
            generator = protocol$grids$independent_time_course$fixed,
            generator_seed = seeds[[1L]],
            association_seed = as.integer(seeds[[1L]] + 1L)
        )))
    }
    if (identical(control, "repeated_subject")) {
        return(c(common, list(
            generator = protocol$grids$repeated_subject$fixed,
            generator_seed = seeds[[1L]],
            association_seed = as.integer(seeds[[1L]] + 1L),
            proposal_seed = as.integer(seeds[[1L]] + 2L),
            axis_resampling_seed = as.integer(seeds[[1L]] + 3L),
            axis_resamples = protocol$resampling$repeated_axis_resamples
        )))
    }
    fixed <- protocol$grids[[control]]$fixed
    c(common, list(
        generator = list(
            n = fixed$n,
            informative_features = min(fixed$informative_features,
                task$p[[1L]]),
            signal_strength = task$signal_strength[[1L]],
            noise_sd = fixed$noise_sd,
            module_correlation = fixed$module_correlation
        ),
        task_stream = task$task_stream[[1L]],
        child_seeds = stats::setNames(
            seeds[1:4],
            c("generator", "association", "proposal", "resampling")
        ),
        axis_resamples = protocol$resampling$high_dimensional_axis_resamples
    ))
}

.k1_revised_run_task <- function(task, protocol, expected_identity = NULL) {
    .k1_revised_assert_execution_authorized(protocol)
    identity <- .k1_acceptance_worker_identity()
    if (!is.null(expected_identity) &&
            !identical(identity$source_revision,
                expected_identity$source_revision)) {
        .k1_acceptance_runner_abort(
            "worker source revision differs from the preflight revision"
        )
    }
    tryCatch({
        control <- task$control[[1L]]
        seeds <- task$stream_seeds[[1L]]
        threshold <- protocol$thresholds$target_axis_recovery$minimum
        assessment <- if (identical(control, "independent_time_course")) {
            fixed <- protocol$grids$independent_time_course$fixed
            .k1_independent_time_assess_one(
                task$design_id[[1L]], task$p[[1L]], fixed$noise_sd,
                fixed$time_signal, fixed$condition_time_signal,
                seeds[[1L]], threshold
            )
        } else if (identical(control, "repeated_subject")) {
            fixed <- protocol$grids$repeated_subject$fixed
            .k1_repeated_assess_one(
                task$design_id[[1L]], task$p[[1L]], fixed$noise_sd,
                fixed$time_signal, fixed$condition_time_signal,
                seeds[[1L]], threshold,
                protocol$resampling$repeated_axis_resamples
            )
        } else {
            fixed <- protocol$grids[[control]]$fixed
            .k1_high_dimensional_assess_one(
                task$design_id[[1L]], fixed$n, task$p[[1L]],
                min(fixed$informative_features, task$p[[1L]]),
                task$signal_strength[[1L]], fixed$noise_sd,
                fixed$module_correlation,
                protocol$resampling$high_dimensional_axis_resamples,
                task$task_stream[[1L]], task$task_id[[1L]], threshold,
                child_seeds = seeds[1:4]
            )
        }
        row <- if (is.list(assessment) && !is.null(assessment$row)) {
            assessment$row
        } else assessment
        if ("execution_completed" %in% names(row) &&
                !isTRUE(row$execution_completed[[1L]])) {
            return(.k1_revised_failure(
                task, simpleError(as.character(row$diagnostic[[1L]])), identity
            ))
        }
        recovery_evaluable <- isTRUE(row$recovery_evaluable[[1L]])
        recovered <- recovery_evaluable && isTRUE(row$recovery_met[[1L]])
        downstream_estimable <- if (identical(control, "repeated_subject")) {
            isTRUE(row$model_estimable[[1L]])
        } else isTRUE(row$downstream_estimable[[1L]])
        outcome <- if (!recovery_evaluable) {
            "recovery_not_evaluable"
        } else if (!recovered) {
            "recovery_below_threshold"
        } else if (!downstream_estimable) {
            "recovered_downstream_nonestimable"
        } else "recovered_and_estimable"
        structure(list(
            version = "k1-revised-acceptance-replicate-v1",
            task_id = task$task_id[[1L]], control = control,
            status = "success", outcome = outcome,
            recovery = list(
                evaluable = recovery_evaluable, met = recovered,
                absolute_loading_cosine = as.numeric(
                    row$target_loading_cosine[[1L]]
                )
            ),
            downstream = list(
                estimable = if (recovered) downstream_estimable else NA,
                diagnostic = if ("diagnostic" %in% names(row)) {
                    as.character(row$diagnostic[[1L]])
                } else if ("model_diagnostic" %in% names(row)) {
                    as.character(row$model_diagnostic[[1L]])
                } else ""
            ),
            scientific_evidence = list(
                version = "k1-revised-scientific-evidence-v1",
                control = control,
                task_id = task$task_id[[1L]],
                stream_seeds = task$stream_seeds[[1L]],
                task_stream = task$task_stream[[1L]],
                execution_contract =
                    .k1_revised_execution_contract(task, protocol),
                observed_generator = if (identical(
                    control, "independent_time_course"
                )) list(
                    template_id = row$template_id[[1L]],
                    p = as.integer(row$p[[1L]]),
                    noise_sd = protocol$grids[[control]]$fixed$noise_sd,
                    time_signal = protocol$grids[[control]]$fixed$time_signal,
                    condition_time_signal =
                        protocol$grids[[control]]$fixed$condition_time_signal,
                    generator_seed = task$stream_seeds[[1L]][[1L]],
                    association_seed = as.integer(
                        task$stream_seeds[[1L]][[1L]] + 1L
                    )
                ) else NULL,
                assessment = assessment
            ),
            runtime_identity = identity
        ), class = c("K1RevisedAcceptanceReplicate", "list"))
    }, error = function(condition) {
        .k1_revised_failure(task, condition, identity)
    })
}

.k1_revised_validate_result <- function(
    result, task, protocol, expected_revision = NULL,
    allow_implementation_fixture = FALSE
) {
    expected_names <- c(
        "version", "task_id", "control", "status", "outcome", "recovery",
        "downstream", "scientific_evidence", "runtime_identity"
    )
    fixture <- inherits(result, "K1RevisedAcceptanceImplementationFixture")
    if (!inherits(result, "K1RevisedAcceptanceReplicate") ||
            (fixture && !allow_implementation_fixture) ||
            !is.list(result) || !identical(names(result), expected_names) ||
            !identical(result$version, "k1-revised-acceptance-replicate-v1") ||
            !identical(result$task_id, task$task_id[[1L]]) ||
            !identical(result$control, task$control[[1L]]) ||
            !result$status %in% c("success", "failure") ||
            !result$outcome %in% protocol$outcome_states ||
            !identical(names(result$recovery), c(
                "evaluable", "met", "absolute_loading_cosine"
            )) || !identical(names(result$downstream), c(
                "estimable", "diagnostic"
            ))) {
        .k1_acceptance_runner_abort(
            "revised acceptance result violates its typed task contract"
        )
    }
    if (!is.null(result$runtime_identity)) {
        .k1_acceptance_validate_identity(result$runtime_identity)
    }
    if (identical(result$status, "success") &&
            is.null(result$runtime_identity)) {
        .k1_acceptance_runner_abort(
            "successful revised acceptance result has no worker identity"
        )
    }
    if (!is.null(expected_revision) &&
            !is.null(result$runtime_identity) && !identical(
            result$runtime_identity$source_revision, expected_revision)) {
        .k1_acceptance_runner_abort(
            "revised acceptance worker revision differs from the manifest"
        )
    }
    recovery <- result$recovery
    downstream <- result$downstream
    scalar_flag <- function(x, allow_na = FALSE) {
        is.logical(x) && length(x) == 1L && (allow_na || !is.na(x))
    }
    valid_common <- scalar_flag(recovery$evaluable) &&
        scalar_flag(recovery$met) &&
        is.numeric(recovery$absolute_loading_cosine) &&
        length(recovery$absolute_loading_cosine) == 1L &&
        (is.na(recovery$absolute_loading_cosine) ||
            (is.finite(recovery$absolute_loading_cosine) &&
                recovery$absolute_loading_cosine >= 0 &&
                recovery$absolute_loading_cosine <= 1)) &&
        scalar_flag(downstream$estimable, allow_na = TRUE) &&
        is.character(downstream$diagnostic) &&
        length(downstream$diagnostic) == 1L && !is.na(downstream$diagnostic)
    if (!valid_common) {
        .k1_acceptance_runner_abort(
            "revised acceptance recovery or downstream evidence is invalid"
        )
    }
    if (identical(result$status, "failure")) {
        valid_failure <- identical(result$outcome, "execution_failure") &&
            identical(recovery$evaluable, FALSE) &&
            identical(recovery$met, FALSE) &&
            is.na(recovery$absolute_loading_cosine) &&
            is.na(downstream$estimable) &&
            is.null(result$scientific_evidence) && nzchar(downstream$diagnostic)
        if (!valid_failure) {
            .k1_acceptance_runner_abort(
                "execution failure contains scientific evidence"
            )
        }
        return(invisible(TRUE))
    }
    evidence <- result$scientific_evidence
    evidence_valid <- if (fixture) {
        is.list(result$scientific_evidence) &&
            identical(result$scientific_evidence$fixture, TRUE) &&
            identical(result$scientific_evidence$claim_status,
                "implementation_proof_only")
    } else {
        is.list(evidence) && identical(names(evidence), c(
            "version", "control", "task_id", "stream_seeds", "task_stream",
            "execution_contract", "observed_generator", "assessment"
        )) && identical(evidence$version,
            "k1-revised-scientific-evidence-v1") &&
            identical(evidence$control, result$control) &&
            identical(evidence$task_id, result$task_id) &&
            identical(evidence$stream_seeds, task$stream_seeds[[1L]]) &&
            identical(evidence$task_stream, task$task_stream[[1L]]) &&
            identical(evidence$execution_contract,
                .k1_revised_execution_contract(task, protocol))
    }
    expected_outcome <- if (!recovery$evaluable) {
        "recovery_not_evaluable"
    } else if (!recovery$met) {
        "recovery_below_threshold"
    } else if (!isTRUE(downstream$estimable)) {
        "recovered_downstream_nonestimable"
    } else "recovered_and_estimable"
    threshold_consistent <- if (!recovery$evaluable) {
        is.na(recovery$absolute_loading_cosine)
    } else identical(
        recovery$met,
        recovery$absolute_loading_cosine >=
            protocol$thresholds$target_axis_recovery$minimum
    )
    if (!evidence_valid || !identical(result$outcome, expected_outcome) ||
            !threshold_consistent ||
            (!recovery$met && !is.na(downstream$estimable))) {
        .k1_acceptance_runner_abort(
            "successful revised acceptance evidence is internally inconsistent"
        )
    }
    if (!fixture && !.k1_revised_validate_scientific_evidence(
            result, task, protocol)) {
        .k1_acceptance_runner_abort(
            "control-specific scientific evidence does not match its task"
        )
    }
    invisible(TRUE)
}

.k1_revised_validate_scientific_evidence <- function(result, task, protocol) {
    assessment <- result$scientific_evidence$assessment
    row <- if (is.list(assessment) && is.data.frame(assessment$row)) {
        assessment$row
    } else assessment
    if ((!is.list(row) && !is.data.frame(row)) || length(row) == 0L ||
            !identical(as.character(row$outcome[[1L]]), result$outcome) ||
            !identical(isTRUE(row$recovery_evaluable[[1L]]),
                result$recovery$evaluable) ||
            !identical(isTRUE(row$recovery_met[[1L]]), result$recovery$met) ||
            !identical(as.numeric(row$target_loading_cosine[[1L]]),
                result$recovery$absolute_loading_cosine) ||
            !identical(isTRUE(row$execution_completed[[1L]]), TRUE)) {
        return(FALSE)
    }
    control <- result$control
    if (identical(control, "independent_time_course")) {
        contract <- result$scientific_evidence$execution_contract
        expected_observed <- list(
            template_id = task$design_id[[1L]], p = task$p[[1L]],
            noise_sd = contract$generator$noise_sd,
            time_signal = contract$generator$time_signal,
            condition_time_signal = contract$generator$condition_time_signal,
            generator_seed = contract$generator_seed,
            association_seed = contract$association_seed
        )
        return(identical(row$template_id[[1L]], task$design_id[[1L]]) &&
            identical(as.integer(row$p[[1L]]), task$p[[1L]]) &&
            identical(isTRUE(row$downstream_estimable[[1L]]),
                isTRUE(result$downstream$estimable)) &&
            identical(contract$generator_seed,
                task$stream_seeds[[1L]][[1L]]) &&
            identical(contract$generator,
                protocol$grids$independent_time_course$fixed) &&
            identical(result$scientific_evidence$observed_generator,
                expected_observed))
    }
    if (!is.list(assessment) || !identical(names(assessment),
            c("row", "evidence")) || !is.data.frame(assessment$row)) {
        return(FALSE)
    }
    scientific <- assessment$evidence
    if (identical(control, "repeated_subject")) {
        recovery <- scientific$recovery
        model <- scientific$repeated_subject_model
        identifiability <- scientific$identifiability
        nomination <- scientific$metadata_nomination
        return(inherits(scientific, "K1RepeatedSubjectReplicateEvidence") &&
            identical(scientific$version,
                "k1-repeated-subject-replicate-evidence-v1") &&
            identical(scientific$template$id, task$design_id[[1L]]) &&
            identical(scientific$template$seed,
                task$stream_seeds[[1L]][[1L]]) &&
            identical(scientific$outcome, result$outcome) &&
            identical(recovery$target_loading_cosine,
                result$recovery$absolute_loading_cosine) &&
            identical(recovery$threshold,
                protocol$thresholds$target_axis_recovery$minimum) &&
            identical(recovery$met, result$recovery$met) &&
            identical(model$status == "estimable",
                isTRUE(result$downstream$estimable)) &&
            identical(model$status == "estimable",
                isTRUE(row$model_estimable[[1L]])) &&
            identical(identifiability$plan_seed,
                as.integer(task$stream_seeds[[1L]][[1L]] + 3L)) &&
            identical(identifiability$n_requested,
                protocol$resampling$repeated_axis_resamples) &&
            identical(nomination$nominated_component,
                row$nominated_component[[1L]]) &&
            identical(as.integer(row$p[[1L]]), task$p[[1L]]))
    }
    generator <- scientific$generator
    rng <- scientific$rng
    recovery <- scientific$target_recovery
    downstream <- scientific$downstream_estimability
    identifiability <- scientific$axis_identifiability
    identical(scientific$version, "k1-high-dimensional-replicate-v1") &&
        identical(scientific$row, assessment$row) &&
        identical(generator$regime_id, task$design_id[[1L]]) &&
        identical(as.integer(generator$p), task$p[[1L]]) &&
        identical(as.integer(generator$n),
            protocol$grids[[control]]$fixed$n) &&
        identical(as.integer(generator$informative_feature_count),
            min(protocol$grids[[control]]$fixed$informative_features,
                task$p[[1L]])) &&
        identical(generator$signal_strength, task$signal_strength[[1L]]) &&
        identical(generator$noise_sd,
            protocol$grids[[control]]$fixed$noise_sd) &&
        identical(generator$module_correlation,
            protocol$grids[[control]]$fixed$module_correlation) &&
        is.list(generator$planted_answer_key) &&
        identical(generator$seed,
            task$stream_seeds[[1L]][[1L]]) &&
        identical(rng$task_id, task$task_id[[1L]]) &&
        identical(rng$task_stream, task$task_stream[[1L]]) &&
        identical(unname(rng$child_seeds),
            task$stream_seeds[[1L]][1:4]) &&
        identical(recovery$target_loading_cosine,
            result$recovery$absolute_loading_cosine) &&
        identical(recovery$threshold,
            protocol$thresholds$target_axis_recovery$minimum) &&
        identical(recovery$met, result$recovery$met) &&
        identical(downstream$estimable,
            isTRUE(result$downstream$estimable)) &&
        identical(downstream$estimable,
            isTRUE(row$downstream_estimable[[1L]])) &&
        identical(identifiability$n_requested,
            protocol$resampling$high_dimensional_axis_resamples) &&
        identical(identifiability$n_completed,
            row$axis_refits_completed[[1L]])
}

.k1_revised_collect <- function(
    results, tasks, protocol, expected_revision = NULL,
    allow_implementation_fixture = FALSE
) {
    if (!is.list(results) || length(results) != nrow(tasks)) {
        .k1_acceptance_runner_abort(
            "revised acceptance collector requires one result per task"
        )
    }
    results <- unname(results)
    results <- lapply(seq_along(results), function(index) {
        if (!is.null(results[[index]])) return(results[[index]])
        .k1_revised_failure(
            tasks[index, , drop = FALSE],
            simpleError("worker branch returned no serialized result")
        )
    })
    ids <- vapply(results, function(x) x$task_id %||% "", character(1L))
    if (!identical(ids, tasks$task_id)) {
        .k1_acceptance_runner_abort(
            "revised acceptance result order or task identity is invalid"
        )
    }
    for (index in seq_along(results)) {
        .k1_revised_validate_result(
            results[[index]], tasks[index, , drop = FALSE], protocol,
            expected_revision, allow_implementation_fixture
        )
    }
    results
}

.k1_revised_wilson <- function(successes, trials, confidence = 0.95) {
    if (trials < 1L) return(c(lower = NA_real_, upper = NA_real_))
    z <- stats::qnorm(1 - (1 - confidence) / 2)
    estimate <- successes / trials
    denominator <- 1 + z^2 / trials
    centre <- estimate + z^2 / (2 * trials)
    radius <- z * sqrt(
        estimate * (1 - estimate) / trials + z^2 / (4 * trials^2)
    )
    round(c(
        lower = (centre - radius) / denominator,
        upper = (centre + radius) / denominator
    ), 15L)
}

#' Summarize revised K=1 acceptance evidence
#'
#' @param results one typed result for every row in `tasks`.
#' @param tasks rows from a validated revised manifest.
#' @param protocol frozen version 3 protocol.
#' @return Digest-bound `K1RevisedAcceptanceSummary`.
#' @export
summarize_k1_revised_acceptance <- function(
    results, tasks, protocol = k1_acceptance_protocol("3"), manifest = NULL
) {
    validate_k1_acceptance_protocol(protocol)
    complete_manifest <- !is.null(manifest)
    if (complete_manifest) {
        validate_k1_revised_acceptance_manifest(manifest)
        complete_manifest <- identical(tasks, manifest$tasks) &&
            identical(protocol$digest, manifest$protocol_digest)
        if (!complete_manifest) {
            .k1_acceptance_runner_abort(
                "acceptance summary manifest does not match its complete tasks"
            )
        }
    }
    expected_revision <- if (complete_manifest) manifest$runner_revision else NULL
    results <- .k1_revised_collect(
        results, tasks, protocol, expected_revision,
        allow_implementation_fixture = !complete_manifest
    )
    groups <- split(
        seq_len(nrow(tasks)),
        factor(
            tasks$canonical_cell,
            levels = unique(tasks$canonical_cell)
        )
    )
    cells <- do.call(rbind, lapply(groups, function(indices) {
        cell_tasks <- tasks[indices, , drop = FALSE]
        cell_results <- results[indices]
        requested <- nrow(cell_tasks)
        completed <- sum(vapply(
            cell_results, function(x) identical(x$status, "success"), logical(1L)
        ))
        evaluable <- sum(vapply(
            cell_results, function(x) isTRUE(x$recovery$evaluable), logical(1L)
        ))
        recovered <- sum(vapply(
            cell_results, function(x) isTRUE(x$recovery$met), logical(1L)
        ))
        interval <- .k1_revised_wilson(recovered, requested)
        recovered_estimable <- sum(vapply(cell_results, function(x) {
            isTRUE(x$recovery$met) && isTRUE(x$downstream$estimable)
        }, logical(1L)))
        complete <- requested == 100L && completed == requested &&
            evaluable == requested
        is_null <- identical(
            cell_tasks$control[[1L]], "high_dimensional_null"
        )
        probability <- recovered / requested
        decision <- if (!complete) {
            "indeterminate"
        } else if (is_null &&
                probability <= protocol$thresholds$null_control$
                    maximum_recovery_probability &&
                interval[["upper"]] <= protocol$thresholds$null_control$
                    maximum_wilson_95_upper_bound) {
            "passed_null"
        } else if (is_null) {
            "failed_null"
        } else if (
            probability >= protocol$thresholds$supported_cell$
                minimum_recovery_probability &&
            interval[["lower"]] >= protocol$thresholds$supported_cell$
                minimum_wilson_95_lower_bound
        ) {
            "supported"
        } else "unsupported"
        data.frame(
            canonical_cell = cell_tasks$canonical_cell[[1L]],
            control = cell_tasks$control[[1L]],
            design_id = cell_tasks$design_id[[1L]],
            p = cell_tasks$p[[1L]],
            signal_ratio = cell_tasks$signal_ratio[[1L]],
            signal_strength = cell_tasks$signal_strength[[1L]],
            n_requested = as.integer(requested),
            n_completed = as.integer(completed),
            n_recovery_evaluable = as.integer(evaluable),
            n_recovered = as.integer(recovered),
            recovery_probability = probability,
            wilson_95_lower = interval[["lower"]],
            wilson_95_upper = interval[["upper"]],
            n_recovered_downstream_estimable =
                as.integer(recovered_estimable),
            downstream_estimability_probability = if (recovered) {
                recovered_estimable / recovered
            } else NA_real_,
            decision = decision, stringsAsFactors = FALSE
        )
    }))
    rownames(cells) <- NULL
    null_cells <- cells$control == "high_dimensional_null"
    retired <- identical(protocol$artifact_version, "3")
    claim_status <- if (!complete_manifest) {
        "implementation_proof_only"
    } else if (retired) {
        "retired_protocol_audit_only"
    } else "independent_acceptance_evidence"
    null_controls_pass <- complete_manifest && !retired && any(null_cells) &&
        all(cells$decision[null_cells] == "passed_null")
    payload <- list(
        version = "k1-revised-acceptance-summary-v1",
        claim_status = claim_status,
        protocol_digest = protocol$digest,
        evidence_context = list(
            complete_manifest = complete_manifest,
            protocol_retired = retired,
            requested_replicates_per_cell = 100L,
            target_loading_cosine_threshold =
                protocol$thresholds$target_axis_recovery$minimum,
            supported_wilson_lower = protocol$thresholds$supported_cell$
                minimum_wilson_95_lower_bound,
            null_recovery_maximum = protocol$thresholds$null_control$
                maximum_recovery_probability,
            null_wilson_upper = protocol$thresholds$null_control$
                maximum_wilson_95_upper_bound,
            svd_components = protocol$execution_contracts$svd$k_components,
            high_dimensional_n = protocol$grids$high_dimensional_signal$fixed$n,
            signal_reference_p = protocol$grids$high_dimensional_signal$
                signal_parameterization$reference_p,
            high_dimensional_axis_resamples =
                protocol$resampling$high_dimensional_axis_resamples,
            independent_sampling_unit =
                protocol$resampling$independent_biological_unit,
            repeated_sampling_unit = protocol$resampling$repeated_biological_unit
        ),
        cells = cells,
        advancement = list(
            null_controls_pass = null_controls_pass,
            supported_positive_cells = cells$canonical_cell[
                claim_status == "independent_acceptance_evidence" &
                    cells$decision == "supported"
            ],
            conclusion = if (
                null_controls_pass &&
                    any(cells$decision == "supported")
            ) "supported_regions_available" else "no_advance"
        )
    )
    structure(c(payload, list(
        digest = digest::digest(payload, algo = "sha256")
    )), class = c("K1RevisedAcceptanceSummary", "list"))
}

.validate_k1_revised_summary <- function(summary) {
    if (!inherits(summary, "K1RevisedAcceptanceSummary") ||
            !is.list(summary)) {
        .k1_acceptance_runner_abort(
            "summary must inherit from K1RevisedAcceptanceSummary"
        )
    }
    payload <- unclass(summary)
    observed <- payload$digest
    payload$digest <- NULL
    if (!identical(observed, digest::digest(payload, algo = "sha256"))) {
        .k1_acceptance_runner_abort(
            "revised acceptance summary digest is invalid"
        )
    }
    invisible(TRUE)
}

#' Plot revised K=1 acceptance operating evidence
#'
#' @param summary revised acceptance summary.
#' @param view either sampling-design recovery or high-dimensional signal
#'   recovery. Downstream estimability is shown only as a secondary annotation
#'   because it is conditional on planted-axis recovery.
#' @return Publication-themed ggplot with an accessible separate caption.
#' @export
plot_k1_revised_acceptance <- function(
    summary, view = c("sampling_design", "signal_regime")
) {
    .validate_k1_revised_summary(summary)
    view <- match.arg(view)
    cells <- summary$cells
    if (identical(view, "sampling_design")) {
        display <- cells[cells$control %in% c(
            "independent_time_course", "repeated_subject"
        ), , drop = FALSE]
        display$design_family <- factor(
            display$control,
            levels = c("independent_time_course", "repeated_subject"),
            labels = c(
                "Independent destructive sampling",
                "Repeated-subject sampling"
            )
        )
        design_labels <- c(
            balanced_1 = "Balanced: one animal",
            balanced_2 = "Balanced: two animals",
            balanced_3 = "Balanced: three animals",
            unequal_1_2_3 = "Unequal: one to three animals",
            isolated_library_failure = "Isolated library failure",
            missing_internal_cell = "Missing internal cell",
            complete = "Complete trajectories",
            isolated_observation_loss = "Isolated observation loss",
            terminal_dropout = "Terminal dropout",
            condition_dependent_loss = "Condition-dependent loss"
        )
        display$facet_label <- unname(design_labels[display$design_id])
        display$feature_count <- factor(
            display$p, levels = sort(unique(display$p)),
            labels = scales::label_comma()(sort(unique(display$p)))
        )
        plot <- ggplot2::ggplot(display, ggplot2::aes(
            x = feature_count, y = recovery_probability,
            group = design_id
        )) +
            ggplot2::geom_hline(
                yintercept = 0.90, colour = "#B2182B", linewidth = 0.45,
                linetype = "dashed"
            ) +
            ggplot2::geom_line(
                colour = "#777777", linewidth = 0.45, alpha = 0.65
            ) +
            ggplot2::geom_linerange(ggplot2::aes(
                ymin = wilson_95_lower, ymax = wilson_95_upper
            ), colour = "#555555", linewidth = 0.35) +
            ggplot2::geom_point(ggplot2::aes(
                fill = decision, shape = decision
            ), colour = "#1A1A1A", size = 2.5, stroke = 0.4) +
            ggplot2::facet_wrap(
                ggplot2::vars(facet_label), ncol = 5, scales = "free_x"
            ) +
            ggplot2::scale_fill_manual(values = c(
                supported = "#B2182B", unsupported = "white",
                indeterminate = "#BDBDBD"
            ), drop = FALSE) +
            ggplot2::scale_shape_manual(values = c(
                supported = 21, unsupported = 21, indeterminate = 22
            ), drop = FALSE) +
            ggplot2::coord_cartesian(ylim = c(0, 1)) +
            ggplot2::labs(
                x = "Expression features", y = "Target-axis recovery",
                fill = "Cell decision", shape = "Cell decision"
            ) +
            theme_landscapeR(square = FALSE) +
            ggplot2::theme(
                legend.position = "bottom",
                panel.spacing = grid::unit(4, "mm"),
                axis.text.x = ggplot2::element_text(angle = 45, hjust = 1)
            )
        context <- summary$evidence_context
        caption <- .build_scientific_caption(.new_scientific_caption_view(
            title = "Recovery across declared longitudinal sampling designs",
            experiment_label = "synthetic K=1 assessment",
            sampling_unit = paste(
                context$independent_sampling_unit, "or",
                context$repeated_sampling_unit
            ),
            encodings = c(paste(
                "Red filled circles denote supported cells, open circles",
                "denote unsupported cells, and grey squares denote cells",
                "with incomplete or non-evaluable execution. The dashed red",
                "line marks the predeclared 0.90 recovery-probability gate."
            )),
            design = paste(
                "Independent designs resample one destructively collected",
                "animal; repeated designs resample complete subject",
                "trajectories. SVD used", context$svd_components,
                "components and no metadata during decomposition"
            ),
            uncertainty = paste(
                "Vertical intervals are Wilson 95% confidence intervals for",
                "recovery among all",
                context$requested_replicates_per_cell,
                "requested replicates per complete cell."
            ),
            threshold = paste(
                "Support requires recovery of at least",
                context$target_loading_cosine_threshold,
                ", a Wilson lower bound of at least",
                context$supported_wilson_lower,
                ", and complete evaluability."
            ),
            claim_boundary = paste(
                "Claim status is", gsub("_", " ", summary$claim_status),
                "; results apply only to the displayed synthetic designs and",
                "are not a universal sample-size rule."
            ),
            state = if (identical(
                summary$claim_status, "independent_acceptance_evidence"
            )) "calibrated" else "uncalibrated"
        ))
    } else {
        display <- cells[cells$control %in% c(
            "high_dimensional_signal", "high_dimensional_null"
        ), , drop = FALSE]
        display$feature_count <- factor(
            display$p, levels = rev(sort(unique(display$p))),
            labels = scales::label_comma()(rev(sort(unique(display$p))))
        )
        display$signal_ratio_label <- factor(
            display$signal_ratio,
            levels = sort(unique(display$signal_ratio)),
            labels = format(sort(unique(display$signal_ratio)), trim = TRUE)
        )
        regime_labels <- c(
            correlated_modules = "Correlated modules",
            fixed_sparse = "Fixed sparse signal",
            fixed_total_spike = "Fixed total spike",
            growing_coherent = "Growing coherent signal",
            null_near_null = "Null and near-null"
        )
        display$regime_label <- unname(regime_labels[display$design_id])
        plot <- ggplot2::ggplot(display, ggplot2::aes(
            x = signal_ratio_label, y = feature_count,
            fill = recovery_probability
        )) +
            ggplot2::geom_tile(colour = "white", linewidth = 0.8) +
            ggplot2::geom_point(ggplot2::aes(shape = decision),
                colour = "#1A1A1A", fill = "white", size = 2.2, stroke = 0.5) +
            ggplot2::facet_wrap(
                ggplot2::vars(regime_label), ncol = 3, scales = "free_x"
            ) +
            ggplot2::scale_fill_gradient(
                low = "white", high = "#B2182B", limits = c(0, 1),
                name = "Recovery"
            ) +
            ggplot2::scale_shape_manual(values = c(
                supported = 21, unsupported = 1, indeterminate = 4,
                passed_null = 24, failed_null = 25
            ), drop = FALSE, name = "Cell decision") +
            ggplot2::labs(
                x = "Signal coefficient relative to the p = 100 reference",
                y = "Expression features"
            ) +
            theme_landscapeR(square = FALSE) +
            ggplot2::theme(
                legend.position = "bottom",
                panel.spacing = grid::unit(5, "mm")
            )
        context <- summary$evidence_context
        caption <- .build_scientific_caption(.new_scientific_caption_view(
            title = "Recovery across high-dimensional signal regimes",
            experiment_label = "synthetic K=1 assessment",
            sampling_unit = context$independent_sampling_unit,
            encodings = c(paste(
                "Circle symbols distinguish supported and unsupported",
                "positive cells; upward triangles mark passing null controls",
                "and downward triangles mark failed null controls."
            )),
            design = paste(
                "Signal coefficients use the regime-specific noise reference",
                "at n =", context$high_dimensional_n, "and p =",
                context$signal_reference_p, ". Each replicate requests",
                context$high_dimensional_axis_resamples,
                "stratified axis refits"
            ),
            uncertainty = paste(
                "Cell decisions use Wilson 95% confidence intervals over all",
                context$requested_replicates_per_cell,
                "requested replicates in each complete cell."
            ),
            threshold = paste(
                "Positive support requires recovery at least",
                context$target_loading_cosine_threshold,
                "and a Wilson lower bound at least",
                context$supported_wilson_lower,
                "; passing null controls require recovery no greater than",
                context$null_recovery_maximum,
                "and a Wilson upper bound no greater than",
                context$null_wilson_upper, "."
            ),
            claim_boundary = paste(
                "Claim status is", gsub("_", " ", summary$claim_status),
                "; the map describes only the frozen feature counts, signal",
                "coefficients, covariance regimes, and sample size."
            ),
            state = if (identical(
                summary$claim_status, "independent_acceptance_evidence"
            )) "calibrated" else "uncalibrated"
        ))
    }
    attr(plot, "landscapeR_k1_revised_map_data") <- display
    .with_scientific_caption(plot, caption)
}

.k1_revised_governed_files <- function() c(
    "protocol.rds", "seed-manifest.rds", "replicates.rds", "summary.rds",
    "replicates.csv", "cell-summary.csv", "sampling-design-map.csv",
    "sampling-design-map.png", "sampling-design-map-caption.txt",
    "signal-regime-map.csv", "signal-regime-map.png",
    "signal-regime-map-caption.txt", "environment.rds"
)

.k1_revised_flatten <- function(results) do.call(rbind, lapply(results, function(x) {
    data.frame(
        task_id = x$task_id, control = x$control, status = x$status,
        outcome = x$outcome,
        recovery_evaluable = isTRUE(x$recovery$evaluable),
        recovery_met = isTRUE(x$recovery$met),
        absolute_loading_cosine = x$recovery$absolute_loading_cosine,
        downstream_estimable = x$downstream$estimable,
        diagnostic = x$downstream$diagnostic, stringsAsFactors = FALSE
    )
}))

.k1_revised_publish <- function(
    artifact_root, protocol, manifest, tasks, results, identity,
    collector_identity = identity
) {
    validate_k1_acceptance_protocol(protocol)
    validate_k1_revised_acceptance_manifest(manifest)
    .k1_acceptance_validate_identity(identity)
    .k1_acceptance_validate_collector_identity(collector_identity)
    .k1_validate_runtime_revision(identity, manifest)
    if (identical(protocol$artifact_version, "3")) {
        .k1_acceptance_runner_abort(
            "retired version 3 evidence cannot be published as acceptance"
        )
    }
    if (!identical(tasks, manifest$tasks)) {
        .k1_acceptance_runner_abort(
            "revised acceptance publication requires the complete manifest"
        )
    }
    results <- .k1_revised_collect(
        results, tasks, protocol, manifest$runner_revision
    )
    summary <- summarize_k1_revised_acceptance(
        results, tasks, protocol, manifest
    )
    sampling_plot <- plot_k1_revised_acceptance(summary, "sampling_design")
    signal_plot <- plot_k1_revised_acceptance(summary, "signal_regime")
    artifact_root <- path.expand(artifact_root)
    dir.create(artifact_root, recursive = TRUE, showWarnings = FALSE)
    staging <- tempfile(
        pattern = paste0(".", protocol$protocol_id, "-tmp-"),
        tmpdir = artifact_root
    )
    dir.create(staging, recursive = TRUE, showWarnings = FALSE)
    saveRDS(protocol, file.path(staging, "protocol.rds"))
    saveRDS(manifest, file.path(staging, "seed-manifest.rds"))
    saveRDS(results, file.path(staging, "replicates.rds"))
    saveRDS(summary, file.path(staging, "summary.rds"))
    utils::write.csv(.k1_revised_flatten(results),
        file.path(staging, "replicates.csv"), row.names = FALSE)
    utils::write.csv(summary$cells,
        file.path(staging, "cell-summary.csv"), row.names = FALSE)
    utils::write.csv(
        attr(sampling_plot, "landscapeR_k1_revised_map_data"),
        file.path(staging, "sampling-design-map.csv"), row.names = FALSE
    )
    utils::write.csv(
        attr(signal_plot, "landscapeR_k1_revised_map_data"),
        file.path(staging, "signal-regime-map.csv"), row.names = FALSE
    )
    ggplot2::ggsave(file.path(staging, "sampling-design-map.png"),
        sampling_plot, width = 180, height = 130, units = "mm", dpi = 450,
        bg = "white")
    ggplot2::ggsave(file.path(staging, "signal-regime-map.png"),
        signal_plot, width = 160, height = 140, units = "mm", dpi = 450,
        bg = "white")
    writeLines(scientific_caption(sampling_plot),
        file.path(staging, "sampling-design-map-caption.txt"))
    writeLines(scientific_caption(signal_plot),
        file.path(staging, "signal-regime-map-caption.txt"))
    worker_identities <- lapply(results, `[[`, "runtime_identity")
    environment <- list(
        version = .k1_revised_acceptance_version,
        protocol_digest = protocol$digest,
        manifest_digest = manifest$digest,
        summary_digest = summary$digest,
        runtime_identity = identity,
        worker_identity_digest = digest::digest(
            worker_identities, algo = "sha256"
        ),
        collector_identity = collector_identity
    )
    saveRDS(environment, file.path(staging, "environment.rds"))
    governed <- .k1_revised_governed_files()
    file_manifest <- data.frame(
        file = governed,
        sha256 = vapply(file.path(staging, governed),
            .k1_acceptance_file_digest, character(1L)),
        stringsAsFactors = FALSE
    )
    artifact_digest <- .k1_acceptance_artifact_digest(file_manifest)
    artifact <- file.path(artifact_root, paste0(
        protocol$protocol_id, "-", substr(artifact_digest, 1L, 16L)
    ))
    if (dir.exists(artifact)) {
        unlink(staging, recursive = TRUE)
        .k1_revised_verify_artifact(artifact)
        return(artifact)
    }
    utils::write.table(file_manifest, file.path(staging, "MANIFEST.tsv"),
        sep = "\t", quote = FALSE, row.names = FALSE)
    if (!file.rename(staging, artifact)) {
        unlink(staging, recursive = TRUE)
        .k1_acceptance_runner_abort(
            "could not atomically publish revised acceptance artifact"
        )
    }
    .k1_revised_verify_artifact(artifact)
    artifact
}

.k1_revised_verify_artifact <- function(artifact) {
    artifact <- path.expand(artifact)
    manifest_path <- file.path(artifact, "MANIFEST.tsv")
    if (!file.exists(manifest_path)) {
        .k1_acceptance_runner_abort(
            "revised acceptance artifact has no MANIFEST.tsv"
        )
    }
    files <- utils::read.delim(manifest_path, stringsAsFactors = FALSE)
    if (!identical(names(files), c("file", "sha256")) ||
            !identical(files$file, .k1_revised_governed_files()) ||
            anyNA(files) || anyDuplicated(files$file)) {
        .k1_acceptance_runner_abort(
            "revised acceptance file manifest is invalid"
        )
    }
    actual_files <- list.files(
        artifact, recursive = TRUE, all.files = TRUE, no.. = TRUE,
        include.dirs = FALSE
    )
    if (!setequal(actual_files, c("MANIFEST.tsv", files$file))) {
        .k1_acceptance_runner_abort(
            "revised acceptance artifact contains undeclared files"
        )
    }
    paths <- file.path(artifact, files$file)
    if (any(!file.exists(paths)) || !identical(
            unname(vapply(paths, .k1_acceptance_file_digest, character(1L))),
            files$sha256
        )) {
        .k1_acceptance_runner_abort(
            "revised acceptance artifact digest verification failed"
        )
    }
    protocol <- readRDS(file.path(artifact, "protocol.rds"))
    manifest <- readRDS(file.path(artifact, "seed-manifest.rds"))
    results <- readRDS(file.path(artifact, "replicates.rds"))
    summary <- readRDS(file.path(artifact, "summary.rds"))
    environment <- readRDS(file.path(artifact, "environment.rds"))
    validate_k1_revised_acceptance_manifest(manifest)
    .k1_acceptance_validate_identity(environment$runtime_identity)
    .k1_acceptance_validate_collector_identity(environment$collector_identity)
    .k1_validate_runtime_revision(environment$runtime_identity, manifest)
    reproduced <- summarize_k1_revised_acceptance(
        results, manifest$tasks, protocol, manifest
    )
    if (!identical(summary, reproduced)) {
        .k1_acceptance_runner_abort(
            "revised acceptance summary does not reproduce"
        )
    }
    captions <- c(
        sampling_design = scientific_caption(
            plot_k1_revised_acceptance(reproduced, "sampling_design")
        ),
        signal_regime = scientific_caption(
            plot_k1_revised_acceptance(reproduced, "signal_regime")
        )
    )
    observed_captions <- c(
        sampling_design = paste(readLines(file.path(
            artifact, "sampling-design-map-caption.txt"
        ), warn = FALSE), collapse = "\n"),
        signal_regime = paste(readLines(file.path(
            artifact, "signal-regime-map-caption.txt"
        ), warn = FALSE), collapse = "\n")
    )
    expected_csv <- c(
        sampling_design = tempfile("sampling-design-", fileext = ".csv"),
        signal_regime = tempfile("signal-regime-", fileext = ".csv")
    )
    on.exit(unlink(expected_csv), add = TRUE)
    utils::write.csv(
        attr(plot_k1_revised_acceptance(
            reproduced, "sampling_design"
        ), "landscapeR_k1_revised_map_data"),
        expected_csv[["sampling_design"]], row.names = FALSE
    )
    utils::write.csv(
        attr(plot_k1_revised_acceptance(
            reproduced, "signal_regime"
        ), "landscapeR_k1_revised_map_data"),
        expected_csv[["signal_regime"]], row.names = FALSE
    )
    csv_reproduces <- identical(
        readLines(expected_csv[["sampling_design"]], warn = FALSE),
        readLines(file.path(artifact, "sampling-design-map.csv"), warn = FALSE)
    ) && identical(
        readLines(expected_csv[["signal_regime"]], warn = FALSE),
        readLines(file.path(artifact, "signal-regime-map.csv"), warn = FALSE)
    )
    expected_environment <- list(
        version = .k1_revised_acceptance_version,
        protocol_digest = protocol$digest,
        manifest_digest = manifest$digest,
        summary_digest = summary$digest,
        runtime_identity = environment$runtime_identity,
        worker_identity_digest = digest::digest(
            lapply(results, `[[`, "runtime_identity"), algo = "sha256"
        ),
        collector_identity = environment$collector_identity
    )
    artifact_digest <- .k1_acceptance_artifact_digest(files)
    expected_name <- paste0(
        protocol$protocol_id, "-", substr(artifact_digest, 1L, 16L)
    )
    if (!identical(captions, observed_captions) || !csv_reproduces ||
            !identical(environment, expected_environment) ||
            !identical(basename(artifact), expected_name)) {
        .k1_acceptance_runner_abort(
            "revised acceptance derivatives or provenance are inconsistent"
        )
    }
    invisible(TRUE)
}

#' Verify a revised K=1 acceptance artifact
#'
#' @param artifact path returned by `k1_revised_acceptance_targets()`.
#' @return Invisibly `TRUE`, or throws `k1_acceptance_runner_error`.
#' @export
verify_k1_revised_acceptance_artifact <- function(artifact) {
    .k1_acceptance_public_boundary(
        .k1_revised_verify_artifact(artifact),
        "could not verify revised K=1 acceptance artifact"
    )
}

#' Inspect the retired version 3 K=1 acceptance targets graph
#'
#' This audit-only graph records the intended one-branch-per-replicate topology,
#' but its preflight deliberately stops because version 3 seeds were retired
#' during runner development. It cannot execute scientific work. Version 4 must
#' be frozen and explicitly supported before production scheduling.
#'
#' @param phase_a_merge_commit reviewed version 3 protocol merge SHA-1.
#' @param runner_revision reviewed runner merge SHA-1.
#' @param artifact_root absolute publication directory.
#' @param controller named crew controller configured by the caller.
#' @return Audit-only list of targets objects whose preflight always stops for
#'   the retired version 3 protocol.
#' @export
k1_revised_acceptance_targets <- function(
    phase_a_merge_commit, runner_revision, artifact_root,
    controller = "k1-revised-acceptance"
) {
    if (!requireNamespace("targets", quietly = TRUE)) {
        .k1_acceptance_runner_abort(
            "revised K=1 orchestration requires optional package 'targets'"
        )
    }
    .k1_acceptance_validate_merge_commit(phase_a_merge_commit)
    .k1_acceptance_validate_merge_commit(runner_revision)
    if (!.is_scalar_nonempty_text(artifact_root) ||
            !grepl("^/", path.expand(artifact_root)) ||
            !.is_scalar_nonempty_text(controller)) {
        .k1_acceptance_runner_abort(
            "artifact_root must be absolute and controller must be non-empty"
        )
    }
    list(
        .k1_acceptance_target(
            "k1_v3_protocol", quote(landscapeR::k1_acceptance_protocol("3"))
        ),
        .k1_acceptance_target(
            "k1_v3_manifest",
            substitute(landscapeR::k1_revised_acceptance_manifest(
                PROTOCOL, RUNNER, k1_v3_protocol
            ), list(PROTOCOL = phase_a_merge_commit, RUNNER = runner_revision))
        ),
        .k1_acceptance_target(
            "k1_v3_identity", quote(landscapeR:::.k1_acceptance_worker_identity())
        ),
        .k1_acceptance_target("k1_v3_preflight", quote({
            landscapeR:::.k1_revised_assert_execution_authorized(
                k1_v3_protocol
            )
            landscapeR:::.k1_validate_runtime_revision(
                k1_v3_identity, k1_v3_manifest
            )
            TRUE
        })),
        .k1_acceptance_target("k1_v3_tasks", quote({
            k1_v3_preflight
            k1_v3_manifest$tasks
        })),
        .k1_acceptance_target(
            "k1_v3_task", quote(landscapeR:::.k1_revised_task_rows(k1_v3_tasks)),
            iteration = "list"
        ),
        .k1_acceptance_target(
            "k1_v3_result", quote(landscapeR:::.k1_revised_run_task(
                k1_v3_task, k1_v3_protocol,
                expected_identity = k1_v3_identity
            )), deployment = "worker", pattern = quote(map(k1_v3_task)),
            controller = controller, packages = "landscapeR",
            iteration = "list", error = "null"
        ),
        .k1_acceptance_target(
            "k1_v3_results", quote(landscapeR:::.k1_revised_collect(
                k1_v3_result, k1_v3_tasks, k1_v3_protocol,
                k1_v3_manifest$runner_revision
            ))
        ),
        .k1_acceptance_target(
            "k1_v3_artifact", substitute(
                landscapeR:::.k1_revised_publish(
                    ROOT, k1_v3_protocol, k1_v3_manifest,
                    k1_v3_tasks, k1_v3_results, k1_v3_identity
                ), list(ROOT = path.expand(artifact_root))
            ), format = "file"
        ),
        .k1_acceptance_target("k1_v3_artifact_verified", quote({
            landscapeR:::.k1_revised_verify_artifact(k1_v3_artifact)
            k1_v3_artifact
        })),
        .k1_acceptance_target("k1_v3_evidence", quote(structure(list(
            artifact = k1_v3_artifact_verified, verified = TRUE,
            protocol_digest = k1_v3_protocol$digest,
            manifest_digest = k1_v3_manifest$digest
        ), class = c("K1RevisedAcceptanceWorkflowResult", "list"))))
    )
}
