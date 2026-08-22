# Stage 0 K=1 independent acceptance runner
#
# The protocol owns every scientific value. This module reveals deterministic
# post-merge seeds, executes independent branches, and publishes immutable
# evidence. Scheduler resources remain caller-owned operational policy.

.k1_acceptance_worker_identity_cache <- new.env(parent = emptyenv())

.k1_acceptance_runner_abort <- function(message) {
    stop(structure(
        list(message = message, call = NULL),
        class = c("k1_acceptance_runner_error", "error", "condition")
    ))
}

.k1_acceptance_public_boundary <- function(expression, context) {
    tryCatch(
        force(expression),
        k1_acceptance_runner_error = function(error) stop(error),
        error = function(error) {
            .k1_acceptance_runner_abort(sprintf(
                "%s: %s",
                context,
                conditionMessage(error)
            ))
        }
    )
}

.k1_acceptance_validate_merge_commit <- function(commit) {
    if (!is.character(commit) || length(commit) != 1L || is.na(commit) ||
            !grepl("^[0-9a-f]{40}$", commit)) {
        .k1_acceptance_runner_abort(
            paste(
                "phase_a_merge_commit must identify the reviewed protocol",
                "merge with one lowercase 40-character SHA-1"
            )
        )
    }
    commit
}

.k1_acceptance_hex_modulo <- function(hex, modulus) {
    digits <- strtoi(strsplit(tolower(hex), "", fixed = TRUE)[[1L]], 16L)
    if (anyNA(digits)) {
        .k1_acceptance_runner_abort("seed digest contains non-hexadecimal text")
    }
    value <- 0
    for (digit in digits) value <- (value * 16 + digit) %% modulus
    value
}

.k1_acceptance_seed_root <- function(
    protocol,
    merge_commit,
    canonical_cell,
    replicate_index,
    task_ordinal = NULL,
    total_tasks = NULL
) {
    if (identical(
        protocol$seed_derivation$algorithm,
        "sha256-merge-commit-indexed-block-v2"
    )) {
        if (!is.numeric(task_ordinal) || length(task_ordinal) != 1L ||
                is.na(task_ordinal) || task_ordinal < 1L ||
                task_ordinal != as.integer(task_ordinal) ||
                !is.numeric(total_tasks) || length(total_tasks) != 1L ||
                is.na(total_tasks) || total_tasks < task_ordinal ||
                total_tasks != as.integer(total_tasks)) {
            .k1_acceptance_runner_abort(
                "v2 seed derivation requires a valid canonical task ordinal"
            )
        }
        stride <- protocol$seed_derivation$block_stride
        minimum <- protocol$seed_derivation$minimum_seed_root
        maximum <- 2147483644
        maximum_start <- maximum -
            (as.integer(total_tasks) - 1L) * stride - (stride - 1L)
        if (maximum_start < minimum) {
            .k1_acceptance_runner_abort(
                "v2 acceptance workload exceeds the indexed seed space"
            )
        }
        input <- paste(
            protocol$protocol_id,
            protocol$digest,
            merge_commit,
            "seed-block",
            sep = "|"
        )
        hexadecimal <- digest::digest(input, algo = "sha256", serialize = FALSE)
        base <- minimum + .k1_acceptance_hex_modulo(
            substr(hexadecimal, 1L, 13L),
            maximum_start - minimum + 1
        )
        return(as.integer(base + (as.integer(task_ordinal) - 1L) * stride))
    }
    input <- paste(
        protocol$protocol_id,
        protocol$digest,
        merge_commit,
        canonical_cell,
        replicate_index,
        sep = "|"
    )
    hexadecimal <- digest::digest(input, algo = "sha256", serialize = FALSE)
    as.integer(1 + .k1_acceptance_hex_modulo(
        substr(hexadecimal, 1L, 13L),
        2147483644
    ))
}

.k1_acceptance_grid <- function(protocol, control) {
    grid <- if (identical(control, "generic_double_well")) {
        protocol$grids$generic_double_well$varying
    } else if (control %in% c("pure_noise", "single_well")) {
        protocol$grids$negative_controls$varying
    } else if (identical(control, "aml_synchronized")) {
        protocol$grids$aml_synchronized$varying
    } else if (identical(control, "shared_baseline_missing_cells")) {
        protocol$grids$shared_baseline_missing_cells$varying
    } else {
        .k1_acceptance_runner_abort(sprintf(
            "unknown K=1 acceptance control '%s'", control
        ))
    }
    do.call(
        expand.grid,
        c(grid, list(KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE))
    )
}

.k1_acceptance_canonical_cell <- function(control, row, schema) {
    values <- vapply(schema, function(field) {
        value <- row[[field]][[1L]]
        if (!is.numeric(value) || length(value) != 1L || is.na(value) ||
                value != as.integer(value)) {
            .k1_acceptance_runner_abort(
                "acceptance grid values must be non-missing integers"
            )
        }
        paste0(field, "=", as.integer(value))
    }, character(1L))
    paste(c(paste0("control=", control), values), collapse = ";")
}

.k1_acceptance_manifest_payload <- function(
    protocol,
    merge_commit,
    runner_revision = NULL
) {
    controls <- protocol$seed_plan$control
    task_counts <- vapply(controls, function(control) {
        grid <- .k1_acceptance_grid(protocol, control)
        replicate_count <- protocol$seed_plan$replicates_per_grid_cell[
            protocol$seed_plan$control == control
        ][[1L]]
        nrow(grid) * replicate_count
    }, integer(1L))
    task_offsets <- c(0L, head(cumsum(task_counts), -1L))
    total_tasks <- sum(task_counts)
    task_groups <- lapply(seq_along(controls), function(control_index) {
        control <- controls[[control_index]]
        grid <- .k1_acceptance_grid(protocol, control)
        schema <- protocol$seed_derivation$canonical_cell_schemas[[control]]
        replicate_count <- protocol$seed_plan$replicates_per_grid_cell[
            protocol$seed_plan$control == control
        ][[1L]]
        rows <- vector("list", nrow(grid) * replicate_count)
        index <- 0L
        for (grid_index in seq_len(nrow(grid))) {
            cell <- .k1_acceptance_canonical_cell(
                control,
                grid[grid_index, , drop = FALSE],
                schema
            )
            for (replicate_index in seq_len(replicate_count)) {
                index <- index + 1L
                root <- .k1_acceptance_seed_root(
                    protocol,
                    merge_commit,
                    cell,
                    replicate_index,
                    task_ordinal = task_offsets[[control_index]] + index,
                    total_tasks = total_tasks
                )
                offsets <- protocol$seed_derivation$acceptance_stream_offsets[[control]]
                streams <- stats::setNames(
                    as.integer(root + unname(offsets)),
                    names(offsets)
                )
                row <- data.frame(
                    task_id = substr(digest::digest(
                        paste(cell, replicate_index, sep = "|"),
                        algo = "sha256",
                        serialize = FALSE
                    ), 1L, 20L),
                    control = control,
                    n = if ("n" %in% names(grid)) {
                        as.integer(grid$n[[grid_index]])
                    } else if (identical(
                        control,
                        "shared_baseline_missing_cells"
                    )) {
                        fixed <- protocol$grids$
                            shared_baseline_missing_cells$fixed
                        as.integer(
                            fixed$replicates_per_observed_cell *
                                (1L + fixed$time_points)
                        )
                    } else {
                        NA_integer_
                    },
                    p = if ("p" %in% names(grid)) {
                        as.integer(grid$p[[grid_index]])
                    } else {
                        as.integer(protocol$grids$
                            shared_baseline_missing_cells$fixed$p)
                    },
                    subjects_per_condition = if (
                        "subjects_per_condition" %in% names(grid)
                    ) as.integer(grid$subjects_per_condition[[grid_index]])
                    else NA_integer_,
                    replicate_index = as.integer(replicate_index),
                    seed_root = root,
                    canonical_cell = cell,
                    stringsAsFactors = FALSE
                )
                if (identical(protocol$artifact_version, "2")) {
                    row$design_cell <- if ("design_cell" %in% names(grid)) {
                        as.integer(grid$design_cell[[grid_index]])
                    } else {
                        NA_integer_
                    }
                    row$task_ordinal <- as.integer(
                        task_offsets[[control_index]] + index
                    )
                }
                rows[[index]] <- row
                rows[[index]]$stream_seeds <- list(streams)
            }
        }
        do.call(rbind, rows)
    })
    tasks <- do.call(rbind, task_groups)
    rownames(tasks) <- NULL
    payload <- list(
        artifact_version = protocol$artifact_version,
        protocol_id = protocol$protocol_id,
        protocol_digest = protocol$digest,
        runner_contract = protocol$execution_contracts$version,
        phase_a_merge_commit = merge_commit
    )
    if (!is.null(runner_revision)) {
        payload$runner_revision <- runner_revision
    }
    payload$seed_derivation <- protocol$seed_derivation$algorithm
    payload$tasks <- tasks
    payload
}

#' Reveal the frozen K=1 independent acceptance seed manifest
#'
#' Seed roots become deterministic only after the reviewed protocol
#' merge. This function expands every frozen cell and replicate and rejects any
#' collision with calibration or another acceptance stream.
#'
#' @param phase_a_merge_commit lowercase 40-character SHA-1 of the reviewed
#'   merge that froze `protocol`. The legacy argument name is retained so that
#'   version 1 manifests remain reproducible.
#' @param protocol the unmodified object returned by
#'   [k1_acceptance_protocol()].
#' @param runner_revision optional lowercase 40-character SHA-1 of the reviewed
#'   execution revision. It is retained as provenance but never enters seed
#'   derivation. Omit it to reproduce historical manifests whose runner and
#'   protocol revisions were the same.
#' @return A digest-bound `K1AcceptanceManifest`.
#' @export
k1_acceptance_manifest <- function(
    phase_a_merge_commit,
    protocol = k1_acceptance_protocol(),
    runner_revision = NULL
) {
    validate_k1_acceptance_protocol(protocol)
    merge_commit <- .k1_acceptance_validate_merge_commit(phase_a_merge_commit)
    if (!is.null(runner_revision)) {
        runner_revision <- .k1_acceptance_validate_merge_commit(
            runner_revision
        )
        if (!identical(protocol$artifact_version, "2")) {
            .k1_acceptance_runner_abort(
                "runner_revision is supported only by artifact version 2"
            )
        }
        if (identical(runner_revision, merge_commit)) {
            runner_revision <- NULL
        }
    }
    payload <- .k1_acceptance_manifest_payload(
        protocol,
        merge_commit,
        runner_revision
    )
    streams <- unlist(payload$tasks$stream_seeds, use.names = FALSE)
    reserved <- protocol$separation$reserved_calibration_rng_streams
    if (any(streams %in% reserved)) {
        .k1_acceptance_runner_abort(
            "acceptance seed stream collides with a reserved calibration stream"
        )
    }
    if (anyDuplicated(streams)) {
        .k1_acceptance_runner_abort(
            "acceptance seed streams collide with one another"
        )
    }
    manifest <- c(payload, list(
        digest = digest::digest(payload, algo = "sha256")
    ))
    class(manifest) <- c("K1AcceptanceManifest", "list")
    manifest
}

