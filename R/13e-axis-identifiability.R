# Evidence-tier component alignment and axis-identifiability helpers.
#
# These algorithms operate on stored decomposition evidence. They do not apply
# thresholds or classify scientific support; calibration remains owned by #67.

.finite_loading_matrix <- function(x, name) {
    if (!is.matrix(x) || !is.numeric(x) || !nrow(x) || !ncol(x) ||
        any(!is.finite(x))) {
        .stop_landscapeR_validation(sprintf(
            "%s must be one finite numeric loading matrix",
            name
        ))
    }
    norms <- sqrt(colSums(x^2))
    if (any(!is.finite(norms)) || any(norms == 0)) {
        .stop_landscapeR_validation(sprintf(
            "%s cannot contain a zero-norm loading",
            name
        ))
    }
    sweep(x, 2L, norms, "/")
}

.solve_loading_assignment <- function(similarity) {
    n_reference <- nrow(similarity)
    n_replicate <- ncol(similarity)
    size <- max(n_reference, n_replicate)
    padded <- matrix(0, nrow = size, ncol = size)
    padded[seq_len(n_reference), seq_len(n_replicate)] <- similarity
    assignment <- as.integer(clue::solve_LSAP(padded, maximum = TRUE))
    list(
        padded = padded,
        assignment = assignment,
        total = sum(padded[cbind(seq_len(size), assignment)])
    )
}

.competing_loading_assignments <- function(solution) {
    size <- nrow(solution$padded)
    lapply(seq_len(size), function(reference_index) {
        forbidden <- solution$padded
        replicate_index <- solution$assignment[[reference_index]]
        maximum_similarity <- max(forbidden)
        cost <- maximum_similarity - forbidden
        cost[reference_index, replicate_index] <-
            (maximum_similarity + 1) * (size + 1)
        alternative <- as.integer(clue::solve_LSAP(
            cost,
            maximum = FALSE
        ))
        data.frame(
            forbidden_reference = as.integer(reference_index),
            forbidden_replicate = as.integer(replicate_index),
            total_similarity = sum(solution$padded[
                cbind(seq_len(size), alternative)
            ]),
            assignment = I(list(alternative)),
            stringsAsFactors = FALSE
        )
    })
}

.match_component_loadings <- function(reference, replicate) {
    reference <- .finite_loading_matrix(reference, "reference")
    replicate <- .finite_loading_matrix(replicate, "replicate")
    if (nrow(reference) != nrow(replicate)) {
        .stop_landscapeR_validation(
            "reference and replicate loadings must share feature rows"
        )
    }

    signed_similarity <- crossprod(reference, replicate)
    similarity <- abs(signed_similarity)
    solution <- .solve_loading_assignment(similarity)
    n_reference <- nrow(similarity)
    n_replicate <- ncol(similarity)
    selected <- solution$assignment[seq_len(n_reference)]
    matched <- selected <= n_replicate
    selected_actual <- ifelse(matched, selected, NA_integer_)

    matched_signed <- rep(NA_real_, n_reference)
    matched_absolute <- rep(NA_real_, n_reference)
    orientation <- rep(NA_integer_, n_reference)
    local_margin <- rep(NA_real_, n_reference)
    for (i in seq_len(n_reference)) {
        if (!matched[[i]]) next
        j <- selected[[i]]
        matched_signed[[i]] <- signed_similarity[i, j]
        matched_absolute[[i]] <- similarity[i, j]
        orientation[[i]] <- if (matched_signed[[i]] < 0) -1L else 1L
        alternatives <- similarity[i, -j, drop = TRUE]
        local_margin[[i]] <- if (length(alternatives)) {
            matched_absolute[[i]] - max(alternatives)
        } else {
            NA_real_
        }
    }

    competitors <- .competing_loading_assignments(solution)
    alternative_totals <- vapply(
        competitors,
        function(x) x$total_similarity[[1L]],
        numeric(1L)
    )
    global_margin <- if (length(alternative_totals)) {
        solution$total - max(alternative_totals)
    } else {
        NA_real_
    }

    list(
        geometry = "feature-loading-cosine",
        signed_similarity = signed_similarity,
        similarity = similarity,
        assignment = data.frame(
            reference_component = seq_len(n_reference),
            replicate_component = as.integer(selected_actual),
            signed_similarity = matched_signed,
            absolute_similarity = matched_absolute,
            orientation = orientation,
            assignment_margin = local_margin,
            matched = matched,
            stringsAsFactors = FALSE
        ),
        competing_assignments = competitors,
        total_similarity = solution$total,
        global_assignment_margin = global_margin
    )
}

