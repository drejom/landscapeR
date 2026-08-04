# Shared component-interpretation evidence boundary (ADR 0020; issue #100)

utils::globalVariables(c("metadata_field", "component_label"))

.association_atlas_columns <- c(
    "metadata_field", "component", "component_label", "estimand",
    "estimate", "effect_magnitude", "reference_level", "comparison_level",
    "n_available", "n_missing", "n_score_ties", "n_target_ties",
    "evidence_variant", "proposal_eligible", "nuisance_fields",
    "cohort_digest", "design_digest", "diagnostic", "p_value", "q_value",
    "effect_conf_low", "effect_conf_high", "n_resamples",
    "resample_failures", "resampling_method", "resampling_plan_digest",
    "evidence_status"
)

.association_observation_columns <- c(
    "metadata_field", "component", "component_label", "sample_index",
    "primary_sample", "metadata_type", "metadata_value", "metadata_numeric",
    "score", "atom_count", "available"
)

.cross_sectional_evidence_version <- "cross-sectional-v1"
.independent_time_evidence_version <- "independent-time-course-v1"
.repeated_time_evidence_version <- "repeated-time-course-v1"

.association_multiplicity_contract <- function() {
    list(
        method = "holm",
        method_label = "Holm",
        family_columns = c("metadata_field", "evidence_variant"),
        family_description = paste(
            "declared components within each metadata field and",
            "evidence variant"
        )
    )
}

.adjust_association_multiplicity <- function(associations) {
    contract <- .association_multiplicity_contract()
    required <- c(contract$family_columns, "p_value", "q_value")
    missing <- setdiff(required, names(associations))
    if (length(missing)) {
        .stop_landscapeR_validation(paste(
            "association multiplicity input is missing:",
            paste(missing, collapse = ", ")
        ))
    }
    if (!nrow(associations)) return(associations)

    family <- do.call(
        interaction,
        c(
            lapply(associations[contract$family_columns], as.character),
            list(drop = TRUE, lex.order = TRUE)
        )
    )
    for (family_level in levels(family)) {
        index <- family == family_level
        associations$q_value[index] <- stats::p.adjust(
            associations$p_value[index],
            method = contract$method
        )
    }
    associations
}

.association_multiplicity_caption <- function(provenance) {
    contract <- provenance$multiplicity
    if (!is.list(contract) ||
        !.is_scalar_nonempty_text(contract$method_label) ||
        !.is_scalar_nonempty_text(contract$family_description)) {
        return("Multiplicity provenance is unavailable")
    }
    sprintf(
        "Raw p-values are retained; q-values use %s correction across %s",
        contract$method_label,
        contract$family_description
    )
}

.interpretation_evidence_versions <- c(
    cross_sectional = .cross_sectional_evidence_version,
    independent_time_course = .independent_time_evidence_version,
    longitudinal = .repeated_time_evidence_version
)

.is_sha256_digest <- function(x) {
    length(x) == 1L && !is.na(x) &&
        grepl("^[[:xdigit:]]{64}$", x)
}

.is_scalar_nonempty_text <- function(x) {
    length(x) == 1L && !is.na(x) && nzchar(x)
}

.association_cohort_digest <- function(primary_sample, complete) {
    digest::digest(
        as.character(primary_sample[complete]),
        algo = "sha256",
        serialize = TRUE
    )
}

.evidence_table_digest <- function(x) {
    digest::digest(x, algo = "sha256", serialize = TRUE)
}

.interpretation_cohort_summary <- function(associations) {
    columns <- c(
        "metadata_field", "component", "evidence_variant",
        "cohort_digest", "n_available", "n_missing"
    )
    summary <- unique(associations[, columns, drop = FALSE])
    rownames(summary) <- NULL
    summary
}

.new_cross_sectional_contract <- function(
    associations,
    observations,
    exclusions,
    cohort_members,
    visual_evidence
) {
    .new_interpretation_contract(
        .cross_sectional_evidence_version,
        "cross_sectional",
        associations,
        observations,
        exclusions,
        cohort_members,
        visual_evidence
    )
}

