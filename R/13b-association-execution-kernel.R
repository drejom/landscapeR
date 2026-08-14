# Normalized association execution kernel (issue #210)

.stop_association_execution <- function(message, call = sys.call(-1L)) {
    stop(structure(
        list(message = message, call = call),
        class = c(
            "association_execution_error",
            "landscapeR_validation_error",
            "error",
            "condition"
        )
    ))
}

.association_execution_attempt <- function(expr, phase) {
    tryCatch(
        force(expr),
        error = function(error) {
            if (inherits(error, "landscapeR_validation_error")) stop(error)
            .stop_association_execution(sprintf(
                "association execution adapter failed during %s: %s",
                phase,
                conditionMessage(error)
            ))
        }
    )
}

.resolve_assoc_strategy <- function(data, values, resolver) {
    if (!is(data, "StateTransitionData") || !is.function(resolver)) {
        .stop_association_execution(
            "association strategy resolution requires data and a resolver"
        )
    }
    strategy <- .association_execution_attempt(
        resolver(data, values),
        "strategy resolution"
    )
    if (is.null(strategy)) return(NULL)
    contract <- .validated_association_contract(strategy)
    target_type <- .metadata_target_type(values)
    if (!data@sampling_design@kind %in% contract$sampling_designs ||
            !target_type %in% contract$target_types) {
        .stop_association_execution(paste(
            "resolved association strategy contract does not support",
            sprintf("design '%s' and target '%s'", data@sampling_design@kind, target_type)
        ))
    }
    list(
        strategy = strategy,
        id = association_strategy_id(strategy),
        contract = contract
    )
}

.new_assoc_execution_adapter <- function(
    id,
    sampling_design,
    prepare,
    execute_component
) {
    adapter <- structure(
        list(
            version = "1.0.0",
            id = id,
            sampling_design = sampling_design,
            prepare = prepare,
            execute_component = execute_component
        ),
        class = "landscapeR_association_execution_adapter"
    )
    .validate_assoc_exec_adapter(adapter)
    adapter
}

.validate_assoc_exec_adapter <- function(adapter) {
    required <- c(
        "version", "id", "sampling_design", "prepare", "execute_component"
    )
    if (!inherits(adapter, "landscapeR_association_execution_adapter") ||
            !identical(names(adapter), required)) {
        .stop_association_execution(paste(
            "association execution adapter must contain exactly:",
            paste(required, collapse = ", ")
        ))
    }
    scalar_fields <- c("version", "id", "sampling_design")
    if (any(!vapply(adapter[scalar_fields], .is_scalar_nonempty_text, logical(1L)))) {
        .stop_association_execution(
            "association execution adapter identity fields must be non-empty strings"
        )
    }
    callback_fields <- c("prepare", "execute_component")
    if (any(!vapply(adapter[callback_fields], is.function, logical(1L)))) {
        .stop_association_execution(
            "association execution adapter callbacks must be functions"
        )
    }
    invisible(TRUE)
}

.validate_assoc_exec_plan <- function(plan, adapter) {
    required <- c(
        "coordinate_matrix", "component_labels", "work_items", "state",
        "strategy_contracts", "exclusion_rows"
    )
    if (!is.list(plan) || !identical(names(plan), required)) {
        .stop_association_execution(paste(
            "association execution preparation must contain exactly:",
            paste(required, collapse = ", ")
        ))
    }
    coordinates <- plan$coordinate_matrix
    if (!is.matrix(coordinates) || !is.numeric(coordinates) ||
            !length(coordinates) || any(!is.finite(coordinates))) {
        .stop_association_execution(
            "association execution coordinates must be a non-empty finite numeric matrix"
        )
    }
    labels <- plan$component_labels
    if (!is.character(labels) || length(labels) != ncol(coordinates) ||
            anyNA(labels) || any(!nzchar(labels)) || anyDuplicated(labels)) {
        .stop_association_execution(paste(
            "association execution component labels must be unique non-empty",
            "strings matching the coordinate columns"
        ))
    }
    if (!is.list(plan$work_items) || !length(plan$work_items)) {
        .stop_association_execution(
            "association execution preparation must declare at least one work item"
        )
    }
    work_ids <- vapply(plan$work_items, function(item) {
        if (!is.list(item) || !.is_scalar_nonempty_text(item$id)) {
            .stop_association_execution(
                "each association execution work item must have a non-empty id"
            )
        }
        item$id
    }, character(1L))
    if (anyDuplicated(work_ids)) {
        .stop_association_execution(
            "association execution work-item ids must be unique"
        )
    }
    if (!is.list(plan$state) || !is.list(plan$strategy_contracts) ||
            !is.list(plan$exclusion_rows) ||
            any(!vapply(plan$exclusion_rows, is.data.frame, logical(1L)))) {
        .stop_association_execution(paste(
            "association execution state, strategy contracts, and exclusion",
            "rows must use their declared list forms"
        ))
    }
    if (length(plan$strategy_contracts)) {
        for (contract in plan$strategy_contracts) {
            contract_errors <- .association_contract_errors(contract)
            if (length(contract_errors)) {
                .stop_association_execution(sprintf(
                    "association strategy contract is invalid: %s",
                    paste(contract_errors, collapse = "; ")
                ))
            }
            if (!adapter$sampling_design %in% contract$sampling_designs) {
                .stop_association_execution(paste(
                    "association strategy contract does not support adapter design",
                    adapter$sampling_design
                ))
            }
        }
    }
    invisible(TRUE)
}