.principal_angles <- function(reference, replicate) {
    reference <- .finite_loading_matrix(reference, "reference")
    replicate <- .finite_loading_matrix(replicate, "replicate")
    if (nrow(reference) != nrow(replicate)) {
        .stop_landscapeR_validation(
            "principal-angle inputs must share feature rows"
        )
    }
    dimension <- min(ncol(reference), ncol(replicate))
    reference_basis <- qr.Q(qr(reference))[, seq_len(dimension), drop = FALSE]
    replicate_basis <- qr.Q(qr(replicate))[, seq_len(dimension), drop = FALSE]
    cosines <- svd(
        crossprod(reference_basis, replicate_basis),
        nu = 0L,
        nv = 0L
    )$d
    acos(pmin(1, pmax(0, sort(cosines, decreasing = TRUE))))
}

.without_stage1 <- function(data) {
    out <- data
    scratch <- metadata(out)
    scratch$stage1 <- NULL
    metadata(out) <- scratch
    out
}

.evidence_decompose <- function(data, config) {
    implementation <- config@strategies[["Decomposer"]]
    if (!.is_scalar_nonempty_text(implementation)) {
        .stop_landscapeR_validation(
            "identifiability assessment requires a declared Decomposer"
        )
    }
    constructor <- tryCatch(
        get_strategy("Decomposer", implementation),
        error = function(error) {
            .stop_landscapeR_validation(conditionMessage(error))
        }
    )
    params <- config@params[[implementation]] %||% list()
    suppressWarnings(decompose(
        constructor(params),
        .without_stage1(data)
    ))
}

.evidence_loading_geometry <- function(config) {
    implementation <- config@strategies[["Decomposer"]]
    constructor <- get_strategy("Decomposer", implementation)
    strategy <- constructor(config@params[[implementation]] %||% list())
    geometry <- component_loading_geometry(strategy)
    if (!identical(geometry, "feature-loading-cosine")) {
        .stop_landscapeR_validation(sprintf(
            "unsupported component-loading geometry: %s",
            paste(geometry, collapse = ", ")
        ))
    }
    geometry
}

.identifiability_rng <- function(seed, expression) {
    had_seed <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
    if (had_seed) previous_seed <- get(".Random.seed", envir = .GlobalEnv)
    on.exit({
        if (had_seed) {
            assign(".Random.seed", previous_seed, envir = .GlobalEnv)
        } else if (exists(
            ".Random.seed",
            envir = .GlobalEnv,
            inherits = FALSE
        )) {
            rm(".Random.seed", envir = .GlobalEnv)
        }
    }, add = TRUE)
    set.seed(seed)
    force(expression)
}

.identifiability_resampling_plan <- function(
    discovery,
    specification,
    n_resamples,
    seed
) {
    target <- .aligned_component_metadata(
        discovery,
        1L,
        specification@target_field,
        caller = "assess_component_identifiability"
    )
    primary <- names(target)
    design <- discovery@sampling_design
    kind <- design@kind

    if (identical(kind, "cross_sectional")) {
        strata <- split(
            seq_along(primary),
            factor(as.character(target), exclude = NA),
            drop = TRUE
        )
        method <- "target-stratified-biological-unit-bootstrap"
        unit <- "independent-biological-observation"
        make_draw <- function(replicate_index) {
            indices <- unlist(lapply(strata, function(index) {
                sample(index, length(index), replace = TRUE)
            }), use.names = FALSE)
            list(
                source_primary = primary[indices],
                replicate_subject = NULL
            )
        }
    } else if (identical(kind, "independent_time_course")) {
        observed_time <- .aligned_component_metadata(
            discovery,
            1L,
            design@time_col,
            caller = "assess_component_identifiability"
        )
        strata <- split(
            seq_along(primary),
            interaction(
                as.character(target),
                observed_time,
                drop = TRUE,
                lex.order = TRUE
            ),
            drop = TRUE
        )
        method <- "condition-time-cell-bootstrap"
        unit <- "independent-biological-observation"
        make_draw <- function(replicate_index) {
            indices <- unlist(lapply(strata, function(index) {
                sample(index, length(index), replace = TRUE)
            }), use.names = FALSE)
            list(
                source_primary = primary[indices],
                replicate_subject = NULL
            )
        }
    } else if (identical(kind, "longitudinal")) {
        subject <- .aligned_component_metadata(
            discovery,
            1L,
            design@subject_id_col,
            caller = "assess_component_identifiability"
        )
        subject_rows <- split(seq_along(primary), subject)
        subject_condition <- vapply(subject_rows, function(index) {
            values <- unique(as.character(target[index]))
            if (length(values) != 1L || is.na(values)) {
                .stop_landscapeR_validation(
                    "target assignment must be constant within each subject"
                )
            }
            values
        }, character(1L))
        strata <- split(names(subject_rows), subject_condition)
        method <- "condition-stratified-subject-trajectory-bootstrap"
        unit <- "complete-subject-trajectory"
        make_draw <- function(replicate_index) {
            sampled <- unlist(lapply(strata, function(ids) {
                sample(ids, length(ids), replace = TRUE)
            }), use.names = FALSE)
            source_primary <- character()
            replicate_subject <- character()
            for (draw in seq_along(sampled)) {
                rows <- subject_rows[[sampled[[draw]]]]
                source_primary <- c(source_primary, primary[rows])
                replicate_subject <- c(
                    replicate_subject,
                    rep(
                        sprintf(
                            "bootstrap_%04d_subject_%04d",
                            replicate_index,
                            draw
                        ),
                        length(rows)
                    )
                )
            }
            list(
                source_primary = source_primary,
                replicate_subject = replicate_subject
            )
        }
    } else {
        .stop_landscapeR_validation(
            "sampling design is unsupported for identifiability assessment"
        )
    }

    generated <- .identifiability_rng(seed, {
        draws <- lapply(seq_len(n_resamples), make_draw)
        replicate_seeds <- sample.int(
            .Machine$integer.max,
            n_resamples,
            replace = FALSE
        )
        list(draws = draws, seeds = replicate_seeds)
    })
    list(
        draws = generated$draws,
        replicate_seeds = as.integer(generated$seeds),
        method = method,
        unit = unit,
        seed = as.integer(seed),
        n_resamples = as.integer(n_resamples),
        digest = digest::digest(
            list(
                kind = kind,
                method = method,
                unit = unit,
                seed = seed,
                draws = generated$draws,
                replicate_seeds = generated$seeds
            ),
            algo = "sha256",
            serialize = TRUE
        )
    )
}