.new_interpretation_contract <- function(
    version,
    sampling_design,
    associations,
    observations,
    exclusions,
    cohort_members,
    display_evidence
) {
    list(
        version = version,
        sampling_design = sampling_design,
        row_counts = c(
            associations = as.integer(nrow(associations)),
            observations = as.integer(nrow(observations)),
            exclusions = as.integer(nrow(exclusions))
        ),
        digests = c(
            associations = .evidence_table_digest(associations),
            observations = .evidence_table_digest(observations),
            exclusions = .evidence_table_digest(exclusions),
            cohort_members = .evidence_table_digest(cohort_members),
            display_evidence = .evidence_table_digest(display_evidence)
        ),
        cohorts = .interpretation_cohort_summary(associations),
        cohort_members = cohort_members
    )
}

.cross_sectional_evidence_errors <- function(
    associations,
    observations,
    exclusions,
    contract,
    provenance
) {
    errors <- character()
    association_columns <- c(
        "metadata_field", "component", "evidence_variant", "cohort_digest",
        "n_available", "n_missing"
    )
    observation_columns <- c("metadata_field", "component")
    exclusion_columns <- c("metadata_field", "reason")
    if (!all(association_columns %in% names(associations)) ||
            !all(observation_columns %in% names(observations)) ||
            !all(exclusion_columns %in% names(exclusions))) {
        return(
            paste(
                "cross-sectional evidence contract requires normalized",
                "association, observation, and exclusion columns"
            )
        )
    }
    required <- c(
        "version", "sampling_design", "row_counts", "digests", "cohorts",
        "cohort_members"
    )
    if (!is.list(contract) || !all(required %in% names(contract))) {
        return("cross-sectional evidence contract is missing required fields")
    }
    visual <- provenance$visual_evidence
    visual_columns <- list(
        monotone_fit = c(
            "metadata_field", "component_label", "metadata_numeric",
            "monotone_fitted"
        ),
        flexible_fit = c(
            "metadata_field", "component_label", "metadata_numeric",
            "flexible_fitted"
        )
    )
    visual_valid <- is.list(visual) &&
        all(names(visual_columns) %in% names(visual)) &&
        all(vapply(names(visual_columns), function(name) {
            fitted_column <- visual_columns[[name]][[4L]]
            is.data.frame(visual[[name]]) &&
                all(visual_columns[[name]] %in% names(visual[[name]])) &&
                all(is.finite(visual[[name]]$metadata_numeric)) &&
                all(is.finite(visual[[name]][[fitted_column]]))
        }, logical(1L)))
    if (!visual_valid) {
        errors <- c(
            errors,
            "cross-sectional stored visual evidence is invalid"
        )
    } else {
        observation_keys <- unique(paste(
            observations$metadata_field,
            observations$component_label,
            sep = "\r"
        ))
        visual_keys <- unique(unlist(lapply(visual, function(table) {
            paste(table$metadata_field, table$component_label, sep = "\r")
        }), use.names = FALSE))
        if (!all(visual_keys %in% observation_keys)) {
            errors <- c(
                errors,
                "cross-sectional stored visual evidence lacks observations"
            )
        }
    }
    if (!identical(
        contract$version,
        .cross_sectional_evidence_version
    )) {
        errors <- c(errors, "cross-sectional evidence contract version is invalid")
    }
    if (!identical(contract$sampling_design, "cross_sectional")) {
        errors <- c(
            errors,
            "cross-sectional evidence contract sampling design is invalid"
        )
    }
    member_columns <- c(
        "metadata_field", "component", "evidence_variant", "primary_sample",
        "included"
    )
    members_valid <- is.data.frame(contract$cohort_members) &&
        all(member_columns %in% names(contract$cohort_members)) &&
        is.logical(contract$cohort_members$included) &&
        !anyNA(contract$cohort_members$included)
    if (!members_valid) {
        return(c(
            errors,
            "cross-sectional evidence contract cohort members are invalid"
        ))
    }
    association_group_keys <- paste(
        associations$metadata_field,
        associations$component,
        associations$evidence_variant,
        sep = "\r"
    )
    if (anyDuplicated(association_group_keys)) {
        errors <- c(
            errors,
            "cross-sectional association groups must be unique"
        )
    }
    association_group_keys <- unique(association_group_keys)
    member_group_keys <- unique(paste(
        contract$cohort_members$metadata_field,
        contract$cohort_members$component,
        contract$cohort_members$evidence_variant,
        sep = "\r"
    ))
    if (!setequal(association_group_keys, member_group_keys)) {
        errors <- c(
            errors,
            paste(
                "cross-sectional cohort membership groups do not equal",
                "association groups"
            )
        )
    }
    expected <- .new_cross_sectional_contract(
        associations,
        observations,
        exclusions,
        contract$cohort_members,
        provenance$visual_evidence
    )
    if (!identical(contract$row_counts, expected$row_counts)) {
        errors <- c(
            errors,
            "cross-sectional evidence contract row counts do not match evidence"
        )
    }
    if (!identical(contract$digests, expected$digests)) {
        errors <- c(
            errors,
            "cross-sectional evidence contract digests do not match evidence"
        )
    }
    if (!identical(contract$cohorts, expected$cohorts)) {
        errors <- c(
            errors,
            "cross-sectional evidence contract cohorts do not match associations"
        )
    }
    if (nrow(associations)) {
        cohort_digests <- associations$cohort_digest
        invalid_cohort <- !vapply(
            cohort_digests,
            .is_sha256_digest,
            logical(1L)
        )
        if (any(invalid_cohort)) {
            errors <- c(
                errors,
                "cross-sectional association cohorts require SHA-256 digests"
            )
        }
        association_keys <- unique(paste(
            associations$metadata_field,
            associations$component,
            sep = "\r"
        ))
        observation_keys <- unique(paste(
            observations$metadata_field,
            observations$component,
            sep = "\r"
        ))
        if (!all(association_keys %in% observation_keys)) {
            errors <- c(
                errors,
                "cross-sectional associations lack normalized observations"
            )
        }
        for (i in seq_len(nrow(associations))) {
            association <- associations[i, , drop = FALSE]
            members <- contract$cohort_members
            members <- members[
                members$metadata_field == association$metadata_field &
                    members$component == association$component &
                    members$evidence_variant == association$evidence_variant,
                ,
                drop = FALSE
            ]
            member_ids <- as.character(
                members$primary_sample[members$included]
            )
            observed <- observations[
                observations$metadata_field == association$metadata_field &
                    observations$component == association$component,
                ,
                drop = FALSE
            ]
            member_order <- match(
                observed$primary_sample,
                members$primary_sample
            )
            expected_included <- unname(observed$available)
            if (identical(association$evidence_variant, "adjusted")) {
                nuisance_values <- provenance$nuisance_values
                if (!is.list(nuisance_values) || !length(nuisance_values)) {
                    errors <- c(
                        errors,
                        paste(
                            "adjusted cross-sectional cohort requires",
                            "declared nuisance values"
                        )
                    )
                    break
                }
                for (values in nuisance_values) {
                    aligned <- values[match(
                        observed$primary_sample,
                        names(values)
                    )]
                    nuisance_available <- unname(!is.na(aligned))
                    if (is.numeric(aligned)) {
                        nuisance_available <-
                            nuisance_available & is.finite(aligned)
                    }
                    expected_included <-
                        expected_included & nuisance_available
                }
            }
            expected_digest <- .association_cohort_digest(
                member_ids,
                rep(TRUE, length(member_ids))
            )
            if (anyDuplicated(members$primary_sample) ||
                anyNA(member_order) ||
                !setequal(
                    as.character(members$primary_sample),
                    as.character(observed$primary_sample)
                ) ||
                nrow(members) != nrow(observed) ||
                !identical(
                    members$included[member_order],
                    expected_included
                ) ||
                length(member_ids) != association$n_available ||
                association$n_missing != sum(!members$included) ||
                !identical(expected_digest, association$cohort_digest)) {
                errors <- c(
                    errors,
                    paste(
                        "cross-sectional cohort membership does not match",
                        "association evidence"
                    )
                )
                break
            }
        }
    } else if (nrow(contract$cohort_members)) {
        errors <- c(
            errors,
            "cross-sectional cohort members require association evidence"
        )
    }
    errors
}

