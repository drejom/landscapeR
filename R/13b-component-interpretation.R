# Cross-sectional component interpretation (ADR 0020; issues #79 and #80)

utils::globalVariables(c("metadata_field", "component_label"))

.association_atlas_columns <- c(
    "metadata_field", "component", "component_label", "estimand",
    "estimate", "effect_magnitude", "reference_level", "comparison_level",
    "n_available", "n_missing", "n_score_ties", "n_target_ties",
    "evidence_variant", "nuisance_fields", "design_digest", "diagnostic",
    "p_value", "q_value", "evidence_status"
)

.association_observation_columns <- c(
    "metadata_field", "component", "component_label", "sample_index",
    "primary_sample", "metadata_type", "metadata_value", "metadata_numeric",
    "score", "available"
)

.is_sha256_digest <- function(x) {
    length(x) == 1L && !is.na(x) &&
        grepl("^[[:xdigit:]]{64}$", x)
}

.is_scalar_nonempty_text <- function(x) {
    length(x) == 1L && !is.na(x) && nzchar(x)
}

#' Component-by-metadata association evidence
#'
#' A versioned, serializable atlas containing every eligible association and
#' every excluded metadata field. The atlas is descriptive evidence: it does
#' not nominate or confirm a component.
#'
#' @slot version schema version, currently `"1.0.0"`
#' @slot dataset_id stable dataset identifier used by confirmation IDs
#' @slot associations canonical component-by-metadata association table
#' @slot observations canonical raw component distributions for eligible fields
#' @slot exclusions metadata fields excluded from association with reasons
#' @slot sampling_design the declared biological sampling design
#' @slot input_digest digest of aligned metadata and canonical sample identity
#' @slot state_space_digest digest of the frozen Stage 1 coordinates/loadings
#' @slot compute_tier computation tier used for the stored evidence
#' @slot provenance deterministic strategy and package provenance
#' @slot evidence_status support tier, initially
#'   `"estimable-exploratory-only"`
#'
#' @export
setClass("MetadataAssociationAtlas",
    representation(
        version = "character",
        dataset_id = "character",
        associations = "data.frame",
        observations = "data.frame",
        exclusions = "data.frame",
        sampling_design = "SamplingDesign",
        input_digest = "character",
        state_space_digest = "character",
        compute_tier = "character",
        provenance = "list",
        evidence_status = "character"
    ),
    prototype = prototype(
        version = "1.0.0",
        dataset_id = character(0L),
        associations = data.frame(),
        observations = data.frame(),
        exclusions = data.frame(),
        sampling_design = new("SamplingDesign"),
        input_digest = character(0L),
        state_space_digest = character(0L),
        compute_tier = "analytic-unadjusted",
        provenance = list(),
        evidence_status = "estimable-exploratory-only"
    )
)

setValidity("MetadataAssociationAtlas", function(object) {
    errors <- character()
    if (!identical(object@version, "1.0.0")) {
        errors <- c(errors, "version must be '1.0.0'")
    }
    if (!.is_scalar_nonempty_text(object@dataset_id)) {
        errors <- c(errors, "dataset_id must be one non-empty identifier")
    }
    missing_columns <- setdiff(
        .association_atlas_columns,
        names(object@associations)
    )
    if (length(missing_columns)) {
        errors <- c(
            errors,
            paste0(
                "associations is missing columns: ",
                paste(missing_columns, collapse = ", ")
            )
        )
    }
    missing_observation_columns <- setdiff(
        .association_observation_columns,
        names(object@observations)
    )
    if (length(missing_observation_columns)) {
        errors <- c(
            errors,
            paste0(
                "observations is missing columns: ",
                paste(missing_observation_columns, collapse = ", ")
            )
        )
    }
    if (!all(c("metadata_field", "reason") %in% names(object@exclusions))) {
        errors <- c(
            errors,
            "exclusions must contain metadata_field and reason columns"
        )
    }
    if (!.is_sha256_digest(object@input_digest)) {
        errors <- c(errors, "input_digest must be one SHA-256 digest")
    }
    if (!.is_sha256_digest(object@state_space_digest)) {
        errors <- c(errors, "state_space_digest must be one SHA-256 digest")
    }
    if (!identical(object@compute_tier, "analytic-unadjusted")) {
        errors <- c(errors, "compute_tier must be 'analytic-unadjusted'")
    }
    required_provenance <- c(
        "association_strategy", "package_version", "sampling_design",
        "layer", "input_digest", "state_space_digest", "dataset_id"
    )
    if (!all(required_provenance %in% names(object@provenance))) {
        errors <- c(errors, "provenance is missing required fields")
    }
    if (!identical(
        object@evidence_status,
        "estimable-exploratory-only"
    )) {
        errors <- c(
            errors,
            "evidence_status must be 'estimable-exploratory-only'"
        )
    }
    if (length(errors)) errors else TRUE
})

.aligned_component_metadata <- function(
    std,
    layer,
    field,
    caller,
    field_label = "metadata field"
) {
    prefix <- paste0(caller, "(): ")
    if (!is.character(field) || length(field) != 1L ||
        is.na(field) || !nzchar(field)) {
        .stop_landscapeR_validation(
            paste0(prefix, field_label, " must be one non-empty name")
        )
    }

    experiments_list <- as.list(experiments(std))
    if (length(layer) != 1L || is.na(layer) || !is.numeric(layer) ||
        !is.finite(layer) || layer != as.integer(layer) ||
        layer < 1L || layer > length(experiments_list)) {
        .stop_landscapeR_validation(
            paste0(prefix, "layer must be one in-range integer index")
        )
    }
    layer <- as.integer(layer)
    experiment_names <- names(experiments_list)
    if (is.null(experiment_names) ||
        !.is_scalar_nonempty_text(experiment_names[[layer]])) {
        .stop_landscapeR_validation(
            paste0(prefix, "selected layer must have a non-empty name")
        )
    }

    cd_s4 <- colData(std)
    field_idx <- which(names(cd_s4) == field)
    if (!length(field_idx)) {
        .stop_landscapeR_validation(sprintf(
            "%s%s '%s' was not found in MAE-level colData",
            prefix,
            field_label,
            field
        ))
    }
    if (length(field_idx) > 1L) {
        .stop_landscapeR_validation(sprintf(
            "%s%s '%s' is ambiguous in MAE-level colData",
            prefix,
            field_label,
            field
        ))
    }
    cd <- as.data.frame(cd_s4)

    layer_name <- experiment_names[[layer]]
    assay_samples <- colnames(experiments_list[[layer]])
    mapping <- as.data.frame(sampleMap(std), stringsAsFactors = FALSE)
    layer_map <- mapping[
        as.character(mapping$assay) == layer_name,
        ,
        drop = FALSE
    ]
    mapped_samples <- as.character(layer_map$colname)
    map_index <- match(assay_samples, mapped_samples)
    if (anyNA(map_index)) {
        .stop_landscapeR_validation(sprintf(
            paste0(
                "%smissing canonical sample mapping for layer ",
                "'%s' observation '%s'"
            ),
            prefix,
            layer_name,
            assay_samples[[which(is.na(map_index))[[1L]]]]
        ))
    }
    duplicate_samples <- unique(mapped_samples[duplicated(mapped_samples)])
    ambiguous <- assay_samples %in% duplicate_samples
    if (any(ambiguous)) {
        .stop_landscapeR_validation(sprintf(
            paste0(
                "%sambiguous canonical sample mapping for layer ",
                "'%s' observation '%s'"
            ),
            prefix,
            layer_name,
            assay_samples[[which(ambiguous)[[1L]]]]
        ))
    }

    primary <- as.character(layer_map$primary[map_index])
    primary_rows <- rownames(cd)
    if (anyDuplicated(primary_rows) > 0L) {
        .stop_landscapeR_validation(
            paste0(
                prefix,
                "MAE-level colData has ambiguous primary sample IDs"
            )
        )
    }
    cd_index <- match(primary, primary_rows)
    if (anyNA(cd_index)) {
        .stop_landscapeR_validation(sprintf(
            "%sMAE-level colData is missing primary sample '%s'",
            prefix,
            primary[[which(is.na(cd_index))[[1L]]]]
        ))
    }
    values <- cd[[field_idx]][cd_index]
    names(values) <- primary
    values
}