.resample_state_transition_data <- function(
    data,
    source_primary,
    replicate_index,
    replicate_subject = NULL
) {
    source_primary <- as.character(source_primary)
    if (!length(source_primary) || anyNA(source_primary)) {
        .stop_landscapeR_validation(
            "resampling requires non-missing biological sample identifiers"
        )
    }
    source_col_data <- as.data.frame(colData(data))
    source_rows <- match(source_primary, rownames(source_col_data))
    if (anyNA(source_rows)) {
        .stop_landscapeR_validation(
            "resampling plan references an unknown biological sample"
        )
    }
    replicate_primary <- sprintf(
        "bootstrap_%04d_sample_%04d",
        replicate_index,
        seq_along(source_primary)
    )
    sampled_col_data <- source_col_data[source_rows, , drop = FALSE]
    rownames(sampled_col_data) <- replicate_primary
    if (!is.null(replicate_subject)) {
        subject_field <- data@sampling_design@subject_id_col
        sampled_col_data[[subject_field]] <- replicate_subject
    }

    source_map <- as.data.frame(sampleMap(data))
    source_experiments <- as.list(experiments(data))
    sampled_experiments <- vector("list", length(source_experiments))
    names(sampled_experiments) <- names(source_experiments)
    sampled_maps <- vector("list", length(source_experiments))
    for (layer_index in seq_along(source_experiments)) {
        layer <- names(source_experiments)[[layer_index]]
        layer_map <- source_map[as.character(source_map$assay) == layer, ]
        selected_map_rows <- unlist(lapply(source_primary, function(primary) {
            which(layer_map$primary == primary)
        }), use.names = FALSE)
        if (length(selected_map_rows) != length(source_primary)) {
            .stop_landscapeR_validation(
                paste0(
                    "each resampled biological sample must map exactly once ",
                    "within every decomposition layer"
                )
            )
        }
        selected_map <- layer_map[selected_map_rows, , drop = FALSE]
        source_columns <- match(
            selected_map$colname,
            colnames(source_experiments[[layer_index]])
        )
        if (anyNA(source_columns)) {
            .stop_landscapeR_validation(
                "sampleMap references an unknown assay column"
            )
        }
        sampled <- source_experiments[[layer_index]][
            ,
            source_columns,
            drop = FALSE
        ]
        replicate_columns <- sprintf(
            "%s_bootstrap_%04d_%04d",
            layer,
            replicate_index,
            seq_along(source_columns)
        )
        colnames(sampled) <- replicate_columns
        sampled_experiments[[layer_index]] <- sampled
        sampled_maps[[layer_index]] <- data.frame(
            assay = layer,
            primary = replicate_primary,
            colname = replicate_columns,
            stringsAsFactors = FALSE
        )
    }
    sampled_map <- do.call(rbind, sampled_maps)
    sampled_map$assay <- factor(
        sampled_map$assay,
        levels = names(sampled_experiments)
    )
    out <- StateTransitionData(
        experiments = sampled_experiments,
        colData = S4Vectors::DataFrame(sampled_col_data),
        sampleMap = S4Vectors::DataFrame(sampled_map),
        sampling_design = data@sampling_design
    )
    out@provenance <- data@provenance
    scratch <- metadata(data)
    scratch$stage1 <- NULL
    scratch$identifiability_resample <- list(
        replicate = as.integer(replicate_index),
        source_primary = source_primary,
        replicate_primary = replicate_primary
    )
    metadata(out) <- scratch
    validObject(out)
    out
}