.time_course_evidence_errors <- function(
    module,
    sampling_design,
    associations,
    observations,
    exclusions,
    contract,
    provenance
) {
    errors <- character()
    association_columns <- c(
        "metadata_field", "component", "evidence_variant", "cohort_digest",
        "n_available", "n_missing"
    )
    observation_columns <- c(
        "metadata_field", "component", "primary_sample"
    )
    exclusion_columns <- c("metadata_field", "reason")
    required_contract <- c(
        "version", "sampling_design", "row_counts", "digests", "cohorts",
        "cohort_members"
    )
    if (!all(association_columns %in% names(associations)) ||
            !all(observation_columns %in% names(observations)) ||
            !all(exclusion_columns %in% names(exclusions))) {
        return(
            paste(
                "time-course evidence contract requires normalized",
                "association, observation, and exclusion columns"
            )
        )
    }
    if (!is.list(contract) ||
            !all(required_contract %in% names(contract))) {
        return("time-course evidence contract is missing required fields")
    }
    if (!identical(contract$version, module)) {
        errors <- c(errors, "time-course evidence contract version is invalid")
    }
    if (!identical(contract$sampling_design, sampling_design)) {
        errors <- c(
            errors,
            "time-course evidence contract sampling design is invalid"
        )
    }
    member_columns <- c(
        "metadata_field", "component", "evidence_variant", "primary_sample",
        "included"
    )
    members <- contract$cohort_members
    if (!is.data.frame(members) ||
            !all(member_columns %in% names(members)) ||
            !is.logical(members$included) ||
            anyNA(members$included)) {
        return(c(
            errors,
            "time-course evidence contract cohort members are invalid"
        ))
    }
    association_keys <- paste(
        associations$metadata_field,
        associations$component,
        associations$evidence_variant,
        sep = "\r"
    )
    if (anyDuplicated(association_keys)) {
        errors <- c(errors, "time-course association groups must be unique")
    }
    member_keys <- unique(paste(
        members$metadata_field,
        members$component,
        members$evidence_variant,
        sep = "\r"
    ))
    if (!setequal(unique(association_keys), member_keys)) {
        errors <- c(
            errors,
            "time-course cohort membership groups do not equal association groups"
        )
    }
    expected <- .new_interpretation_contract(
        module,
        sampling_design,
        associations,
        observations,
        exclusions,
        members,
        .time_course_display_evidence(provenance, sampling_design)
    )
    if (!identical(contract$row_counts, expected$row_counts)) {
        errors <- c(
            errors,
            "time-course evidence contract row counts do not match evidence"
        )
    }
    if (!identical(contract$digests, expected$digests)) {
        errors <- c(
            errors,
            "time-course evidence contract digests do not match evidence"
        )
    }
    if (!identical(contract$cohorts, expected$cohorts)) {
        errors <- c(
            errors,
            "time-course evidence contract cohorts do not match associations"
        )
    }
    observation_keys <- unique(paste(
        observations$metadata_field,
        observations$component,
        sep = "\r"
    ))
    association_observation_keys <- unique(paste(
        associations$metadata_field,
        associations$component,
        sep = "\r"
    ))
    if (!all(association_observation_keys %in% observation_keys)) {
        errors <- c(
            errors,
            "time-course associations lack normalized observations"
        )
    }
    for (i in seq_len(nrow(associations))) {
        association <- associations[i, , drop = FALSE]
        observed <- observations[
            observations$metadata_field == association$metadata_field &
                observations$component == association$component,
            ,
            drop = FALSE
        ]
        group <- members[
            members$metadata_field == association$metadata_field &
                members$component == association$component &
                members$evidence_variant == association$evidence_variant,
            ,
            drop = FALSE
        ]
        included_ids <- as.character(
            group$primary_sample[group$included]
        )
        expected_digest <- .association_cohort_digest(
            included_ids,
            rep(TRUE, length(included_ids))
        )
        member_order <- match(observed$primary_sample, group$primary_sample)
        expected_included <- if (identical(
            association$evidence_variant,
            "pooled-descriptive"
        )) {
            observed$available
        } else {
            observed$primary_sample %in% provenance$analysis_cohort
        }
        if (anyDuplicated(group$primary_sample) ||
                anyNA(member_order) ||
                nrow(group) != nrow(observed) ||
                !setequal(group$primary_sample, observed$primary_sample) ||
                !identical(
                    group$included[member_order],
                    unname(expected_included)
                ) ||
                length(included_ids) != association$n_available ||
                sum(!group$included) != association$n_missing ||
                !identical(expected_digest, association$cohort_digest)) {
            errors <- c(
                errors,
                paste(
                    "time-course cohort membership does not match",
                    "association evidence"
                )
            )
            break
        }
    }
    design <- provenance$time_course_observations
    analysis_cohort <- provenance$analysis_cohort
    if (!is.data.frame(design) ||
            !"primary_sample" %in% names(design) ||
            anyDuplicated(design$primary_sample) ||
            !is.character(analysis_cohort) ||
            !setequal(
                as.character(design$primary_sample),
                analysis_cohort
            ) ||
            !setequal(
                as.character(design$primary_sample),
                as.character(unique(observations$primary_sample))
            )) {
        errors <- c(
            errors,
            "time-course sampling structure does not match normalized observations"
        )
    } else if (identical(sampling_design, "independent_time_course")) {
        required <- c("condition", "observed_time")
        if (!all(required %in% names(design)) ||
                anyNA(design[, required, drop = FALSE]) ||
                any(!is.finite(design$observed_time))) {
            errors <- c(
                errors,
                "independent time-course sampling cells are not recorded"
            )
        }
        cells <- provenance$time_course_cells
        missing_cells <- provenance$time_course_missing_cells
        missing_count <- provenance$time_course_missing_cell_count
        cell_columns <- c(
            "condition", "observed_time", "scaled_time", "count"
        )
        missing_valid <- is.data.frame(cells) &&
            is.data.frame(missing_cells) &&
            all(cell_columns %in% names(cells)) &&
            all(cell_columns %in% names(missing_cells)) &&
            identical(
                missing_cells,
                cells[cells$count == 0L, , drop = FALSE]
            ) &&
            identical(missing_count, as.integer(nrow(missing_cells)))
        if (!missing_valid) {
            errors <- c(
                errors,
                "independent time-course missing-cell evidence is invalid"
            )
        }
    } else if (identical(sampling_design, "longitudinal")) {
        required <- c("subject", "condition", "observed_time")
        structure_valid <- all(required %in% names(design))
        if (structure_valid) {
            structure_valid <-
                anyNA(design[, required, drop = FALSE]) ||
                    any(!nzchar(as.character(design$subject))) ||
                    any(!is.finite(design$observed_time))
            structure_valid <- !structure_valid
        }
        if (!structure_valid) {
            errors <- c(
                errors,
                "repeated-subject trajectory structure is not recorded"
            )
        }
        endpoints <- provenance$time_course_dropout_endpoints
        endpoint_count <- provenance$time_course_dropout_subject_count
        endpoint_columns <- c(
            "primary_sample", "subject", "condition", "observed_time",
            "scaled_time", "dropout"
        )
        endpoint_valid <- is.data.frame(endpoints) &&
            all(endpoint_columns %in% names(endpoints)) &&
            all(endpoints$dropout) &&
            all(endpoints$primary_sample %in% design$primary_sample) &&
            identical(
                endpoint_count,
                as.integer(length(unique(endpoints$subject)))
            )
        if (endpoint_valid) {
            expected_endpoints <- design[design$dropout, , drop = FALSE]
            endpoint_time <- ave(
                expected_endpoints$scaled_time,
                expected_endpoints$subject,
                FUN = max
            )
            expected_endpoints <- expected_endpoints[
                expected_endpoints$scaled_time == endpoint_time,
                ,
                drop = FALSE
            ]
            endpoint_valid <- identical(endpoints, expected_endpoints)
        }
        if (!endpoint_valid) {
            errors <- c(
                errors,
                "repeated time-course dropout endpoint evidence is invalid"
            )
        }
    }
    state <- provenance$time_course_display_state
    state_fields <- c(
        "has_trajectories", "resampling_requested", "requested_searches",
        "complete_searches", "partial_resampling"
    )
    state_valid <- is.list(state) &&
        all(state_fields %in% names(state)) &&
        is.logical(state$has_trajectories) &&
        length(state$has_trajectories) == 1L &&
        is.logical(state$resampling_requested) &&
        length(state$resampling_requested) == 1L &&
        is.integer(state$requested_searches) &&
        length(state$requested_searches) == 1L &&
        is.integer(state$complete_searches) &&
        length(state$complete_searches) == 1L &&
        is.logical(state$partial_resampling) &&
        length(state$partial_resampling) == 1L
    if (!state_valid) {
        errors <- c(errors, "time-course display state is invalid")
    } else {
        expected_state <- .new_time_course_display_state(
            provenance$time_course_display_lines,
            provenance$time_course_rank_summary
        )
        if (!identical(state, expected_state)) {
            errors <- c(
                errors,
                "time-course display state does not match stored evidence"
            )
        }
    }
    errors
}