#' Validate a K=1 independent acceptance seed manifest
#'
#' @param manifest object returned by [k1_acceptance_manifest()].
#' @return Invisibly `TRUE`, or throws `k1_acceptance_runner_error`.
#' @export
validate_k1_acceptance_manifest <- function(manifest) {
    if (!inherits(manifest, "K1AcceptanceManifest")) {
        .k1_acceptance_runner_abort(
            "manifest must inherit from K1AcceptanceManifest"
        )
    }
    version <- switch(
        manifest$protocol_id,
        `k1-stage0-acceptance-v1` = "1",
        `k1-stage0-acceptance-v2` = "2",
        .k1_acceptance_runner_abort(
            "manifest does not identify a readable K=1 protocol"
        )
    )
    expected <- k1_acceptance_manifest(
        manifest$phase_a_merge_commit,
        protocol = k1_acceptance_protocol(version),
        runner_revision = manifest$runner_revision
    )
    if (!identical(manifest, expected)) {
        .k1_acceptance_runner_abort(
            "manifest differs from the frozen post-merge seed derivation"
        )
    }
    invisible(TRUE)
}

#' @export
print.K1AcceptanceManifest <- function(x, ...) {
    validate_k1_acceptance_manifest(x)
    cat("<K1AcceptanceManifest>\n")
    cat("  protocol:", x$protocol_id, "\n")
    cat("  tasks:", nrow(x$tasks), "\n")
    cat("  protocol merge:", x$phase_a_merge_commit, "\n")
    if (!is.null(x$runner_revision)) {
        cat("  runner revision:", x$runner_revision, "\n")
    }
    cat("  digest:", x$digest, "\n")
    invisible(x)
}

.k1_acceptance_generic_config <- function(protocol) {
    analysis <- protocol$execution_contracts$generic_double_well_analysis
    PipelineConfig(
        strategies = list(
            Decomposer = protocol$strategies$decomposer,
            DynamicsEstimator = protocol$strategies$dynamics_estimator
        ),
        params = list(
            svd = protocol$execution_contracts$svd,
            kde_logdensity = protocol$execution_contracts$kde_logdensity
        ),
        dataset = "k1-independent-acceptance-generic-double-well",
        analysis = analysis_specification(
            id = "k1-independent-acceptance-generic-double-well-PC1",
            target_field = analysis$target_field,
            target_type = analysis$target_type,
            continuous_direction = analysis$continuous_direction,
            lifecycle = analysis$lifecycle,
            selected_component = analysis$selected_component,
            proposal_digest = digest::digest(
                list(
                    protocol_digest = protocol$digest,
                    control = "generic_double_well"
                ),
                algo = "sha256"
            ),
            proposal_decision = analysis$proposal_decision,
            analyst_rationale = paste(
                "The frozen known-truth protocol fixes the planted target",
                "axis at component 1 before independent execution."
            ),
            claim_intent = analysis$claim_intent
        )
    )
}

.k1_acceptance_generate_generic <- function(task, protocol) {
    .synthetic_k1_double_well_control(
        n = task$n[[1L]],
        p = task$p[[1L]],
        noise_sd = protocol$grids$generic_double_well$fixed$noise_sd,
        beta = protocol$grids$generic_double_well$fixed$beta,
        seed = task$seed_root[[1L]],
        governance = list(
            calibration_only = FALSE,
            evidence_status = "independent_acceptance",
            claim_status = "independent_acceptance_pending_aggregation",
            protocol_digest = protocol$digest,
            runner_contract = protocol$execution_contracts$version,
            task_id = task$task_id[[1L]],
            control = task$control[[1L]]
        ),
        provenance_implementation = protocol$generators$generic_double_well,
        provenance_input_hashes = c(protocol = protocol$digest)
    )
}

.k1_acceptance_run_generic <- function(task, protocol) {
    std <- .k1_acceptance_generate_generic(task, protocol)
    control <- metadata(std)$k1_double_well_control
    pipeline <- run_pipeline(std, .k1_acceptance_generic_config(protocol))
    if (!is(pipeline, "StageResult") || pipeline@status != "success") {
        reason <- if (is(pipeline, "StageResult")) pipeline@reason else
            "pipeline did not return a StageResult"
        return(list(status = "failure", reason = reason, metrics = list()))
    }
    result <- pipeline@value
    stage1 <- stage_artifact(result, "stage1")
    truth <- std@ground_truth@subspace@shared[, 1L]
    estimate <- shared_axis(stage1)
    cosine <- sum(truth * estimate) /
        (sqrt(sum(truth^2)) * sqrt(sum(estimate^2)))
    cosine <- max(-1, min(1, cosine))
    orientation <- if (cosine < 0) -1 else 1
    metrics <- .potential_recovery_metrics(
        stage2 = stage_artifact(result, "stage2"),
        true_wells = control$true_wells,
        true_barrier = control$true_barrier,
        true_barrier_height = control$true_barrier_height,
        orientation = orientation
    )
    metrics$subspace_angle_deg <- acos(abs(cosine)) * 180 / pi
    list(status = "success", reason = "", metrics = metrics)
}

.k1_aml_generate_governed <- function(
    task,
    protocol,
    calibration_only,
    evidence_status,
    claim_status,
    seed_derivation
) {
    fixed <- protocol$grids$aml_synchronized$fixed
    streams <- task$stream_seeds[[1L]]
    expected_streams <- streams[["generator"]] + 0:3
    if (!identical(
        unname(streams[c("generator", "association", "permutations",
            "identifiability")]),
        unname(expected_streams)
    )) {
        .k1_acceptance_runner_abort(
            "AML acceptance streams do not match the frozen execution offsets"
        )
    }
    std <- synthetic_k1_aml_longitudinal_control(
        subjects_per_condition = task$subjects_per_condition[[1L]],
        times = fixed$times,
        p = task$p[[1L]],
        noise_sd = fixed$noise_sd,
        time_signal = fixed$time_signal,
        disease_signal = fixed$disease_signal,
        dropout_subjects = protocol$execution_contracts$aml$dropout_subjects,
        seed = streams[["generator"]]
    )
    md <- metadata(std)
    md$aml_k1_control$calibration_only <- calibration_only
    md$aml_k1_control$evidence_status <- evidence_status
    md$aml_k1_control$claim_status <- claim_status
    md$aml_k1_control$task_id <- task$task_id[[1L]]
    md$aml_k1_control$protocol_digest <- protocol$digest
    md$aml_k1_control$runner_contract <-
        protocol$execution_contracts$version
    metadata(std) <- md
    std@provenance <- list()
    record_provenance(
        std,
        stage = "generate_control",
        contract = "SyntheticControlGenerator",
        implementation = protocol$generators$aml_synchronized,
        params = md$aml_k1_control,
        rng = list(
            run_seed = as.integer(streams[["generator"]]),
            rng_kind = "L'Ecuyer-CMRG",
            seed_derivation = seed_derivation,
            task_id = task$task_id[[1L]],
            streams = stats::setNames(as.integer(streams), names(streams))
        ),
        input_hashes = c(protocol = protocol$digest)
    )
}

.k1_acceptance_generate_aml <- function(task, protocol) {
    .k1_aml_generate_governed(
        task = task,
        protocol = protocol,
        calibration_only = FALSE,
        evidence_status = "independent_acceptance",
        claim_status = "independent_acceptance_pending_aggregation",
        seed_derivation = protocol$seed_derivation$algorithm
    )
}

.k1_aml_resource_pilot <- function(task, protocol, expected_identity) {
    validate_k1_acceptance_protocol(protocol)
    .k1_acceptance_check_identity(expected_identity)
    source <- .k1_aml_generate_governed(
        task = task,
        protocol = protocol,
        calibration_only = TRUE,
        evidence_status = "non_evidentiary_resource_pilot",
        claim_status = "non_evidentiary_resource_pilot",
        seed_derivation = "disclosed-development-seed-v1"
    )
    .aml_k1_assess_control(
        std = source,
        config = .aml_k1_calibration_config(),
        n_resamples = protocol$resampling$aml_identifiability_resamples,
        n_permutations = protocol$resampling$aml_permutations,
        seed = task$stream_seeds[[1L]][["generator"]],
        evidence_status = "non_evidentiary_resource_pilot",
        claim_status = "non_evidentiary_resource_pilot",
        sequential_internal = TRUE
    )
}

.k1_acceptance_aml_provenance <- function(calibration) {
    evidence <- calibration$identifiability_evidence
    proposal <- calibration$proposal
    proposal_payload <- if (is(proposal, "ComponentProposal")) {
        list(
            type = "proposal",
            digest = proposal_digest(proposal),
            provenance = proposal_provenance(proposal),
            evidence_status = proposal@evidence_status,
            permutation_evidence = proposal_permutation_evidence(proposal)
        )
    } else if (is(proposal, "ComponentAbstention")) {
        list(
            type = "abstention",
            digest = abstention_digest(proposal),
            provenance = abstention_provenance(proposal),
            evidence_status = proposal@evidence_status,
            reason = proposal@reason,
            permutation_evidence = abstention_permutation_evidence(proposal)
        )
    } else {
        .k1_acceptance_runner_abort(
            "AML acceptance returned unsupported proposal evidence"
        )
    }
    list(
        version = "1.0.0",
        evidence_status = calibration$evidence_status,
        generator_and_decomposition = calibration$provenance,
        atlas = atlas_provenance(calibration$atlas),
        proposal = proposal_payload,
        identifiability = list(
            status = if (is.null(evidence)) "not_assessed" else "assessed",
            evidence = evidence
        ),
        stage2 = list(
            class = class(calibration$stage2),
            status = calibration$stage2@status,
            reason = calibration$stage2@reason
        )
    )
}

