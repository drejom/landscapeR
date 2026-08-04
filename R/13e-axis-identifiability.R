# Evidence-tier component alignment and axis-identifiability helpers.
#
# These algorithms operate on stored decomposition evidence. They do not apply
# thresholds or classify scientific support; calibration remains owned by #67.

utils::globalVariables(c(
    "evidence_index", "focal", "series", "surface", "value"
))

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
    if (size == 1L) {
        return(list())
    }
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

    policy <- .resampling_policy_plan(
        lifecycle = "bootstrap",
        method = method,
        unit = unit,
        n_requested = n_resamples,
        seed = seed,
        design = list(kind = kind, strata = strata),
        draw_factory = make_draw,
        materialize_replicate_seeds = TRUE
    )
    list(
        draws = policy$draws,
        replicate_seeds = policy$replicate_seeds,
        method = method,
        unit = unit,
        seed = as.integer(seed),
        n_resamples = as.integer(n_resamples),
        digest = policy$digest,
        policy = policy
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
    replicate_subject = NULL,
    alignment = NULL,
    reference_loadings = NULL,
    replicate_decomposition = NULL
) {
    failure <- list(
        replicate = as.integer(index),
        seed = as.integer(seed),
        source_primary = source_primary,
        replicate_subject = replicate_subject,
        decomposition_status = if (identical(stage, "decomposition")) {
            "failure"
        } else {
            "success"
        },
        association_status = if (identical(stage, "decomposition")) {
            "not-run"
        } else if (identical(stage, "association")) {
            "failure"
        } else {
            "success"
        },
        proposal_status = if (identical(stage, "proposal")) {
            "failure"
        } else {
            "not-run"
        },
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
    if (!is.null(alignment)) {
        failure$similarity <- alignment$similarity
        failure$signed_similarity <- alignment$signed_similarity
        failure$assignment <- alignment$assignment
        failure$competing_assignments <- alignment$competing_assignments
        failure$global_assignment_margin <- alignment$global_assignment_margin
        failure$subspace_angles <- .subspace_angle_evidence(
            reference_loadings,
            dr_V_k(replicate_decomposition)
        )
        failure$spectral_gaps <- .spectral_gap_evidence(
            replicate_decomposition
        )
    }
    failure
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
            decomposition@reason
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
        return(.failed_identifiability_replicate(
            index,
            replicate_seed,
            draw$source_primary,
            "association",
            diagnostic,
            draw$replicate_subject,
            alignment,
            reference_loadings,
            replicate_decomposition
        ))
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
            "proposal",
            conditionMessage(replicate_proposal),
            draw$replicate_subject,
            alignment,
            reference_loadings,
            replicate_decomposition
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
    nominated_component,
    reference_ranking
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
            replicate_estimate <- if (
                nrow(rank_row) &&
                    "estimate" %in% names(rank_row)
            ) {
                rank_row$estimate[[1L]]
            } else {
                NA_real_
            }
            reference_row <- reference_ranking[
                reference_ranking$component == component,
                ,
                drop = FALSE
            ]
            reference_estimate <- if (
                nrow(reference_row) &&
                    "estimate" %in% names(reference_row)
            ) {
                reference_row$estimate[[1L]]
            } else {
                NA_real_
            }
            loading_orientation <- if (nrow(match_row)) {
                match_row$orientation[[1L]]
            } else {
                NA_integer_
            }
            corrected_estimate <- replicate_estimate * loading_orientation
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
                orientation = loading_orientation,
                assignment_margin = if (nrow(match_row)) {
                    match_row$assignment_margin[[1L]]
                } else {
                    NA_real_
                },
                index_recurrent = !is.na(replicate_component) &&
                    replicate_component == component,
                orientation_recurrent =
                    is.finite(corrected_estimate) &&
                    is.finite(reference_estimate) &&
                    sign(corrected_estimate) == sign(reference_estimate),
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
                component_rows$orientation_recurrent
            ))) {
                mean(
                    component_rows$orientation_recurrent[
                        !is.na(component_rows$orientation_recurrent)
                    ]
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

.summarize_subspace_angles <- function(replicates) {
    rows <- lapply(replicates, function(replicate) {
        angles <- replicate$subspace_angles
        if (!nrow(angles)) return(NULL)
        maximum <- stats::aggregate(
            angle_degrees ~ dimension,
            data = angles,
            FUN = max
        )
        data.frame(
            replicate = replicate$replicate,
            dimension = maximum$dimension,
            maximum_angle_degrees = maximum$angle_degrees,
            stringsAsFactors = FALSE
        )
    })
    rows <- Filter(function(x) !is.null(x) && nrow(x), rows)
    if (!length(rows)) {
        return(data.frame(
            replicate = integer(),
            dimension = integer(),
            maximum_angle_degrees = numeric()
        ))
    }
    out <- do.call(rbind, rows)
    rownames(out) <- NULL
    out
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
    computationally_completed <- vapply(
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
        proposal@recommended_component,
        proposal@ranking
    )
    proposal_abstained <- vapply(
        replicates,
        function(x) identical(x$proposal_status, "abstention"),
        logical(1L)
    )
    proposal_failed <- vapply(
        replicates,
        function(x) identical(x$proposal_status, "failure"),
        logical(1L)
    )
    proposal_completed <- vapply(
        replicates,
        function(x) identical(x$proposal_status, "proposal"),
        logical(1L)
    )
    matching_reached <- computationally_completed & vapply(
        replicates,
        function(x) is.data.frame(x$assignment) && nrow(x$assignment) > 0L,
        logical(1L)
    )
    nominated_rows <- recurrence$recurrence[
        recurrence$recurrence$nominated_reference,
        ,
        drop = FALSE
    ]
    nominated_matched <- nominated_rows$matched[
        match(
            vapply(replicates, function(x) x$replicate, integer(1L)),
            nominated_rows$replicate
        )
    ]
    nominated_matched[is.na(nominated_matched)] <- FALSE
    completed <- computationally_completed &
        proposal_completed &
        nominated_matched
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
        subspace_angle_summary = .summarize_subspace_angles(replicates),
        failure_summary = list(
            n_requested = as.integer(length(replicates)),
            n_completed = as.integer(sum(completed)),
            n_failed = as.integer(sum(!completed)),
            n_computational_failures =
                as.integer(sum(!computationally_completed)),
            n_proposal_abstentions =
                as.integer(sum(proposal_abstained)),
            n_proposal_execution_failures =
                as.integer(sum(proposal_failed)),
            n_nominated_unmatched =
                as.integer(sum(matching_reached & !nominated_matched)),
            failure_fraction = mean(!completed),
            computational_failure_fraction =
                mean(!computationally_completed),
            proposal_abstention_fraction = mean(proposal_abstained),
            proposal_execution_failure_fraction = mean(proposal_failed),
            nominated_unmatched_fraction =
                mean(matching_reached & !nominated_matched),
            failed_replicates = as.integer(vapply(
                replicates,
                function(x) x$replicate,
                integer(1L)
            )[!completed])
        ),
        thresholds = list(),
        effect_equivalent_candidates = integer(),
        effect_equivalence_status = "not-calibrated",
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
    run_replicate <- .run_identifiability_replicate
    failed_replicate <- .failed_identifiability_replicate
    replicates <- future.apply::future_lapply(
        seq_len(n_resamples),
        function(index) {
            tryCatch(
                run_replicate(
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
                    failed_replicate(
                        index,
                        plan$replicate_seeds[[index]],
                        plan$draws[[index]]$source_primary,
                        "decomposition",
                        conditionMessage(error),
                        plan$draws[[index]]$replicate_subject
                    )
                }
            )
        },
        future.seed = TRUE
    )
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
    axis_rows <- data.frame(
        surface = "Individual-axis recurrence",
        evidence_index = recurrence$replicate,
        value = as.numeric(recurrence$matched),
        series = paste0("Component ", recurrence$reference_component),
        focal = recurrence$nominated_reference,
        stringsAsFactors = FALSE
    )
    index_rows <- data.frame(
        surface = "Index recurrence",
        evidence_index = recurrence$replicate,
        value = as.numeric(recurrence$index_recurrent),
        series = paste0("Component ", recurrence$reference_component),
        focal = recurrence$nominated_reference,
        stringsAsFactors = FALSE
    )
    orientation_rows <- data.frame(
        surface = "Orientation recurrence",
        evidence_index = recurrence$replicate,
        value = as.numeric(recurrence$orientation_recurrent),
        series = paste0("Component ", recurrence$reference_component),
        focal = recurrence$nominated_reference,
        stringsAsFactors = FALSE
    )
    rank_rows <- data.frame(
        surface = "Proposal rank",
        evidence_index = recurrence$replicate,
        value = recurrence$proposal_rank,
        series = paste0("Component ", recurrence$reference_component),
        focal = recurrence$nominated_reference,
        stringsAsFactors = FALSE
    )
    angle_summary <- evidence$subspace_angle_summary
    angle_rows <- data.frame(
        surface = "Subspace angle",
        evidence_index = angle_summary$replicate,
        value = angle_summary$maximum_angle_degrees,
        series = paste0("Dimension ", angle_summary$dimension),
        focal = FALSE,
        stringsAsFactors = FALSE
    )
    completion_rows <- data.frame(
        surface = "Replicate completion",
        evidence_index = vapply(
            evidence$replicates,
            function(x) x$replicate,
            integer(1L)
        ),
        value = as.numeric(!vapply(
            evidence$replicates,
            function(x) {
                x$replicate %in%
                    evidence$failure_summary$failed_replicates
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
            axis_rows,
            index_rows,
            orientation_rows,
            rank_rows,
            angle_rows,
            completion_rows
        )
    )
    surface_data <- do.call(rbind, rows)
    surface_data$surface <- factor(
        surface_data$surface,
        levels = c(
            "Spectrum", "Matching similarity", "Assignment margin",
            "Individual-axis recurrence", "Index recurrence",
            "Orientation recurrence", "Proposal rank", "Subspace angle",
            "Replicate completion"
        )
    )
    rownames(surface_data) <- NULL
    surface_data
}

.identifiability_primary_data <- function(evidence) {
    summary <- evidence$recurrence_summary
    summary_rows <- rbind(
        data.frame(
            surface = "Axis recurrence",
            evidence_index = summary$reference_component,
            value = summary$matched_fraction,
            series = paste0("Component ", summary$reference_component),
            focal = summary$nominated_reference,
            stringsAsFactors = FALSE
        ),
        data.frame(
            surface = "Matching similarity",
            evidence_index = summary$reference_component,
            value = summary$mean_absolute_similarity,
            series = paste0("Component ", summary$reference_component),
            focal = summary$nominated_reference,
            stringsAsFactors = FALSE
        )
    )
    recurrence <- evidence$recurrence
    margin_rows <- data.frame(
        surface = "Assignment margin",
        evidence_index = recurrence$reference_component,
        value = recurrence$assignment_margin,
        series = paste0("Component ", recurrence$reference_component),
        focal = recurrence$nominated_reference,
        stringsAsFactors = FALSE
    )
    angle_summary <- evidence$subspace_angle_summary
    angle_rows <- data.frame(
        surface = "Subspace angle",
        evidence_index = angle_summary$dimension,
        value = angle_summary$maximum_angle_degrees,
        series = paste0("Dimension ", angle_summary$dimension),
        focal = FALSE,
        stringsAsFactors = FALSE
    )
    rows <- Filter(
        function(x) !is.null(x) && nrow(x),
        list(summary_rows, margin_rows, angle_rows)
    )
    primary_data <- do.call(rbind, rows)
    primary_data$surface <- factor(
        primary_data$surface,
        levels = c(
            "Axis recurrence", "Matching similarity",
            "Assignment margin", "Subspace angle"
        )
    )
    rownames(primary_data) <- NULL
    primary_data
}

.identifiability_caption_context <- function(proposal) {
    provenance <- proposal@provenance
    dataset <- provenance$dataset_id
    layer <- provenance$layer
    target <- proposal@target_field
    target_type <- provenance$target_type
    target_context <- switch(
        target_type,
        binary = sprintf(
            "the %s versus %s contrast",
            proposal@comparison_level,
            proposal@reference_level
        ),
        continuous = sprintf(
            "the declared %s association with %s",
            provenance$continuous_direction,
            target
        ),
        ordered = sprintf(
            "differences across %s in the declared order %s",
            target,
            paste(provenance$ordered_levels, collapse = " < ")
        ),
        target
    )
    context <- sprintf(
        "Axis identifiability was assessed for %s%s%s.",
        target_context,
        if (.is_scalar_nonempty_text(layer)) {
            sprintf(" using %s data", layer)
        } else {
            ""
        },
        if (.is_scalar_nonempty_text(dataset)) {
            sprintf(" from the %s", dataset)
        } else {
            ""
        }
    )
    design <- provenance$sampling_design
    design_label <- c(
        cross_sectional = "cross-sectional biological samples",
        independent_time_course =
            "independent biological samples collected over time",
        longitudinal = "repeated observations of complete subject trajectories"
    )[[design]]
    if (!is.null(design_label)) {
        context <- c(
            context,
            sprintf("The analysis used %s.", design_label)
        )
    }
    time_field <- provenance$time_field
    if (.is_scalar_nonempty_text(time_field)) {
        time_unit <- provenance$time_unit
        context <- c(context, if (.is_scalar_nonempty_text(time_unit)) {
            sprintf(
                "Observed time was recorded as %s in %s.",
                time_field,
                time_unit
            )
        } else {
            sprintf("Observed time was recorded as %s.", time_field)
        })
    }
    subject_field <- provenance$subject_field
    if (.is_scalar_nonempty_text(subject_field)) {
        context <- c(
            context,
            sprintf(
                "Repeated observations were grouped by %s.",
                subject_field
            )
        )
    }
    nuisance_fields <- provenance$nuisance_fields
    if (is.character(nuisance_fields) && length(nuisance_fields)) {
        context <- c(
            context,
            sprintf(
                "The analysis adjusted for %s.",
                paste(nuisance_fields, collapse = ", ")
            )
        )
    }
    paste(context, collapse = " ")
}

.identifiability_caption <- function(proposal, evidence, view) {
    resampling_description <- c(
        `target-stratified-biological-unit-bootstrap` =
            paste(
                "a stratified bootstrap of biological sampling units",
                "within target groups"
            ),
        `condition-time-cell-bootstrap` =
            paste(
                "a bootstrap of biological sampling units within",
                "condition-by-time cells"
            ),
        `condition-stratified-subject-trajectory-bootstrap` =
            paste(
                "a stratified bootstrap of complete subject trajectories",
                "within conditions"
            )
    )[[evidence$resampling$method]]
    if (is.null(resampling_description)) {
        resampling_description <- evidence$resampling$method
    }
    count_phrase <- function(value, singular, plural) {
        sprintf("%d %s", value, if (value == 1L) singular else plural)
    }
    completion <- if (evidence$n_completed == evidence$n_requested) {
        sprintf(
            "All %s bootstrap replicates completed the full assessment.",
            evidence$n_requested
        )
    } else {
        sprintf(
            paste(
                "Of %s bootstrap replicates, %s completed the full",
                "assessment; %s did not."
            ),
            evidence$n_requested,
            evidence$n_completed,
            evidence$n_requested - evidence$n_completed
        )
    }
    incomplete <- if (evidence$n_completed < evidence$n_requested) {
        summary <- evidence$failure_summary
        paste(
            "The incomplete assessments comprised",
            paste0(count_phrase(
                summary$n_computational_failures,
                "resample in which decomposition could not be evaluated",
                "resamples in which decomposition could not be evaluated"
            ), ","),
            paste0(count_phrase(
                summary$n_proposal_abstentions,
                "resample in which no component could be nominated",
                "resamples in which no component could be nominated"
            ), ","),
            paste0(count_phrase(
                summary$n_proposal_execution_failures,
                "resample in which component nomination could not be evaluated",
                "resamples in which component nomination could not be evaluated"
            ), ","),
            "and",
            paste0(count_phrase(
                summary$n_nominated_unmatched,
                "resample in which the nominated axis could not be matched",
                "resamples in which the nominated axis could not be matched"
            ), ".")
        )
    } else {
        NULL
    }
    single_axis <- nrow(evidence$recurrence_summary) == 1L
    assignment_description <- if (single_axis) {
        paste(
            "(C) For K=1, no competing axis exists, so assignment margins",
            "are undefined rather than zero."
        )
    } else if (identical(view, "primary")) {
        paste(
            "(C) Assignment margins are shown for individual resamples;",
            "smaller values indicate greater ambiguity between competing",
            "one-to-one assignments."
        )
    } else {
        paste(
            "(C) Assignment margins quantify ambiguity between competing",
            "one-to-one assignments."
        )
    }
    panel_description <- if (single_axis && identical(view, "primary")) {
        paste(
            "(A) Loading agreement is the distribution of absolute",
            "feature-loading cosine similarities across completed resamples;",
            "values approaching one indicate closer agreement.",
            "(B) Subspace rotation is the distribution of one-dimensional",
            "principal angles; values approaching zero indicate less",
            "rotation. Black diamonds mark medians, black bars span the middle",
            "50%, and grey points represent completed resamples."
        )
    } else if (single_axis && identical(view, "diagnostic")) {
        paste(
            "(A) Each point represents one completed resample, locating its",
            "absolute feature-loading cosine similarity against the magnitude",
            "of its repeated biological-effect estimate. This shows whether",
            "geometric recovery and the declared biological contrast vary",
            "together without treating either quantity as an acceptance rule."
        )
    } else if (identical(view, "primary")) {
        paste(
            "(A) Axis recurrence is the proportion of resamples assigned",
            "to the corresponding discovery axis.",
            "(B) Mean absolute feature-loading cosine similarity measures",
            "agreement between matched resampled and discovery axes;",
            "values approaching one indicate closer agreement.",
            assignment_description,
            "(D) The largest principal angle is shown for each enclosing",
            "subspace dimension; smaller angles indicate greater subspace",
            "recurrence."
        )
    } else {
        paste(
            "(A) The singular-value spectrum is shown for each molecular",
            "layer.",
            "(B) Absolute feature-loading cosine similarity measures",
            "agreement between matched axes.",
            assignment_description,
            "(D) Individual-axis recurrence records, for every discovery",
            "component, whether its axis was recovered in each resample.",
            "(E) Component-index recurrence records whether its original",
            "component index was retained.",
            "(F) Orientation recurrence records whether each sign-corrected",
            "biological-effect direction agrees with its discovery estimate.",
            "(G) Proposal rank records the repeated biological-effect",
            "ranking.",
            "(H) Largest principal angles summarize recurrence of each",
            "enclosing subspace dimension.",
            "(I) Replicate completion equals one only when the complete",
            "assessment succeeded."
        )
    }
    encodings <- paste(
        if (single_axis && identical(view, "primary")) {
            paste(
                "Because K=1 contains only the nominated component, no",
                "comparison-axis or assignment-margin encoding is shown."
            )
        } else if (single_axis && identical(view, "diagnostic")) {
            "Grey points represent completed biological-unit resamples."
        } else if (single_axis) {
            "The red mark denotes the sole nominated discovery component."
        } else if (identical(view, "primary")) {
            paste(
                "Red triangles denote the nominated component and black",
                "circles denote the remaining candidate components in",
                "panels A-C."
            )
        } else {
            paste(
                "Larger red points denote the nominated component and",
                "smaller black points denote the remaining candidate",
                "components in component-indexed panels."
            )
        },
        "Components were matched jointly by maximizing total absolute",
        "feature-loading cosine similarity."
    )
    calibrated <- !identical(evidence$structured_outcome, "not-calibrated") &&
        is.character(evidence$calibration_digest) &&
        length(evidence$calibration_digest) == 1L &&
        !is.na(evidence$calibration_digest) &&
        nzchar(evidence$calibration_digest)
    boundary <- .identifiability_caption_conclusion(evidence, calibrated)
    caption <- paste(
        c(
            "Component-axis identifiability under design-preserving resampling.",
            .identifiability_caption_context(proposal),
            sprintf(
                "%s Resampling used %s.",
                completion,
                resampling_description
            ),
            incomplete,
            panel_description,
            encodings,
            boundary
        ),
        collapse = " "
    )
    paste(strwrap(caption, width = 96L), collapse = "\n")
}

.identifiability_caption_conclusion <- function(evidence, calibrated) {
    conclusions <- c(
        `not-calibrated` = paste(
            "No stability threshold was applied. The nominated axis",
            "therefore remains exploratory and must not be interpreted as",
            "stably recovered."
        ),
        `stable-axis` = paste(
            "Under the prespecified calibrated criteria, the nominated",
            "individual axis was recovered and is eligible for",
            "one-dimensional interpretation."
        ),
        `stable-subspace/no-stable-axis` = paste(
            "Under the prespecified calibrated criteria, the enclosing",
            "subspace was recovered but no individual axis was recovered;",
            "interpretation must therefore remain at the subspace level."
        ),
        `no-stable-target-structure` = paste(
            "Under the prespecified calibrated criteria, no stable",
            "target-associated axis or enclosing subspace was recovered."
        ),
        `outside-calibrated-operating-region` = paste(
            "The design lies outside the prespecified calibrated operating",
            "region, so no calibrated recovery claim can be made."
        ),
        `unique-winner-failure` = paste(
            "The biological-effect ranking did not identify a unique",
            "candidate component, so no individual axis can be nominated."
        ),
        `non-identifiable-design` = paste(
            "The sampling design does not identify an individual axis, so",
            "one-dimensional interpretation is not supported."
        )
    )
    conclusion <- unname(conclusions[[evidence$structured_outcome]])
    if (is.null(conclusion)) {
        conclusion <- sprintf(
            "The recorded assessment outcome was %s.",
            .identifiability_outcome_label(evidence$structured_outcome)
        )
    }
    paste(
        conclusion,
        if (calibrated) {
            paste(
                "This numerical result does not, by itself, establish",
                "biological validity."
            )
        } else {
            paste(
                "These results describe numerical identifiability and do",
                "not, by themselves, establish biological validity."
            )
        }
    )
}

.identifiability_outcome_label <- function(outcome) {
    labels <- c(
        `not-calibrated` = "Calibration not yet available",
        `stable-axis` = "Individual axis recovered",
        `stable-subspace/no-stable-axis` =
            "Enclosing subspace recovered; individual axis unresolved",
        `no-stable-target-structure` =
            "No stable target-associated structure recovered",
        `outside-calibrated-operating-region` =
            "Design outside the calibrated operating region",
        `unique-winner-failure` =
            "No unique effect-ranked component identified",
        `non-identifiable-design` =
            "Design does not identify an individual axis"
    )
    label <- unname(labels[[outcome]])
    if (is.null(label)) gsub("-", " ", outcome, fixed = TRUE) else label
}

#' Plot component-axis identifiability evidence
#'
#' For a single-component decomposition, the default primary view summarizes
#' loading agreement and one-dimensional subspace rotation, while the
#' diagnostic view relates loading agreement to the repeated biological-effect
#' magnitude within resamples. For multi-component decompositions, the primary
#' and diagnostic views retain the component and subspace summaries. The audit
#' view exposes the complete nine-panel evidence surface. Values are shown
#' without uncalibrated stability thresholds.
#'
#' @param proposal a `ComponentProposal` assessed by
#'   `assess_component_identifiability()`
#' @param view one of `"primary"` (the default scientific summary),
#'   `"diagnostic"` (the focused diagnostic), or `"audit"` (the complete
#'   nine-panel evidence surface)
#' @return a `ggplot2` object whose separate scientific figure caption is
#'   available through [scientific_caption()]
#' @export
plot_component_identifiability <- function(
    proposal,
    view = c("primary", "diagnostic", "audit")
) {
    view <- match.arg(view)
    evidence <- proposal_identifiability(proposal)
    single_axis <- nrow(evidence$recurrence_summary) == 1L
    surface_data <- if (identical(view, "primary")) {
        .identifiability_primary_data(evidence)
    } else {
        .identifiability_surface_data(evidence)
    }
    palette <- landscapeR_palette("semantic")
    subtitle <- paste(strwrap(sprintf(
        "Evidence outcome: %s; full-assessment completion: %d/%d",
        .identifiability_outcome_label(evidence$structured_outcome),
        evidence$n_completed,
        evidence$n_requested
    ), width = 74L), collapse = "\n")
    caption <- .identifiability_caption(proposal, evidence, view)
    colour_scale <- ggplot2::scale_colour_manual(
        values = c(
            `FALSE` = unname(palette[["ink"]]),
            `TRUE` = unname(palette[["focal"]])
        ),
        breaks = c(FALSE, TRUE),
        labels = if (single_axis) {
            c("Context evidence", "Nominated component")
        } else {
            c("Comparison components", "Nominated component")
        },
        name = "Discovery component"
    )
    if (single_axis && view %in% c("primary", "diagnostic")) {
        recurrence <- evidence$recurrence[
            evidence$recurrence$nominated_reference,
            c("replicate", "absolute_similarity"),
            drop = FALSE
        ]
        angles <- evidence$subspace_angle_summary[
            evidence$subspace_angle_summary$dimension == 1L,
            c("replicate", "maximum_angle_degrees"),
            drop = FALSE
        ]
        replicate_data <- merge(
            recurrence,
            angles,
            by = "replicate",
            all = FALSE
        )
        effect_magnitude <- vapply(
            evidence$replicates,
            function(replicate) {
                ranking <- replicate$ranking
                assignment <- replicate$assignment
                if (!is.data.frame(ranking) || !nrow(ranking) ||
                        !is.data.frame(assignment) || !nrow(assignment)) {
                    return(NA_real_)
                }
                selected <- ranking$component ==
                    assignment$replicate_component[[1L]]
                values <- ranking$effect_magnitude[selected]
                if (length(values) == 1L && is.finite(values)) {
                    as.numeric(values)
                } else {
                    NA_real_
                }
            },
            numeric(1L)
        )
        effect_data <- data.frame(
            replicate = seq_along(evidence$replicates),
            effect_magnitude = effect_magnitude
        )
        replicate_data <- merge(
            replicate_data,
            effect_data,
            by = "replicate",
            all.x = TRUE
        )
        if (identical(view, "diagnostic")) {
            plot <- ggplot2::ggplot(
                replicate_data,
                ggplot2::aes(
                    x = absolute_similarity,
                    y = effect_magnitude
                )
            ) +
                ggplot2::geom_point(
                    colour = unname(palette[["nuisance"]]),
                    alpha = 0.65,
                    size = 1.8
                ) +
                ggplot2::labs(
                    title = "A  Replicate-level recovery map",
                    subtitle = subtitle,
                    x = "Absolute loading cosine (larger is better)",
                    y = "Repeated biological-effect magnitude"
                ) +
                theme_landscapeR(square = TRUE)
            return(.with_scientific_caption(plot, caption))
        }
        interval_data <- function(values, surface) {
            if (!length(values)) {
                return(data.frame(
                    surface = character(), xmin = numeric(), xmax = numeric(),
                    value = numeric(), y = numeric()
                ))
            }
            data.frame(
                surface = surface,
                xmin = unname(stats::quantile(values, 0.25, na.rm = TRUE)),
                xmax = unname(stats::quantile(values, 0.75, na.rm = TRUE)),
                value = stats::median(values, na.rm = TRUE),
                y = 1
            )
        }
        distribution_data <- rbind(
            data.frame(
                surface = rep(
                    "A  Loading agreement (larger is better)",
                    nrow(replicate_data)
                ),
                value = replicate_data$absolute_similarity,
                y = rep(1, nrow(replicate_data))
            ),
            data.frame(
                surface = rep(
                    "B  Subspace rotation (smaller is better)",
                    nrow(replicate_data)
                ),
                value = replicate_data$maximum_angle_degrees,
                y = rep(1, nrow(replicate_data))
            )
        )
        interval_data <- rbind(
            interval_data(
                replicate_data$absolute_similarity,
                "A  Loading agreement (larger is better)"
            ),
            interval_data(
                replicate_data$maximum_angle_degrees,
                "B  Subspace rotation (smaller is better)"
            )
        )
        distribution_data$surface <- factor(
            distribution_data$surface,
            levels = c(
                "A  Loading agreement (larger is better)",
                "B  Subspace rotation (smaller is better)"
            )
        )
        interval_data$surface <- factor(
            interval_data$surface,
            levels = levels(distribution_data$surface)
        )
        plot <- ggplot2::ggplot(
            distribution_data,
            ggplot2::aes(x = value, y = y)
        ) +
            ggplot2::geom_jitter(
                width = 0,
                height = 0.08,
                colour = unname(palette[["nuisance"]]),
                alpha = 0.45,
                size = 1.1
            ) +
            ggplot2::geom_segment(
                data = interval_data,
                ggplot2::aes(x = xmin, xend = xmax, y = y, yend = y),
                inherit.aes = FALSE,
                colour = unname(palette[["ink"]]),
                linewidth = 1.5
            ) +
            ggplot2::geom_point(
                data = interval_data,
                ggplot2::aes(x = value, y = y),
                inherit.aes = FALSE,
                colour = unname(palette[["ink"]]),
                shape = 18,
                size = 3
            ) +
            ggplot2::facet_wrap(
                ggplot2::vars(surface),
                ncol = 1L,
                scales = "free_x"
            ) +
            ggplot2::scale_y_continuous(NULL, breaks = NULL) +
            ggplot2::labs(
                title = "Single-axis recovery summary",
                subtitle = subtitle,
                x = "Observed value"
            ) +
            theme_landscapeR(square = FALSE)
        return(.with_scientific_caption(plot, caption))
    }
    if (identical(view, "primary")) {
        shape_scale <- ggplot2::scale_shape_manual(
            values = c(`FALSE` = 16, `TRUE` = 17),
            breaks = c(FALSE, TRUE),
            labels = if (single_axis) {
                c("Context evidence", "Nominated component")
            } else {
                c("Comparison components", "Nominated component")
            },
            name = "Discovery component"
        )
        summary_surfaces <- c("Axis recurrence", "Matching similarity")
        primary_panel_labels <- c(
            `Axis recurrence` = "A  Axis recurrence",
            `Matching similarity` = "B  Matching similarity",
            `Assignment margin` = "C  Assignment margin",
            `Subspace angle` = "D  Subspace angle"
        )
        bounded <- data.frame(
            surface = factor(
                rep(summary_surfaces, each = 2L),
                levels = levels(surface_data$surface)
            ),
            evidence_index = NA_real_,
            value = rep(c(0, 1), length(summary_surfaces))
        )
        undefined_margin <- data.frame(
            surface = factor(
                "Assignment margin",
                levels = levels(surface_data$surface)
            ),
            evidence_index = evidence$nominated_component,
            value = 0.5,
            label = "Not applicable\nNo competing axis"
        )
        plot <- ggplot2::ggplot(
                surface_data,
                ggplot2::aes(
                    x = evidence_index,
                    y = value,
                    colour = focal,
                    shape = focal
                )
            ) +
                ggplot2::geom_blank(
                    data = bounded,
                    ggplot2::aes(x = evidence_index, y = value),
                    inherit.aes = FALSE
                ) +
                ggplot2::geom_point(
                    data = surface_data[
                        surface_data$surface %in% summary_surfaces,
                        ,
                        drop = FALSE
                    ],
                    size = 2.2,
                    alpha = 0.9,
                    na.rm = TRUE
                ) +
                ggplot2::geom_jitter(
                    data = surface_data[
                        !surface_data$surface %in% summary_surfaces,
                        ,
                        drop = FALSE
                    ],
                    width = 0.12,
                    height = 0,
                    size = 1.2,
                    alpha = 0.5,
                    na.rm = TRUE
                ) +
                ggplot2::facet_wrap(
                    ggplot2::vars(surface),
                    scales = "free_y",
                    ncol = 2L,
                    labeller = ggplot2::as_labeller(primary_panel_labels)
                ) +
                colour_scale +
                shape_scale +
                ggplot2::labs(
                    title = "Axis identifiability summary",
                    subtitle = subtitle,
                    x = "Discovery component or subspace dimension",
                    y = "Observed value",
                    colour = "Discovery component",
                    shape = "Discovery component"
                ) +
                theme_landscapeR(square = FALSE) +
                ggplot2::theme(
                    legend.position = "bottom"
                )
        if (single_axis) {
            plot <- plot + ggplot2::geom_text(
                data = undefined_margin,
                ggplot2::aes(
                    x = evidence_index,
                    y = value,
                    label = label
                ),
                inherit.aes = FALSE,
                size = 3,
                colour = unname(palette[["nuisance"]])
            )
        }
        return(.with_scientific_caption(plot, caption))
    }
    binary_limits <- data.frame(
        surface = factor(
            rep(
                c(
                    "Individual-axis recurrence",
                    "Index recurrence",
                    "Orientation recurrence",
                    "Replicate completion"
                ),
                each = 2L
            ),
            levels = levels(surface_data$surface)
        ),
        evidence_index = NA_real_,
        value = rep(c(0, 1), 4L)
    )
    series_levels <- unique(as.character(surface_data$series))
    series_shapes <- rep(
        c(16, 17, 15, 3, 7, 8, 0:2, 4:6, 9:14),
        length.out = length(series_levels)
    )
    names(series_shapes) <- series_levels
    diagnostic_panel_labels <- c(
        Spectrum = "A  Spectrum",
        `Matching similarity` = "B  Match cosine",
        `Assignment margin` = "C  Margin",
        `Individual-axis recurrence` = "D  Axis recurrence",
        `Index recurrence` = "E  Index recurrence",
        `Orientation recurrence` = "F  Orientation",
        `Proposal rank` = "G  Proposal rank",
        `Subspace angle` = "H  Subspace angle",
        `Replicate completion` = "I  Completion"
    )
    diagnostic_margin <- data.frame(
        surface = factor(
            "Assignment margin",
            levels = levels(surface_data$surface)
        ),
        evidence_index = median(surface_data$evidence_index, na.rm = TRUE),
        value = 0.5,
        label = "Not applicable\nNo competing axis"
    )
    spectrum_line <- surface_data[
        surface_data$surface == "Spectrum",
        ,
        drop = FALSE
    ]
    plot <- ggplot2::ggplot(
        surface_data,
        ggplot2::aes(
            x = evidence_index,
            y = value,
            colour = focal,
            shape = series
        )
    ) +
        ggplot2::geom_blank(
            data = binary_limits,
            ggplot2::aes(x = evidence_index, y = value),
            inherit.aes = FALSE
        ) +
        ggplot2::geom_point(
            data = surface_data[
                !surface_data$surface %in% c(
                    "Individual-axis recurrence",
                    "Index recurrence",
                    "Orientation recurrence",
                    "Replicate completion"
                ),
                ,
                drop = FALSE
            ],
            ggplot2::aes(size = focal),
            alpha = 0.65,
            na.rm = TRUE
        ) +
        ggplot2::geom_jitter(
            data = surface_data[
                surface_data$surface %in% c(
                    "Individual-axis recurrence",
                    "Index recurrence",
                    "Orientation recurrence"
                ),
                ,
                drop = FALSE
            ],
            ggplot2::aes(size = focal),
            width = 0.15,
            height = 0,
            alpha = 0.55,
            na.rm = TRUE
        ) +
        ggplot2::geom_jitter(
            data = surface_data[
                surface_data$surface == "Replicate completion",
                ,
                drop = FALSE
            ],
            ggplot2::aes(size = focal),
            width = 0.15,
            height = 0,
            alpha = 0.55,
            na.rm = TRUE
        ) +
        ggplot2::facet_wrap(
            ggplot2::vars(surface),
            scales = "free",
            ncol = 3L,
            labeller = ggplot2::as_labeller(diagnostic_panel_labels)
        ) +
        colour_scale +
        ggplot2::scale_shape_manual(
            values = series_shapes,
            name = "Evidence series"
        ) +
        ggplot2::scale_size_manual(
            values = c(`FALSE` = 0.8, `TRUE` = 1.5),
            guide = "none"
        ) +
        ggplot2::guides(
            shape = ggplot2::guide_legend(
                nrow = 4L,
                byrow = TRUE,
                order = 1L
            ),
            colour = ggplot2::guide_legend(
                nrow = 2L,
                byrow = TRUE,
                order = 2L
            )
        ) +
        ggplot2::labs(
            title = "Component identifiability diagnostics",
            subtitle = subtitle,
            x = "Evidence replicate or component",
            y = "Observed value",
            colour = "Discovery component",
            shape = "Evidence series",
            size = "Nominated component"
        ) +
        theme_landscapeR(square = FALSE) +
        ggplot2::theme(
            legend.position = "bottom",
            legend.box = "vertical",
            strip.text = ggplot2::element_text(size = 7.5)
        )
    if (single_axis) {
        plot <- plot + ggplot2::geom_text(
            data = diagnostic_margin,
            ggplot2::aes(
                x = evidence_index,
                y = value,
                label = label
            ),
            inherit.aes = FALSE,
            size = 2.3,
            colour = unname(palette[["nuisance"]])
        )
    }
    if (nrow(spectrum_line) > 1L) {
        plot <- plot + ggplot2::geom_line(
            data = spectrum_line,
            ggplot2::aes(group = series),
            linewidth = 0.45,
            alpha = 0.75,
            na.rm = TRUE
        )
    }
    .with_scientific_caption(plot, caption)
}