.binary_level_order <- function(values) {
    observed <- values[!is.na(values)]
    if (is.factor(observed)) {
        declared <- levels(droplevels(observed))
    } else {
        declared <- sort(unique(as.character(observed)))
    }
    if (length(declared) != 2L) return(NULL)
    declared
}

.signed_rank_biserial <- function(scores, groups, reference, comparison) {
    complete <- is.finite(scores) & !is.na(groups)
    scores <- scores[complete]
    groups <- as.character(groups[complete])
    keep <- groups %in% c(reference, comparison)
    scores <- scores[keep]
    groups <- groups[keep]
    reference_scores <- scores[groups == reference]
    comparison_scores <- scores[groups == comparison]
    if (!length(reference_scores) || !length(comparison_scores)) {
        return(NULL)
    }
    ranks <- rank(
        c(reference_scores, comparison_scores),
        ties.method = "average"
    )
    n_reference <- length(reference_scores)
    n_comparison <- length(comparison_scores)
    comparison_ranks <- ranks[seq.int(
        n_reference + 1L,
        n_reference + n_comparison
    )]
    u_comparison <- sum(comparison_ranks) -
        n_comparison * (n_comparison + 1) / 2
    estimate <- 2 * u_comparison / (n_reference * n_comparison) - 1
    all_scores <- c(reference_scores, comparison_scores)
    tied <- duplicated(all_scores) |
        duplicated(all_scores, fromLast = TRUE)
    p_value <- suppressWarnings(stats::wilcox.test(
        comparison_scores,
        reference_scores,
        exact = FALSE
    )$p.value)
    list(
        estimate = unname(estimate),
        n_available = length(all_scores),
        n_score_ties = sum(tied),
        p_value = unname(p_value)
    )
}

#' Cross-sectional binary rank-biserial association strategy
#'
#' @rdname AssociationStrategy-class
#' @export
setClass(
    "CrossSectionalBinaryAssociationStrategy",
    contains = "AssociationStrategy"
)

#' @rdname association_applicable
#' @export
setMethod(
    "association_applicable",
    signature(
        strategy = "CrossSectionalBinaryAssociationStrategy",
        data = "StateTransitionData",
        values = "ANY"
    ),
    function(strategy, data, values) {
        identical(data@sampling_design@kind, "cross_sectional") &&
            !is.null(.binary_level_order(values))
    }
)

#' @rdname associate_component
#' @export
setMethod(
    "associate_component",
    signature(
        strategy = "CrossSectionalBinaryAssociationStrategy",
        scores = "numeric",
        values = "ANY"
    ),
    function(strategy, scores, values) {
        levels <- .binary_level_order(values)
        if (is.null(levels)) {
            .stop_landscapeR_validation(
                paste0(
                    "associate_component(): cross-sectional binary ",
                    "strategy requires exactly two observed levels"
                )
            )
        }
        effect <- .signed_rank_biserial(
            scores,
            values,
            reference = levels[[1L]],
            comparison = levels[[2L]]
        )
        if (is.null(effect)) return(NULL)
        effect$estimand <- "signed-rank-biserial"
        effect$reference_level <- levels[[1L]]
        effect$comparison_level <- levels[[2L]]
        effect$n_target_ties <- NA_integer_
        effect
    }
)

#' @rdname association_strategy_id
#' @export
setMethod(
    "association_strategy_id",
    signature(strategy = "CrossSectionalBinaryAssociationStrategy"),
    function(strategy) {
        "cross-sectional-binary-signed-rank-biserial-v1"
    }
)

register_strategy(
    "AssociationStrategy",
    "cross_sectional_binary",
    function(params = list()) {
        if (length(params)) {
            .stop_landscapeR_validation(
                paste0(
                    "cross_sectional_binary association strategy does not ",
                    "accept parameters"
                )
            )
        }
        new("CrossSectionalBinaryAssociationStrategy")
    }
)

#' Cross-sectional continuous Spearman association strategy
#'
#' @rdname AssociationStrategy-class
#' @export
setClass(
    "CrossSectionalContinuousAssociationStrategy",
    contains = "AssociationStrategy"
)

#' @rdname association_applicable
#' @export
setMethod(
    "association_applicable",
    signature(
        strategy = "CrossSectionalContinuousAssociationStrategy",
        data = "StateTransitionData",
        values = "ANY"
    ),
    function(strategy, data, values) {
        observed <- values[!is.na(values)]
        identical(data@sampling_design@kind, "cross_sectional") &&
            is.numeric(values) &&
            !is.logical(values) &&
            length(unique(observed)) >= 3L
    }
)

#' @rdname associate_component
#' @export
setMethod(
    "associate_component",
    signature(
        strategy = "CrossSectionalContinuousAssociationStrategy",
        scores = "numeric",
        values = "ANY"
    ),
    function(strategy, scores, values) {
        complete <- is.finite(scores) & !is.na(values) & is.finite(values)
        complete_scores <- scores[complete]
        complete_values <- as.numeric(values[complete])
        if (length(complete_scores) < 3L ||
            length(unique(complete_scores)) < 2L ||
            length(unique(complete_values)) < 2L) {
            return(NULL)
        }
        score_ties <- duplicated(complete_scores) |
            duplicated(complete_scores, fromLast = TRUE)
        target_ties <- duplicated(complete_values) |
            duplicated(complete_values, fromLast = TRUE)
        test <- suppressWarnings(stats::cor.test(
            complete_scores,
            complete_values,
            method = "spearman",
            exact = FALSE
        ))
        list(
            estimand = "spearman",
            estimate = unname(test$estimate),
            reference_level = NA_character_,
            comparison_level = NA_character_,
            n_available = length(complete_scores),
            n_score_ties = sum(score_ties),
            n_target_ties = sum(target_ties),
            p_value = unname(test$p.value)
        )
    }
)

#' @rdname association_strategy_id
#' @export
setMethod(
    "association_strategy_id",
    signature(strategy = "CrossSectionalContinuousAssociationStrategy"),
    function(strategy) {
        "cross-sectional-continuous-spearman-v1"
    }
)

register_strategy(
    "AssociationStrategy",
    "cross_sectional_continuous",
    function(params = list()) {
        if (length(params)) {
            .stop_landscapeR_validation(
                paste0(
                    "cross_sectional_continuous association strategy does ",
                    "not accept parameters"
                )
            )
        }
        new("CrossSectionalContinuousAssociationStrategy")
    }
)

#' Cross-sectional ordered Kendall tau-b association strategy
#'
#' @rdname AssociationStrategy-class
#' @export
setClass(
    "CrossSectionalOrderedAssociationStrategy",
    contains = "AssociationStrategy"
)

#' @rdname association_applicable
#' @export
setMethod(
    "association_applicable",
    signature(
        strategy = "CrossSectionalOrderedAssociationStrategy",
        data = "StateTransitionData",
        values = "ANY"
    ),
    function(strategy, data, values) {
        if (!is.ordered(values)) return(FALSE)
        observed <- droplevels(values[!is.na(values)])
        identical(data@sampling_design@kind, "cross_sectional") &&
            nlevels(observed) >= 3L
    }
)