.new_time_course_display_state <- function(lines, rank_summary) {
    resampling_requested <- nrow(rank_summary) > 0L &&
        any(rank_summary$n_resamples > 0L)
    requested_searches <- if (resampling_requested) {
        max(rank_summary$n_resamples)
    } else {
        0L
    }
    complete_searches <- if (resampling_requested) {
        min(rank_summary$n_complete_searches)
    } else {
        0L
    }
    list(
        has_trajectories = nrow(lines) > 0L,
        resampling_requested = resampling_requested,
        requested_searches = as.integer(requested_searches),
        complete_searches = as.integer(complete_searches),
        partial_resampling = resampling_requested &&
            complete_searches < requested_searches
    )
}

.time_course_display_evidence <- function(provenance, sampling_design) {
    common <- list(
        display_lines = provenance$time_course_display_lines,
        rank_summary = provenance$time_course_rank_summary,
        display_state = provenance$time_course_display_state
    )
    if (identical(sampling_design, "independent_time_course")) {
        return(c(common, list(
            cells = provenance$time_course_cells,
            missing_cells = provenance$time_course_missing_cells,
            missing_cell_count = provenance$time_course_missing_cell_count
        )))
    }
    c(common, list(
        dropout_endpoints = provenance$time_course_dropout_endpoints,
        dropout_subject_count =
            provenance$time_course_dropout_subject_count
    ))
}