.assoc_exec_row_lists <- function(value, field, identity) {
    if (is.data.frame(value)) value <- list(value)
    if (!is.list(value) || any(!vapply(value, is.data.frame, logical(1L)))) {
        .stop_association_execution(sprintf(
            "%s returned invalid %s; expected a data frame or list of data frames",
            identity,
            field
        ))
    }
    value
}

.validate_assoc_component <- function(result, identity) {
    required <- c(
        "association_rows", "observation_rows", "execution_records",
        "scientific_records", "display_records"
    )
    if (!is.list(result) || !identical(names(result), required)) {
        .stop_association_execution(sprintf(
            "%s must return exactly: %s",
            identity,
            paste(required, collapse = ", ")
        ))
    }
    result$association_rows <- .assoc_exec_row_lists(
        result$association_rows,
        "association_rows",
        identity
    )
    result$observation_rows <- .assoc_exec_row_lists(
        result$observation_rows,
        "observation_rows",
        identity
    )
    list_fields <- c("execution_records", "scientific_records", "display_records")
    if (any(!vapply(result[list_fields], is.list, logical(1L)))) {
        .stop_association_execution(sprintf(
            "%s execution, scientific, and display records must be lists",
            identity
        ))
    }
    result
}

.association_execution_bind <- function(rows, empty) {
    if (!length(rows)) return(empty())
    table <- do.call(rbind, rows)
    rownames(table) <- NULL
    table
}

.validate_resample_accounting <- function(associations) {
    required <- c(
        "n_resamples", "resample_failures", "resampling_method",
        "resampling_plan_digest"
    )
    missing <- setdiff(required, names(associations))
    if (length(missing)) {
        .stop_association_execution(paste(
            "association execution rows are missing resampling accounting:",
            paste(missing, collapse = ", ")
        ))
    }
    if (!nrow(associations)) return(invisible(TRUE))
    valid_counts <- is.finite(associations$n_resamples) &
        is.finite(associations$resample_failures) &
        associations$n_resamples >= 0L &
        associations$resample_failures >= 0L &
        associations$resample_failures <= associations$n_resamples
    valid_digest <- associations$n_resamples == 0L |
        (
            !is.na(associations$resampling_plan_digest) &
                nzchar(associations$resampling_plan_digest)
        )
    valid_policy <- !is.na(associations$resampling_method) &
        nzchar(associations$resampling_method) &
        valid_digest
    if (any(!valid_counts) || any(!valid_policy)) {
        .stop_association_execution(
            "association execution rows contain invalid resampling accounting"
        )
    }
    invisible(TRUE)
}

.assoc_exec_cohort_members <- function(associations) {
    if (!nrow(associations) || !".cohort_members" %in% names(associations)) {
        return(.empty_cohort_members())
    }
    members <- do.call(rbind, lapply(seq_len(nrow(associations)), function(i) {
        row_members <- associations$.cohort_members[[i]]
        if (!is.data.frame(row_members) ||
                !all(c("primary_sample", "included") %in% names(row_members))) {
            .stop_association_execution(paste(
                "association execution cohort members must contain",
                "primary_sample and included"
            ))
        }
        data.frame(
            metadata_field = associations$metadata_field[[i]],
            component = associations$component[[i]],
            evidence_variant = associations$evidence_variant[[i]],
            primary_sample = as.character(row_members$primary_sample),
            included = as.logical(row_members$included),
            stringsAsFactors = FALSE
        )
    }))
    rownames(members) <- NULL
    members
}

.assoc_exec_attach_members <- function(associations, cohort_members) {
    if (!nrow(associations)) return(associations)
    if (!is.data.frame(cohort_members)) {
        .stop_association_execution(
            "association execution cohort membership must be a data frame"
        )
    }
    associations$.cohort_members <- I(lapply(
        seq_len(nrow(associations)),
        function(i) {
            members <- cohort_members[
                cohort_members$metadata_field ==
                    associations$metadata_field[[i]] &
                    cohort_members$component == associations$component[[i]] &
                    cohort_members$evidence_variant ==
                        associations$evidence_variant[[i]],
                c("primary_sample", "included"),
                drop = FALSE
            ]
            rownames(members) <- NULL
            members
        }
    ))
    associations
}