.identifiability_non_analytical_fields <- function(
    proposal,
    non_analytical_fields
) {
    unique(as.character(non_analytical_fields))
}

.spectral_gap_evidence <- function(decomposition) {
    sigma <- dr_sigma_k(decomposition)
    rows <- lapply(seq_len(nrow(sigma)), function(layer) {
        values <- as.numeric(sigma[layer, ])
        data.frame(
            layer = as.integer(layer),
            component = seq_along(values),
            singular_value = values,
            adjacent_gap = c(values[-length(values)] - values[-1L], NA_real_),
            adjacent_ratio = c(
                values[-length(values)] / values[-1L],
                NA_real_
            ),
            stringsAsFactors = FALSE
        )
    })
    do.call(rbind, rows)
}

.subspace_angle_evidence <- function(reference, replicate) {
    maximum_dimension <- min(ncol(reference), ncol(replicate))
    do.call(rbind, lapply(seq_len(maximum_dimension), function(dimension) {
        angles <- .principal_angles(
            reference[, seq_len(dimension), drop = FALSE],
            replicate[, seq_len(dimension), drop = FALSE]
        )
        data.frame(
            dimension = as.integer(dimension),
            angle_index = seq_along(angles),
            angle_radians = angles,
            angle_degrees = angles * 180 / pi,
            stringsAsFactors = FALSE
        )
    }))
}

.failed_identifiability_replicate <- function(
    index,
    seed,
    source_primary,
    stage,
    diagnostic,
    replicate_subject = NULL
) {
    list(
        replicate = as.integer(index),
        seed = as.integer(seed),
        source_primary = source_primary,
        replicate_subject = replicate_subject,
        decomposition_status = if (identical(stage, "decomposition")) {
            "failure"
        } else {
            "success"
        },
        association_status = if (identical(stage, "association")) {
            "failure"
        } else {
            "not-run"
        },
        proposal_status = "not-run",
        diagnostic = as.character(diagnostic),
        similarity = matrix(numeric(), 0L, 0L),
        signed_similarity = matrix(numeric(), 0L, 0L),
        assignment = data.frame(),
        competing_assignments = list(),
        global_assignment_margin = NA_real_,
        ranking = data.frame(),
        subspace_angles = data.frame(),
        spectral_gaps = data.frame()
    )
}

.run_identifiability_replicate <- function(
    index,
    draw,
    replicate_seed,
    source_data,
    reference_loadings,
    loading_geometry,
    config,
    non_analytical_fields
) {
    sampled <- .resample_state_transition_data(
        source_data,
        draw$source_primary,
        index,
        draw$replicate_subject
    )
    decomposition <- .evidence_decompose(sampled, config)
    if (!is(decomposition, "StageResult") ||
        !identical(decomposition@status, "success")) {
        diagnostic <- if (is(decomposition, "StageResult")) {
            decomposition@message
        } else {
            "decomposer did not return a StageResult"
        }
        return(.failed_identifiability_replicate(
            index,
            replicate_seed,
            draw$source_primary,
            "decomposition",
            diagnostic,
            draw$replicate_subject
        ))
    }
    decomposed <- decomposition@value
    replicate_decomposition <- metadata(decomposed)$stage1
    replicate_loadings <- dr_V_k(replicate_decomposition)
    alignment <- .match_component_loadings(
        reference_loadings,
        replicate_loadings
    )
    alignment$geometry <- loading_geometry
    atlas <- tryCatch(
        associate_metadata(
            decomposed,
            specification = config@analysis,
            non_analytical_fields = non_analytical_fields,
            dataset_id = config@dataset,
            n_resamples = 0L,
            seed = replicate_seed
        ),
        error = identity
    )
    if (inherits(atlas, "error") || is(atlas, "AssociationAbstention")) {
        diagnostic <- if (inherits(atlas, "error")) {
            conditionMessage(atlas)
        } else {
            atlas@diagnostic
        }
        failed <- .failed_identifiability_replicate(
            index,
            replicate_seed,
            draw$source_primary,
            "association",
            diagnostic,
            draw$replicate_subject
        )
        failed$similarity <- alignment$similarity
        failed$signed_similarity <- alignment$signed_similarity
        failed$assignment <- alignment$assignment
        failed$competing_assignments <- alignment$competing_assignments
        failed$global_assignment_margin <-
            alignment$global_assignment_margin
        failed$subspace_angles <- .subspace_angle_evidence(
            reference_loadings,
            replicate_loadings
        )
        failed$spectral_gaps <- .spectral_gap_evidence(
            replicate_decomposition
        )
        return(failed)
    }
    replicate_proposal <- tryCatch(
        propose_component(atlas, target = config@analysis@target_field),
        error = identity
    )
    if (inherits(replicate_proposal, "error")) {
        return(.failed_identifiability_replicate(
            index,
            replicate_seed,
            draw$source_primary,
            "association",
            conditionMessage(replicate_proposal),
            draw$replicate_subject
        ))
    }
    proposal_status <- if (is(replicate_proposal, "ComponentProposal")) {
        "proposal"
    } else {
        "abstention"
    }
    list(
        replicate = as.integer(index),
        seed = as.integer(replicate_seed),
        source_primary = draw$source_primary,
        replicate_subject = draw$replicate_subject,
        decomposition_status = "success",
        association_status = "success",
        proposal_status = proposal_status,
        diagnostic = if (identical(proposal_status, "abstention")) {
            replicate_proposal@reason
        } else {
            ""
        },
        similarity = alignment$similarity,
        signed_similarity = alignment$signed_similarity,
        assignment = alignment$assignment,
        competing_assignments = alignment$competing_assignments,
        global_assignment_margin = alignment$global_assignment_margin,
        ranking = replicate_proposal@ranking,
        subspace_angles = .subspace_angle_evidence(
            reference_loadings,
            replicate_loadings
        ),
        spectral_gaps = .spectral_gap_evidence(replicate_decomposition)
    )
}

