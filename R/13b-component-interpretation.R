# Cross-sectional component interpretation (ADR 0020; issues #79 and #80)

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
    "score", "available"
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

.monotonicity_diagnostic <- function(scores, values) {
    if (!is.numeric(values) && !is.ordered(values)) {
        return("")
    }
    complete <- is.finite(scores) & !is.na(values)
    if (is.numeric(values)) {
        complete <- complete & is.finite(values)
    }
    scores <- scores[complete]
    values <- values[complete]
    if (length(scores) < 3L) return("")
    groups <- if (is.ordered(values)) {
        factor(values, levels = levels(values), ordered = TRUE)
    } else {
        values
    }
    medians <- tapply(scores, groups, stats::median)
    changes <- diff(as.numeric(medians))
    changes <- changes[is.finite(changes) & changes != 0]
    if (any(changes > 0) && any(changes < 0)) {
        "possible-nonmonotone-association"
    } else {
        ""
    }
}

.association_resampling_plan <- function(
    values,
    nuisance_values,
    n_resamples,
    seed
) {
    if (n_resamples == 0L) {
        return(list(indices = list(), digest = NA_character_))
    }
    complete <- !is.na(values)
    if (is.numeric(values)) complete <- complete & is.finite(values)
    for (nuisance in nuisance_values) {
        complete <- complete & !is.na(nuisance)
        if (is.numeric(nuisance)) {
            complete <- complete & is.finite(nuisance)
        }
    }
    strata_fields <- list()
    if (!is.numeric(values) || is.ordered(values)) {
        strata_fields$target <- as.character(values)
    }
    for (field in names(nuisance_values)) {
        nuisance <- nuisance_values[[field]]
        if (!is.numeric(nuisance) || is.ordered(nuisance)) {
            strata_fields[[field]] <- as.character(nuisance)
        }
    }
    complete_indices <- which(complete)
    strata <- if (length(strata_fields)) {
        interaction(
            lapply(strata_fields, `[`, complete),
            drop = TRUE,
            lex.order = TRUE
        )
    } else {
        factor(rep("all", length(complete_indices)))
    }
    strata_indices <- split(complete_indices, strata, drop = TRUE)
    had_seed <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
    if (had_seed) {
        previous_seed <- get(".Random.seed", envir = .GlobalEnv)
    }
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
    indices <- replicate(n_resamples, {
        unlist(lapply(strata_indices, function(index) {
            sample(index, length(index), replace = TRUE)
        }), use.names = FALSE)
    }, simplify = FALSE)
    list(
        indices = indices,
        digest = digest::digest(
            list(seed = seed, strata = strata_indices, indices = indices),
            algo = "sha256",
            serialize = TRUE
        )
    )
}