.k1_acceptance_run_aml <- function(task, protocol) {
    streams <- task$stream_seeds[[1L]]
    source <- .k1_acceptance_generate_aml(task, protocol)
    calibration <- suppressWarnings(.aml_k1_assess_control(
        std = source,
        config = .aml_k1_calibration_config(),
        n_resamples = protocol$resampling$aml_identifiability_resamples,
        n_permutations = protocol$resampling$aml_permutations,
        seed = streams[["generator"]],
        evidence_status = "independent_acceptance",
        claim_status = "independent_acceptance_pending_aggregation",
        sequential_internal = TRUE
    ))
    if (!identical(calibration$status, "success")) {
        return(list(
            status = "failure",
            reason = calibration$reason,
            metrics = list()
        ))
    }
    target <- calibration$target_component
    nuisance <- calibration$nuisance_component
    ranking <- calibration$proposal@ranking
    rank_for <- function(component) {
        row <- ranking[ranking$component == component, , drop = FALSE]
        if (nrow(row) != 1L || !is.finite(row$proposal_rank[[1L]])) {
            return(NA_integer_)
        }
        as.integer(row$proposal_rank[[1L]])
    }
    evidence <- calibration$identifiability_evidence
    recurrence <- if (is.null(evidence)) NULL else evidence$target_recurrence
    recurrence_value <- function(field) {
        if (is.null(recurrence) || !field %in% names(recurrence) ||
                nrow(recurrence) != 1L) {
            return(NA_real_)
        }
        as.numeric(recurrence[[field]][[1L]])
    }
    subspace_angles <- if (is.null(evidence)) {
        numeric()
    } else {
        rows <- evidence$subspace_angle_summary$dimension == target
        evidence$subspace_angle_summary$maximum_angle_degrees[rows]
    }
    subspace_angles <- subspace_angles[is.finite(subspace_angles)]
    bootstrap_subspace <- function(summary) {
        if (!length(subspace_angles)) return(NA_real_)
        as.numeric(summary(subspace_angles))
    }
    associations <- calibration$atlas@associations
    association_value <- function(component, variant, field) {
        row <- associations[
            associations$metadata_field ==
                protocol$execution_contracts$aml$target_field &
                associations$component == component &
                associations$evidence_variant == variant,
            ,
            drop = FALSE
        ]
        if (nrow(row) != 1L) {
            .k1_acceptance_runner_abort(
                "AML atlas does not contain the frozen association evidence"
            )
        }
        row[[field]][[1L]]
    }
    unadjusted <- "repeated-time-course-unadjusted"
    adjusted <- "repeated-time-course-adjusted"
    recovery_index <- match(target, calibration$recovery$component)
    if (length(recovery_index) != 1L || is.na(recovery_index)) {
        .k1_acceptance_runner_abort(
            "AML recovery does not contain the frozen target component"
        )
    }
    stage2_ineligible <- is(calibration$stage2, "StageResult") &&
        identical(calibration$stage2@status, "failure") &&
        grepl(
            "sampling design 'longitudinal' is not supported",
            calibration$stage2@reason,
            fixed = TRUE
        )
    acceptance_provenance <- .k1_acceptance_aml_provenance(calibration)
    metrics <- list(
        target_loading_cosine = calibration$recovery$
            absolute_loading_cosine[[recovery_index]],
        target_subspace_angle_deg = max(
            calibration$recovery$subspace_principal_angle_degrees
        ),
        mean_bootstrap_subspace_angle_deg = bootstrap_subspace(mean),
        q95_bootstrap_subspace_angle_deg = bootstrap_subspace(
            function(value) stats::quantile(value, 0.95, names = FALSE)
        ),
        target_component = as.integer(target),
        nuisance_component = as.integer(nuisance),
        target_proposal_rank = rank_for(target),
        nuisance_proposal_rank = rank_for(nuisance),
        target_unadjusted_estimate = association_value(
            target, unadjusted, "estimate"
        ),
        target_adjusted_estimate = association_value(
            target, adjusted, "estimate"
        ),
        nuisance_unadjusted_estimate = association_value(
            nuisance, unadjusted, "estimate"
        ),
        nuisance_adjusted_estimate = association_value(
            nuisance, adjusted, "estimate"
        ),
        target_unadjusted_status = association_value(
            target, unadjusted, "evidence_status"
        ),
        target_adjusted_status = association_value(
            target, adjusted, "evidence_status"
        ),
        nuisance_unadjusted_status = association_value(
            nuisance, unadjusted, "evidence_status"
        ),
        nuisance_adjusted_status = association_value(
            nuisance, adjusted, "evidence_status"
        ),
        target_index_recurrence = recurrence_value("index_recurrence"),
        mean_matched_loading_cosine = recurrence_value(
            "mean_absolute_similarity"
        ),
        identifiability_completion_rate = if (is.null(evidence)) 0 else
            evidence$n_completed / evidence$n_requested,
        stage2_ineligible = stage2_ineligible,
        orientation_recurrence = recurrence_value("orientation_recurrence"),
        rank_one_fraction = recurrence_value("rank_one_fraction"),
        matched_fraction = recurrence_value("matched_fraction"),
        acceptance_evidence_status = calibration$evidence_status,
        acceptance_provenance = acceptance_provenance,
        acceptance_provenance_digest = digest::digest(
            acceptance_provenance,
            algo = "sha256"
        )
    )
    list(status = "success", reason = "", metrics = metrics)
}

.k1_acceptance_negative_control <- function(task, protocol) {
    control <- task$control[[1L]]
    n <- task$n[[1L]]
    p <- task$p[[1L]]
    streams <- task$stream_seeds[[1L]]
    setup_rng(streams[["generator"]])
    if (identical(control, "pure_noise")) {
        expression <- matrix(stats::rnorm(p * n), nrow = p, ncol = n)
    } else if (identical(control, "single_well")) {
        coordinate <- stats::rnorm(n)
        loading <- .unit_rnorm(p)
        noise_sd <- .k1_acceptance_single_well_noise_sd(protocol)
        expression <- t(outer(coordinate, loading)) +
            matrix(stats::rnorm(p * n, sd = noise_sd), nrow = p, ncol = n)
    } else {
        .k1_acceptance_runner_abort("negative control family is unsupported")
    }
    sample_ids <- paste0("s", seq_len(n))
    feature_ids <- paste0("g", seq_len(p))
    rownames(expression) <- feature_ids
    colnames(expression) <- sample_ids
    setup_rng(streams[["metadata"]])
    target <- sample(rep(
        c("reference", "comparison"),
        each = n %/% 2L
    ))
    target <- factor(target, levels = c("reference", "comparison"))
    experiment <- SummarizedExperiment::SummarizedExperiment(
        assays = list(expression = expression)
    )
    std <- StateTransitionData(
        experiments = list(layer1 = experiment),
        colData = S4Vectors::DataFrame(
            target = target,
            row.names = sample_ids
        ),
        sampling_design = cross_sectional()
    )
    md <- metadata(std)
    md$dataset_id <- paste0("k1-independent-acceptance-", control)
    md$k1_negative_control <- list(
        control = control,
        generator = protocol$generators[[control]]$id,
        n = n,
        p = p,
        task_id = task$task_id[[1L]],
        protocol_digest = protocol$digest,
        runner_contract = protocol$execution_contracts$version,
        evidence_status = "independent_acceptance"
    )
    metadata(std) <- md
    record_provenance(
        std,
        stage = "generate_control",
        contract = "SyntheticControlGenerator",
        implementation = protocol$generators[[control]]$id,
        params = md$k1_negative_control,
        rng = .generator_rng_identity(
            task$seed_root[[1L]],
            paste0("k1-acceptance-", task$task_id[[1L]]),
            streams
        ),
        input_hashes = c(protocol = protocol$digest)
    )
}

.k1_acceptance_single_well_noise_sd <- function(protocol) {
    # Protocol v1 froze this value in the generator definition rather than a
    # structured field. Decode that immutable contract instead of introducing
    # an unbound runner default.
    definition <- protocol$generators$single_well$embedding
    match <- regexec("N\\(0,([0-9.]+)\\^2\\)", definition, perl = TRUE)
    value <- regmatches(definition, match)[[1L]]
    if (length(value) != 2L || !is.finite(as.numeric(value[[2L]]))) {
        .k1_acceptance_runner_abort(
            "frozen single-well generator has no parseable noise scale"
        )
    }
    as.numeric(value[[2L]])
}

.k1_acceptance_negative_analysis <- function(protocol, task, confirmed) {
    analysis <- protocol$execution_contracts$negative_control_analysis
    arguments <- list(
        id = paste0("k1-acceptance-", task$task_id[[1L]]),
        target_field = analysis$target_field,
        target_type = analysis$target_type,
        reference_level = analysis$reference_level,
        comparison_level = analysis$comparison_level,
        nuisance_fields = analysis$nuisance_fields,
        claim_intent = analysis$claim_intent
    )
    if (isTRUE(confirmed)) {
        arguments <- c(arguments, list(
            lifecycle = "confirmed",
            selected_component = 1L,
            proposal_digest = digest::digest(
                list(
                    protocol_digest = protocol$digest,
                    task_id = task$task_id[[1L]],
                    topology_component = 1L
                ),
                algo = "sha256"
            ),
            proposal_decision = "accepted",
            analyst_rationale = paste(
                "The frozen negative-control topology diagnostic evaluates",
                "component 1 independently of metadata association."
            )
        ))
    }
    do.call(analysis_specification, arguments)
}

.k1_acceptance_negative_config <- function(
    protocol,
    task,
    include_dynamics = FALSE
) {
    strategies <- list(Decomposer = protocol$strategies$decomposer)
    params <- list(svd = protocol$execution_contracts$svd)
    if (isTRUE(include_dynamics)) {
        strategies$DynamicsEstimator <- protocol$strategies$dynamics_estimator
        params$kde_logdensity <- protocol$execution_contracts$kde_logdensity
    }
    PipelineConfig(
        strategies = strategies,
        params = params,
        dataset = paste0("k1-independent-acceptance-", task$control[[1L]]),
        analysis = .k1_acceptance_negative_analysis(
            protocol,
            task,
            confirmed = include_dynamics
        )
    )
}

.k1_acceptance_false_double_well <- function(stage2) {
    wells <- sort(stage2$wells)
    barriers <- stage2$barriers
    length(wells) >= 2L && length(barriers) >= 1L && any(
        barriers > min(wells) & barriers < max(wells)
    )
}

.k1_acceptance_negative_selection_thresholds <- function(protocol) {
    # Protocol v1 froze these gates in its definition prose. This compatibility
    # decoder keeps execution bound to that reviewed digest without inventing
    # separate runner constants.
    definition <- protocol$thresholds$negative_controls$
        false_target_selection_definition
    extract <- function(pattern, label) {
        match <- regexec(pattern, definition, perl = TRUE)
        value <- regmatches(definition, match)[[1L]]
        if (length(value) != 2L || !is.finite(as.numeric(value[[2L]]))) {
            .k1_acceptance_runner_abort(paste(
                "frozen negative-control definition has no parseable", label
            ))
        }
        as.numeric(value[[2L]])
    }
    list(
        maximum_search_aware_p = extract(
            "permutation p <= ([0-9.]+)",
            "search-aware p-value threshold"
        ),
        minimum_axis_recurrence = extract(
            "recurrence >= ([0-9.]+)",
            "axis-recurrence threshold"
        )
    )
}