.normalize_assoc_execution <- function(results, exclusion_rows) {
    .association_execution_attempt({
        association_rows <- unlist(
            lapply(results, `[[`, "association_rows"),
            recursive = FALSE
        )
        observation_rows <- unlist(
            lapply(results, `[[`, "observation_rows"),
            recursive = FALSE
        )
        associations <- .association_execution_bind(
            association_rows,
            .empty_association_evidence
        )
        observations <- .association_execution_bind(
            observation_rows,
            .empty_observation_evidence
        )
        exclusions <- .association_execution_bind(
            exclusion_rows,
            .empty_exclusion_evidence
        )
        .validate_resample_accounting(associations)
        associations <- .adjust_association_multiplicity(associations)
        cohort_members <- .assoc_exec_cohort_members(associations)
        associations$.cohort_members <- NULL
        records <- lapply(
            c("execution_records", "scientific_records", "display_records"),
            function(field) {
                unlist(lapply(results, `[[`, field), recursive = FALSE)
            }
        )
        names(records) <- c(
            "execution_records", "scientific_records", "display_records"
        )
        c(list(
            associations = associations,
            observations = observations,
            exclusions = exclusions,
            cohort_members = cohort_members
        ), records)
    }, "normalization")
}

.validate_assoc_blueprint <- function(blueprint, sampling_design) {
    required <- c(
        "module", "contract_sampling_design", "version", "dataset_id",
        "associations", "observations", "exclusions", "cohort_members",
        "sampling_design", "input_digest", "state_space_digest",
        "compute_tier", "provenance", "evidence_status"
    )
    if (!is.list(blueprint) || !identical(names(blueprint), required)) {
        .stop_association_execution(paste(
            "association execution finalizer must return exactly:",
            paste(required, collapse = ", ")
        ))
    }
    scalar_text <- c(
        "module", "contract_sampling_design", "version", "dataset_id",
        "input_digest", "state_space_digest", "compute_tier",
        "evidence_status"
    )
    if (any(!vapply(blueprint[scalar_text], .is_scalar_nonempty_text, logical(1L)))) {
        .stop_association_execution(
            "association execution atlas identity fields must be non-empty strings"
        )
    }
    if (!identical(
        blueprint$contract_sampling_design,
        sampling_design
    )) {
        .stop_association_execution(
            "association execution finalizer changed the declared sampling design"
        )
    }
    tables <- c(
        blueprint[c("associations", "observations", "exclusions")],
        list(cohort_members = blueprint$cohort_members)
    )
    if (any(!vapply(tables, is.data.frame, logical(1L))) ||
            !is(blueprint$sampling_design, "SamplingDesign") ||
            !is.list(blueprint$provenance)) {
        .stop_association_execution(
            "association execution finalizer returned invalid atlas data"
        )
    }
    invisible(TRUE)
}

.assoc_exec_build_atlas <- function(blueprint) {
    evidence <- .new_interpretation_evidence(
        module = blueprint$module,
        sampling_design = blueprint$contract_sampling_design,
        associations = blueprint$associations,
        observations = blueprint$observations,
        exclusions = blueprint$exclusions,
        cohort_members = blueprint$cohort_members,
        provenance = blueprint$provenance
    )
    atlas <- new(
        "MetadataAssociationAtlas",
        version = blueprint$version,
        dataset_id = blueprint$dataset_id,
        associations = evidence@associations,
        observations = evidence@observations,
        exclusions = evidence@exclusions,
        sampling_design = blueprint$sampling_design,
        input_digest = blueprint$input_digest,
        state_space_digest = blueprint$state_space_digest,
        compute_tier = blueprint$compute_tier,
        provenance = evidence@provenance,
        evidence_status = blueprint$evidence_status
    )
    validObject(atlas)
    atlas
}

.finalize_assoc_blueprint <- function(blueprint, sampling_design) {
    .association_execution_attempt({
        .validate_assoc_blueprint(blueprint, sampling_design)
        .assoc_exec_build_atlas(blueprint)
    }, "atlas assembly")
}

.execute_assoc_components <- function(adapter, context) {
    .validate_assoc_exec_adapter(adapter)
    if (!is.list(context)) {
        .stop_association_execution(
            "association execution context must be a named list"
        )
    }
    plan <- .association_execution_attempt(
        adapter$prepare(context),
        "preparation"
    )
    if (is(plan, "AssociationAbstention")) return(plan)
    .validate_assoc_exec_plan(plan, adapter)

    results <- list()
    for (work_item in plan$work_items) {
        for (component in seq_len(ncol(plan$coordinate_matrix))) {
            identity <- sprintf(
                "%s[%s:%s]",
                adapter$id,
                work_item$id,
                plan$component_labels[[component]]
            )
            result <- .association_execution_attempt(
                adapter$execute_component(
                    context = context,
                    plan = plan,
                    work_item = work_item,
                    component = as.integer(component),
                    component_label = plan$component_labels[[component]],
                    scores = plan$coordinate_matrix[, component]
                ),
                identity
            )
            if (is(result, "AssociationAbstention")) return(result)
            results[[length(results) + 1L]] <-
                .validate_assoc_component(result, identity)
        }
    }
    normalized <- .normalize_assoc_execution(
        results,
        plan$exclusion_rows
    )
    list(plan = plan, normalized = normalized)
}