.identifiability_recurrence <- function(
    replicates,
    reference_components,
    nominated_component
) {
    rows <- lapply(replicates, function(replicate) {
        assignment <- replicate$assignment
        ranking <- replicate$ranking
        do.call(rbind, lapply(reference_components, function(component) {
            match_row <- if (nrow(assignment)) {
                assignment[
                    assignment$reference_component == component,
                    ,
                    drop = FALSE
                ]
            } else {
                data.frame()
            }
            replicate_component <- if (nrow(match_row)) {
                match_row$replicate_component[[1L]]
            } else {
                NA_integer_
            }
            rank_row <- if (
                nrow(ranking) &&
                    !is.na(replicate_component) &&
                    "component" %in% names(ranking)
            ) {
                ranking[
                    ranking$component == replicate_component,
                    ,
                    drop = FALSE
                ]
            } else {
                data.frame()
            }
            proposal_rank <- if (
                nrow(rank_row) &&
                    "proposal_rank" %in% names(rank_row)
            ) {
                as.integer(rank_row$proposal_rank[[1L]])
            } else {
                NA_integer_
            }
            data.frame(
                replicate = replicate$replicate,
                reference_component = as.integer(component),
                replicate_component = as.integer(replicate_component),
                matched = nrow(match_row) &&
                    isTRUE(match_row$matched[[1L]]),
                signed_similarity = if (nrow(match_row)) {
                    match_row$signed_similarity[[1L]]
                } else {
                    NA_real_
                },
                absolute_similarity = if (nrow(match_row)) {
                    match_row$absolute_similarity[[1L]]
                } else {
                    NA_real_
                },
                orientation = if (nrow(match_row)) {
                    match_row$orientation[[1L]]
                } else {
                    NA_integer_
                },
                assignment_margin = if (nrow(match_row)) {
                    match_row$assignment_margin[[1L]]
                } else {
                    NA_real_
                },
                index_recurrent = !is.na(replicate_component) &&
                    replicate_component == component,
                proposal_rank = proposal_rank,
                rank_one = !is.na(proposal_rank) && proposal_rank == 1L,
                nominated_reference = component == nominated_component,
                stringsAsFactors = FALSE
            )
        }))
    })
    recurrence <- do.call(rbind, rows)
    summary_rows <- lapply(reference_components, function(component) {
        component_rows <- recurrence[
            recurrence$reference_component == component,
            ,
            drop = FALSE
        ]
        matched_similarity <- component_rows$absolute_similarity[
            is.finite(component_rows$absolute_similarity)
        ]
        data.frame(
            reference_component = as.integer(component),
            nominated_reference = component == nominated_component,
            matched_fraction = mean(component_rows$matched),
            mean_absolute_similarity = if (length(matched_similarity)) {
                mean(matched_similarity)
            } else {
                NA_real_
            },
            orientation_recurrence = if (any(!is.na(
                component_rows$orientation
            ))) {
                mean(
                    component_rows$orientation[
                        !is.na(component_rows$orientation)
                    ] == 1L
                )
            } else {
                NA_real_
            },
            index_recurrence = mean(component_rows$index_recurrent),
            rank_one_fraction = mean(component_rows$rank_one),
            stringsAsFactors = FALSE
        )
    })
    summary <- do.call(rbind, summary_rows)
    list(
        recurrence = recurrence,
        summary = summary,
        target = summary[
            summary$reference_component == nominated_component,
            ,
            drop = FALSE
        ]
    )
}