#' @rdname associate_component
#' @export
setMethod(
    "associate_component",
    signature(
        strategy = "CrossSectionalOrderedAssociationStrategy",
        scores = "numeric",
        values = "ANY"
    ),
    function(strategy, scores, values) {
        complete <- is.finite(scores) & !is.na(values)
        complete_scores <- scores[complete]
        complete_values <- as.integer(values[complete])
        if (length(complete_scores) < 3L ||
            length(unique(complete_scores)) < 2L ||
            length(unique(complete_values)) < 2L) {
            return(NULL)
        }
        score_ties <- duplicated(complete_scores) |
            duplicated(complete_scores, fromLast = TRUE)
        target_ties <- duplicated(complete_values) |
            duplicated(complete_values, fromLast = TRUE)
        test <- suppressWarnings(stats::cor.test(
            complete_scores,
            complete_values,
            method = "kendall",
            exact = FALSE
        ))
        list(
            estimand = "kendall-tau-b",
            estimate = unname(test$estimate),
            reference_level = NA_character_,
            comparison_level = NA_character_,
            n_available = length(complete_scores),
            n_score_ties = sum(score_ties),
            n_target_ties = sum(target_ties),
            p_value = unname(test$p.value)
        )
    }
)

#' @rdname association_strategy_id
#' @export
setMethod(
    "association_strategy_id",
    signature(strategy = "CrossSectionalOrderedAssociationStrategy"),
    function(strategy) {
        "cross-sectional-ordered-kendall-tau-b-v1"
    }
)

register_strategy(
    "AssociationStrategy",
    "cross_sectional_ordered",
    function(params = list()) {
        if (length(params)) {
            .stop_landscapeR_validation(
                paste0(
                    "cross_sectional_ordered association strategy does not ",
                    "accept parameters"
                )
            )
        }
        new("CrossSectionalOrderedAssociationStrategy")
    }
)

.resolve_component_association_strategy <- function(std, values) {
    keys <- list_strategies("AssociationStrategy")
    strategy_names <- sub("^AssociationStrategy:", "", keys)
    strategies <- lapply(
        sort(strategy_names),
        function(name) get_strategy("AssociationStrategy", name)()
    )
    applicable <- Filter(
        function(strategy) association_applicable(strategy, std, values),
        strategies
    )
    if (length(applicable) != 1L) return(NULL)
    applicable[[1L]]
}

.atlas_input_digest <- function(std) {
    digest::digest(
        list(
            colData = as.data.frame(colData(std)),
            sampleMap = as.data.frame(sampleMap(std))
        ),
        algo = "sha256",
        serialize = TRUE
    )
}

.atlas_state_space_digest <- function(stage1) {
    digest::digest(
        list(
            V_star = dr_V_star(stage1),
            V_k = dr_V_k(stage1),
            sigma = dr_sigma(stage1),
            sigma_k = dr_sigma_k(stage1),
            coords_k = dr_coords_k(stage1)
        ),
        algo = "sha256",
        serialize = TRUE
    )
}

.adjusted_rank_score_effect <- function(
    std,
    scores,
    target_values,
    specification
) {
    nuisance_values <- lapply(
        specification@nuisance_fields,
        function(field) {
            .aligned_component_metadata(
                std,
                1L,
                field,
                caller = "associate_metadata"
            )
        }
    )
    names(nuisance_values) <- specification@nuisance_fields
    complete <- is.finite(scores) & !is.na(target_values)
    for (values in nuisance_values) {
        complete <- complete & !is.na(values)
        if (is.numeric(values)) {
            complete <- complete & is.finite(values)
        }
    }
    complete_scores <- scores[complete]
    complete_target <- target_values[complete]
    if (length(complete_scores) < 3L) return(NULL)

    nuisance_frame <- as.data.frame(lapply(
        nuisance_values,
        function(values) {
            values <- values[complete]
            if (is.numeric(values) || is.ordered(values)) {
                rank(values, ties.method = "average")
            } else {
                factor(values)
            }
        }
    ), stringsAsFactors = FALSE)
    design <- stats::model.matrix(~ ., data = nuisance_frame)
    target_numeric <- if (identical(specification@target_type, "binary")) {
        match(
            as.character(complete_target),
            c(specification@reference_level, specification@comparison_level)
        )
    } else if (identical(specification@target_type, "ordered")) {
        match(
            as.character(complete_target),
            specification@ordered_levels
        )
    } else {
        as.numeric(complete_target)
    }
    score_rank <- rank(complete_scores, ties.method = "average")
    target_rank <- rank(target_numeric, ties.method = "average")
    score_ties <- duplicated(complete_scores) |
        duplicated(complete_scores, fromLast = TRUE)
    target_ties <- duplicated(target_numeric) |
        duplicated(target_numeric, fromLast = TRUE)
    design_digest <- digest::digest(
        list(
            nuisance_fields = specification@nuisance_fields,
            design = unname(design),
            design_columns = colnames(design),
            complete_indices = which(complete)
        ),
        algo = "sha256",
        serialize = TRUE
    )
    estimand <- if (identical(specification@target_type, "binary")) {
        "adjusted-rank-score-contrast"
    } else {
        "adjusted-rank-score-association"
    }
    adjustment_result <- function(
        estimate,
        p_value,
        diagnostic,
        evidence_status
    ) {
        list(
            estimand = estimand,
            estimate = estimate,
            reference_level = if (identical(
                specification@target_type,
                "binary"
            )) specification@reference_level else NA_character_,
            comparison_level = if (identical(
                specification@target_type,
                "binary"
            )) specification@comparison_level else NA_character_,
            n_available = length(complete_scores),
            n_score_ties = sum(score_ties),
            n_target_ties = sum(target_ties),
            p_value = p_value,
            design_digest = design_digest,
            diagnostic = diagnostic,
            evidence_status = evidence_status
        )
    }
    design_rank <- qr(design)$rank
    target_augmented_rank <- qr(cbind(design, target_rank))$rank
    if (design_rank < ncol(design) ||
        identical(target_augmented_rank, design_rank)) {
        return(adjustment_result(
            estimate = NA_real_,
            p_value = NA_real_,
            diagnostic = "non-identifiable-design",
            evidence_status = "adjustment-abstention"
        ))
    }

    score_residual <- stats::lm.fit(design, score_rank)$residuals
    target_residual <- stats::lm.fit(design, target_rank)$residuals
    if (!is.finite(stats::var(score_residual)) ||
        !is.finite(stats::var(target_residual)) ||
        stats::var(score_residual) == 0 ||
        stats::var(target_residual) == 0) {
        return(adjustment_result(
            estimate = NA_real_,
            p_value = NA_real_,
            diagnostic = "non-identifiable-design",
            evidence_status = "adjustment-abstention"
        ))
    }
    test <- stats::cor.test(score_residual, target_residual)
    adjustment_result(
        estimate = unname(test$estimate),
        p_value = unname(test$p.value),
        diagnostic = "",
        evidence_status = "estimable-exploratory-only"
    )
}