.interpretation_evidence_errors <- function(
    module,
    associations,
    observations,
    exclusions,
    contract,
    provenance
) {
    if (identical(module, .cross_sectional_evidence_version)) {
        return(.cross_sectional_evidence_errors(
            associations,
            observations,
            exclusions,
            contract,
            provenance
        ))
    }
    sampling_design <- names(.interpretation_evidence_versions)[
        match(module, .interpretation_evidence_versions)
    ]
    if (!length(sampling_design) || is.na(sampling_design)) {
        return("interpretation evidence module is not registered")
    }
    .time_course_evidence_errors(
        module,
        sampling_design,
        associations,
        observations,
        exclusions,
        contract,
        provenance
    )
}

.empty_association_evidence <- function() {
    empty <- lapply(.association_atlas_columns, function(name) {
        if (name %in% c(
            "component", "n_available", "n_missing", "n_score_ties",
            "n_target_ties", "n_resamples", "resample_failures"
        )) {
            integer()
        } else if (name %in% c(
            "estimate", "effect_magnitude", "p_value", "q_value",
            "effect_conf_low", "effect_conf_high"
        )) {
            numeric()
        } else if (identical(name, "proposal_eligible")) {
            logical()
        } else {
            character()
        }
    })
    names(empty) <- .association_atlas_columns
    as.data.frame(empty, stringsAsFactors = FALSE)
}