.new_identifiability_evidence <- function(
    proposal,
    config,
    source_data,
    reference_decomposition,
    loading_geometry,
    plan,
    replicates
) {
    replicate_order <- order(vapply(
        replicates,
        function(x) x$replicate,
        integer(1L)
    ))
    replicates <- replicates[replicate_order]
    completed <- vapply(
        replicates,
        function(x) {
            identical(x$decomposition_status, "success") &&
                identical(x$association_status, "success")
        },
        logical(1L)
    )
    reference_components <- seq_len(ncol(dr_V_k(reference_decomposition)))
    recurrence <- .identifiability_recurrence(
        replicates,
        reference_components,
        proposal@recommended_component
    )
    payload <- list(
        version = "1.0.0",
        status = "estimable-exploratory-only",
        evidence_status = "estimable-exploratory-only",
        structured_outcome = "not-calibrated",
        n_requested = as.integer(length(replicates)),
        n_completed = as.integer(sum(completed)),
        n_failed = as.integer(sum(!completed)),
        nominated_component = proposal@recommended_component,
        source_data_digest = digest::digest(
            source_data,
            algo = "sha256",
            serialize = TRUE
        ),
        analysis_specification_digest = canonical_digest(config@analysis),
        decomposition_strategy = config@strategies[["Decomposer"]],
        loading_geometry = loading_geometry,
        decomposition_params_digest = digest::digest(
            config@params[[config@strategies[["Decomposer"]]]] %||% list(),
            algo = "sha256",
            serialize = TRUE
        ),
        reference_state_space_digest =
            .atlas_state_space_digest(reference_decomposition),
        reference_spectral_gaps =
            .spectral_gap_evidence(reference_decomposition),
        resampling = plan[c(
            "method", "unit", "seed", "n_resamples", "replicate_seeds",
            "draws", "digest"
        )],
        replicates = replicates,
        recurrence = recurrence$recurrence,
        recurrence_summary = recurrence$summary,
        target_recurrence = recurrence$target,
        failure_summary = list(
            n_requested = as.integer(length(replicates)),
            n_completed = as.integer(sum(completed)),
            n_failed = as.integer(sum(!completed)),
            failure_fraction = mean(!completed)
        ),
        thresholds = list(),
        calibration_digest = NA_character_
    )
    payload$digest <- digest::digest(
        payload,
        algo = "sha256",
        serialize = TRUE
    )
    payload
}

.proposal_with_identifiability <- function(proposal, evidence) {
    provenance <- proposal@provenance
    provenance$axis_identifiability <- evidence
    digest_value <- .component_proposal_digest(
        target_field = proposal@target_field,
        reference_level = proposal@reference_level,
        comparison_level = proposal@comparison_level,
        ranking = proposal@ranking,
        observations = proposal@observations,
        permutation_evidence = proposal@permutation_evidence,
        recommended_component = proposal@recommended_component,
        atlas_digest = proposal@atlas_digest,
        provenance = provenance,
        evidence_status = proposal@evidence_status
    )
    out <- new(
        "ComponentProposal",
        version = proposal@version,
        target_field = proposal@target_field,
        reference_level = proposal@reference_level,
        comparison_level = proposal@comparison_level,
        ranking = proposal@ranking,
        observations = proposal@observations,
        permutation_evidence = proposal@permutation_evidence,
        recommended_component = proposal@recommended_component,
        atlas_digest = proposal@atlas_digest,
        provenance = provenance,
        digest = digest_value,
        evidence_status = proposal@evidence_status
    )
    validObject(out)
    out
}