#' Associate Stage 1 components with eligible metadata
#'
#' The cross-sectional tracer supports one biological layer. Binary metadata
#' use signed rank-biserial association, continuous metadata use Spearman
#' association, and ordered factors use Kendall tau-b against their declared
#' level order. Binary factor levels declare reference then comparison;
#' character or logical levels use deterministic lexical order. Identifier-like
#' fields and caller-declared non-analytical fields are excluded with reasons.
#'
#' @param std a Stage-1-complete `StateTransitionData`
#' @param specification optional draft `AnalysisSpecification` owning target
#'   and nuisance intent for this run
#' @param non_analytical_fields metadata fields to exclude explicitly
#' @param dataset_id optional stable dataset identifier used in confirmed
#'   analysis IDs; defaults to `metadata(std)$dataset_id` when present, then a
#'   deterministic input-digest identifier
#'
#' @return a validated `MetadataAssociationAtlas`
#' @export
associate_metadata <- function(
    std,
    specification = NULL,
    non_analytical_fields = character(),
    dataset_id = NULL
) {
    if (!is(std, "StateTransitionData")) {
        .stop_landscapeR_validation(
            "associate_metadata(): std must be a StateTransitionData object"
        )
    }
    stage1 <- metadata(std)$stage1
    if (is.null(stage1)) {
        .stop_landscapeR_validation(
            "associate_metadata(): Stage 1 has not been run"
        )
    }
    if (!identical(std@sampling_design@kind, "cross_sectional")) {
        .stop_landscapeR_validation(
            "associate_metadata(): issue #79 requires a cross-sectional design"
        )
    }
    specification_provenance <- list()
    if (!is.null(specification)) {
        if (!is(specification, "AnalysisSpecification") ||
            !identical(specification@lifecycle, "draft")) {
            .stop_landscapeR_validation(
                paste0(
                    "associate_metadata(): specification must be a draft ",
                    "AnalysisSpecification"
                )
            )
        }
        specification_error <- .validate_analysis_specification_data(
            specification,
            std
        )
        if (!identical(specification_error, TRUE)) {
            .stop_landscapeR_validation(paste0(
                "associate_metadata(): ",
                specification_error
            ))
        }
        specification_provenance <- list(
            analysis_specification_id = specification@id,
            analysis_specification_digest = canonical_digest(specification),
            target_field = specification@target_field,
            target_type = specification@target_type,
            nuisance_fields = specification@nuisance_fields,
            claim_intent = specification@claim_intent
        )
    }
    coordinates <- dr_coords_k(stage1)
    if (length(coordinates) != 1L) {
        .stop_landscapeR_validation(
            "associate_metadata(): issue #79 supports exactly one omic layer"
        )
    }
    if (!is.character(non_analytical_fields) ||
        anyNA(non_analytical_fields) ||
        any(!nzchar(non_analytical_fields)) ||
        anyDuplicated(non_analytical_fields)) {
        .stop_landscapeR_validation(
            paste0(
                "associate_metadata(): non_analytical_fields must be ",
                "unique non-empty names"
            )
        )
    }

    metadata_fields <- unique(names(colData(std)))
    unknown <- setdiff(non_analytical_fields, metadata_fields)
    if (length(unknown)) {
        .stop_landscapeR_validation(sprintf(
            "associate_metadata(): non-analytical field '%s' was not found",
            unknown[[1L]]
        ))
    }
    identifier_fields <- grepl(
        "(^id$|_id$|^identifier$)",
        metadata_fields,
        ignore.case = TRUE
    )
    exclusion_rows <- list()
    association_rows <- list()
    observation_rows <- list()
    association_strategy_ids <- character()
    coordinate_matrix <- coordinates[[1L]]
    if (!is.matrix(coordinate_matrix) ||
        !is.numeric(coordinate_matrix) ||
        !length(coordinate_matrix) ||
        any(!is.finite(coordinate_matrix))) {
        .stop_landscapeR_validation(
            paste0(
                "associate_metadata(): Stage 1 coords_k[[1]] must be a ",
                "non-empty finite numeric matrix"
            )
        )
    }
    layer_observations <- ncol(as.list(experiments(std))[[1L]])
    if (nrow(coordinate_matrix) != layer_observations) {
        .stop_landscapeR_validation(sprintf(
            paste0(
                "associate_metadata(): coordinate rows (%d) must equal ",
                "selected-layer observations (%d)"
            ),
            nrow(coordinate_matrix),
            layer_observations
        ))
    }
    component_labels <- colnames(coordinate_matrix)
    if (is.null(component_labels)) {
        component_labels <- paste0("PC", seq_len(ncol(coordinate_matrix)))
    }

    for (field in metadata_fields) {
        if (field %in% non_analytical_fields) {
            exclusion_rows[[length(exclusion_rows) + 1L]] <- data.frame(
                metadata_field = field,
                reason = "declared-non-analytical",
                stringsAsFactors = FALSE
            )
            next
        }
        if (identifier_fields[[match(field, metadata_fields)]]) {
            exclusion_rows[[length(exclusion_rows) + 1L]] <- data.frame(
                metadata_field = field,
                reason = "identifier-field",
                stringsAsFactors = FALSE
            )
            next
        }
        values <- .aligned_component_metadata(
            std,
            1L,
            field,
            caller = "associate_metadata"
        )
        strategy <- .resolve_component_association_strategy(std, values)
        if (is.null(strategy)) {
            exclusion_rows[[length(exclusion_rows) + 1L]] <- data.frame(
                metadata_field = field,
                reason = "unsupported-non-binary-field",
                stringsAsFactors = FALSE
            )
            next
        }
        association_strategy_ids <- c(
            association_strategy_ids,
            association_strategy_id(strategy)
        )

        field_rows <- lapply(seq_len(ncol(coordinate_matrix)), function(j) {
            scores <- coordinate_matrix[, j]
            effect <- associate_component(strategy, scores, values)
            if (is.null(effect)) return(NULL)
            data.frame(
                metadata_field = field,
                component = as.integer(j),
                component_label = component_labels[[j]],
                estimand = effect$estimand,
                estimate = effect$estimate,
                effect_magnitude = abs(effect$estimate),
                reference_level = effect$reference_level,
                comparison_level = effect$comparison_level,
                n_available = as.integer(effect$n_available),
                n_missing = as.integer(length(values) - effect$n_available),
                n_score_ties = as.integer(effect$n_score_ties),
                n_target_ties = as.integer(effect$n_target_ties),
                evidence_variant = "unadjusted",
                nuisance_fields = "",
                design_digest = NA_character_,
                diagnostic = "",
                p_value = effect$p_value,
                q_value = NA_real_,
                evidence_status = "estimable-exploratory-only",
                stringsAsFactors = FALSE
            )
        })
        field_rows <- Filter(Negate(is.null), field_rows)
        if (length(field_rows)) {
            field_table <- do.call(rbind, field_rows)
            field_table$q_value <- stats::p.adjust(
                field_table$p_value,
                method = "BH"
            )
            association_rows[[length(association_rows) + 1L]] <- field_table
            if (!is.null(specification) &&
                identical(field, specification@target_field) &&
                length(specification@nuisance_fields)) {
                adjusted_rows <- lapply(
                    seq_len(ncol(coordinate_matrix)),
                    function(j) {
                        effect <- .adjusted_rank_score_effect(
                            std,
                            coordinate_matrix[, j],
                            values,
                            specification
                        )
                        if (is.null(effect)) return(NULL)
                        data.frame(
                            metadata_field = field,
                            component = as.integer(j),
                            component_label = component_labels[[j]],
                            estimand = effect$estimand,
                            estimate = effect$estimate,
                            effect_magnitude = abs(effect$estimate),
                            reference_level = effect$reference_level,
                            comparison_level = effect$comparison_level,
                            n_available = as.integer(effect$n_available),
                            n_missing = as.integer(
                                length(values) - effect$n_available
                            ),
                            n_score_ties = as.integer(effect$n_score_ties),
                            n_target_ties = as.integer(effect$n_target_ties),
                            evidence_variant = "adjusted",
                            nuisance_fields = paste(
                                specification@nuisance_fields,
                                collapse = " + "
                            ),
                            design_digest = effect$design_digest,
                            diagnostic = effect$diagnostic,
                            p_value = effect$p_value,
                            q_value = NA_real_,
                            evidence_status = effect$evidence_status,
                            stringsAsFactors = FALSE
                        )
                    }
                )
                adjusted_rows <- Filter(Negate(is.null), adjusted_rows)
                if (length(adjusted_rows)) {
                    adjusted_table <- do.call(rbind, adjusted_rows)
                    adjusted_table$q_value <- stats::p.adjust(
                        adjusted_table$p_value,
                        method = "BH"
                    )
                    association_rows[[length(association_rows) + 1L]] <-
                        adjusted_table
                }
            }
            field_observations <- lapply(
                seq_len(ncol(coordinate_matrix)),
                function(j) {
                    scores <- coordinate_matrix[, j]
                    metadata_type <- if (is.ordered(values)) {
                        "ordered"
                    } else if (is.numeric(values) && !is.logical(values)) {
                        "continuous"
                    } else {
                        "categorical"
                    }
                    metadata_numeric <- if (is.ordered(values)) {
                        as.numeric(values)
                    } else if (identical(metadata_type, "continuous")) {
                        as.numeric(values)
                    } else {
                        rep(NA_real_, length(values))
                    }
                    data.frame(
                        metadata_field = field,
                        component = as.integer(j),
                        component_label = component_labels[[j]],
                        sample_index = seq_along(scores),
                        primary_sample = names(values),
                        metadata_type = metadata_type,
                        metadata_value = as.character(values),
                        metadata_numeric = metadata_numeric,
                        score = as.numeric(scores),
                        available = is.finite(scores) & !is.na(values),
                        stringsAsFactors = FALSE
                    )
                }
            )
            observation_rows[[length(observation_rows) + 1L]] <-
                do.call(rbind, field_observations)
        }
    }

    associations <- if (length(association_rows)) {
        do.call(rbind, association_rows)
    } else {
        empty <- lapply(.association_atlas_columns, function(name) {
            if (name %in% c(
                "component", "n_available", "n_missing", "n_score_ties",
                "n_target_ties"
            )) integer() else if (name %in% c(
                "estimate", "effect_magnitude", "p_value", "q_value"
            )) numeric() else character()
        })
        names(empty) <- .association_atlas_columns
        as.data.frame(empty, stringsAsFactors = FALSE)
    }
    observations <- if (length(observation_rows)) {
        do.call(rbind, observation_rows)
    } else {
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
            available = logical(),
            stringsAsFactors = FALSE
        )
    }
    exclusions <- if (length(exclusion_rows)) {
        do.call(rbind, exclusion_rows)
    } else {
        data.frame(
            metadata_field = character(),
            reason = character(),
            stringsAsFactors = FALSE
        )
    }
    rownames(associations) <- NULL
    rownames(observations) <- NULL
    rownames(exclusions) <- NULL
    input_digest <- .atlas_input_digest(std)
    state_space_digest <- .atlas_state_space_digest(stage1)
    metadata_dataset_id <- metadata(std)$dataset_id
    if (is.null(dataset_id) && .is_scalar_nonempty_text(metadata_dataset_id)) {
        dataset_id <- metadata_dataset_id
    }
    if (is.null(dataset_id)) {
        dataset_id <- paste0("dataset-", substr(input_digest, 1L, 12L))
    }
    if (!.is_scalar_nonempty_text(dataset_id)) {
        .stop_landscapeR_validation(
            "associate_metadata(): dataset_id must be one non-empty string"
        )
    }
    atlas <- new(
        "MetadataAssociationAtlas",
        version = "1.0.0",
        dataset_id = dataset_id,
        associations = associations,
        observations = observations,
        exclusions = exclusions,
        sampling_design = std@sampling_design,
        input_digest = input_digest,
        state_space_digest = state_space_digest,
        compute_tier = "analytic-unadjusted",
        provenance = c(list(
            association_strategy = sort(unique(association_strategy_ids)),
            package_version = as.character(
                utils::packageVersion("landscapeR")
            ),
            sampling_design = std@sampling_design@kind,
            layer = names(as.list(experiments(std)))[[1L]],
            input_digest = input_digest,
            state_space_digest = state_space_digest,
            dataset_id = dataset_id
        ), specification_provenance),
        evidence_status = "estimable-exploratory-only"
    )
    validObject(atlas)
    atlas
}