.empty_observation_evidence <- function() {
    data.frame(
        metadata_field = character(),
        component = integer(),
        component_label = character(),
        sample_index = integer(),
        primary_sample = character(),
        metadata_type = character(),
        metadata_value = character(),
        metadata_numeric = numeric(),
        score = numeric(),
        atom_count = integer(),
        available = logical(),
        stringsAsFactors = FALSE
    )
}

.empty_exclusion_evidence <- function() {
    data.frame(
        metadata_field = character(),
        reason = character(),
        stringsAsFactors = FALSE
    )
}

.empty_cohort_members <- function() {
    data.frame(
        metadata_field = character(),
        component = integer(),
        evidence_variant = character(),
        primary_sample = character(),
        included = logical(),
        stringsAsFactors = FALSE
    )
}

# Package-owned construction boundary shared by interpretation modules.
# Method authors return narrow AssociationStrategy results; they do not
# construct, serialize, or expose this internal object.
setClass(
    "InterpretationEvidence",
    representation(
        module = "character",
        associations = "data.frame",
        observations = "data.frame",
        exclusions = "data.frame",
        provenance = "list"
    ),
    prototype = list(module = character())
)

setValidity("InterpretationEvidence", function(object) {
    .interpretation_evidence_errors(
        module = object@module,
        associations = object@associations,
        observations = object@observations,
        exclusions = object@exclusions,
        contract = object@provenance$evidence_contract,
        provenance = object@provenance
    )
})