.k1_acceptance_run_negative <- function(
    task,
    protocol,
    sequential_internal
) {
    source <- .k1_acceptance_negative_control(task, protocol)
    topology <- run_pipeline(
        source,
        .k1_acceptance_negative_config(
            protocol,
            task,
            include_dynamics = TRUE
        )
    )
    if (!is(topology, "StageResult") || topology@status != "success") {
        reason <- if (is(topology, "StageResult")) topology@reason else
            "negative topology pipeline did not return a StageResult"
        return(list(status = "failure", reason = reason, metrics = list()))
    }
    stage2 <- stage_artifact(topology@value, "stage2")
    config <- .k1_acceptance_negative_config(protocol, task)
    discovery <- run_pipeline(source, config)
    if (!is(discovery, "StageResult") || discovery@status != "success") {
        reason <- if (is(discovery, "StageResult")) discovery@reason else
            "negative discovery pipeline did not return a StageResult"
        return(list(status = "failure", reason = reason, metrics = list()))
    }
    atlas <- associate_metadata(
        discovery@value,
        specification = config@analysis,
        non_analytical_fields = character(),
        dataset_id = config@dataset,
        n_resamples = 0L,
        seed = task$stream_seeds[[1L]][["metadata"]],
        exchangeability = "independent",
        sequential_internal = sequential_internal
    )
    if (!is(atlas, "MetadataAssociationAtlas")) {
        return(list(
            status = "failure",
            reason = "negative target association returned an abstention",
            metrics = list()
        ))
    }
    proposal <- propose_component(
        atlas,
        n_permutations = protocol$resampling$negative_permutations,
        seed = task$stream_seeds[[1L]][["permutations"]],
        sequential_internal = sequential_internal
    )
    if (!is(proposal, "ComponentProposal")) {
        reason <- if (is(proposal, "ComponentAbstention")) {
            paste0("negative target proposal abstained: ", proposal@reason)
        } else {
            "negative target proposal returned an unsupported result"
        }
        return(list(status = "failure", reason = reason, metrics = list()))
    }
    false_target <- FALSE
    p_value <- NA_real_
    recurrence <- NA_real_
    completion <- NA_real_
    mean_similarity <- NA_real_
    nominated_component <- NA_integer_
    assessed <- assess_component_identifiability(
        data = source,
        proposal = proposal,
        config = config,
        non_analytical_fields = character(),
        n_resamples = protocol$resampling$negative_identifiability_resamples,
        seed = task$stream_seeds[[1L]][["identifiability"]],
        sequential_internal = sequential_internal
    )
    permutation <- proposal_permutation_evidence(assessed)
    identifiability <- proposal_identifiability(assessed)
    target_recurrence <- identifiability$target_recurrence
    p_value <- permutation@search_aware_p_value
    recurrence <- target_recurrence$index_recurrence[[1L]]
    mean_similarity <- target_recurrence$mean_absolute_similarity[[1L]]
    completion <- identifiability$n_completed / identifiability$n_requested
    nominated_component <- assessed@recommended_component
    thresholds <- .k1_acceptance_negative_selection_thresholds(protocol)
    false_target <- is.finite(p_value) &&
        p_value <= thresholds$maximum_search_aware_p &&
        is.finite(recurrence) &&
        recurrence >= thresholds$minimum_axis_recurrence
    metrics <- list(
        n_wells_found = length(stage2$wells),
        n_barriers_found = length(stage2$barriers),
        false_double_well = .k1_acceptance_false_double_well(stage2),
        false_target_selection = false_target,
        search_aware_p_value = p_value,
        target_index_recurrence = recurrence,
        mean_matched_loading_cosine = mean_similarity,
        identifiability_completion_rate = completion,
        nominated_component = nominated_component
    )
    list(status = "success", reason = "", metrics = metrics)
}

.k1_acceptance_shared_baseline_source <- function(task, protocol) {
    fixed <- protocol$grids$shared_baseline_missing_cells$fixed
    streams <- task$stream_seeds[[1L]]
    if (!identical(
        as.integer(task$seed_root[[1L]]),
        as.integer(streams[["generation"]])
    )) {
        .k1_acceptance_runner_abort(
            "shared-baseline seed root must equal its generation stream"
        )
    }
    replicates <- fixed$replicates_per_observed_cell
    times <- seq.int(0L, fixed$time_points - 1L)
    condition <- c(
        rep("control", replicates),
        rep("treated", replicates * fixed$time_points)
    )
    observed_time <- c(
        rep(times[[1L]], replicates),
        rep(times, each = replicates)
    )
    sample_ids <- sprintf("sample_%02d", seq_along(condition))
    setup_rng(streams[["generation"]])
    expression <- matrix(
        stats::rnorm(fixed$p * length(condition)),
        nrow = fixed$p,
        dimnames = list(paste0("g", seq_len(fixed$p)), sample_ids)
    )
    std <- StateTransitionData(
        experiments = list(
            layer1 = SummarizedExperiment::SummarizedExperiment(
                assays = list(expression = expression)
            )
        ),
        colData = S4Vectors::DataFrame(
            condition = factor(condition, levels = c("control", "treated")),
            observed_time = observed_time,
            row.names = sample_ids
        ),
        sampling_design = independent_time_course(
            time = "observed_time",
            time_unit = "arbitrary time units"
        )
    )
    md <- metadata(std)
    md$dataset_id <- paste0(
        "k1-independent-acceptance-", task$control[[1L]]
    )
    md$k1_shared_baseline_control <- list(
        generator = protocol$generators$shared_baseline_missing_cells$id,
        task_id = task$task_id[[1L]],
        protocol_digest = protocol$digest,
        runner_contract = protocol$execution_contracts$version,
        independent_biological_observations = length(condition),
        unique_baseline_controls = replicates,
        duplicated_controls = FALSE,
        expected_outcome = "non-identifiable-design"
    )
    md$scientific_labels <- list(
        experiment = "K=1 shared-baseline safety control",
        layers = c(layer1 = "simulated molecular features")
    )
    metadata(std) <- md
    record_provenance(
        std,
        stage = "generate_control",
        contract = "SyntheticControlGenerator",
        implementation = protocol$generators$
            shared_baseline_missing_cells$id,
        params = md$k1_shared_baseline_control,
        rng = .generator_rng_identity(
            streams[["generation"]],
            paste0("k1-acceptance-", task$task_id[[1L]]),
            streams
        ),
        input_hashes = c(protocol = protocol$digest)
    )
}

.k1_label_baseline_atlas <- function(atlas, source) {
    labels <- metadata(source)$scientific_labels
    layer_id <- atlas@provenance$layer
    atlas@provenance$dataset_label <- labels$experiment
    atlas@provenance$layer_label <- unname(labels$layers[[layer_id]])
    atlas
}

.k1_acceptance_run_shared_baseline <- function(task, protocol) {
    source <- .k1_acceptance_shared_baseline_source(task, protocol)
    analysis <- protocol$execution_contracts$
        shared_baseline_missing_cells_analysis
    specification <- analysis_specification(
        id = paste0("k1-acceptance-", task$task_id[[1L]]),
        target_field = analysis$target_field,
        target_type = analysis$target_type,
        reference_level = analysis$reference_level,
        comparison_level = analysis$comparison_level,
        claim_intent = analysis$claim_intent
    )
    config <- PipelineConfig(
        strategies = list(Decomposer = protocol$strategies$decomposer),
        params = list(svd = protocol$execution_contracts$svd),
        dataset = metadata(source)$dataset_id,
        analysis = specification
    )
    discovery <- run_pipeline(source, config)
    if (!is(discovery, "StageResult") || discovery@status != "success") {
        reason <- if (is(discovery, "StageResult")) discovery@reason else
            "shared-baseline discovery did not return a StageResult"
        return(list(status = "failure", reason = reason, metrics = list()))
    }
    atlas <- associate_metadata(
        discovery@value,
        specification = specification,
        dataset_id = config@dataset,
        n_resamples = 0L,
        seed = task$stream_seeds[[1L]][["association"]],
        sequential_internal = TRUE
    )
    if (!is(atlas, "MetadataAssociationAtlas")) {
        return(list(
            status = "failure",
            reason = "shared-baseline association did not retain an atlas",
            metrics = list()
        ))
    }
    atlas <- .k1_label_baseline_atlas(atlas, source)
    proposal <- propose_component(atlas)
    if (!is(proposal, "ComponentAbstention")) {
        return(list(
            status = "failure",
            reason = paste(
                "shared-baseline design did not produce the required typed",
                "abstention"
            ),
            metrics = list()
        ))
    }
    provenance <- atlas_provenance(atlas)
    condition <- as.character(colData(source)$condition)
    metrics <- list(
        abstention_reason = proposal@reason,
        missing_control_time_cells = as.integer(
            provenance$time_course_missing_cell_count
        ),
        unique_control_observations = as.integer(sum(condition == "control")),
        total_observations = as.integer(length(condition))
    )
    list(status = "success", reason = "", metrics = metrics)
}

.k1_acceptance_payload_identity <- function() {
    expected <- Sys.getenv("LANDSCAPER_PAYLOAD_SHA256", unset = "")
    verifier <- Sys.getenv("LANDSCAPER_PAYLOAD_VERIFIER", unset = "")
    verifier_digest <- Sys.getenv(
        "LANDSCAPER_PAYLOAD_VERIFIER_SHA256", unset = ""
    )
    if (!nzchar(expected) && !nzchar(verifier) && !nzchar(verifier_digest)) {
        return(NULL)
    }
    if (!grepl("^[0-9a-f]{64}$", expected) ||
            !grepl("^[0-9a-f]{64}$", verifier_digest) ||
            !nzchar(verifier) ||
            !file.exists(verifier) || file.access(verifier, 1L) != 0L) {
        .k1_acceptance_runner_abort(
            "external landscapeR payload identity configuration is invalid"
        )
    }
    observed_verifier_digest <- tryCatch(
        digest::digest(verifier, algo = "sha256", file = TRUE),
        error = function(condition) {
            .k1_acceptance_runner_abort(
                "external landscapeR payload verifier cannot be hashed"
            )
        }
    )
    if (!identical(observed_verifier_digest, verifier_digest)) {
        .k1_acceptance_runner_abort(
            "external landscapeR payload verifier differs from the reviewed identity"
        )
    }
    package_root <- system.file(package = "landscapeR")
    if (!nzchar(package_root)) {
        .k1_acceptance_runner_abort(
            "loaded landscapeR package has no payload root"
        )
    }
    observed <- system2(
        "bash", c(verifier, package_root), stdout = TRUE, stderr = TRUE
    )
    status <- attr(observed, "status")
    if (!is.null(status) && !identical(as.integer(status), 0L)) {
        .k1_acceptance_runner_abort(
            "external landscapeR payload verifier failed"
        )
    }
    observed <- trimws(tail(observed, 1L))
    if (length(observed) != 1L || !identical(observed, expected)) {
        .k1_acceptance_runner_abort(
            "installed landscapeR payload differs from the reviewed identity"
        )
    }
    observed
}