.resampling_summary <- function(estimates, plan) {
    finite <- estimates[is.finite(estimates)]
    n_resamples <- length(estimates)
    if (!n_resamples) {
        return(list(
            effect_conf_low = NA_real_,
            effect_conf_high = NA_real_,
            n_resamples = 0L,
            resample_failures = 0L,
            resampling_method = "not-requested",
            resampling_plan_digest = NA_character_
        ))
    }
    interval <- if (length(finite)) {
        stats::quantile(
            finite,
            probs = c(0.025, 0.975),
            names = FALSE,
            type = 6
        )
    } else {
        c(NA_real_, NA_real_)
    }
    list(
        effect_conf_low = interval[[1L]],
        effect_conf_high = interval[[2L]],
        n_resamples = as.integer(n_resamples),
        resample_failures = as.integer(n_resamples - length(finite)),
        resampling_method = "stratified-biological-unit-bootstrap",
        resampling_plan_digest = plan$digest
    )
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
    allowed_compute_tiers <- c(
        "analytic-unadjusted",
        "analytic-adjusted",
        "standard-resampled"
    )
    if (length(object@compute_tier) != 1L ||
        !object@compute_tier %in% allowed_compute_tiers) {
        errors <- c(errors, "compute_tier is not supported")
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
            cohort_digest = .association_cohort_digest(
                names(target_values),
                complete
            ),
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

.adjusted_resampled_estimate <- function(
    scores,
    target_values,
    nuisance_values,
    specification
) {
    if (length(scores) < 3L) return(NA_real_)
    design <- .nuisance_design(
        nuisance_values,
        rep(TRUE, length(scores))
    )
    target_numeric <- if (identical(specification@target_type, "binary")) {
        match(
            as.character(target_values),
            c(specification@reference_level, specification@comparison_level)
        )
    } else if (identical(specification@target_type, "ordered")) {
        match(
            as.character(target_values),
            specification@ordered_levels
        )
    } else {
        as.numeric(target_values)
    }
    score_rank <- rank(scores, ties.method = "average")
    target_rank <- rank(target_numeric, ties.method = "average")
    if (qr(design)$rank < ncol(design) ||
        qr(cbind(design, target_rank))$rank == qr(design)$rank) {
        return(NA_real_)
    }
    score_residual <- stats::lm.fit(design, score_rank)$residuals
    target_residual <- stats::lm.fit(design, target_rank)$residuals
    if (stats::var(score_residual) == 0 ||
        stats::var(target_residual) == 0) {
        return(NA_real_)
    }
    stats::cor(score_residual, target_residual)
}

.unordered_rank_effect <- function(scores, values) {
    complete <- is.finite(scores) & !is.na(values)
    complete_scores <- scores[complete]
    complete_values <- droplevels(values[complete])
    n_groups <- nlevels(complete_values)
    if (length(complete_scores) <= n_groups || n_groups < 2L) {
        return(NULL)
    }
    test <- stats::kruskal.test(complete_scores, complete_values)
    epsilon_squared <- max(
        0,
        (unname(test$statistic) - n_groups + 1) /
            (length(complete_scores) - n_groups)
    )
    score_ties <- duplicated(complete_scores) |
        duplicated(complete_scores, fromLast = TRUE)
    target_ties <- duplicated(complete_values) |
        duplicated(complete_values, fromLast = TRUE)
    list(
        estimand = "kruskal-wallis-epsilon-squared",
        estimate = epsilon_squared,
        reference_level = NA_character_,
        comparison_level = NA_character_,
        n_available = length(complete_scores),
        n_score_ties = sum(score_ties),
        n_target_ties = sum(target_ties),
        p_value = unname(test$p.value),
        cohort_digest = .association_cohort_digest(
            names(values),
            complete
        )
    )
}

#' Associate Stage 1 components with eligible metadata
#'
#' The cross-sectional tracer supports one biological layer. Binary metadata
#' use signed rank-biserial association, continuous metadata use Spearman
#' association, and ordered factors use Kendall tau-b against their declared
#' level order. Unordered multilevel factors retain descriptive Kruskal-Wallis
#' epsilon-squared evidence but cannot nominate a component. Binary factor
#' levels declare reference then comparison; character or logical levels use
#' deterministic lexical order. Identifier-like fields and caller-declared
#' non-analytical fields are excluded from target association with reasons.
#'
#' @param std a Stage-1-complete `StateTransitionData`
#' @param specification optional draft `AnalysisSpecification` owning target
#'   and nuisance intent for this run
#' @param non_analytical_fields metadata fields to exclude explicitly
#' @param dataset_id optional stable dataset identifier used in confirmed
#'   analysis IDs; defaults to `metadata(std)$dataset_id` when present, then a
#'   deterministic input-digest identifier
#' @param n_resamples number of design-preserving association bootstraps; zero
#'   retains point/descriptive evidence only
#' @param seed deterministic bootstrap seed
#'
#' @return a validated `MetadataAssociationAtlas`
#' @export
associate_metadata <- function(
    std,
    specification = NULL,
    non_analytical_fields = character(),
    dataset_id = NULL,
    n_resamples = 0L,
    seed = 1L
) {
    if (!is(std, "StateTransitionData")) {
        .stop_landscapeR_validation(
            "associate_metadata(): std must be a StateTransitionData object"
        )
    }
    if (length(n_resamples) != 1L ||
        is.na(n_resamples) ||
        n_resamples < 0 ||
        n_resamples != as.integer(n_resamples)) {
        .stop_landscapeR_validation(
            "associate_metadata(): n_resamples must be one non-negative integer"
        )
    }
    n_resamples <- as.integer(n_resamples)
    if (length(seed) != 1L || is.na(seed) || seed != as.integer(seed)) {
        .stop_landscapeR_validation(
            "associate_metadata(): seed must be one integer"
        )
    }
    seed <- as.integer(seed)
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
            reference_level = specification@reference_level,
            comparison_level = specification@comparison_level,
            ordered_levels = specification@ordered_levels,
            continuous_direction = specification@continuous_direction,
            nuisance_fields = specification@nuisance_fields,
            nuisance_values = stats::setNames(
                lapply(specification@nuisance_fields, function(field) {
                    .aligned_component_metadata(
                        std,
                        1L,
                        field,
                        caller = "associate_metadata"
                    )
                }),
                specification@nuisance_fields
            ),
            orientation_anchor = specification@orientation_anchor,
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
        descriptive_unordered <- is.factor(values) &&
            !is.ordered(values) &&
            nlevels(droplevels(values[!is.na(values)])) > 2L
        if (is.null(strategy) && !descriptive_unordered) {
            exclusion_rows[[length(exclusion_rows) + 1L]] <- data.frame(
                metadata_field = field,
                reason = "unsupported-non-binary-field",
                stringsAsFactors = FALSE
            )
            next
        }
        if (!is.null(strategy)) {
            association_strategy_ids <- c(
                association_strategy_ids,
                association_strategy_id(strategy)
            )
        }
        field_nuisance_values <- if (
            !is.null(specification) &&
            identical(field, specification@target_field)
        ) {
            specification_provenance$nuisance_values
        } else {
            list()
        }
        resampling_plan <- .association_resampling_plan(
            values,
            field_nuisance_values,
            n_resamples,
            seed + match(field, metadata_fields) - 1L
        )

        field_rows <- lapply(seq_len(ncol(coordinate_matrix)), function(j) {
            scores <- coordinate_matrix[, j]
            effect <- if (descriptive_unordered) {
                .unordered_rank_effect(scores, values)
            } else {
                associate_component(strategy, scores, values)
            }
            if (is.null(effect)) return(NULL)
            complete <- is.finite(scores) & !is.na(values)
            resampled_estimates <- vapply(
                resampling_plan$indices,
                function(index) {
                    resampled <- if (descriptive_unordered) {
                        .unordered_rank_effect(
                            scores[index],
                            values[index]
                        )
                    } else {
                        associate_component(
                            strategy,
                            scores[index],
                            values[index]
                        )
                    }
                    if (is.null(resampled)) NA_real_ else resampled$estimate
                },
                numeric(1L)
            )
            uncertainty <- .resampling_summary(
                resampled_estimates,
                resampling_plan
            )
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
                proposal_eligible = !descriptive_unordered,
                nuisance_fields = "",
                cohort_digest = if (!is.null(effect$cohort_digest)) {
                    effect$cohort_digest
                } else {
                    .association_cohort_digest(names(values), complete)
                },
                design_digest = NA_character_,
                diagnostic = .monotonicity_diagnostic(scores, values),
                p_value = effect$p_value,
                q_value = NA_real_,
                effect_conf_low = uncertainty$effect_conf_low,
                effect_conf_high = uncertainty$effect_conf_high,
                n_resamples = uncertainty$n_resamples,
                resample_failures = uncertainty$resample_failures,
                resampling_method = uncertainty$resampling_method,
                resampling_plan_digest =
                    uncertainty$resampling_plan_digest,
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
                        resampled_estimates <- vapply(
                            resampling_plan$indices,
                            function(index) {
                                .adjusted_resampled_estimate(
                                    coordinate_matrix[index, j],
                                    values[index],
                                    lapply(
                                        field_nuisance_values,
                                        `[`,
                                        index
                                    ),
                                    specification
                                )
                            },
                            numeric(1L)
                        )
                        uncertainty <- .resampling_summary(
                            resampled_estimates,
                            resampling_plan
                        )
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
                            proposal_eligible = TRUE,
                            nuisance_fields = paste(
                                specification@nuisance_fields,
                                collapse = " + "
                            ),
                            cohort_digest = effect$cohort_digest,
                            design_digest = effect$design_digest,
                            diagnostic = effect$diagnostic,
                            p_value = effect$p_value,
                            q_value = NA_real_,
                            effect_conf_low = uncertainty$effect_conf_low,
                            effect_conf_high = uncertainty$effect_conf_high,
                            n_resamples = uncertainty$n_resamples,
                            resample_failures =
                                uncertainty$resample_failures,
                            resampling_method =
                                uncertainty$resampling_method,
                            resampling_plan_digest =
                                uncertainty$resampling_plan_digest,
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
                "estimate", "effect_magnitude", "p_value", "q_value",
                "effect_conf_low", "effect_conf_high"
            )) numeric() else if (identical(name, "proposal_eligible")) {
                logical()
            } else if (name %in% c(
                "n_resamples", "resample_failures"
            )) {
                integer()
            } else character()
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
        compute_tier = if (n_resamples > 0L) {
            "standard-resampled"
        } else if (
            !is.null(specification) &&
            length(specification@nuisance_fields)
        ) {
            "analytic-adjusted"
        } else {
            "analytic-unadjusted"
        },
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

#' Search-aware permutation evidence
#'
#' A typed record of the maximum absolute target effect obtained after
#' repeating the complete eligible-component search under each null
#' permutation. It cannot alter point ranking.
#'
#' @slot version schema version, currently `"1.0.0"`
#' @slot method permutation method or `"none"`
#' @slot status computation status
#' @slot n_requested,n_completed requested and completed permutations
#' @slot observed_max_effect observed maximum absolute target effect
#' @slot null_max_effect maximum absolute effect from each null search
#' @slot search_aware_p_value finite-sample corrected search-aware p-value
#' @slot seed deterministic permutation seed
#' @slot cohort_digest complete analysis-cohort digest
#' @slot design_digest nuisance-design digest when adjusted
#' @slot diagnostic machine-readable diagnostic
#'
#' @export
setClass("PermutationEvidence",
    representation(
        version = "character",
        method = "character",
        status = "character",
        n_requested = "integer",
        n_completed = "integer",
        observed_max_effect = "numeric",
        null_max_effect = "numeric",
        search_aware_p_value = "numeric",
        seed = "integer",
        cohort_digest = "character",
        design_digest = "character",
        diagnostic = "character"
    ),
    prototype = prototype(
        version = "1.0.0",
        method = "none",
        status = "not-requested",
        n_requested = 0L,
        n_completed = 0L,
        observed_max_effect = NA_real_,
        null_max_effect = numeric(),
        search_aware_p_value = NA_real_,
        seed = NA_integer_,
        cohort_digest = NA_character_,
        design_digest = NA_character_,
        diagnostic = ""
    )
)

setValidity("PermutationEvidence", function(object) {
    errors <- character()
    statuses <- c(
        "not-requested", "complete", "not-identifiable",
        "insufficient-support"
    )
    if (!identical(object@version, "1.0.0")) {
        errors <- c(errors, "version must be '1.0.0'")
    }
    if (length(object@status) != 1L || !object@status %in% statuses) {
        errors <- c(errors, "status is not supported")
    }
    if (length(object@n_requested) != 1L ||
        length(object@n_completed) != 1L ||
        object@n_requested < 0L ||
        object@n_completed < 0L) {
        errors <- c(errors, "permutation counts must be non-negative scalars")
    }
    if (identical(object@status, "complete")) {
        if (object@n_requested < 1L ||
            !identical(object@n_completed, object@n_requested) ||
            length(object@null_max_effect) != object@n_completed ||
            any(!is.finite(object@null_max_effect)) ||
            !is.finite(object@observed_max_effect) ||
            !is.finite(object@search_aware_p_value) ||
            object@search_aware_p_value < 0 ||
            object@search_aware_p_value > 1 ||
            !.is_sha256_digest(object@cohort_digest)) {
            errors <- c(errors, "complete permutation evidence is malformed")
        }
    } else if (length(object@null_max_effect) ||
        object@n_completed != 0L ||
        !is.na(object@search_aware_p_value)) {
        errors <- c(errors, "incomplete evidence must not contain null results")
    }
    if (object@status %in% c("not-identifiable", "insufficient-support") &&
        !.is_scalar_nonempty_text(object@diagnostic)) {
        errors <- c(errors, "incomplete evidence requires a diagnostic")
    }
    if (length(errors)) errors else TRUE
})

.new_permutation_evidence <- function(
    method = "none",
    status = "not-requested",
    n_requested = 0L,
    n_completed = 0L,
    observed_max_effect = NA_real_,
    null_max_effect = numeric(),
    search_aware_p_value = NA_real_,
    seed = NA_integer_,
    cohort_digest = NA_character_,
    design_digest = NA_character_,
    diagnostic = ""
) {
    evidence <- new(
        "PermutationEvidence",
        version = "1.0.0",
        method = method,
        status = status,
        n_requested = as.integer(n_requested),
        n_completed = as.integer(n_completed),
        observed_max_effect = as.numeric(observed_max_effect),
        null_max_effect = as.numeric(null_max_effect),
        search_aware_p_value = as.numeric(search_aware_p_value),
        seed = as.integer(seed),
        cohort_digest = as.character(cohort_digest),
        design_digest = as.character(design_digest),
        diagnostic = diagnostic
    )
    validObject(evidence)
    evidence
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
#' @slot permutation_evidence typed search-aware null evidence
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
        permutation_evidence = "PermutationEvidence",
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
        permutation_evidence = new("PermutationEvidence"),
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
        "non-identifiable-design",
        "permutation-not-identifiable",
        "insufficient-resampling-support"
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
    permutation_candidates_valid <- object@reason %in% c(
        "permutation-not-identifiable",
        "insufficient-resampling-support"
    ) && length(object@candidate_components) >= 1L
    if ((!tie_candidates_valid &&
            !empty_candidates_valid &&
            !design_candidates_valid &&
            !permutation_candidates_valid) ||
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
#' @slot permutation_evidence typed search-aware null evidence
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
        permutation_evidence = "PermutationEvidence",
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
        permutation_evidence = new("PermutationEvidence"),
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
    binary_target <- is.null(object@provenance$target_type) ||
        identical(object@provenance$target_type, "binary")
    if (binary_target &&
        (!.is_scalar_nonempty_text(object@reference_level) ||
            !.is_scalar_nonempty_text(object@comparison_level) ||
            identical(object@reference_level, object@comparison_level))) {
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
    permutation_evidence,
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
            permutation_evidence = permutation_evidence,
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
    permutation_evidence,
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
            permutation_evidence = permutation_evidence,
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
    candidate_components,
    permutation_evidence = .new_permutation_evidence()
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
        permutation_evidence = permutation_evidence,
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
        permutation_evidence = permutation_evidence,
        atlas_digest = atlas_digest,
        provenance = provenance,
        digest = digest_value,
        evidence_status = evidence_status
    )
    validObject(abstention)
    abstention
}

.permutation_target_values <- function(atlas, target, observations) {
    values <- observations$metadata_value
    target_type <- atlas@provenance$target_type
    if (identical(target_type, "binary")) {
        return(factor(
            values,
            levels = c(
                atlas@provenance$reference_level,
                atlas@provenance$comparison_level
            )
        ))
    }
    if (identical(target_type, "ordered")) {
        return(ordered(
            values,
            levels = atlas@provenance$ordered_levels
        ))
    }
    if (identical(target_type, "continuous")) {
        return(observations$metadata_numeric)
    }
    NULL
}

.permuted_target_effect <- function(atlas, scores, values) {
    target_type <- atlas@provenance$target_type
    if (identical(target_type, "binary")) {
        effect <- .signed_rank_biserial(
            scores,
            values,
            atlas@provenance$reference_level,
            atlas@provenance$comparison_level
        )
        return(if (is.null(effect)) NA_real_ else effect$estimate)
    }
    if (identical(target_type, "continuous")) {
        return(stats::cor(
            rank(scores, ties.method = "average"),
            rank(values, ties.method = "average")
        ))
    }
    if (identical(target_type, "ordered")) {
        return(stats::cor(
            scores,
            as.integer(values),
            method = "kendall"
        ))
    }
    NA_real_
}

.permutation_indices <- function(n_observations, n_permutations, seed) {
    had_seed <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
    if (had_seed) {
        previous_seed <- get(".Random.seed", envir = .GlobalEnv)
    }
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
    replicate(
        n_permutations,
        sample.int(n_observations),
        simplify = FALSE
    )
}

.permutation_supports_resolution <- function(values, n_permutations) {
    counts <- as.numeric(table(values, useNA = "no"))
    log_arrangements <- lgamma(sum(counts) + 1) -
        sum(lgamma(counts + 1))
    log(n_permutations + 1) <= log_arrangements
}

.nuisance_design <- function(nuisance_values, complete) {
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
    stats::model.matrix(~ ., data = nuisance_frame)
}

.compute_permutation_evidence <- function(
    atlas,
    target,
    ranking,
    n_permutations,
    seed
) {
    if (n_permutations == 0L) {
        return(.new_permutation_evidence())
    }
    if (!.is_scalar_nonempty_text(
        atlas@provenance$analysis_specification_digest
    )) {
        return(.new_permutation_evidence(
            status = "not-identifiable",
            n_requested = n_permutations,
            seed = seed,
            diagnostic = "missing-declared-target-intent"
        ))
    }
    target_observations <- atlas@observations[
        atlas@observations$metadata_field == target,
        ,
        drop = FALSE
    ]
    components <- sort(unique(target_observations$component))
    first <- target_observations[
        target_observations$component == components[[1L]],
        ,
        drop = FALSE
    ]
    first <- first[order(first$sample_index), , drop = FALSE]
    values <- .permutation_target_values(atlas, target, first)
    if (is.null(values)) {
        return(.new_permutation_evidence(
            status = "not-identifiable",
            n_requested = n_permutations,
            seed = seed,
            diagnostic = "unsupported-declared-target-type"
        ))
    }
    complete <- first$available & !is.na(values)
    nuisance_values <- atlas@provenance$nuisance_values
    if (length(atlas@provenance$nuisance_fields)) {
        if (!is.list(nuisance_values) ||
            !identical(
                names(nuisance_values),
                atlas@provenance$nuisance_fields
            )) {
            return(.new_permutation_evidence(
                status = "not-identifiable",
                n_requested = n_permutations,
                seed = seed,
                diagnostic = "missing-nuisance-permutation-data"
            ))
        }
        for (nuisance in nuisance_values) {
            complete <- complete & !is.na(nuisance)
            if (is.numeric(nuisance)) {
                complete <- complete & is.finite(nuisance)
            }
        }
    }
    complete_values <- values[complete]
    cohort_digest <- .association_cohort_digest(
        first$primary_sample,
        complete
    )
    if (!.permutation_supports_resolution(
        complete_values,
        n_permutations
    )) {
        return(.new_permutation_evidence(
            status = "insufficient-support",
            n_requested = n_permutations,
            seed = seed,
            cohort_digest = cohort_digest,
            diagnostic = "insufficient-distinct-rearrangements"
        ))
    }
    permutation_plan <- .permutation_indices(
        sum(complete),
        n_permutations,
        seed
    )
    score_matrix <- vapply(components, function(component) {
        component_rows <- target_observations[
            target_observations$component == component,
            ,
            drop = FALSE
        ]
        component_rows <- component_rows[
            order(component_rows$sample_index),
            ,
            drop = FALSE
        ]
        component_rows$score[complete]
    }, numeric(sum(complete)))

    if (!length(atlas@provenance$nuisance_fields)) {
        null_max <- vapply(permutation_plan, function(indices) {
            effects <- apply(score_matrix, 2L, function(scores) {
                .permuted_target_effect(
                    atlas,
                    scores,
                    complete_values[indices]
                )
            })
            max(abs(effects), na.rm = TRUE)
        }, numeric(1L))
        method <- "label-permutation"
        design_digest <- NA_character_
    } else {
        design <- .nuisance_design(nuisance_values, complete)
        if (qr(design)$rank < ncol(design)) {
            return(.new_permutation_evidence(
                status = "not-identifiable",
                n_requested = n_permutations,
                seed = seed,
                cohort_digest = cohort_digest,
                diagnostic = "non-identifiable-permutation-design"
            ))
        }
        target_numeric <- if (identical(
            atlas@provenance$target_type,
            "binary"
        )) {
            match(
                as.character(complete_values),
                c(
                    atlas@provenance$reference_level,
                    atlas@provenance$comparison_level
                )
            )
        } else if (identical(
            atlas@provenance$target_type,
            "ordered"
        )) {
            match(
                as.character(complete_values),
                atlas@provenance$ordered_levels
            )
        } else {
            as.numeric(complete_values)
        }
        target_rank <- rank(target_numeric, ties.method = "average")
        target_residual <- stats::lm.fit(design, target_rank)$residuals
        score_models <- lapply(seq_len(ncol(score_matrix)), function(j) {
            score_rank <- rank(
                score_matrix[, j],
                ties.method = "average"
            )
            fit <- stats::lm.fit(design, score_rank)
            list(fitted = fit$fitted.values, residuals = fit$residuals)
        })
        null_max <- vapply(permutation_plan, function(indices) {
            effects <- vapply(score_models, function(model) {
                reconstructed <- model$fitted + model$residuals[indices]
                reconstructed_residual <- stats::lm.fit(
                    design,
                    reconstructed
                )$residuals
                stats::cor(reconstructed_residual, target_residual)
            }, numeric(1L))
            max(abs(effects), na.rm = TRUE)
        }, numeric(1L))
        method <- "nuisance-only-residual-permutation"
        design_digest <- unique(ranking$design_digest)[[1L]]
    }
    observed <- max(ranking$effect_magnitude)
    .new_permutation_evidence(
        method = method,
        status = "complete",
        n_requested = n_permutations,
        n_completed = n_permutations,
        observed_max_effect = observed,
        null_max_effect = null_max,
        search_aware_p_value = (
            1 + sum(null_max >= observed)
        ) / (n_permutations + 1),
        seed = seed,
        cohort_digest = cohort_digest,
        design_digest = design_digest
    )
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
#' @param n_permutations number of complete-search null permutations; zero
#'   retains point/descriptive evidence only
#' @param seed deterministic permutation seed
#'
#' @return a versioned exploratory `ComponentProposal`, or a
#'   `ComponentAbstention` when the largest effect is tied
#' @export
propose_component <- function(
    atlas,
    target = NULL,
    n_permutations = 0L,
    seed = 1L
) {
    if (!is(atlas, "MetadataAssociationAtlas")) {
        .stop_landscapeR_validation(
            "propose_component(): atlas must be a MetadataAssociationAtlas"
        )
    }
    if (length(n_permutations) != 1L ||
        is.na(n_permutations) ||
        n_permutations < 0 ||
        n_permutations != as.integer(n_permutations)) {
        .stop_landscapeR_validation(
            "propose_component(): n_permutations must be one non-negative integer"
        )
    }
    n_permutations <- as.integer(n_permutations)
    if (length(seed) != 1L ||
        is.na(seed) ||
        seed != as.integer(seed)) {
        .stop_landscapeR_validation(
            "propose_component(): seed must be one integer"
        )
    }
    seed <- as.integer(seed)
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
        atlas@associations$metadata_field == target &
            atlas@associations$proposal_eligible,
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
    permutation_evidence <- .compute_permutation_evidence(
        atlas,
        target,
        ranking,
        n_permutations,
        seed
    )
    if (identical(permutation_evidence@status, "not-identifiable")) {
        return(.new_component_abstention(
            atlas = atlas,
            target = target,
            reason = "permutation-not-identifiable",
            ranking = ranking,
            candidate_components = as.integer(ranking$component),
            permutation_evidence = permutation_evidence
        ))
    }
    if (identical(permutation_evidence@status, "insufficient-support")) {
        return(.new_component_abstention(
            atlas = atlas,
            target = target,
            reason = "insufficient-resampling-support",
            ranking = ranking,
            candidate_components = as.integer(ranking$component),
            permutation_evidence = permutation_evidence
        ))
    }
    proposal_digest_value <- .component_proposal_digest(
        target_field = target,
        reference_level = ranking$reference_level[[1L]],
        comparison_level = ranking$comparison_level[[1L]],
        ranking = ranking,
        observations = observations,
        permutation_evidence = permutation_evidence,
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
        permutation_evidence = permutation_evidence,
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

#' Extract search-aware permutation evidence from a proposal
#'
#' @param proposal a `ComponentProposal`
#' @return a `PermutationEvidence`
#' @export
proposal_permutation_evidence <- function(proposal) {
    if (!is(proposal, "ComponentProposal")) {
        stop(
            paste0(
                "proposal_permutation_evidence(): proposal must be a ",
                "ComponentProposal"
            )
        )
    }
    proposal@permutation_evidence
}

#' Plot search-aware permutation evidence
#'
#' Shows the null distribution of the maximum absolute target effect across
#' the complete eligible-component search. The observed maximum is marked in
#' red and cannot alter the point ranking.
#'
#' @param x a `PermutationEvidence`
#' @param y ignored
#' @param ... ignored
#' @return a `ggplot` object
#' @export
plot.PermutationEvidence <- function(x, y, ...) {
    if (!is(x, "PermutationEvidence")) {
        stop("plot.PermutationEvidence(): x must be PermutationEvidence")
    }
    data <- data.frame(max_effect = x@null_max_effect)
    plot <- ggplot2::ggplot(
        data,
        ggplot2::aes(x = .data[["max_effect"]])
    )
    if (identical(x@status, "complete")) {
        plot <- plot +
            ggplot2::geom_histogram(
                bins = min(30L, max(5L, floor(sqrt(x@n_completed)))),
                boundary = 0,
                colour = "#111111",
                fill = "#D9D9D9",
                linewidth = 0.4
            ) +
            ggplot2::geom_vline(
                xintercept = x@observed_max_effect,
                colour = "#B2182B",
                linewidth = 0.8
            )
    } else {
        plot <- plot + ggplot2::annotate(
            "text",
            x = 0,
            y = 0,
            label = x@diagnostic,
            colour = "#B2182B"
        )
    }
    plot +
        ggplot2::labs(
            title = "Search-aware permutation evidence",
            subtitle = paste(
                "Null maximum across the complete component search;",
                x@status
            ),
            x = "Maximum absolute target effect",
            y = "Permutation count",
            caption = if (identical(x@status, "complete")) {
                sprintf(
                    "Observed maximum in red; search-aware p = %.3f",
                    x@search_aware_p_value
                )
            } else {
                "No search-aware p-value was fabricated"
            }
        ) +
        theme_landscapeR()
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

#' Extract permutation evidence from a component abstention
#'
#' @param abstention a `ComponentAbstention`
#' @return a `PermutationEvidence`
#' @export
abstention_permutation_evidence <- function(abstention) {
    if (!is(abstention, "ComponentAbstention")) {
        stop(
            paste0(
                "abstention_permutation_evidence(): abstention must be a ",
                "ComponentAbstention"
            )
        )
    }
    abstention@permutation_evidence
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

#' Plot a component-nomination abstention
#'
#' Displays retained finite effect evidence when available and the
#' machine-readable reason that prevents nomination. The plot never marks or
#' promotes an alternative component.
#'
#' @param x a `ComponentAbstention`
#' @param y ignored
#' @param ... ignored
#' @return a `ggplot` object
#' @export
plot.ComponentAbstention <- function(x, y, ...) {
    if (!is(x, "ComponentAbstention")) {
        stop("plot.ComponentAbstention(): x must be ComponentAbstention")
    }
    ranking <- abstention_ranking(x)
    finite <- ranking[
        is.finite(ranking$effect_magnitude),
        ,
        drop = FALSE
    ]
    if (nrow(finite)) {
        plot <- ggplot2::ggplot(
            finite,
            ggplot2::aes(
                x = stats::reorder(
                    .data[["component_label"]],
                    .data[["proposal_rank"]]
                ),
                y = .data[["effect_magnitude"]]
            )
        ) +
            ggplot2::geom_col(
                width = 0.62,
                colour = "#111111",
                fill = "#D9D9D9",
                linewidth = 0.45
            )
    } else {
        plot <- ggplot2::ggplot(data.frame(x = 0, y = 0)) +
            ggplot2::geom_blank(ggplot2::aes(
                x = .data[["x"]],
                y = .data[["y"]]
            )) +
            ggplot2::annotate(
                "text",
                x = 0,
                y = 0,
                label = "No estimable adjusted effect",
                colour = "#111111"
            )
    }
    plot +
        ggplot2::labs(
            title = sprintf("No component nominated for %s", x@target_field),
            subtitle = x@reason,
            x = "Recovered component",
            y = "Absolute target effect",
            caption = paste(
                "Evidence is retained; no runner-up is promoted and",
                "human confirmation is unavailable"
            )
        ) +
        theme_landscapeR() +
        ggplot2::theme(
            plot.subtitle = ggplot2::element_text(colour = "#B2182B")
        )
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
    target_type <- if (declared_specification) {
        proposal@provenance$target_type
    } else {
        "binary"
    }
    analysis_specification(
        id = specification_id,
        target_field = proposal@target_field,
        target_type = target_type,
        reference_level = if (identical(target_type, "binary")) {
            proposal@reference_level
        } else {
            NULL
        },
        comparison_level = if (identical(target_type, "binary")) {
            proposal@comparison_level
        } else {
            NULL
        },
        ordered_levels = if (identical(target_type, "ordered")) {
            proposal@provenance$ordered_levels
        } else {
            character()
        },
        continuous_direction = if (identical(target_type, "continuous")) {
            proposal@provenance$continuous_direction
        } else {
            NULL
        },
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
        orientation_anchor = if (
            declared_specification &&
            .is_scalar_nonempty_text(
                proposal@provenance$orientation_anchor
            )
        ) {
            proposal@provenance$orientation_anchor
        } else {
            NULL
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
    diagnostics <- atlas_associations(x)
    diagnostics <- unique(diagnostics[
        diagnostics$evidence_variant == "unadjusted" &
            diagnostics$diagnostic == "possible-nonmonotone-association",
        c("metadata_field", "component_label", "diagnostic"),
        drop = FALSE
    ])
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
        ggplot2::geom_text(
            data = diagnostics,
            mapping = ggplot2::aes(
                x = -Inf,
                y = Inf,
                label = "△ non-monotone"
            ),
            hjust = -0.05,
            vjust = 1.2,
            colour = "#B2182B",
            size = 3,
            inherit.aes = FALSE
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
    ranking <- proposal_ranking(x)
    facet_labels <- stats::setNames(
        sprintf(
            "%s  |  rank %d  |  |effect| = %.2f",
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
    categorical_marker <- if (nrow(categorical)) {
        data.frame(
            component_label = unique(recommended_data$component_label),
            metadata_value = if (.is_scalar_nonempty_text(
                x@comparison_level
            )) {
                x@comparison_level
            } else {
                recommended_data$metadata_value[[1L]]
            },
            score = max(recommended_data$score) + 0.12 * marker_range,
            stringsAsFactors = FALSE
        )
    } else {
        data.frame(
            component_label = character(),
            metadata_value = character(),
            score = numeric()
        )
    }
    numeric_marker <- if (nrow(numeric)) {
        data.frame(
            component_label = unique(recommended_data$component_label),
            metadata_numeric = max(
                recommended_data$metadata_numeric,
                na.rm = TRUE
            ),
            score = max(recommended_data$score) + 0.12 * marker_range,
            stringsAsFactors = FALSE
        )
    } else {
        data.frame(
            component_label = character(),
            metadata_numeric = numeric(),
            score = numeric()
        )
    }

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
        ggplot2::geom_point(
            data = categorical_marker,
            mapping = ggplot2::aes(
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
        ggplot2::geom_point(
            data = numeric_marker,
            mapping = ggplot2::aes(
                x = .data[["metadata_numeric"]],
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
                "Raw target observations;",
                "ranked by absolute biological effect only"
            ),
            x = "Target value",
            y = "Component score",
            caption = paste(
                "The red diamond marks the proposed component;",
                "human confirmation is required"
            )
        ) +
        theme_landscapeR()
}