.new_interpretation_evidence <- function(
    module,
    sampling_design,
    associations,
    observations,
    exclusions,
    cohort_members,
    provenance
) {
    tables <- list(
        associations = associations,
        observations = observations,
        exclusions = exclusions,
        cohort_members = cohort_members
    )
    if (!all(vapply(tables, is.data.frame, logical(1L)))) {
        .stop_landscapeR_validation(
            "normalized interpretation evidence must contain data frames"
        )
    }
    tables <- lapply(tables, function(table) {
        rownames(table) <- NULL
        table
    })
    provenance$interpretation_module <- module
    display_evidence <- if (identical(sampling_design, "cross_sectional")) {
        provenance$visual_evidence
    } else {
        .time_course_display_evidence(provenance, sampling_design)
    }
    provenance$evidence_contract <- .new_interpretation_contract(
        module,
        sampling_design,
        tables$associations,
        tables$observations,
        tables$exclusions,
        tables$cohort_members,
        display_evidence
    )
    evidence <- new(
        "InterpretationEvidence",
        module = module,
        associations = tables$associations,
        observations = tables$observations,
        exclusions = tables$exclusions,
        provenance = provenance
    )
    validObject(evidence)
    evidence
}

.new_cross_sectional_evidence <- function(
    association_rows,
    observation_rows,
    exclusion_rows,
    provenance
) {
    associations <- if (length(association_rows)) {
        do.call(rbind, association_rows)
    } else {
        .empty_association_evidence()
    }
    observations <- if (length(observation_rows)) {
        do.call(rbind, observation_rows)
    } else {
        .empty_observation_evidence()
    }
    exclusions <- if (length(exclusion_rows)) {
        do.call(rbind, exclusion_rows)
    } else {
        .empty_exclusion_evidence()
    }
    cohort_members <- if (nrow(associations)) {
        do.call(rbind, lapply(seq_len(nrow(associations)), function(i) {
            members <- associations$.cohort_members[[i]]
            data.frame(
                metadata_field = associations$metadata_field[[i]],
                component = associations$component[[i]],
                evidence_variant = associations$evidence_variant[[i]],
                primary_sample = as.character(members$primary_sample),
                included = as.logical(members$included),
                stringsAsFactors = FALSE
            )
        }))
    } else {
        .empty_cohort_members()
    }
    associations$.cohort_members <- NULL
    .new_interpretation_evidence(
        module = .cross_sectional_evidence_version,
        sampling_design = "cross_sectional",
        associations,
        observations,
        exclusions,
        cohort_members,
        provenance
    )
}

.new_time_course_evidence <- function(
    module,
    sampling_design,
    associations,
    observations,
    exclusions,
    cohort_members,
    provenance
) {
    .new_interpretation_evidence(
        module = module,
        sampling_design = sampling_design,
        associations,
        observations,
        exclusions,
        cohort_members,
        provenance
    )
}

.time_course_cohort_members <- function(
    associations,
    observations,
    analysis_cohort
) {
    members <- do.call(rbind, lapply(
        seq_len(nrow(associations)),
        function(i) {
            association <- associations[i, , drop = FALSE]
            observed <- observations[
                observations$metadata_field == association$metadata_field &
                    observations$component == association$component,
                ,
                drop = FALSE
            ]
            included <- if (identical(
                association$evidence_variant,
                "pooled-descriptive"
            )) {
                observed$available
            } else {
                observed$primary_sample %in% analysis_cohort
            }
            data.frame(
                metadata_field = association$metadata_field,
                component = association$component,
                evidence_variant = association$evidence_variant,
                primary_sample = as.character(observed$primary_sample),
                included = unname(as.logical(included)),
                stringsAsFactors = FALSE
            )
        }
    ))
    rownames(members) <- NULL
    members
}

.new_time_course_atlas <- function(
    module,
    contract_sampling_design,
    version,
    dataset_id,
    associations,
    observations,
    exclusions,
    cohort_members,
    sampling_design,
    input_digest,
    state_space_digest,
    compute_tier,
    provenance,
    evidence_status
) {
    evidence <- .new_time_course_evidence(
        module = module,
        sampling_design = contract_sampling_design,
        associations = associations,
        observations = observations,
        exclusions = exclusions,
        cohort_members = cohort_members,
        provenance = provenance
    )
    atlas <- new(
        "MetadataAssociationAtlas",
        version = version,
        dataset_id = dataset_id,
        associations = evidence@associations,
        observations = evidence@observations,
        exclusions = evidence@exclusions,
        sampling_design = sampling_design,
        input_digest = input_digest,
        state_space_digest = state_space_digest,
        compute_tier = compute_tier,
        provenance = evidence@provenance,
        evidence_status = evidence_status
    )
    validObject(atlas)
    atlas
}