.k1_acceptance_worker_identity <- function() {
    cache_key <- paste(
        Sys.getenv("LANDSCAPER_PAYLOAD_SHA256", unset = ""),
        Sys.getenv("LANDSCAPER_PAYLOAD_VERIFIER", unset = ""),
        Sys.getenv("LANDSCAPER_PAYLOAD_VERIFIER_SHA256", unset = ""),
        system.file(package = "landscapeR"),
        sep = "\r"
    )
    if (exists(cache_key, envir = .k1_acceptance_worker_identity_cache,
            inherits = FALSE)) {
        return(get(cache_key, envir = .k1_acceptance_worker_identity_cache,
            inherits = FALSE))
    }
    packages <- c(
        "landscapeR", "digest", "future", "future.apply", "targets", "crew",
        "ggplot2", "lme4", "clue"
    )
    versions <- vapply(packages, function(package) {
        if (!requireNamespace(package, quietly = TRUE)) return(NA_character_)
        as.character(utils::packageVersion(package))
    }, character(1L))
    identity <- list(
        source_revision = landscapeR_revision(),
        r_version = paste(R.version$major, R.version$minor, sep = "."),
        package_versions = versions
    )
    payload <- .k1_acceptance_payload_identity()
    if (!is.null(payload)) identity$payload_sha256 <- payload
    assign(cache_key, identity, envir = .k1_acceptance_worker_identity_cache)
    identity
}

.k1_acceptance_check_identity <- function(expected) {
    if (is.null(expected)) return(invisible(TRUE))
    observed <- .k1_acceptance_worker_identity()
    if (!identical(observed, expected)) {
        .k1_acceptance_runner_abort(
            "acceptance worker runtime differs from the controlling runtime"
        )
    }
    invisible(TRUE)
}

.k1_acceptance_failure <- function(task, protocol, reason) {
    structure(
        list(
            artifact_version = protocol$artifact_version,
            task_id = task$task_id[[1L]],
            control = task$control[[1L]],
            canonical_cell = task$canonical_cell[[1L]],
            replicate_index = task$replicate_index[[1L]],
            status = "failure",
            reason = reason,
            metrics = list(),
            protocol_digest = protocol$digest,
            runner_contract = protocol$execution_contracts$version
        ),
        class = c("K1AcceptanceReplicate", "list")
    )
}

.k1_acceptance_run_task <- function(
    task,
    protocol,
    expected_identity,
    sequential_internal = TRUE
) {
    validate_k1_acceptance_protocol(protocol)
    .k1_acceptance_check_identity(expected_identity)
    if (!is.data.frame(task) || nrow(task) != 1L) {
        .k1_acceptance_runner_abort("acceptance task must be one manifest row")
    }
    if (!isTRUE(sequential_internal)) {
        .k1_acceptance_runner_abort(
            "outer acceptance branches require sequential internal execution"
        )
    }
    control <- task$control[[1L]]
    observed <- tryCatch(
        if (identical(control, "generic_double_well")) {
            .k1_acceptance_run_generic(task, protocol)
        } else if (identical(control, "aml_synchronized")) {
            .k1_acceptance_run_aml(task, protocol)
        } else if (control %in% c("pure_noise", "single_well")) {
            .k1_acceptance_run_negative(
                task,
                protocol,
                sequential_internal = sequential_internal
            )
        } else if (identical(control, "shared_baseline_missing_cells")) {
            .k1_acceptance_run_shared_baseline(task, protocol)
        } else {
            list(
                status = "failure",
                reason = sprintf("control '%s' is not implemented", control),
                metrics = list()
            )
        },
        error = function(error) list(
            status = "failure",
            reason = conditionMessage(error),
            metrics = list()
        )
    )
    if (!identical(observed$status, "success")) {
        return(.k1_acceptance_failure(task, protocol, observed$reason))
    }
    structure(
        list(
            artifact_version = protocol$artifact_version,
            task_id = task$task_id[[1L]],
            control = control,
            canonical_cell = task$canonical_cell[[1L]],
            replicate_index = task$replicate_index[[1L]],
            status = "success",
            reason = "",
            metrics = observed$metrics,
            protocol_digest = protocol$digest,
            runner_contract = protocol$execution_contracts$version
        ),
        class = c("K1AcceptanceReplicate", "list")
    )
}

.k1_acceptance_task_rows <- function(tasks) {
    lapply(seq_len(nrow(tasks)), function(index) tasks[index, , drop = FALSE])
}

.k1_acceptance_validate_result <- function(result, task, protocol) {
    required <- c(
        "artifact_version", "task_id", "control", "canonical_cell",
        "replicate_index", "status", "reason", "metrics",
        "protocol_digest", "runner_contract"
    )
    if (!inherits(result, "K1AcceptanceReplicate") ||
            !identical(names(result), required) ||
            !identical(result$artifact_version, protocol$artifact_version) ||
            !identical(result$task_id, task$task_id[[1L]]) ||
            !identical(result$control, task$control[[1L]]) ||
            !identical(result$canonical_cell, task$canonical_cell[[1L]]) ||
            !identical(result$replicate_index, task$replicate_index[[1L]]) ||
            !result$status %in% c("success", "failure") ||
            !is.character(result$reason) || length(result$reason) != 1L ||
            is.na(result$reason) ||
            !is.list(result$metrics) ||
            !identical(result$protocol_digest, protocol$digest) ||
            !identical(
                result$runner_contract,
                protocol$execution_contracts$version
            )) {
        .k1_acceptance_runner_abort(
            "acceptance result does not match its manifest task and protocol"
        )
    }
    if (identical(result$status, "success") && nzchar(result$reason)) {
        .k1_acceptance_runner_abort("successful acceptance result has a reason")
    }
    if (identical(result$status, "failure") &&
            (!nzchar(result$reason) || length(result$metrics))) {
        .k1_acceptance_runner_abort(
            "failed acceptance result must retain one reason and no metrics"
        )
    }
    if (identical(result$status, "success")) {
        .k1_acceptance_validate_metrics(result$metrics, result$control)
    }
    invisible(TRUE)
}