#' Extract association rows from an atlas
#'
#' @param atlas a `MetadataAssociationAtlas`
#' @return a canonical data frame
#' @export
atlas_associations <- function(atlas) {
    if (!is(atlas, "MetadataAssociationAtlas")) {
        stop("atlas_associations(): atlas must be a MetadataAssociationAtlas")
    }
    atlas@associations
}

#' Extract raw eligible component distributions from an atlas
#'
#' @param atlas a `MetadataAssociationAtlas`
#' @return a canonical long data frame
#' @export
atlas_observations <- function(atlas) {
    if (!is(atlas, "MetadataAssociationAtlas")) {
        stop("atlas_observations(): atlas must be a MetadataAssociationAtlas")
    }
    atlas@observations
}

#' Extract metadata exclusions from an atlas
#'
#' @param atlas a `MetadataAssociationAtlas`
#' @return a data frame with metadata fields and exclusion reasons
#' @export
atlas_exclusions <- function(atlas) {
    if (!is(atlas, "MetadataAssociationAtlas")) {
        stop("atlas_exclusions(): atlas must be a MetadataAssociationAtlas")
    }
    atlas@exclusions
}

#' Extract deterministic atlas provenance
#'
#' @param atlas a `MetadataAssociationAtlas`
#' @return a named list describing the strategy, package, design, layer, and
#'   bound inputs
#' @export
atlas_provenance <- function(atlas) {
    if (!is(atlas, "MetadataAssociationAtlas")) {
        stop("atlas_provenance(): atlas must be a MetadataAssociationAtlas")
    }
    atlas@provenance
}

#' @export
as.data.frame.MetadataAssociationAtlas <- function(
    x,
    row.names = NULL,
    optional = FALSE,
    ...
) {
    atlas_associations(x)
}

#' Extract the canonical digest of a metadata-association atlas
#'
#' @param atlas a `MetadataAssociationAtlas`
#' @return one SHA-256 digest
#' @export
atlas_digest <- function(atlas) {
    if (!is(atlas, "MetadataAssociationAtlas")) {
        stop("atlas_digest(): atlas must be a MetadataAssociationAtlas")
    }
    .metadata_atlas_digest(atlas)
}

#' Explicit abstention from component nomination
#'
#' An abstention preserves the ranked exploratory evidence and records why no
#' unique component could be nominated. It cannot be confirmed.
#'
#' @slot version schema version, currently `"1.0.0"`
#' @slot target_field nominated binary metadata field
#' @slot reason machine-readable abstention reason
#' @slot candidate_components tied candidate component indices
#' @slot ranking effect-first component ranking
#' @slot observations target-specific raw component distributions
#' @slot atlas_digest digest of the complete source atlas
#' @slot provenance complete inherited and proposal-step provenance
#' @slot digest digest of the abstention payload
#' @slot evidence_status support tier
#'
#' @export
setClass("ComponentAbstention",
    representation(
        version = "character",
        target_field = "character",
        reason = "character",
        candidate_components = "integer",
        ranking = "data.frame",
        observations = "data.frame",
        atlas_digest = "character",
        provenance = "list",
        digest = "character",
        evidence_status = "character"
    ),
    prototype = prototype(
        version = "1.0.0",
        target_field = character(0L),
        reason = character(0L),
        candidate_components = integer(),
        ranking = data.frame(),
        observations = data.frame(),
        atlas_digest = character(0L),
        provenance = list(),
        digest = character(0L),
        evidence_status = "estimable-exploratory-only"
    )
)

setValidity("ComponentAbstention", function(object) {
    errors <- character()
    if (!identical(object@version, "1.0.0")) {
        errors <- c(errors, "version must be '1.0.0'")
    }
    if (!.is_scalar_nonempty_text(object@target_field)) {
        errors <- c(errors, "target_field must be one non-empty name")
    }
    valid_reasons <- c(
        "effect-magnitude-tie",
        "no-eligible-association",
        "non-identifiable-design"
    )
    if (length(object@reason) != 1L ||
        !object@reason %in% valid_reasons) {
        errors <- c(errors, "reason is not a supported abstention reason")
    }
    tie_candidates_valid <- identical(
        object@reason,
        "effect-magnitude-tie"
    ) && length(object@candidate_components) >= 2L
    empty_candidates_valid <- identical(
        object@reason,
        "no-eligible-association"
    ) && !length(object@candidate_components)
    design_candidates_valid <- identical(
        object@reason,
        "non-identifiable-design"
    ) && length(object@candidate_components) >= 1L
    if ((!tie_candidates_valid &&
            !empty_candidates_valid &&
            !design_candidates_valid) ||
        anyNA(object@candidate_components) ||
        any(object@candidate_components < 1L)) {
        errors <- c(
            errors,
            "candidate_components are inconsistent with abstention reason"
        )
    }
    required <- c(
        "component", "estimate", "effect_magnitude", "proposal_rank"
    )
    if (!all(required %in% names(object@ranking))) {
        errors <- c(errors, "ranking is missing required columns")
    }
    if (!all(
        .association_observation_columns %in% names(object@observations)
    )) {
        errors <- c(errors, "observations is missing required columns")
    }
    if (!all(c(
        "association_strategy", "package_version", "sampling_design",
        "layer", "input_digest", "state_space_digest", "atlas_digest",
        "target_field", "compute_tier", "dataset_id"
    ) %in% names(object@provenance))) {
        errors <- c(errors, "provenance is missing required fields")
    }
    if (!.is_sha256_digest(object@atlas_digest)) {
        errors <- c(errors, "atlas_digest must be one SHA-256 digest")
    }
    if (!.is_sha256_digest(object@digest)) {
        errors <- c(errors, "digest must be one SHA-256 digest")
    }
    if (!identical(
        object@evidence_status,
        "estimable-exploratory-only"
    )) {
        errors <- c(
            errors,
            "evidence_status must be 'estimable-exploratory-only'"
        )
    }
    if (length(errors)) errors else TRUE
})