#' Assess component-axis identifiability under design-preserving resampling
#'
#' Repeats decomposition, metadata association, and the complete eligible
#' component search for each biological-unit bootstrap replicate. Components
#' are assigned jointly to the frozen discovery basis by absolute loading
#' cosine. No stability threshold or scientific support label is inferred.
#'
#' @param data pre-decomposition `StateTransitionData` used for discovery
#' @param proposal frozen exploratory `ComponentProposal`
#' @param config discovery `PipelineConfig` with its draft analysis declaration
#' @param non_analytical_fields metadata fields excluded from association
#' @param n_resamples positive number of evidence bootstrap replicates
#' @param seed deterministic resampling seed
#'
#' @return the proposal with digest-bound identifiability evidence
#' @export
assess_component_identifiability <- function(
    data,
    proposal,
    config,
    non_analytical_fields = character(),
    n_resamples,
    seed = 1L
) {
    if (!is(data, "StateTransitionData")) {
        .stop_landscapeR_validation(
            "data must be a StateTransitionData object"
        )
    }
    if (!is(proposal, "ComponentProposal")) {
        .stop_landscapeR_validation(
            "proposal must be a ComponentProposal"
        )
    }
    if (!is(config, "PipelineConfig")) {
        .stop_landscapeR_validation("config must be a PipelineConfig")
    }
    if (length(n_resamples) != 1L || is.na(n_resamples) ||
        n_resamples < 1L || n_resamples != as.integer(n_resamples)) {
        .stop_landscapeR_validation(
            "n_resamples must be one positive integer"
        )
    }
    if (length(seed) != 1L || is.na(seed) ||
        seed != as.integer(seed)) {
        .stop_landscapeR_validation("seed must be one integer")
    }
    if (!identical(
        canonical_digest(config@analysis),
        proposal@provenance$analysis_specification_digest
    )) {
        .stop_landscapeR_validation(
            "config analysis does not match the proposal declaration"
        )
    }
    discovery_result <- .evidence_decompose(data, config)
    if (!is(discovery_result, "StageResult") ||
        !identical(discovery_result@status, "success")) {
        .stop_landscapeR_validation(
            "discovery decomposition could not be reproduced"
        )
    }
    discovery <- discovery_result@value
    reference_decomposition <- metadata(discovery)$stage1
    reference_digest <- .atlas_state_space_digest(reference_decomposition)
    if (!identical(
        reference_digest,
        proposal@provenance$state_space_digest
    )) {
        .stop_landscapeR_validation(
            "reproduced discovery basis does not match the proposal"
        )
    }
    plan <- .identifiability_resampling_plan(
        discovery,
        config@analysis,
        as.integer(n_resamples),
        as.integer(seed)
    )
    reference_loadings <- dr_V_k(reference_decomposition)
    loading_geometry <- .evidence_loading_geometry(config)
    fields <- .identifiability_non_analytical_fields(
        proposal,
        non_analytical_fields
    )
    replicates <- lapply(seq_len(n_resamples), function(index) {
        tryCatch(
            .run_identifiability_replicate(
                index = index,
                draw = plan$draws[[index]],
                replicate_seed = plan$replicate_seeds[[index]],
                source_data = data,
                reference_loadings = reference_loadings,
                loading_geometry = loading_geometry,
                config = config,
                non_analytical_fields = fields
            ),
            error = function(error) {
                .failed_identifiability_replicate(
                    index,
                    plan$replicate_seeds[[index]],
                    plan$draws[[index]]$source_primary,
                    "decomposition",
                    conditionMessage(error),
                    plan$draws[[index]]$replicate_subject
                )
            }
        )
    })
    evidence <- .new_identifiability_evidence(
        proposal,
        config,
        data,
        reference_decomposition,
        loading_geometry,
        plan,
        replicates
    )
    .proposal_with_identifiability(proposal, evidence)
}

#' Extract component-axis identifiability evidence
#'
#' @param proposal a `ComponentProposal` assessed by
#'   `assess_component_identifiability()`
#' @return a digest-bound evidence list
#' @export
proposal_identifiability <- function(proposal) {
    if (!is(proposal, "ComponentProposal")) {
        .stop_landscapeR_validation(
            "proposal_identifiability(): proposal must be a ComponentProposal"
        )
    }
    evidence <- proposal@provenance$axis_identifiability
    if (is.null(evidence)) {
        .stop_landscapeR_validation(
            "proposal has no axis-identifiability evidence"
        )
    }
    evidence
}

.record_identifiability_outcome <- function(
    proposal,
    outcome,
    calibration_digest,
    diagnostic
) {
    allowed <- c(
        "stable-axis",
        "stable-subspace-no-stable-axis",
        "no-stable-target-structure",
        "outside-operating-region",
        "unique-winner-failure",
        "invalid-design"
    )
    if (length(outcome) != 1L || is.na(outcome) ||
        !outcome %in% allowed) {
        .stop_landscapeR_validation(
            "identifiability outcome is not supported"
        )
    }
    if (!.is_sha256_digest(calibration_digest)) {
        .stop_landscapeR_validation(
            "identifiability outcome requires a calibration SHA-256 digest"
        )
    }
    if (!.is_scalar_nonempty_text(diagnostic)) {
        .stop_landscapeR_validation(
            "identifiability outcome requires one diagnostic"
        )
    }
    evidence <- proposal_identifiability(proposal)
    evidence$structured_outcome <- outcome
    evidence$status <- if (identical(outcome, "stable-axis")) {
        "calibrated-axis-eligible"
    } else if (outcome %in% c(
        "stable-subspace-no-stable-axis",
        "no-stable-target-structure"
    )) {
        "calibrated-scientific-abstention"
    } else {
        "calibrated-ineligible"
    }
    evidence$calibration_digest <- calibration_digest
    evidence$outcome_diagnostic <- diagnostic
    evidence$digest <- NULL
    evidence$digest <- digest::digest(
        evidence,
        algo = "sha256",
        serialize = TRUE
    )
    .proposal_with_identifiability(proposal, evidence)
}