.k1_acceptance_validate_metrics <- function(metrics, control) {
    counts_are_valid <- function(values) {
        is.numeric(values) && length(values) == 2L && !anyNA(values) &&
            all(is.finite(values)) && all(values >= 0) &&
            identical(as.numeric(as.integer(values)), as.numeric(values))
    }
    if (identical(control, "generic_double_well")) {
        expected <- c(
            "well_error", "barrier_error", "barrier_height_error",
            "n_wells_found", "n_barriers_found", "subspace_angle_deg"
        )
        nonnegative_or_missing <- function(value, estimable) {
            is.numeric(value) && length(value) == 1L &&
                if (estimable) {
                    is.finite(value) && value >= 0
                } else {
                    is.na(value)
                }
        }
        if (!identical(names(metrics), expected) ||
                !counts_are_valid(unlist(metrics[expected[4:5]])) ||
                !nonnegative_or_missing(
                    metrics$well_error,
                    metrics$n_wells_found >= 2L
                ) ||
                !nonnegative_or_missing(
                    metrics$barrier_error,
                    metrics$n_barriers_found >= 1L
                ) ||
                !nonnegative_or_missing(
                    metrics$barrier_height_error,
                    metrics$n_barriers_found >= 1L
                ) ||
                !is.numeric(metrics$subspace_angle_deg) ||
                length(metrics$subspace_angle_deg) != 1L ||
                !is.finite(metrics$subspace_angle_deg) ||
                metrics$subspace_angle_deg < 0 ||
                metrics$subspace_angle_deg > 90) {
            .k1_acceptance_runner_abort(
                "generic acceptance metrics violate the frozen contract"
            )
        }
        return(invisible(TRUE))
    }
    if (control %in% c("pure_noise", "single_well")) {
        expected <- c(
            "n_wells_found", "n_barriers_found", "false_double_well",
            "false_target_selection", "search_aware_p_value",
            "target_index_recurrence", "mean_matched_loading_cosine",
            "identifiability_completion_rate", "nominated_component"
        )
        bounded_or_na <- function(value) {
            is.numeric(value) && length(value) == 1L &&
                (is.na(value) || (is.finite(value) && value >= 0 && value <= 1))
        }
        nominated <- metrics$nominated_component
        if (!identical(names(metrics), expected) ||
                !counts_are_valid(unlist(metrics[expected[1:2]])) ||
                any(!vapply(metrics[expected[3:4]], function(value) {
                    is.logical(value) && length(value) == 1L && !is.na(value)
                }, logical(1L))) ||
                any(!vapply(metrics[expected[5:8]], bounded_or_na, logical(1L))) ||
                !is.numeric(nominated) || length(nominated) != 1L ||
                !(is.na(nominated) ||
                    (is.finite(nominated) && nominated >= 1 &&
                        nominated == as.integer(nominated)))) {
            .k1_acceptance_runner_abort(
                "negative-control metrics violate the frozen contract"
            )
        }
        return(invisible(TRUE))
    }
    if (identical(control, "shared_baseline_missing_cells")) {
        expected <- c(
            "abstention_reason", "missing_control_time_cells",
            "unique_control_observations", "total_observations"
        )
        counts <- unlist(metrics[expected[2:4]], use.names = FALSE)
        if (!identical(names(metrics), expected) ||
                !.is_scalar_nonempty_text(metrics$abstention_reason) ||
                !is.numeric(counts) || anyNA(counts) ||
                any(!is.finite(counts)) || any(counts < 0) ||
                !identical(
                    as.numeric(as.integer(counts)),
                    as.numeric(counts)
                )) {
            .k1_acceptance_runner_abort(
                "shared-baseline metrics violate the frozen contract"
            )
        }
        return(invisible(TRUE))
    }
    if (identical(control, "aml_synchronized")) {
        expected <- c(
            "target_loading_cosine", "target_subspace_angle_deg",
            "mean_bootstrap_subspace_angle_deg",
            "q95_bootstrap_subspace_angle_deg",
            "target_component", "nuisance_component",
            "target_proposal_rank", "nuisance_proposal_rank",
            "target_unadjusted_estimate", "target_adjusted_estimate",
            "nuisance_unadjusted_estimate", "nuisance_adjusted_estimate",
            "target_unadjusted_status", "target_adjusted_status",
            "nuisance_unadjusted_status", "nuisance_adjusted_status",
            "target_index_recurrence", "mean_matched_loading_cosine",
            "identifiability_completion_rate", "stage2_ineligible",
            "orientation_recurrence", "rank_one_fraction", "matched_fraction",
            "acceptance_evidence_status", "acceptance_provenance",
            "acceptance_provenance_digest"
        )
        bounded_or_missing <- function(value) {
            is.numeric(value) && length(value) == 1L &&
                (is.na(value) || (is.finite(value) && value >= 0 && value <= 1))
        }
        rank_or_missing <- function(value) {
            is.numeric(value) && length(value) == 1L &&
                (is.na(value) || (is.finite(value) && value >= 1L &&
                    value == as.integer(value)))
        }
        angle_or_missing <- function(value) {
            is.numeric(value) && length(value) == 1L &&
                (is.na(value) ||
                    (is.finite(value) && value >= 0 && value <= 90))
        }
        estimate_is_valid <- function(value, component, variant) {
            if (!is.numeric(value) || length(value) != 1L) return(FALSE)
            provenance <- metrics$acceptance_provenance
            if (!is.list(provenance) || !is.list(provenance$atlas)) {
                return(FALSE)
            }
            models <- provenance$atlas$time_course_models
            if (!is.list(models)) return(FALSE)
            rows <- vapply(models, function(model) {
                is.list(model) && identical(model$component, component)
            }, logical(1L))
            if (sum(rows) != 1L) return(FALSE)
            model <- models[[which(rows)]][[variant]]
            if (!is.list(model) ||
                    !.is_scalar_nonempty_text(model$status)) return(FALSE)
            if (is.finite(value)) {
                return(identical(model$status, "estimable"))
            }
            identical(value, NA_real_) &&
                model$status %in% c(
                    "not-estimable", "non-convergent", "singular"
                ) &&
                .is_scalar_nonempty_text(model$diagnostic)
        }
        scalar_text <- function(value) {
            is.character(value) && length(value) == 1L && !is.na(value) &&
                nzchar(value)
        }
        if (!identical(names(metrics), expected) ||
                any(!vapply(metrics[c(
                    "target_loading_cosine", "target_index_recurrence",
                    "mean_matched_loading_cosine",
                    "identifiability_completion_rate",
                    "orientation_recurrence", "rank_one_fraction",
                    "matched_fraction"
                )], bounded_or_missing, logical(1L))) ||
                !is.numeric(metrics$target_subspace_angle_deg) ||
                length(metrics$target_subspace_angle_deg) != 1L ||
                !is.finite(metrics$target_subspace_angle_deg) ||
                metrics$target_subspace_angle_deg < 0 ||
                metrics$target_subspace_angle_deg > 90 ||
                any(!vapply(metrics[c(
                    "mean_bootstrap_subspace_angle_deg",
                    "q95_bootstrap_subspace_angle_deg"
                )], angle_or_missing, logical(1L))) ||
                !estimate_is_valid(
                    metrics$target_unadjusted_estimate,
                    metrics$target_component,
                    "unadjusted"
                ) ||
                !estimate_is_valid(
                    metrics$target_adjusted_estimate,
                    metrics$target_component,
                    "adjusted"
                ) ||
                !estimate_is_valid(
                    metrics$nuisance_unadjusted_estimate,
                    metrics$nuisance_component,
                    "unadjusted"
                ) ||
                !estimate_is_valid(
                    metrics$nuisance_adjusted_estimate,
                    metrics$nuisance_component,
                    "adjusted"
                ) ||
                any(!vapply(metrics[c(
                    "target_unadjusted_status", "target_adjusted_status",
                    "nuisance_unadjusted_status", "nuisance_adjusted_status"
                )], function(value) {
                    scalar_text(value) &&
                        identical(value, "estimable-exploratory-only")
                }, logical(1L))) ||
                any(!vapply(metrics[c(
                    "target_component", "nuisance_component",
                    "target_proposal_rank", "nuisance_proposal_rank"
                )], rank_or_missing, logical(1L))) ||
                !is.logical(metrics$stage2_ineligible) ||
                length(metrics$stage2_ineligible) != 1L ||
                is.na(metrics$stage2_ineligible) ||
                !identical(
                    metrics$acceptance_evidence_status,
                    "independent_acceptance"
                ) ||
                !is.list(metrics$acceptance_provenance) ||
                !identical(
                    names(metrics$acceptance_provenance),
                    c(
                        "version", "evidence_status",
                        "generator_and_decomposition", "atlas", "proposal",
                        "identifiability", "stage2"
                    )
                ) ||
                !identical(
                    metrics$acceptance_provenance$evidence_status,
                    "independent_acceptance"
                ) ||
                !is.character(metrics$acceptance_provenance_digest) ||
                length(metrics$acceptance_provenance_digest) != 1L ||
                !grepl(
                    "^[0-9a-f]{64}$",
                    metrics$acceptance_provenance_digest
                ) ||
                !identical(
                    metrics$acceptance_provenance_digest,
                    digest::digest(
                        metrics$acceptance_provenance,
                        algo = "sha256"
                    )
                )) {
            .k1_acceptance_runner_abort(
                "AML acceptance metrics violate the frozen contract"
            )
        }
        return(invisible(TRUE))
    }
    .k1_acceptance_runner_abort(
        "acceptance result names an unsupported control"
    )
}

.k1_acceptance_validate_identity <- function(identity) {
    required <- c("source_revision", "r_version", "package_versions")
    allowed <- c(required, "payload_sha256")
    if (!is.list(identity) ||
            any(!names(identity) %in% allowed) ||
            anyDuplicated(names(identity)) ||
            !all(required %in% names(identity)) ||
            !is.character(identity$source_revision) ||
            length(identity$source_revision) != 1L ||
            !grepl("^[0-9a-f]{40}$", identity$source_revision) ||
            !.is_scalar_nonempty_text(identity$r_version) ||
            !is.character(identity$package_versions) ||
            !length(identity$package_versions) ||
            is.null(names(identity$package_versions)) ||
            anyNA(identity$package_versions) ||
            any(!nzchar(names(identity$package_versions))) ||
            any(!nzchar(identity$package_versions)) ||
            anyDuplicated(names(identity$package_versions))) {
        .k1_acceptance_runner_abort(
            "acceptance runtime identity must be exact installed metadata"
        )
    }
    if ("payload_sha256" %in% names(identity) &&
            (!is.character(identity$payload_sha256) ||
                length(identity$payload_sha256) != 1L ||
                !grepl("^[0-9a-f]{64}$", identity$payload_sha256))) {
        .k1_acceptance_runner_abort(
            "acceptance payload identity must be a lowercase SHA-256 digest"
        )
    }
    invisible(TRUE)
}

.k1_acceptance_validate_collector_identity <- function(identity) {
    required <- c("source_revision", "r_version", "package_versions")
    allowed <- c(required, "payload_sha256", "recovery")
    if (!is.list(identity) ||
            any(!names(identity) %in% allowed) ||
            anyDuplicated(names(identity)) ||
            !all(required %in% names(identity))) {
        .k1_acceptance_runner_abort(
            "acceptance collector identity has an invalid schema"
        )
    }
    .k1_acceptance_validate_identity(
        identity[setdiff(names(identity), "recovery")]
    )
    if (!"recovery" %in% names(identity)) return(invisible(TRUE))
    recovery <- identity$recovery
    recovery_names <- c(
        "mode", "worker_results_modified", "corrections",
        "source_sha256", "approved_by", "approved_on"
    )
    if (!is.list(recovery) || !identical(names(recovery), recovery_names) ||
            !identical(recovery$mode, "approved_collection_only_patch") ||
            !identical(recovery$worker_results_modified, FALSE) ||
            !is.character(recovery$corrections) ||
            !length(recovery$corrections) || anyNA(recovery$corrections) ||
            any(!nzchar(recovery$corrections)) ||
            !is.character(recovery$source_sha256) ||
            !length(recovery$source_sha256) ||
            is.null(names(recovery$source_sha256)) ||
            anyNA(recovery$source_sha256) ||
            any(!grepl("^[0-9a-f]{64}$", recovery$source_sha256)) ||
            any(!nzchar(names(recovery$source_sha256))) ||
            anyDuplicated(names(recovery$source_sha256)) ||
            !.is_scalar_nonempty_text(recovery$approved_by) ||
            !is.character(recovery$approved_on) ||
            length(recovery$approved_on) != 1L ||
            !grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", recovery$approved_on)) {
        .k1_acceptance_runner_abort(
            "acceptance collector recovery provenance is invalid"
        )
    }
    invisible(TRUE)
}

.k1_validate_runtime_revision <- function(identity, manifest) {
    revised <- inherits(manifest, "K1RevisedAcceptanceManifest") &&
        manifest$artifact_version %in% c("3", "4", "5")
    if (!identical(manifest$artifact_version, "2") && !revised) {
        return(invisible(TRUE))
    }
    reviewed_revision <- if (revised) {
        manifest$runner_revision
    } else if (is.null(manifest$runner_revision)) {
        manifest$phase_a_merge_commit
    } else {
        manifest$runner_revision
    }
    if (!identical(identity$source_revision, reviewed_revision)) {
        .k1_acceptance_runner_abort(
            paste(
                "acceptance runtime revision must equal the reviewed",
                "runner revision recorded by the manifest"
            )
        )
    }
    invisible(TRUE)
}

.k1_acceptance_collect <- function(results, tasks, protocol = NULL) {
    if (!is.data.frame(tasks) || !nrow(tasks) ||
            !"task_id" %in% names(tasks) ||
            !is.character(tasks$task_id) || anyNA(tasks$task_id) ||
            any(!nzchar(tasks$task_id)) || anyDuplicated(tasks$task_id)) {
        .k1_acceptance_runner_abort(
            "acceptance tasks must have unique non-empty task identities"
        )
    }
    if (!is.list(results) || length(results) != nrow(tasks)) {
        .k1_acceptance_runner_abort(
            "acceptance results must retain every requested task"
        )
    }
    ids <- .k1_acceptance_result_ids(results)
    if (!identical(unname(ids), unname(tasks$task_id))) {
        .k1_acceptance_runner_abort(
            "acceptance result order or task identity is incomplete"
        )
    }
    if (!is.null(protocol)) {
        for (index in seq_along(results)) {
            .k1_acceptance_validate_result(
                results[[index]],
                tasks[index, , drop = FALSE],
                protocol
            )
        }
    }
    unname(results)
}