#' Effect-first exploratory component proposal
#'
#' A proposal is a ranked, digest-bound view of one predeclared target in a
#' `MetadataAssociationAtlas`. It cannot confirm a component.
#'
#' @slot version schema version, currently `"1.0.0"`
#' @slot target_field nominated binary metadata field
#' @slot reference_level,comparison_level deterministic target orientation
#' @slot ranking effect-first component ranking
#' @slot observations target-specific raw component distributions
#' @slot recommended_component unique top-ranked component
#' @slot atlas_digest digest of the complete source atlas
#' @slot provenance complete inherited and proposal-step provenance
#' @slot digest digest of the proposal payload
#' @slot evidence_status support tier
#'
#' @export
setClass("ComponentProposal",
    representation(
        version = "character",
        target_field = "character",
        reference_level = "character",
        comparison_level = "character",
        ranking = "data.frame",
        observations = "data.frame",
        recommended_component = "integer",
        atlas_digest = "character",
        provenance = "list",
        digest = "character",
        evidence_status = "character"
    ),
    prototype = prototype(
        version = "1.0.0",
        target_field = character(0L),
        reference_level = character(0L),
        comparison_level = character(0L),
        ranking = data.frame(),
        observations = data.frame(),
        recommended_component = integer(0L),
        atlas_digest = character(0L),
        provenance = list(),
        digest = character(0L),
        evidence_status = "estimable-exploratory-only"
    )
)

setValidity("ComponentProposal", function(object) {
    errors <- character()
    if (!identical(object@version, "1.0.0")) {
        errors <- c(errors, "version must be '1.0.0'")
    }
    if (!.is_scalar_nonempty_text(object@target_field)) {
        errors <- c(errors, "target_field must be one non-empty name")
    }
    if (!.is_scalar_nonempty_text(object@reference_level) ||
        !.is_scalar_nonempty_text(object@comparison_level) ||
        identical(object@reference_level, object@comparison_level)) {
        errors <- c(errors, "proposal requires distinct target levels")
    }
    required <- c(
        "component", "estimate", "effect_magnitude", "proposal_rank"
    )
    if (!all(required %in% names(object@ranking))) {
        errors <- c(errors, "ranking is missing required columns")
    }
    if (!all(
        .association_observation_columns %in% names(object@observations)
    )) {
        errors <- c(errors, "observations is missing required columns")
    }
    if (length(object@recommended_component) != 1L ||
        is.na(object@recommended_component) ||
        object@recommended_component < 1L) {
        errors <- c(errors, "recommended_component must be positive")
    }
    if (!.is_sha256_digest(object@atlas_digest)) {
        errors <- c(errors, "atlas_digest must be one SHA-256 digest")
    }
    if (!.is_sha256_digest(object@digest)) {
        errors <- c(errors, "digest must be one SHA-256 digest")
    }
    if (!all(c(
        "association_strategy", "package_version", "sampling_design",
        "layer", "input_digest", "state_space_digest", "atlas_digest",
        "target_field", "compute_tier", "dataset_id"
    ) %in% names(object@provenance))) {
        errors <- c(errors, "provenance is missing required fields")
    }
    if (!identical(
        object@evidence_status,
        "estimable-exploratory-only"
    )) {
        errors <- c(
            errors,
            "evidence_status must be 'estimable-exploratory-only'"
        )
    }
    if (length(errors)) errors else TRUE
})

.metadata_atlas_digest <- function(atlas) {
    digest::digest(
        list(
            version = atlas@version,
            dataset_id = atlas@dataset_id,
            associations = atlas@associations,
            observations = atlas@observations,
            exclusions = atlas@exclusions,
            sampling_design = atlas@sampling_design,
            input_digest = atlas@input_digest,
            state_space_digest = atlas@state_space_digest,
            compute_tier = atlas@compute_tier,
            provenance = atlas@provenance,
            evidence_status = atlas@evidence_status
        ),
        algo = "sha256",
        serialize = TRUE
    )
}

.component_proposal_digest <- function(
    target_field,
    reference_level,
    comparison_level,
    ranking,
    observations,
    recommended_component,
    atlas_digest,
    provenance,
    evidence_status
) {
    digest::digest(
        list(
            version = "1.0.0",
            target_field = target_field,
            reference_level = reference_level,
            comparison_level = comparison_level,
            ranking = ranking,
            observations = observations,
            recommended_component = recommended_component,
            atlas_digest = atlas_digest,
            provenance = provenance,
            evidence_status = evidence_status
        ),
        algo = "sha256",
        serialize = TRUE
    )
}

.component_abstention_digest <- function(
    target_field,
    reason,
    candidate_components,
    ranking,
    observations,
    atlas_digest,
    provenance,
    evidence_status
) {
    digest::digest(
        list(
            version = "1.0.0",
            target_field = target_field,
            reason = reason,
            candidate_components = candidate_components,
            ranking = ranking,
            observations = observations,
            atlas_digest = atlas_digest,
            provenance = provenance,
            evidence_status = evidence_status
        ),
        algo = "sha256",
        serialize = TRUE
    )
}

.proposal_step_provenance <- function(atlas, target, atlas_digest) {
    utils::modifyList(
        atlas@provenance,
        list(
            atlas_digest = atlas_digest,
            target_field = target,
            compute_tier = atlas@compute_tier,
            dataset_id = atlas@dataset_id
        )
    )
}

.new_component_abstention <- function(
    atlas,
    target,
    reason,
    ranking,
    candidate_components
) {
    atlas_digest <- .metadata_atlas_digest(atlas)
    observations <- atlas@observations[
        atlas@observations$metadata_field == target,
        ,
        drop = FALSE
    ]
    provenance <- .proposal_step_provenance(
        atlas,
        target,
        atlas_digest
    )
    evidence_status <- "estimable-exploratory-only"
    digest_value <- .component_abstention_digest(
        target_field = target,
        reason = reason,
        candidate_components = candidate_components,
        ranking = ranking,
        observations = observations,
        atlas_digest = atlas_digest,
        provenance = provenance,
        evidence_status = evidence_status
    )
    abstention <- new(
        "ComponentAbstention",
        version = "1.0.0",
        target_field = target,
        reason = reason,
        candidate_components = as.integer(candidate_components),
        ranking = ranking,
        observations = observations,
        atlas_digest = atlas_digest,
        provenance = provenance,
        digest = digest_value,
        evidence_status = evidence_status
    )
    validObject(abstention)
    abstention
}