.identifiability_surface_data <- function(evidence) {
    spectrum <- evidence$reference_spectral_gaps
    spectrum_rows <- data.frame(
        surface = "Spectrum",
        evidence_index = spectrum$component,
        value = spectrum$singular_value,
        series = paste0("Layer ", spectrum$layer),
        focal = spectrum$component == evidence$nominated_component,
        stringsAsFactors = FALSE
    )
    recurrence <- evidence$recurrence
    similarity_rows <- data.frame(
        surface = "Matching similarity",
        evidence_index = recurrence$replicate,
        value = recurrence$absolute_similarity,
        series = paste0("Component ", recurrence$reference_component),
        focal = recurrence$nominated_reference,
        stringsAsFactors = FALSE
    )
    margin_rows <- data.frame(
        surface = "Assignment margin",
        evidence_index = recurrence$replicate,
        value = recurrence$assignment_margin,
        series = paste0("Component ", recurrence$reference_component),
        focal = recurrence$nominated_reference,
        stringsAsFactors = FALSE
    )
    recurrence_rows <- data.frame(
        surface = "Axis recurrence",
        evidence_index = recurrence$replicate,
        value = as.numeric(recurrence$rank_one),
        series = paste0("Component ", recurrence$reference_component),
        focal = recurrence$nominated_reference,
        stringsAsFactors = FALSE
    )
    angle_rows <- do.call(rbind, lapply(
        evidence$replicates,
        function(replicate) {
            angles <- replicate$subspace_angles
            if (!nrow(angles)) return(NULL)
            maximum <- aggregate(
                angle_degrees ~ dimension,
                data = angles,
                FUN = max
            )
            data.frame(
                surface = "Subspace angle",
                evidence_index = replicate$replicate,
                value = maximum$angle_degrees,
                series = paste0("Dimension ", maximum$dimension),
                focal = maximum$dimension ==
                    evidence$nominated_component,
                stringsAsFactors = FALSE
            )
        }
    ))
    completion_rows <- data.frame(
        surface = "Replicate completion",
        evidence_index = vapply(
            evidence$replicates,
            function(x) x$replicate,
            integer(1L)
        ),
        value = as.numeric(vapply(
            evidence$replicates,
            function(x) {
                identical(x$decomposition_status, "success") &&
                    identical(x$association_status, "success")
            },
            logical(1L)
        )),
        series = "Complete replicate",
        focal = FALSE,
        stringsAsFactors = FALSE
    )
    rows <- Filter(
        function(x) !is.null(x) && nrow(x),
        list(
            spectrum_rows,
            similarity_rows,
            margin_rows,
            recurrence_rows,
            angle_rows,
            completion_rows
        )
    )
    surface_data <- do.call(rbind, rows)
    surface_data$surface <- factor(
        surface_data$surface,
        levels = c(
            "Spectrum", "Matching similarity", "Assignment margin",
            "Axis recurrence", "Subspace angle", "Replicate completion"
        )
    )
    rownames(surface_data) <- NULL
    surface_data
}

#' Plot component-axis identifiability evidence
#'
#' Produces a compact evidence surface for the spectrum, joint matching,
#' recurrence, subspace angles, and replicate completion. Values are shown
#' without uncalibrated stability thresholds; the subtitle reports the
#' structured evidence outcome.
#'
#' @param proposal a `ComponentProposal` assessed by
#'   `assess_component_identifiability()`
#' @return a `ggplot2` object
#' @export
plot_component_identifiability <- function(proposal) {
    evidence <- proposal_identifiability(proposal)
    surface_data <- .identifiability_surface_data(evidence)
    palette <- landscapeR_palette("semantic")
    ggplot2::ggplot(
        surface_data,
        ggplot2::aes(
            x = evidence_index,
            y = value,
            colour = focal
        )
    ) +
        ggplot2::geom_line(
            data = surface_data[
                surface_data$surface == "Spectrum",
                ,
                drop = FALSE
            ],
            ggplot2::aes(group = series),
            linewidth = 0.45,
            alpha = 0.75,
            na.rm = TRUE
        ) +
        ggplot2::geom_point(
            data = surface_data[
                !surface_data$surface %in% c(
                    "Axis recurrence",
                    "Replicate completion"
                ),
                ,
                drop = FALSE
            ],
            size = 0.9,
            alpha = 0.65,
            na.rm = TRUE
        ) +
        ggplot2::geom_jitter(
            data = surface_data[
                surface_data$surface == "Axis recurrence",
                ,
                drop = FALSE
            ],
            width = 0.15,
            height = 0.012,
            size = 0.8,
            alpha = 0.55,
            na.rm = TRUE
        ) +
        ggplot2::geom_jitter(
            data = surface_data[
                surface_data$surface == "Replicate completion",
                ,
                drop = FALSE
            ],
            width = 0.15,
            height = 0,
            size = 0.8,
            alpha = 0.55,
            na.rm = TRUE
        ) +
        ggplot2::facet_wrap(
            ggplot2::vars(surface),
            scales = "free",
            ncol = 2L
        ) +
        ggplot2::scale_colour_manual(
            values = c(
                `FALSE` = unname(palette[["ink"]]),
                `TRUE` = unname(palette[["focal"]])
            ),
            guide = "none"
        ) +
        ggplot2::labs(
            title = "Component identifiability evidence",
            subtitle = paste(
                "Structured outcome:",
                gsub("-", " ", evidence$structured_outcome)
            ),
            x = "Evidence replicate or component",
            y = "Observed value"
        ) +
        theme_landscapeR(square = FALSE)
}