.k1_acceptance_result_ids <- function(results) {
    valid <- is.list(results) && length(results) && all(vapply(
        results,
        function(result) {
            is.list(result) && "task_id" %in% names(result) &&
                is.character(result[["task_id"]]) &&
                length(result[["task_id"]]) == 1L &&
                !is.na(result[["task_id"]]) && nzchar(result[["task_id"]])
        },
        logical(1L)
    ))
    if (!valid) {
        .k1_acceptance_runner_abort(
            "acceptance results must retain scalar task identities"
        )
    }
    vapply(results, `[[`, character(1L), "task_id")
}

.k1_acceptance_flatten_results <- function(results) {
    rows <- lapply(results, function(result) {
        metrics <- result$metrics
        data.frame(
            task_id = result$task_id,
            control = result$control,
            canonical_cell = result$canonical_cell,
            replicate_index = result$replicate_index,
            status = result$status,
            reason = result$reason,
            subspace_angle_deg = metrics$subspace_angle_deg %||% NA_real_,
            well_error = metrics$well_error %||% NA_real_,
            barrier_error = metrics$barrier_error %||% NA_real_,
            barrier_height_error = metrics$barrier_height_error %||% NA_real_,
            n_wells_found = metrics$n_wells_found %||% NA_integer_,
            n_barriers_found = metrics$n_barriers_found %||% NA_integer_,
            false_double_well = metrics$false_double_well %||% NA,
            false_target_selection = metrics$false_target_selection %||% NA,
            search_aware_p_value = metrics$search_aware_p_value %||% NA_real_,
            target_index_recurrence =
                metrics$target_index_recurrence %||% NA_real_,
            mean_matched_loading_cosine =
                metrics$mean_matched_loading_cosine %||% NA_real_,
            identifiability_completion_rate =
                metrics$identifiability_completion_rate %||% NA_real_,
            nominated_component = metrics$nominated_component %||% NA_integer_,
            target_loading_cosine =
                metrics$target_loading_cosine %||% NA_real_,
            target_subspace_angle_deg =
                metrics$target_subspace_angle_deg %||% NA_real_,
            mean_bootstrap_subspace_angle_deg =
                metrics$mean_bootstrap_subspace_angle_deg %||% NA_real_,
            q95_bootstrap_subspace_angle_deg =
                metrics$q95_bootstrap_subspace_angle_deg %||% NA_real_,
            target_component = metrics$target_component %||% NA_integer_,
            nuisance_component = metrics$nuisance_component %||% NA_integer_,
            target_proposal_rank =
                metrics$target_proposal_rank %||% NA_integer_,
            nuisance_proposal_rank =
                metrics$nuisance_proposal_rank %||% NA_integer_,
            target_unadjusted_estimate =
                metrics$target_unadjusted_estimate %||% NA_real_,
            target_adjusted_estimate =
                metrics$target_adjusted_estimate %||% NA_real_,
            nuisance_unadjusted_estimate =
                metrics$nuisance_unadjusted_estimate %||% NA_real_,
            nuisance_adjusted_estimate =
                metrics$nuisance_adjusted_estimate %||% NA_real_,
            target_unadjusted_status =
                metrics$target_unadjusted_status %||% NA_character_,
            target_adjusted_status =
                metrics$target_adjusted_status %||% NA_character_,
            nuisance_unadjusted_status =
                metrics$nuisance_unadjusted_status %||% NA_character_,
            nuisance_adjusted_status =
                metrics$nuisance_adjusted_status %||% NA_character_,
            stage2_ineligible = metrics$stage2_ineligible %||% NA,
            orientation_recurrence =
                metrics$orientation_recurrence %||% NA_real_,
            rank_one_fraction = metrics$rank_one_fraction %||% NA_real_,
            matched_fraction = metrics$matched_fraction %||% NA_real_,
            acceptance_evidence_status =
                metrics$acceptance_evidence_status %||% NA_character_,
            acceptance_provenance_digest =
                metrics$acceptance_provenance_digest %||% NA_character_,
            abstention_reason = metrics$abstention_reason %||% NA_character_,
            missing_control_time_cells =
                metrics$missing_control_time_cells %||% NA_integer_,
            unique_control_observations =
                metrics$unique_control_observations %||% NA_integer_,
            total_observations = metrics$total_observations %||% NA_integer_,
            stringsAsFactors = FALSE
        )
    })
    do.call(rbind, rows)
}

.k1_acceptance_file_digest <- .artifact_file_digest

.k1_acceptance_governed_files <- function(claim_status = NULL) {
    core <- c(
        "protocol.rds", "seed-manifest.rds", "replicates.rds", "summary.rds",
        "replicates.csv", "cell-summary.csv"
    )
    figures <- if (identical(
        claim_status,
        "independent_aml_acceptance_summary"
    )) {
        c(
            "aml-pass-rate.png", "aml-pass-rate-caption.txt",
            "aml-recovery.png", "aml-recovery-caption.txt"
        )
    } else {
        c("pass-rate.png",
        "pass-rate-caption.txt", "false-positive.png",
        "false-positive-caption.txt")
    }
    c(core, figures, "environment.rds")
}

.k1_acceptance_artifact_errors <- function() list(
    incomplete = "acceptance artifact is incomplete",
    missing_manifest = "acceptance artifact has no MANIFEST.tsv",
    missing_payload = "acceptance artifact is incomplete",
    invalid = "acceptance file manifest is invalid",
    undeclared = "acceptance artifact contains undeclared files",
    digest = "acceptance artifact digest verification failed",
    atomic = "could not atomically publish acceptance artifact"
)

.k1_acceptance_artifact_digest <- .artifact_digest

.k1_acceptance_payload_digest <- function(
    protocol,
    manifest,
    tasks,
    results,
    summary,
    identity,
    collector_identity
) {
    payload <- list(
        protocol_digest = protocol$digest,
        manifest_digest = manifest$digest,
        task_ids = tasks$task_id,
        results = results,
        summary_digest = summary$digest,
        runtime_identity = identity
    )
    if (!is.null(collector_identity)) {
        payload$collector_identity <- collector_identity
    }
    digest::digest(payload, algo = "sha256")
}

.k1_acceptance_validate_protocol_manifest_identity <- function(
    protocol,
    manifest
) {
    expected <- list(
        artifact_version = protocol$artifact_version,
        protocol_id = protocol$protocol_id,
        protocol_digest = protocol$digest,
        runner_contract = protocol$execution_contracts$version
    )
    observed <- unclass(manifest)[names(expected)]
    if (!identical(observed, expected)) {
        .k1_acceptance_runner_abort(
            "acceptance protocol and seed manifest identities do not match"
        )
    }
    invisible(TRUE)
}

.k1_acceptance_publish <- function(
    artifact_root,
    protocol,
    manifest,
    tasks,
    results,
    identity,
    collector_identity = identity
) {
    validate_k1_acceptance_protocol(protocol)
    validate_k1_acceptance_manifest(manifest)
    .k1_acceptance_validate_protocol_manifest_identity(protocol, manifest)
    .k1_acceptance_validate_identity(identity)
    .k1_acceptance_validate_collector_identity(collector_identity)
    .k1_validate_runtime_revision(identity, manifest)
    published_controls <- unique(tasks$control)
    if ("aml_synchronized" %in% published_controls &&
            length(published_controls) > 1L) {
        .k1_acceptance_runner_abort(
            "AML and phase-B1 controls require separate governed artifacts"
        )
    }
    results <- .k1_acceptance_collect(results, tasks, protocol)
    if (!all(tasks$task_id %in% manifest$tasks$task_id)) {
        .k1_acceptance_runner_abort(
            "published tasks must come from the validated acceptance manifest"
        )
    }
    summary <- summarize_k1_acceptance(results, tasks, protocol)
    scientific_payload_digest <- .k1_acceptance_payload_digest(
        protocol,
        manifest,
        tasks,
        results,
        summary,
        identity,
        collector_identity
    )
    aml_only <- identical(
        summary$claim_status,
        "independent_aml_acceptance_summary"
    )
    pass_rate_plot <- if (aml_only) {
        plot_k1_aml_acceptance_summary(summary, "pass_rate")
    } else plot_k1_acceptance_summary(summary, "pass_rate")
    second_plot <- if (aml_only) {
        plot_k1_aml_acceptance_summary(summary, "recovery")
    } else plot_k1_acceptance_summary(summary, "false_positive")
    pass_name <- if (aml_only) "aml-pass-rate" else "pass-rate"
    second_name <- if (aml_only) "aml-recovery" else "false-positive"
    environment <- list(
        artifact_version = protocol$artifact_version,
        claim_status = summary$claim_status,
        protocol_digest = protocol$digest,
        manifest_digest = manifest$digest,
        scientific_payload_digest = scientific_payload_digest,
        runner_contract = protocol$execution_contracts$version,
        runtime_identity = identity,
        collector_identity = collector_identity
    )
    governed <- .k1_acceptance_governed_files(summary$claim_status)
    write_payload <- function(staging) {
        saveRDS(protocol, file.path(staging, "protocol.rds"))
        saveRDS(manifest, file.path(staging, "seed-manifest.rds"))
        saveRDS(results, file.path(staging, "replicates.rds"))
        saveRDS(summary, file.path(staging, "summary.rds"))
        utils::write.csv(.k1_acceptance_flatten_results(results),
            file.path(staging, "replicates.csv"), row.names = FALSE)
        utils::write.csv(summary$cells,
            file.path(staging, "cell-summary.csv"), row.names = FALSE)
        ggplot2::ggsave(file.path(staging, paste0(pass_name, ".png")),
            pass_rate_plot, width = 100, height = 100, units = "mm",
            dpi = 450, bg = "white")
        ggplot2::ggsave(file.path(staging, paste0(second_name, ".png")),
            second_plot, width = 100, height = 100, units = "mm",
            dpi = 450, bg = "white")
        writeLines(scientific_caption(pass_rate_plot),
            file.path(staging, paste0(pass_name, "-caption.txt")))
        writeLines(scientific_caption(second_plot),
            file.path(staging, paste0(second_name, "-caption.txt")))
        saveRDS(environment, file.path(staging, "environment.rds"))
    }
    .artifact_publish(
        artifact_root = artifact_root,
        address_prefix = protocol$protocol_id,
        governed = governed,
        write_payload = write_payload,
        semantic_verifier = .k1_acceptance_verify_artifact,
        abort = .k1_acceptance_runner_abort,
        messages = .k1_acceptance_artifact_errors(),
        staging_prefix = paste0(".", protocol$protocol_id, "-tmp-"),
        preserve_condition = function(condition) {
            inherits(condition, "k1_acceptance_runner_error")
        }
    )
}