#' Nominate a component from a metadata-association atlas
#'
#' Components are ordered only by decreasing absolute biological-effect
#' magnitude, with component index as the deterministic tie order. P-values,
#' q-values, singular values, and plots do not participate.
#'
#' @param atlas a `MetadataAssociationAtlas`
#' @param target optional metadata field present in the atlas; omitted when the
#'   source atlas carries a draft `AnalysisSpecification`
#'
#' @return a versioned exploratory `ComponentProposal`, or a
#'   `ComponentAbstention` when the largest effect is tied
#' @export
propose_component <- function(atlas, target = NULL) {
    if (!is(atlas, "MetadataAssociationAtlas")) {
        .stop_landscapeR_validation(
            "propose_component(): atlas must be a MetadataAssociationAtlas"
        )
    }
    declared_target <- atlas@provenance$target_field
    if (is.null(target) && .is_scalar_nonempty_text(declared_target)) {
        target <- declared_target
    } else if (!is.null(target) &&
        .is_scalar_nonempty_text(declared_target) &&
        !identical(target, declared_target)) {
        .stop_landscapeR_validation(
            paste0(
                "propose_component(): target is owned by the source ",
                "AnalysisSpecification and cannot be redeclared"
            )
        )
    }
    if (!is.character(target) || length(target) != 1L ||
        is.na(target) || !nzchar(target)) {
        .stop_landscapeR_validation(
            paste0(
                "propose_component(): source atlas must carry target intent ",
                "or target must be one non-empty field name"
            )
        )
    }
    target_rows <- atlas@associations[
        atlas@associations$metadata_field == target,
        ,
        drop = FALSE
    ]
    if (length(atlas@provenance$nuisance_fields) &&
        any(target_rows$evidence_variant == "adjusted")) {
        target_rows <- target_rows[
            target_rows$evidence_variant == "adjusted",
            ,
            drop = FALSE
        ]
    } else {
        target_rows <- target_rows[
            target_rows$evidence_variant == "unadjusted",
            ,
            drop = FALSE
        ]
    }
    if (nrow(target_rows) &&
        !any(is.finite(target_rows$effect_magnitude))) {
        ranking <- target_rows
        ranking$proposal_rank <- seq_len(nrow(ranking))
        return(.new_component_abstention(
            atlas = atlas,
            target = target,
            reason = target_rows$diagnostic[[1L]],
            ranking = ranking,
            candidate_components = as.integer(target_rows$component)
        ))
    }
    if (!nrow(target_rows)) {
        ranking <- target_rows
        ranking$proposal_rank <- integer()
        return(.new_component_abstention(
            atlas = atlas,
            target = target,
            reason = "no-eligible-association",
            ranking = ranking,
            candidate_components = integer()
        ))
    }
    order_index <- order(
        -target_rows$effect_magnitude,
        target_rows$component
    )
    ranking <- target_rows[order_index, , drop = FALSE]
    ranking$proposal_rank <- seq_len(nrow(ranking))
    rownames(ranking) <- NULL
    recommended <- as.integer(ranking$component[[1L]])
    atlas_digest <- .metadata_atlas_digest(atlas)
    observations <- atlas@observations[
        atlas@observations$metadata_field == target,
        ,
        drop = FALSE
    ]
    provenance <- .proposal_step_provenance(
        atlas,
        target,
        atlas_digest
    )
    evidence_status <- "estimable-exploratory-only"
    top_candidates <- as.integer(ranking$component[
        ranking$effect_magnitude == ranking$effect_magnitude[[1L]]
    ])
    if (length(top_candidates) > 1L) {
        return(.new_component_abstention(
            atlas = atlas,
            target = target,
            reason = "effect-magnitude-tie",
            ranking = ranking,
            candidate_components = top_candidates
        ))
    }
    proposal_digest_value <- .component_proposal_digest(
        target_field = target,
        reference_level = ranking$reference_level[[1L]],
        comparison_level = ranking$comparison_level[[1L]],
        ranking = ranking,
        observations = observations,
        recommended_component = recommended,
        atlas_digest = atlas_digest,
        provenance = provenance,
        evidence_status = evidence_status
    )
    proposal <- new(
        "ComponentProposal",
        version = "1.0.0",
        target_field = target,
        reference_level = ranking$reference_level[[1L]],
        comparison_level = ranking$comparison_level[[1L]],
        ranking = ranking,
        observations = observations,
        recommended_component = recommended,
        atlas_digest = atlas_digest,
        provenance = provenance,
        digest = proposal_digest_value,
        evidence_status = evidence_status
    )
    validObject(proposal)
    proposal
}

#' Extract the ranked table from a component proposal
#'
#' @param proposal a `ComponentProposal`
#' @return an effect-first data frame
#' @export
proposal_ranking <- function(proposal) {
    if (!is(proposal, "ComponentProposal")) {
        stop("proposal_ranking(): proposal must be a ComponentProposal")
    }
    proposal@ranking
}

#' Extract raw target distributions from a component proposal
#'
#' @param proposal a `ComponentProposal`
#' @return a canonical long data frame
#' @export
proposal_observations <- function(proposal) {
    if (!is(proposal, "ComponentProposal")) {
        stop(
            "proposal_observations(): proposal must be a ComponentProposal"
        )
    }
    proposal@observations
}

#' Extract the canonical digest of a component proposal
#'
#' @param proposal a `ComponentProposal`
#' @return one SHA-256 digest
#' @export
proposal_digest <- function(proposal) {
    if (!is(proposal, "ComponentProposal")) {
        stop("proposal_digest(): proposal must be a ComponentProposal")
    }
    proposal@digest
}

#' Extract complete proposal provenance
#'
#' @param proposal a `ComponentProposal`
#' @return a named provenance list inherited from the atlas and proposal step
#' @export
proposal_provenance <- function(proposal) {
    if (!is(proposal, "ComponentProposal")) {
        stop("proposal_provenance(): proposal must be a ComponentProposal")
    }
    proposal@provenance
}

#' @export
as.data.frame.ComponentProposal <- function(
    x,
    row.names = NULL,
    optional = FALSE,
    ...
) {
    proposal_ranking(x)
}

#' Extract the ranked evidence from a component abstention
#'
#' @param abstention a `ComponentAbstention`
#' @return an effect-first data frame
#' @export
abstention_ranking <- function(abstention) {
    if (!is(abstention, "ComponentAbstention")) {
        stop(
            "abstention_ranking(): abstention must be a ComponentAbstention"
        )
    }
    abstention@ranking
}

#' Extract the canonical digest of a component abstention
#'
#' @param abstention a `ComponentAbstention`
#' @return one SHA-256 digest
#' @export
abstention_digest <- function(abstention) {
    if (!is(abstention, "ComponentAbstention")) {
        stop(
            "abstention_digest(): abstention must be a ComponentAbstention"
        )
    }
    abstention@digest
}

#' Extract complete abstention provenance
#'
#' @param abstention a `ComponentAbstention`
#' @return a named provenance list inherited from the atlas and proposal step
#' @export
abstention_provenance <- function(abstention) {
    if (!is(abstention, "ComponentAbstention")) {
        stop(
            paste0(
                "abstention_provenance(): abstention must be a ",
                "ComponentAbstention"
            )
        )
    }
    abstention@provenance
}

#' @export
as.data.frame.ComponentAbstention <- function(
    x,
    row.names = NULL,
    optional = FALSE,
    ...
) {
    abstention_ranking(x)
}

#' Confirm a proposed component by explicit human decision
#'
#' This is the only public bridge from exploratory component ranking to a
#' confirmed `AnalysisSpecification`. Acceptance must use the recommended
#' component; choosing another ranked component requires an explicit override.
#' A typed abstention cannot be bypassed.
#'
#' @param proposal a `ComponentProposal`
#' @param index positive component index from the proposal ranking
#' @param decision `"accept"` or `"override"`
#' @param rationale non-empty analyst rationale
#'
#' @return a confirmed `AnalysisSpecification`
#' @export
confirm_component <- function(
    proposal,
    index,
    decision,
    rationale
) {
    if (is(proposal, "ComponentAbstention")) {
        .stop_landscapeR_validation(
            "confirm_component(): cannot confirm a component abstention"
        )
    }
    if (!is(proposal, "ComponentProposal")) {
        .stop_landscapeR_validation(
            "confirm_component(): proposal must be a ComponentProposal"
        )
    }
    if (!is.numeric(index) || length(index) != 1L ||
        is.na(index) || !is.finite(index) ||
        index != as.integer(index) || index < 1L) {
        .stop_landscapeR_validation(
            "confirm_component(): index must be one positive integer"
        )
    }
    index <- as.integer(index)
    if (!index %in% proposal@ranking$component) {
        .stop_landscapeR_validation(
            "confirm_component(): index must occur in the proposal ranking"
        )
    }
    if (missing(decision) ||
        !is.character(decision) || length(decision) != 1L ||
        is.na(decision) || !decision %in% c("accept", "override")) {
        .stop_landscapeR_validation(
            "confirm_component(): decision must be 'accept' or 'override'"
        )
    }
    if (!is.character(rationale) || length(rationale) != 1L ||
        is.na(rationale) || !nzchar(trimws(rationale))) {
        .stop_landscapeR_validation(
            "confirm_component(): rationale must be one non-empty string"
        )
    }
    if (identical(decision, "accept") &&
        !identical(index, proposal@recommended_component)) {
        .stop_landscapeR_validation(paste0(
            "confirm_component(): accept must use the recommended component; ",
            "use decision = 'override' for another ranked component"
        ))
    }

    declared_specification <- .is_scalar_nonempty_text(
        proposal@provenance$analysis_specification_digest
    )
    specification_id <- if (declared_specification) {
        proposal@provenance$analysis_specification_id
    } else {
        sprintf(
            "%s_%s_PC%d",
            proposal@provenance$dataset_id,
            proposal@target_field,
            index
        )
    }
    analysis_specification(
        id = specification_id,
        target_field = proposal@target_field,
        target_type = if (declared_specification) {
            proposal@provenance$target_type
        } else {
            "binary"
        },
        reference_level = proposal@reference_level,
        comparison_level = proposal@comparison_level,
        lifecycle = "confirmed",
        selected_component = index,
        proposal_digest = proposal@digest,
        proposal_decision = if (identical(decision, "accept")) {
            "accepted"
        } else {
            "overridden"
        },
        analyst_rationale = rationale,
        nuisance_fields = if (declared_specification) {
            proposal@provenance$nuisance_fields
        } else {
            character()
        },
        claim_intent = if (declared_specification) {
            proposal@provenance$claim_intent
        } else {
            "exploratory"
        }
    )
}

#' Plot a metadata-association atlas
#'
#' Displays the raw component-score distributions for every eligible metadata
#' field and component. Reference/comparison separation and overlap remain
#' visible without relying on colour; supporting p- and q-values do not control
#' the display.
#'
#' @param x a `MetadataAssociationAtlas`
#' @param y ignored
#' @param ... ignored
#' @return a `ggplot` object
#' @export
plot.MetadataAssociationAtlas <- function(x, y, ...) {
    data <- atlas_observations(x)
    available <- data[data$available, , drop = FALSE]
    categorical <- available[
        available$metadata_type == "categorical",
        ,
        drop = FALSE
    ]
    numeric <- available[
        available$metadata_type %in% c("continuous", "ordered"),
        ,
        drop = FALSE
    ]
    ggplot2::ggplot(data) +
        ggplot2::geom_boxplot(
            data = categorical,
            mapping = ggplot2::aes(
            x = .data[["metadata_value"]],
            y = .data[["score"]]
            ),
            width = 0.5,
            outlier.shape = NA,
            colour = "#111111",
            fill = "#FFFFFF",
            linewidth = 0.45
        ) +
        ggplot2::geom_point(
            data = categorical,
            mapping = ggplot2::aes(
                x = .data[["metadata_value"]],
                y = .data[["score"]]
            ),
            shape = 21,
            size = 1.8,
            stroke = 0.45,
            colour = "#111111",
            fill = "#FFFFFF",
            position = ggplot2::position_jitter(
                width = 0.08,
                height = 0,
                seed = 79L
            )
        ) +
        ggplot2::geom_point(
            data = numeric,
            mapping = ggplot2::aes(
                x = .data[["metadata_numeric"]],
                y = .data[["score"]]
            ),
            shape = 21,
            size = 1.8,
            stroke = 0.45,
            colour = "#111111",
            fill = "#FFFFFF"
        ) +
        ggplot2::geom_smooth(
            data = numeric,
            mapping = ggplot2::aes(
                x = .data[["metadata_numeric"]],
                y = .data[["score"]]
            ),
            method = "lm",
            formula = y ~ x,
            se = FALSE,
            colour = "#111111",
            linewidth = 0.6
        ) +
        ggplot2::geom_smooth(
            data = numeric,
            mapping = ggplot2::aes(
                x = .data[["metadata_numeric"]],
                y = .data[["score"]]
            ),
            method = "loess",
            formula = y ~ x,
            se = FALSE,
            colour = "#B2182B",
            linewidth = 0.7
        ) +
        ggplot2::facet_grid(
            rows = ggplot2::vars(metadata_field),
            cols = ggplot2::vars(component_label),
            scales = "free"
        ) +
        ggplot2::labs(
            title = "Metadata association atlas",
            subtitle = paste(
                "Raw observations with linear and flexible fits;",
                "exploratory evidence only"
            ),
            x = "Metadata value",
            y = "Component score"
        ) +
        theme_landscapeR()
}

#' Plot an effect-first component proposal
#'
#' Displays raw target distributions for every ranked component. Facet labels
#' expose the frozen effect rank and magnitude, and a red diamond marks the
#' uniquely recommended component by both colour and shape.
#'
#' @param x a `ComponentProposal`
#' @param y ignored
#' @param ... ignored
#' @return a `ggplot` object
#' @export
plot.ComponentProposal <- function(x, y, ...) {
    data <- proposal_observations(x)
    available <- data[data$available, , drop = FALSE]
    ranking <- proposal_ranking(x)
    facet_labels <- stats::setNames(
        sprintf(
            "%s  |  rank %d  |  |r| = %.2f",
            ranking$component_label,
            ranking$proposal_rank,
            ranking$effect_magnitude
        ),
        ranking$component_label
    )
    recommended_data <- available[
        available$component == x@recommended_component,
        ,
        drop = FALSE
    ]
    marker_range <- diff(range(recommended_data$score))
    if (!is.finite(marker_range) || marker_range == 0) marker_range <- 1
    marker <- data.frame(
        component_label = unique(recommended_data$component_label),
        metadata_value = x@comparison_level,
        score = max(recommended_data$score) + 0.12 * marker_range,
        stringsAsFactors = FALSE
    )

    ggplot2::ggplot(
        data,
        ggplot2::aes(
            x = .data[["metadata_value"]],
            y = .data[["score"]]
        )
    ) +
        ggplot2::geom_boxplot(
            data = available,
            width = 0.5,
            outlier.shape = NA,
            colour = "#111111",
            fill = "#FFFFFF",
            linewidth = 0.45
        ) +
        ggplot2::geom_point(
            data = available,
            shape = 21,
            size = 1.8,
            stroke = 0.45,
            colour = "#111111",
            fill = "#FFFFFF",
            position = ggplot2::position_jitter(
                width = 0.08,
                height = 0,
                seed = 79L
            )
        ) +
        ggplot2::geom_point(
            data = marker,
            ggplot2::aes(
                x = .data[["metadata_value"]],
                y = .data[["score"]]
            ),
            inherit.aes = FALSE,
            shape = 23,
            size = 3.2,
            stroke = 0.65,
            colour = "#111111",
            fill = "#C61A2A"
        ) +
        ggplot2::facet_wrap(
            ggplot2::vars(component_label),
            scales = "free",
            labeller = ggplot2::as_labeller(facet_labels)
        ) +
        ggplot2::scale_y_continuous(
            expand = ggplot2::expansion(mult = c(0.05, 0.16))
        ) +
        ggplot2::labs(
            title = sprintf(
                "Component proposal for %s",
                x@target_field
            ),
            subtitle = paste(
                "Raw target distributions;",
                "ranked by absolute biological effect only"
            ),
            x = "Target level",
            y = "Component score",
            caption = paste(
                "The red diamond marks the proposed component;",
                "human confirmation is required"
            )
        ) +
        theme_landscapeR()
}