.k1_acceptance_verify_artifact <- function(artifact) {
    artifact <- path.expand(artifact)
    files <- .artifact_verify_payload(
        artifact,
        list(
            .k1_acceptance_governed_files(),
            .k1_acceptance_governed_files(
                "independent_aml_acceptance_summary"
            )
        ),
        .k1_acceptance_runner_abort,
        .k1_acceptance_artifact_errors()
    )
    protocol <- readRDS(file.path(artifact, "protocol.rds"))
    manifest <- readRDS(file.path(artifact, "seed-manifest.rds"))
    results <- readRDS(file.path(artifact, "replicates.rds"))
    summary <- readRDS(file.path(artifact, "summary.rds"))
    environment <- readRDS(file.path(artifact, "environment.rds"))
    if (!identical(
        files$file,
        .k1_acceptance_governed_files(summary$claim_status)
    )) {
        .k1_acceptance_runner_abort(
            "acceptance figures do not match the summary phase"
        )
    }
    validate_k1_acceptance_protocol(protocol)
    validate_k1_acceptance_manifest(manifest)
    .k1_acceptance_validate_protocol_manifest_identity(protocol, manifest)
    .k1_acceptance_validate_identity(environment$runtime_identity)
    legacy_environment <- identical(protocol$artifact_version, "1") &&
        is.null(environment$collector_identity)
    if (!legacy_environment) {
        .k1_acceptance_validate_collector_identity(
            environment$collector_identity
        )
    }
    .k1_validate_runtime_revision(
        environment$runtime_identity,
        manifest
    )
    if (!is.list(results) || !length(results)) {
        .k1_acceptance_runner_abort("acceptance artifact has no replicates")
    }
    task_ids <- .k1_acceptance_result_ids(results)
    task_index <- match(task_ids, manifest$tasks$task_id)
    if (anyNA(task_index) || anyDuplicated(task_ids)) {
        .k1_acceptance_runner_abort(
            "acceptance artifact replicates are not unique manifest tasks"
        )
    }
    tasks <- manifest$tasks[task_index, , drop = FALSE]
    .k1_acceptance_collect(results, tasks, protocol)
    observed_summary <- summarize_k1_acceptance(results, tasks, protocol)
    if (!inherits(summary, "K1AcceptanceSummary") ||
            !identical(summary, observed_summary)) {
        .k1_acceptance_runner_abort(
            "acceptance artifact summary does not reproduce from its replicates"
        )
    }
    scientific_payload_digest <- .k1_acceptance_payload_digest(
        protocol,
        manifest,
        tasks,
        results,
        summary,
        environment$runtime_identity,
        if (legacy_environment) NULL else environment$collector_identity
    )
    artifact_digest <- .k1_acceptance_artifact_digest(files)
    expected_name <- paste0(
        protocol$protocol_id, "-", substr(artifact_digest, 1L, 16L)
    )
    expected_environment <- list(
        artifact_version = protocol$artifact_version,
        claim_status = summary$claim_status,
        protocol_digest = protocol$digest,
        manifest_digest = manifest$digest,
        scientific_payload_digest = scientific_payload_digest,
        runner_contract = protocol$execution_contracts$version,
        runtime_identity = environment$runtime_identity
    )
    if (!legacy_environment) {
        expected_environment$collector_identity <-
            environment$collector_identity
    }
    if (!identical(environment, expected_environment) ||
            !identical(basename(artifact), expected_name)) {
        .k1_acceptance_runner_abort(
            "acceptance artifact address or runtime provenance is inconsistent"
        )
    }
    invisible(TRUE)
}

#' Verify an immutable K=1 independent acceptance artifact
#'
#' @param artifact path returned by [k1_acceptance_targets()].
#' @return Invisibly `TRUE`, or throws `k1_acceptance_runner_error`.
#' @export
verify_k1_acceptance_artifact <- function(artifact) {
    .k1_acceptance_public_boundary(
        .k1_acceptance_verify_artifact(artifact),
        "could not verify K=1 acceptance artifact"
    )
}

.k1_acceptance_target_resources <- function(controller) {
    targets::tar_resources(
        crew = targets::tar_resources_crew(controller = controller)
    )
}

.k1_acceptance_target <- function(
    name,
    command,
    deployment = "main",
    pattern = NULL,
    controller = NULL,
    ...
) {
    resources <- if (identical(deployment, "worker")) {
        .k1_acceptance_target_resources(controller)
    } else list()
    targets::tar_target_raw(
        name = name,
        command = command,
        pattern = pattern,
        deployment = deployment,
        storage = "main",
        retrieval = "main",
        resources = resources,
        ...
    )
}

#' Declare the durable K=1 independent acceptance targets graph
#'
#' The graph derives the post-merge seed manifest on the controlling process,
#' delegates one complete replicate to each worker branch, retains failures,
#' and publishes only after all requested branches return. A scheduler is
#' selected outside landscapeR by assigning the named controller. On City of
#' Hope Gemini, load `hprcc` before this graph so that its Slurm controllers and
#' shared rbiocverse environment remain the operational authority.
#'
#' @param phase_a_merge_commit reviewed protocol merge SHA-1.
#' @param artifact_root absolute directory for immutable evidence publication.
#' @param controller named crew controller configured by the caller.
#' @param controls frozen controls to execute in this phase. The current generic
#'   phase includes double-well recovery, both negative-control families, and
#'   the shared-baseline missing-cell safety control. AML execution remains a
#'   separately governed phase.
#' @param runner_revision reviewed execution SHA-1. It is mandatory for the
#'   AML phase and must differ from `phase_a_merge_commit`; other phases may
#'   omit it to reproduce the historical manifest. It is provenance only and
#'   does not alter deterministic seed derivation.
#' @return A list of `targets` target objects.
#' @export
k1_acceptance_targets <- function(
    phase_a_merge_commit,
    artifact_root,
    controller = "k1-acceptance",
    controls = c(
        "generic_double_well", "pure_noise", "single_well",
        "shared_baseline_missing_cells"
    ),
    runner_revision = NULL
) {
    if (!requireNamespace("targets", quietly = TRUE)) {
        .k1_acceptance_runner_abort(
            "K=1 acceptance orchestration requires optional package 'targets'"
        )
    }
    .k1_acceptance_validate_merge_commit(phase_a_merge_commit)
    if (!is.null(runner_revision)) {
        .k1_acceptance_validate_merge_commit(runner_revision)
    }
    if (!is.character(artifact_root) || length(artifact_root) != 1L ||
            is.na(artifact_root) || !nzchar(artifact_root) ||
            !grepl("^/", path.expand(artifact_root))) {
        .k1_acceptance_runner_abort("artifact_root must be one absolute path")
    }
    if (!.is_scalar_nonempty_text(controller)) {
        .k1_acceptance_runner_abort("controller must be one non-empty name")
    }
    supported <- c(
        "generic_double_well", "pure_noise", "single_well",
        "shared_baseline_missing_cells", "aml_synchronized"
    )
    if (!is.character(controls) || !length(controls) || anyNA(controls) ||
            any(!controls %in% supported) || anyDuplicated(controls)) {
        .k1_acceptance_runner_abort(
            paste(
                "controls must be unique implemented K=1 acceptance",
                "controls"
            )
        )
    }
    phase_b1_controls <- c(
        "generic_double_well", "pure_noise", "single_well",
        "shared_baseline_missing_cells"
    )
    supported_phase <- setequal(controls, phase_b1_controls) ||
        identical(controls, "aml_synchronized")
    if (!supported_phase) {
        .k1_acceptance_runner_abort(
            paste(
                "controls must select either the complete phase-B1 control",
                "set or aml_synchronized alone"
            )
        )
    }
    if (identical(controls, "aml_synchronized") &&
            is.null(runner_revision)) {
        .k1_acceptance_runner_abort(
            "AML acceptance requires the reviewed runner_revision"
        )
    }
    if (identical(controls, "aml_synchronized") &&
            identical(runner_revision, phase_a_merge_commit)) {
        .k1_acceptance_runner_abort(
            "AML runner_revision must differ from the protocol merge revision"
        )
    }
    artifact_root <- path.expand(artifact_root)
    list(
        .k1_acceptance_target(
            "k1_protocol",
            quote(landscapeR::k1_acceptance_protocol())
        ),
        .k1_acceptance_target(
            "k1_manifest",
            substitute(
                landscapeR::k1_acceptance_manifest(
                    COMMIT,
                    k1_protocol,
                    runner_revision = RUNNER
                ),
                list(
                    COMMIT = phase_a_merge_commit,
                    RUNNER = runner_revision
                )
            )
        ),
        .k1_acceptance_target(
            "k1_identity",
            quote(landscapeR:::.k1_acceptance_worker_identity())
        ),
        .k1_acceptance_target(
            "k1_preflight",
            quote({
                landscapeR:::.k1_validate_runtime_revision(
                    k1_identity,
                    k1_manifest
                )
                TRUE
            })
        ),
        .k1_acceptance_target(
            "k1_tasks",
            substitute(
                {
                    k1_preflight
                    k1_manifest$tasks[
                        k1_manifest$tasks$control %in% CONTROLS,
                        ,
                        drop = FALSE
                    ]
                },
                list(CONTROLS = controls)
            )
        ),
        .k1_acceptance_target(
            "k1_task",
            quote(landscapeR:::.k1_acceptance_task_rows(k1_tasks)),
            iteration = "list"
        ),
        .k1_acceptance_target(
            "k1_result",
            quote(landscapeR:::.k1_acceptance_run_task(
                k1_task,
                k1_protocol,
                expected_identity = k1_identity,
                sequential_internal = TRUE
            )),
            deployment = "worker",
            pattern = quote(map(k1_task)),
            controller = controller,
            packages = "landscapeR",
            iteration = "list",
            error = "continue"
        ),
        .k1_acceptance_target(
            "k1_results",
            quote(landscapeR:::.k1_acceptance_collect(k1_result, k1_tasks))
        ),
        .k1_acceptance_target(
            "k1_artifact",
            substitute(
                landscapeR:::.k1_acceptance_publish(
                    ROOT,
                    k1_protocol,
                    k1_manifest,
                    k1_tasks,
                    k1_results,
                    k1_identity
                ),
                list(ROOT = artifact_root)
            )
        ),
        .k1_acceptance_target(
            "k1_artifact_verified",
            quote({
                landscapeR:::.k1_acceptance_verify_artifact(k1_artifact)
                k1_artifact
            })
        ),
        .k1_acceptance_target(
            "k1_evidence",
            quote(structure(
                list(
                    artifact = k1_artifact_verified,
                    verified = TRUE,
                    protocol_digest = k1_protocol$digest,
                    manifest_digest = k1_manifest$digest
                ),
                class = c("K1AcceptanceWorkflowResult", "list")
            ))
        )
    )
}
