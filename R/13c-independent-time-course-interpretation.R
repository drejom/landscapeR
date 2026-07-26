# Independent destructive-time-course component interpretation (ADR 0020;
# issue #81)

#' Independent destructive-time-course linear association strategy
#'
#' Fits a declared binary condition, deterministically scaled observed time,
#' their interaction, and optional nuisance fields to one standardized,
#' deterministically oriented component-score vector. The interaction is the
#' proposal-eligible effect.
#'
#' @rdname AssociationStrategy-class
#' @export
setClass(
    "IndependentTimeCourseLinearAssociationStrategy",
    contains = "AssociationStrategy",
    slots = c(
        observed_time = "numeric",
        nuisance_values = "list",
        reference_level = "character",
        comparison_level = "character"
    ),
    prototype = list(
        observed_time = numeric(),
        nuisance_values = list(),
        reference_level = character(),
        comparison_level = character()
    )
)

#' @rdname association_applicable
#' @export
setMethod(
    "association_applicable",
    signature(
        strategy = "IndependentTimeCourseLinearAssociationStrategy",
        data = "StateTransitionData",
        values = "ANY"
    ),
    function(strategy, data, values) {
        identical(
            data@sampling_design@kind,
            "independent_time_course"
        ) && !is.null(.binary_level_order(values))
    }
)

#' @rdname associate_component
#' @export
setMethod(
    "associate_component",
    signature(
        strategy = "IndependentTimeCourseLinearAssociationStrategy",
        scores = "numeric",
        values = "ANY"
    ),
    function(strategy, scores, values) {
        result <- .fit_independent_time_course(
            scores = scores,
            target = values,
            observed_time = strategy@observed_time,
            nuisance_values = strategy@nuisance_values,
            reference_level = strategy@reference_level,
            comparison_level = strategy@comparison_level
        )
        association <- list(
            status = result$status,
            diagnostic = result$diagnostic,
            model_result = result
        )
        if (!identical(result$status, "estimable")) return(association)
        c(association, list(
            estimand = "standardized-condition-time-interaction",
            estimate = result$estimate,
            reference_level = strategy@reference_level,
            comparison_level = strategy@comparison_level,
            n_available = result$n_available,
            n_score_ties = result$n_score_ties,
            n_target_ties = result$n_target_ties,
            p_value = result$p_value,
            cohort_digest = result$cohort_digest,
            design_digest = result$design_digest
        ))
    }
)

#' @rdname association_strategy_id
#' @export
setMethod(
    "association_strategy_id",
    signature(strategy = "IndependentTimeCourseLinearAssociationStrategy"),
    function(strategy) "independent-time-course-linear-v1"
)

register_strategy(
    "AssociationStrategy",
    "independent_time_course_linear",
    function(params = list()) {
        allowed <- c(
            "observed_time",
            "nuisance_values",
            "reference_level",
            "comparison_level"
        )
        unknown <- setdiff(names(params), allowed)
        if (length(unknown)) {
            .stop_landscapeR_validation(sprintf(
                paste0(
                    "independent_time_course_linear strategy received ",
                    "unknown parameter '%s'"
                ),
                unknown[[1L]]
            ))
        }
        new(
            "IndependentTimeCourseLinearAssociationStrategy",
            observed_time = as.numeric(params$observed_time %||% numeric()),
            nuisance_values = params$nuisance_values %||% list(),
            reference_level = as.character(
                params$reference_level %||% character()
            ),
            comparison_level = as.character(
                params$comparison_level %||% character()
            )
        )
    }
)

.time_values_numeric <- function(values) {
    if (inherits(values, c("Date", "POSIXct", "POSIXlt"))) {
        return(as.numeric(values))
    }
    if (is.ordered(values)) return(as.numeric(values))
    as.numeric(values)
}

.time_required_complete <- function(target, observed_time, nuisance_values) {
    complete <- !is.na(target) &
        !is.na(observed_time) &
        is.finite(observed_time)
    for (values in nuisance_values) {
        complete <- complete & !is.na(values)
        if (is.numeric(values)) complete <- complete & is.finite(values)
    }
    complete
}

.time_nuisance_matrix <- function(nuisance_values) {
    if (!length(nuisance_values)) {
        return(matrix(numeric(), nrow = 0L, ncol = 0L))
    }
    frame <- as.data.frame(lapply(nuisance_values, function(values) {
        if (is.ordered(values)) return(as.numeric(values))
        if (is.numeric(values)) return(as.numeric(values))
        if (is.factor(values)) return(values)
        factor(values)
    }), stringsAsFactors = FALSE)
    factor_fields <- names(frame)[vapply(frame, is.factor, logical(1L))]
    contrasts <- stats::setNames(lapply(factor_fields, function(field) {
        stats::contr.treatment(nlevels(frame[[field]]), base = 1L)
    }), factor_fields)
    matrix <- stats::model.matrix(
        ~ .,
        data = frame,
        contrasts.arg = contrasts
    )
    matrix[, colnames(matrix) != "(Intercept)", drop = FALSE]
}

.time_course_design <- function(
    target,
    scaled_time,
    nuisance_values,
    reference_level,
    comparison_level,
    include_interaction = TRUE
) {
    target <- factor(
        as.character(target),
        levels = c(reference_level, comparison_level)
    )
    base_formula <- if (include_interaction) {
        ~ target * scaled_time
    } else {
        ~ target + scaled_time
    }
    base <- stats::model.matrix(
        base_formula,
        data = data.frame(target = target, scaled_time = scaled_time),
        contrasts.arg = list(
            target = stats::contr.treatment(2L, base = 1L)
        )
    )
    nuisance <- .time_nuisance_matrix(nuisance_values)
    if (!length(nuisance_values)) return(base)
    if (nrow(nuisance) != nrow(base)) {
        .stop_landscapeR_validation(
            "time-course nuisance design is not aligned to the model cohort"
        )
    }
    cbind(base, nuisance)
}

.time_course_structural_diagnostic <- function(
    target,
    observed_time,
    nuisance_values,
    reference_level,
    comparison_level
) {
    if (any(!.time_required_complete(
        target,
        observed_time,
        nuisance_values
    ))) {
        return("unexpected-missing-required-values")
    }
    target <- factor(
        as.character(target),
        levels = c(reference_level, comparison_level)
    )
    if (anyNA(target) || any(table(target) == 0L)) {
        return("missing-declared-condition-level")
    }
    times_by_condition <- split(observed_time, target, drop = FALSE)
    overlap <- Reduce(intersect, lapply(times_by_condition, unique))
    if (length(overlap) < 2L) {
        return("insufficient-overlapping-times")
    }
    overlap_rows <- observed_time %in% overlap
    overlap_counts <- table(
        droplevels(target[overlap_rows]),
        observed_time[overlap_rows]
    )
    if (any(overlap_counts < 2L)) {
        return("insufficient-independent-cell-replication")
    }
    ""
}

.time_course_orientation <- function(
    scores,
    target,
    reference_level,
    comparison_level,
    multiplier = NULL
) {
    score_sd <- stats::sd(scores)
    if (!is.finite(score_sd) || score_sd == 0) {
        return(list(
            status = "zero-component-variance",
            multiplier = 1,
            standardized_scores = rep(NA_real_, length(scores))
        ))
    }
    standardized <- as.numeric((scores - mean(scores)) / score_sd)
    target <- as.character(target)
    difference <- mean(
        standardized[target == comparison_level]
    ) - mean(standardized[target == reference_level])
    if (is.null(multiplier)) {
        multiplier <- if (is.finite(difference) && difference < 0) -1 else 1
    }
    list(
        status = "",
        multiplier = multiplier,
        standardized_scores = multiplier * standardized
    )
}

.fit_independent_time_course <- function(
    scores,
    target,
    observed_time,
    nuisance_values,
    reference_level,
    comparison_level,
    orientation_multiplier = NULL
) {
    n <- length(scores)
    if (length(target) != n ||
        length(observed_time) != n ||
        any(vapply(nuisance_values, length, integer(1L)) != n)) {
        return(list(
            status = "non-identifiable-design",
            diagnostic = "misaligned-model-inputs",
            estimate = NA_real_
        ))
    }
    structural <- .time_course_structural_diagnostic(
        target,
        observed_time,
        nuisance_values,
        reference_level,
        comparison_level
    )
    orientation <- .time_course_orientation(
        scores,
        target,
        reference_level,
        comparison_level,
        multiplier = orientation_multiplier
    )
    if (nzchar(orientation$status)) {
        structural <- orientation$status
    }
    time_range <- range(observed_time)
    scaled_time <- (observed_time - time_range[[1L]]) /
        diff(time_range)
    complete <- .time_required_complete(
        target,
        observed_time,
        nuisance_values
    ) & is.finite(scores)
    cohort_digest <- .association_cohort_digest(names(target), complete)
    if (nzchar(structural)) {
        return(list(
            status = "non-identifiable-design",
            diagnostic = structural,
            estimate = NA_real_,
            p_value = NA_real_,
            n_available = sum(complete),
            n_score_ties = NA_integer_,
            n_target_ties = NA_integer_,
            cohort_digest = cohort_digest,
            design_digest = NA_character_,
            design_rank = NA_integer_,
            residual_df = NA_integer_,
            orientation_multiplier = orientation$multiplier,
            standardized_scores = orientation$standardized_scores,
            coefficients = numeric(),
            scaled_time = scaled_time
        ))
    }
    design <- .time_course_design(
        target,
        scaled_time,
        nuisance_values,
        reference_level,
        comparison_level,
        include_interaction = TRUE
    )
    design_rank <- qr(design)$rank
    design_digest <- digest::digest(
        list(
            matrix = unname(design),
            columns = colnames(design),
            time_range = time_range,
            reference_level = reference_level,
            comparison_level = comparison_level,
            nuisance_fields = names(nuisance_values)
        ),
        algo = "sha256",
        serialize = TRUE
    )
    diagnostic <- if (design_rank < ncol(design)) {
        "rank-deficient-fixed-effect-design"
    } else if (n <= ncol(design)) {
        "non-positive-residual-degrees-of-freedom"
    } else {
        ""
    }
    if (nzchar(diagnostic)) {
        return(list(
            status = "non-identifiable-design",
            diagnostic = diagnostic,
            estimate = NA_real_,
            p_value = NA_real_,
            n_available = n,
            n_score_ties = NA_integer_,
            n_target_ties = NA_integer_,
            cohort_digest = cohort_digest,
            design_digest = design_digest,
            design_rank = as.integer(design_rank),
            residual_df = as.integer(n - design_rank),
            orientation_multiplier = orientation$multiplier,
            standardized_scores = orientation$standardized_scores,
            coefficients = numeric(),
            scaled_time = scaled_time
        ))
    }
    response <- orientation$standardized_scores
    fit <- tryCatch(
        stats::lm(
            response ~ design - 1,
            na.action = stats::na.fail,
            singular.ok = FALSE
        ),
        error = function(error) error
    )
    residual_df <- n - ncol(design)
    covariance <- if (inherits(fit, "error")) {
        fit
    } else {
        tryCatch(stats::vcov(fit), error = function(error) error)
    }
    if (inherits(covariance, "error") ||
        any(!is.finite(covariance))) {
        return(list(
            status = "non-identifiable-design",
            diagnostic = "numerical-model-failure",
            estimate = NA_real_,
            p_value = NA_real_,
            n_available = n,
            n_score_ties = NA_integer_,
            n_target_ties = NA_integer_,
            cohort_digest = cohort_digest,
            design_digest = design_digest,
            design_rank = as.integer(design_rank),
            residual_df = as.integer(residual_df),
            orientation_multiplier = orientation$multiplier,
            standardized_scores = response,
            coefficients = numeric(),
            scaled_time = scaled_time
        ))
    }
    names(fit$coefficients) <- colnames(design)
    dimnames(covariance) <- list(colnames(design), colnames(design))
    interaction_index <- grep(
        "^target.*:scaled_time$",
        colnames(design)
    )
    if (length(interaction_index) != 1L) {
        return(list(
            status = "non-identifiable-design",
            diagnostic = "interaction-column-not-identifiable",
            estimate = NA_real_,
            p_value = NA_real_,
            n_available = n,
            n_score_ties = NA_integer_,
            n_target_ties = NA_integer_,
            cohort_digest = cohort_digest,
            design_digest = design_digest,
            design_rank = as.integer(design_rank),
            residual_df = as.integer(residual_df),
            orientation_multiplier = orientation$multiplier,
            standardized_scores = response,
            coefficients = fit$coefficients,
            scaled_time = scaled_time
        ))
    }
    estimate <- unname(fit$coefficients[[interaction_index]])
    standard_error <- sqrt(covariance[
        interaction_index,
        interaction_index
    ])
    p_value <- if (is.finite(standard_error) && standard_error > 0) {
        2 * stats::pt(
            -abs(estimate / standard_error),
            df = residual_df
        )
    } else if (estimate == 0) {
        1
    } else {
        0
    }
    score_ties <- duplicated(response) |
        duplicated(response, fromLast = TRUE)
    target_ties <- duplicated(target) |
        duplicated(target, fromLast = TRUE)
    list(
        status = "estimable",
        diagnostic = "",
        estimate = estimate,
        p_value = unname(p_value),
        n_available = n,
        n_score_ties = sum(score_ties),
        n_target_ties = sum(target_ties),
        cohort_digest = cohort_digest,
        design_digest = design_digest,
        design_rank = as.integer(design_rank),
        residual_df = as.integer(residual_df),
        orientation_multiplier = orientation$multiplier,
        standardized_scores = response,
        coefficients = stats::setNames(
            as.numeric(fit$coefficients),
            colnames(design)
        ),
        scaled_time = scaled_time,
        residual_sd = summary(fit)$sigma
    )
}

.time_course_resampling_plan <- function(
    target,
    observed_time,
    n_resamples,
    seed
) {
    plan <- .association_resampling_plan(
        values = target,
        nuisance_values = list(
            observed_time = factor(
                observed_time,
                levels = sort(unique(observed_time))
            )
        ),
        n_resamples = n_resamples,
        seed = seed
    )
    cell <- interaction(
        target,
        observed_time,
        drop = TRUE,
        lex.order = TRUE
    )
    counts <- as.integer(table(cell))
    names(counts) <- names(table(cell))
    list(
        indices = plan$indices,
        digest = plan$digest,
        method = "condition-time-cell-bootstrap",
        cell_counts = counts,
        n_resamples = n_resamples,
        seed = seed
    )
}

.time_course_uncertainty <- function(
    scores,
    target,
    observed_time,
    nuisance_values,
    reference_level,
    comparison_level,
    plan,
    orientation_multiplier
) {
    estimates <- vapply(plan$indices, function(index) {
        result <- .fit_independent_time_course(
            scores[index],
            target[index],
            observed_time[index],
            lapply(nuisance_values, `[`, index),
            reference_level,
            comparison_level,
            orientation_multiplier = orientation_multiplier
        )
        if (identical(result$status, "estimable")) {
            result$estimate
        } else {
            NA_real_
        }
    }, numeric(1L))
    summary <- .resampling_summary(
        estimates,
        list(digest = plan$digest)
    )
    summary$resampling_method <- if (length(plan$indices)) {
        "condition-time-cell-bootstrap"
    } else {
        "not-requested"
    }
    summary$bootstrap_estimates <- estimates
    summary
}

.time_course_association_row <- function(
    component,
    component_label,
    variant,
    result,
    uncertainty,
    reference_level,
    comparison_level,
    nuisance_fields = character(),
    proposal_eligible = TRUE
) {
    estimable <- identical(result$status, "estimable")
    data.frame(
        metadata_field = "condition",
        component = as.integer(component),
        component_label = component_label,
        estimand = "standardized-condition-time-interaction",
        estimate = if (estimable) result$estimate else NA_real_,
        effect_magnitude = if (estimable) abs(result$estimate) else NA_real_,
        reference_level = reference_level,
        comparison_level = comparison_level,
        n_available = as.integer(result$n_available %||% 0L),
        n_missing = as.integer(
            length(result$standardized_scores %||% numeric()) -
                (result$n_available %||% 0L)
        ),
        n_score_ties = as.integer(result$n_score_ties %||% NA_integer_),
        n_target_ties = as.integer(result$n_target_ties %||% NA_integer_),
        evidence_variant = variant,
        proposal_eligible = proposal_eligible,
        nuisance_fields = paste(nuisance_fields, collapse = " + "),
        cohort_digest = result$cohort_digest %||% NA_character_,
        design_digest = result$design_digest %||% NA_character_,
        diagnostic = if (estimable) {
            ""
        } else {
            paste0(
                "non-identifiable-design:",
                result$diagnostic %||% "unknown"
            )
        },
        p_value = if (estimable) result$p_value else NA_real_,
        q_value = NA_real_,
        effect_conf_low = uncertainty$effect_conf_low,
        effect_conf_high = uncertainty$effect_conf_high,
        n_resamples = uncertainty$n_resamples,
        resample_failures = uncertainty$resample_failures,
        resampling_method = uncertainty$resampling_method,
        resampling_plan_digest = uncertainty$resampling_plan_digest,
        evidence_status = "estimable-exploratory-only",
        stringsAsFactors = FALSE
    )
}

.time_course_pooled_row <- function(
    component,
    component_label,
    scores,
    target,
    reference_level,
    comparison_level
) {
    effect <- .signed_rank_biserial(
        scores,
        target,
        reference_level,
        comparison_level
    )
    data.frame(
        metadata_field = "condition",
        component = as.integer(component),
        component_label = component_label,
        estimand = "pooled-signed-rank-biserial",
        estimate = effect$estimate,
        effect_magnitude = abs(effect$estimate),
        reference_level = reference_level,
        comparison_level = comparison_level,
        n_available = as.integer(effect$n_available),
        n_missing = as.integer(length(scores) - effect$n_available),
        n_score_ties = as.integer(effect$n_score_ties),
        n_target_ties = NA_integer_,
        evidence_variant = "pooled-descriptive",
        proposal_eligible = FALSE,
        nuisance_fields = "",
        cohort_digest = .association_cohort_digest(
            names(target),
            is.finite(scores) & !is.na(target)
        ),
        design_digest = NA_character_,
        diagnostic = "descriptive-only-not-trajectory-evidence",
        p_value = effect$p_value,
        q_value = NA_real_,
        effect_conf_low = NA_real_,
        effect_conf_high = NA_real_,
        n_resamples = 0L,
        resample_failures = 0L,
        resampling_method = "not-requested",
        resampling_plan_digest = NA_character_,
        evidence_status = "estimable-exploratory-only",
        stringsAsFactors = FALSE
    )
}

.time_course_display_lines <- function(
    result,
    component,
    component_label,
    reference_level,
    comparison_level
) {
    coefficients <- result$coefficients
    if (!length(coefficients)) {
        return(data.frame(
            component = integer(),
            component_label = character(),
            condition = character(),
            scaled_time = numeric(),
            fitted_score = numeric(),
            stringsAsFactors = FALSE
        ))
    }
    grid <- expand.grid(
        condition = c(reference_level, comparison_level),
        scaled_time = c(0, 1),
        stringsAsFactors = FALSE
    )
    target_name <- grep("^target", names(coefficients), value = TRUE)
    target_name <- target_name[!grepl(":", target_name)]
    interaction_name <- grep(
        "^target.*:scaled_time$",
        names(coefficients),
        value = TRUE
    )
    target_indicator <- as.numeric(grid$condition == comparison_level)
    grid$fitted_score <- coefficients[["(Intercept)"]] +
        coefficients[["scaled_time"]] * grid$scaled_time +
        coefficients[[target_name[[1L]]]] * target_indicator +
        coefficients[[interaction_name[[1L]]]] *
            target_indicator * grid$scaled_time
    grid$component <- as.integer(component)
    grid$component_label <- component_label
    grid
}

.time_course_dataset_id <- function(std, input_digest, dataset_id) {
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
    dataset_id
}

.associate_independent_time_course <- function(
    std,
    stage1,
    specification,
    non_analytical_fields,
    dataset_id,
    n_resamples,
    seed,
    exchangeability
) {
    if (is.null(specification) ||
        !is(specification, "AnalysisSpecification") ||
        !identical(specification@lifecycle, "draft")) {
        .stop_landscapeR_validation(
            paste0(
                "associate_metadata(): independent time courses require a ",
                "draft AnalysisSpecification"
            )
        )
    }
    if (!identical(specification@target_type, "binary")) {
        return(.new_association_abstention(
            std,
            stage1,
            specification,
            "independent time-course target must be declared binary"
        ))
    }
    specification_error <- .validate_analysis_specification_data(
        specification,
        std
    )
    if (!identical(specification_error, TRUE)) {
        if (grepl("^observed target values must equal", specification_error)) {
            return(.new_association_abstention(
                std,
                stage1,
                specification,
                specification_error
            ))
        }
        .stop_landscapeR_validation(
            paste0("associate_metadata(): ", specification_error)
        )
    }
    if (specification@target_field == std@sampling_design@time_col) {
        .stop_landscapeR_validation(
            paste0(
                "associate_metadata(): observed structural time cannot also ",
                "be the biological target"
            )
        )
    }
    coordinates <- dr_coords_k(stage1)
    if (length(coordinates) != 1L) {
        .stop_landscapeR_validation(
            "associate_metadata(): issue #81 supports exactly one omic layer"
        )
    }
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
    target <- .aligned_component_metadata(
        std,
        1L,
        specification@target_field,
        "associate_metadata",
        "target field"
    )
    observed_time_raw <- .aligned_component_metadata(
        std,
        1L,
        std@sampling_design@time_col,
        "associate_metadata",
        "observed-time field"
    )
    observed_time <- .time_values_numeric(observed_time_raw)
    names(observed_time) <- names(observed_time_raw)
    nuisance_values <- stats::setNames(
        lapply(specification@nuisance_fields, function(field) {
            .aligned_component_metadata(
                std,
                1L,
                field,
                "associate_metadata",
                "nuisance field"
            )
        }),
        specification@nuisance_fields
    )
    all_sample_ids <- names(target)
    analysis_complete <- .time_required_complete(
        target,
        observed_time,
        nuisance_values
    )
    analysis_cohort <- all_sample_ids[analysis_complete]
    excluded_cohort <- all_sample_ids[!analysis_complete]
    if (!length(analysis_cohort)) {
        return(.new_association_abstention(
            std,
            stage1,
            specification,
            paste(
                "non-identifiable-design:",
                "no complete cases for target, observed time, and nuisance"
            )
        ))
    }
    target <- target[analysis_complete]
    observed_time <- observed_time[analysis_complete]
    nuisance_values <- lapply(nuisance_values, `[`, analysis_complete)
    coordinate_matrix <- coordinate_matrix[
        analysis_complete,
        ,
        drop = FALSE
    ]
    reference_level <- specification@reference_level
    comparison_level <- specification@comparison_level
    plan <- .time_course_resampling_plan(
        target,
        observed_time,
        n_resamples,
        seed
    )
    component_labels <- colnames(coordinate_matrix)
    if (is.null(component_labels)) {
        component_labels <- paste0("PC", seq_len(ncol(coordinate_matrix)))
    }
    rows <- list()
    model_records <- list()
    observations <- list()
    display_lines <- list()
    strategy_constructor <- get_strategy(
        "AssociationStrategy",
        "independent_time_course_linear"
    )
    for (component in seq_len(ncol(coordinate_matrix))) {
        scores <- coordinate_matrix[, component]
        unadjusted_strategy <- strategy_constructor(list(
            observed_time = observed_time,
            nuisance_values = list(),
            reference_level = reference_level,
            comparison_level = comparison_level
        ))
        unadjusted_effect <- associate_component(
            unadjusted_strategy,
            scores,
            target
        )
        unadjusted <- unadjusted_effect$model_result
        unadjusted_uncertainty <- .time_course_uncertainty(
            scores,
            target,
            observed_time,
            list(),
            reference_level,
            comparison_level,
            plan,
            orientation_multiplier = unadjusted$orientation_multiplier
        )
        rows[[length(rows) + 1L]] <- .time_course_pooled_row(
            component,
            component_labels[[component]],
            unadjusted$standardized_scores,
            target,
            reference_level,
            comparison_level
        )
        rows[[length(rows) + 1L]] <- .time_course_association_row(
            component,
            component_labels[[component]],
            "time-course-unadjusted",
            unadjusted,
            unadjusted_uncertainty,
            reference_level,
            comparison_level
        )
        adjusted <- NULL
        if (length(nuisance_values)) {
            adjusted_strategy <- strategy_constructor(list(
                observed_time = observed_time,
                nuisance_values = nuisance_values,
                reference_level = reference_level,
                comparison_level = comparison_level
            ))
            adjusted_effect <- associate_component(
                adjusted_strategy,
                scores,
                target
            )
            adjusted <- adjusted_effect$model_result
            adjusted_uncertainty <- .time_course_uncertainty(
                scores,
                target,
                observed_time,
                nuisance_values,
                reference_level,
                comparison_level,
                plan,
                orientation_multiplier = adjusted$orientation_multiplier
            )
            rows[[length(rows) + 1L]] <- .time_course_association_row(
                component,
                component_labels[[component]],
                "time-course-adjusted",
                adjusted,
                adjusted_uncertainty,
                reference_level,
                comparison_level,
                nuisance_fields = names(nuisance_values)
            )
        }
        standardized <- unadjusted$standardized_scores
        observations[[component]] <- data.frame(
            metadata_field = specification@target_field,
            component = as.integer(component),
            component_label = component_labels[[component]],
            sample_index = seq_along(scores),
            primary_sample = names(target),
            metadata_type = "categorical",
            metadata_value = as.character(target),
            metadata_numeric = NA_real_,
            score = standardized,
            atom_count = as.integer(ave(
                rep.int(1L, length(scores)),
                paste(
                    as.character(target),
                    observed_time,
                    sprintf("%.17g", standardized),
                    sep = "\r"
                ),
                FUN = length
            )),
            available = is.finite(standardized) &
                !is.na(target) &
                is.finite(observed_time),
            stringsAsFactors = FALSE
        )
        primary_model <- if (length(nuisance_values)) adjusted else unadjusted
        display_lines[[component]] <- .time_course_display_lines(
            primary_model,
            component,
            component_labels[[component]],
            reference_level,
            comparison_level
        )
        model_records[[component]] <- list(
            component = as.integer(component),
            component_label = component_labels[[component]],
            orientation_multiplier = unadjusted$orientation_multiplier,
            unadjusted = unadjusted,
            adjusted = adjusted,
            unadjusted_uncertainty = unadjusted_uncertainty,
            adjusted_uncertainty = if (length(nuisance_values)) {
                adjusted_uncertainty
            } else {
                NULL
            }
        )
    }
    associations <- do.call(rbind, rows)
    for (variant in unique(associations$evidence_variant)) {
        index <- associations$evidence_variant == variant
        associations$q_value[index] <- stats::p.adjust(
            associations$p_value[index],
            method = "holm"
        )
    }
    observations <- do.call(rbind, observations)
    rownames(associations) <- NULL
    rownames(observations) <- NULL
    input_digest <- .atlas_input_digest(std)
    state_space_digest <- .atlas_state_space_digest(stage1)
    dataset_id <- .time_course_dataset_id(std, input_digest, dataset_id)
    time_min <- min(observed_time)
    time_max <- max(observed_time)
    scaled_time <- (observed_time - time_min) / (time_max - time_min)
    time_cells <- expand.grid(
        condition = c(reference_level, comparison_level),
        observed_time = sort(unique(observed_time)),
        stringsAsFactors = FALSE
    )
    observed_cells <- as.data.frame(table(
        condition = factor(
            target,
            levels = c(reference_level, comparison_level)
        ),
        observed_time = factor(
            observed_time,
            levels = sort(unique(observed_time))
        )
    ), stringsAsFactors = FALSE)
    observed_cells$observed_time <- as.numeric(
        as.character(observed_cells$observed_time)
    )
    time_cells <- merge(
        time_cells,
        observed_cells,
        by = c("condition", "observed_time"),
        all.x = TRUE,
        sort = TRUE
    )
    names(time_cells)[names(time_cells) == "Freq"] <- "count"
    time_cells$scaled_time <- (time_cells$observed_time - time_min) /
        (time_max - time_min)
    metadata_fields <- names(colData(std))
    exclusion_rows <- lapply(setdiff(
        metadata_fields,
        specification@target_field
    ), function(field) {
        reason <- if (field == std@sampling_design@time_col) {
            "sampling-time-field"
        } else if (field %in% specification@nuisance_fields) {
            "declared-nuisance-field"
        } else if (field %in% non_analytical_fields) {
            "declared-non-analytical"
        } else if (grepl(
            "(^id$|_id$|^identifier$)",
            field,
            ignore.case = TRUE
        )) {
            "identifier-field"
        } else {
            "unsupported-time-course-metadata"
        }
        data.frame(
            metadata_field = field,
            reason = reason,
            stringsAsFactors = FALSE
        )
    })
    exclusions <- if (length(exclusion_rows)) {
        do.call(rbind, exclusion_rows)
    } else {
        data.frame(
            metadata_field = character(),
            reason = character(),
            stringsAsFactors = FALSE
        )
    }
    primary_variant <- if (length(nuisance_values)) {
        "time-course-adjusted"
    } else {
        "time-course-unadjusted"
    }
    effect_summary <- associations[
        associations$evidence_variant == primary_variant,
        c(
            "component",
            "component_label",
            "estimate",
            "effect_conf_low",
            "effect_conf_high",
            "diagnostic"
        ),
        drop = FALSE
    ]
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
        } else if (length(nuisance_values)) {
            "analytic-adjusted"
        } else {
            "analytic-unadjusted"
        },
        provenance = list(
            association_strategy = association_strategy_id(
                unadjusted_strategy
            ),
            package_version = as.character(
                utils::packageVersion("landscapeR")
            ),
            sampling_design = std@sampling_design@kind,
            layer = names(as.list(experiments(std)))[[1L]],
            input_digest = input_digest,
            state_space_digest = state_space_digest,
            dataset_id = dataset_id,
            exchangeability = exchangeability,
            analysis_specification_id = specification@id,
            analysis_specification_digest = canonical_digest(specification),
            target_field = specification@target_field,
            target_type = specification@target_type,
            reference_level = reference_level,
            comparison_level = comparison_level,
            ordered_levels = specification@ordered_levels,
            continuous_direction = specification@continuous_direction,
            nuisance_fields = specification@nuisance_fields,
            nuisance_values = nuisance_values,
            orientation_anchor = specification@orientation_anchor,
            claim_intent = specification@claim_intent,
            time_field = std@sampling_design@time_col,
            time_unit = if (length(std@sampling_design@time_unit)) {
                std@sampling_design@time_unit
            } else {
                NA_character_
            },
            observed_time = observed_time,
            scaled_time = scaled_time,
            time_range = c(time_min, time_max),
            time_transform =
                "(time - min(time)) / (max(time) - min(time))",
            model_engine = "stats::lm",
            model_engine_version = as.character(
                utils::packageVersion("stats")
            ),
            model_na_action = "stats::na.fail",
            model_singular_ok = FALSE,
            model_contrasts = list(
                target = "contr.treatment(2, base = 1)",
                nuisance_factors = "contr.treatment(nlevels, base = 1)"
            ),
            engine_formula = "response ~ design - 1",
            scientific_model_formula_unadjusted =
                "standardized_score ~ condition * scaled_time",
            scientific_model_formula_adjusted = paste(
                "standardized_score ~ condition * scaled_time",
                if (length(nuisance_values)) {
                    paste("+", paste(names(nuisance_values), collapse = " + "))
                } else {
                    ""
                }
            ),
            model_formula_digest = digest::digest(
                list(
                    engine = "response ~ design - 1",
                    scientific_unadjusted =
                        "standardized_score ~ condition * scaled_time",
                    scientific_adjusted = paste(
                        "standardized_score ~ condition * scaled_time",
                        if (length(nuisance_values)) {
                            paste(
                                "+",
                                paste(names(nuisance_values), collapse = " + ")
                            )
                        } else {
                            ""
                        }
                    ),
                    contrasts = list(
                        target = "contr.treatment(2, base = 1)",
                        nuisance_factors =
                            "contr.treatment(nlevels, base = 1)"
                    ),
                    na_action = "stats::na.fail",
                    singular_ok = FALSE
                ),
                algo = "sha256",
                serialize = TRUE
            ),
            primary_evidence_variant = primary_variant,
            display_trajectory_variant = primary_variant,
            analysis_cohort = analysis_cohort,
            analysis_cohort_exclusions = excluded_cohort,
            time_course_models = model_records,
            time_course_observations = data.frame(
                primary_sample = names(target),
                condition = as.character(target),
                observed_time = observed_time,
                scaled_time = scaled_time,
                stringsAsFactors = FALSE
            ),
            time_course_display_lines = do.call(rbind, display_lines),
            time_course_effect_summary = effect_summary,
            time_course_cells = time_cells,
            resampling_plan = plan
        ),
        evidence_status = "estimable-exploratory-only"
    )
    validObject(atlas)
    atlas
}

.time_course_permutation_indices <- function(
    observed_time,
    n_permutations,
    seed
) {
    strata <- split(seq_along(observed_time), observed_time, drop = TRUE)
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
    replicate(n_permutations, {
        index <- seq_along(observed_time)
        for (stratum in strata) {
            index[stratum] <- sample(stratum, length(stratum))
        }
        index
    }, simplify = FALSE)
}

.time_course_permutation_support <- function(
    target,
    observed_time,
    n_permutations
) {
    tables <- lapply(
        split(target, observed_time, drop = TRUE),
        table
    )
    log_arrangements <- sum(vapply(tables, function(counts) {
        lgamma(sum(counts) + 1) - sum(lgamma(counts + 1))
    }, numeric(1L)))
    log(n_permutations + 1) <= log_arrangements
}

.compute_independent_time_permutation_evidence <- function(
    atlas,
    target,
    ranking,
    n_permutations,
    seed
) {
    if (n_permutations == 0L) return(.new_permutation_evidence())
    if (!identical(atlas@provenance$exchangeability, "independent")) {
        return(.new_permutation_evidence(
            status = "not-identifiable",
            n_requested = n_permutations,
            seed = seed,
            diagnostic = "exchangeability-not-identifiable"
        ))
    }
    observations <- atlas@observations[
        atlas@observations$metadata_field == target,
        ,
        drop = FALSE
    ]
    components <- sort(unique(observations$component))
    first <- observations[
        observations$component == components[[1L]],
        ,
        drop = FALSE
    ]
    first <- first[order(first$sample_index), , drop = FALSE]
    target_values <- factor(
        first$metadata_value,
        levels = c(
            atlas@provenance$reference_level,
            atlas@provenance$comparison_level
        )
    )
    observed_time <- atlas@provenance$observed_time
    if (!.time_course_permutation_support(
        target_values,
        observed_time,
        n_permutations
    )) {
        return(.new_permutation_evidence(
            status = "insufficient-support",
            n_requested = n_permutations,
            seed = seed,
            cohort_digest = .association_cohort_digest(
                first$primary_sample,
                first$available
            ),
            diagnostic = "insufficient-within-time-rearrangements"
        ))
    }
    permutation_plan <- .time_course_permutation_indices(
        observed_time,
        n_permutations,
        seed
    )
    score_matrix <- vapply(components, function(component) {
        rows <- observations[
            observations$component == component,
            ,
            drop = FALSE
        ]
        rows <- rows[order(rows$sample_index), , drop = FALSE]
        rows$score
    }, numeric(nrow(first)))
    nuisance_values <- atlas@provenance$nuisance_values
    if (!length(nuisance_values)) {
        null_max <- vapply(permutation_plan, function(index) {
            permuted_target <- target_values[index]
            effects <- apply(score_matrix, 2L, function(scores) {
                result <- .fit_independent_time_course(
                    scores,
                    permuted_target,
                    observed_time,
                    list(),
                    atlas@provenance$reference_level,
                    atlas@provenance$comparison_level
                )
                if (identical(result$status, "estimable")) {
                    result$estimate
                } else {
                    NA_real_
                }
            })
            max(abs(effects), na.rm = TRUE)
        }, numeric(1L))
        method <- "within-time-label-permutation"
        design_digest <- NA_character_
    } else {
        scaled_time <- atlas@provenance$scaled_time
        reduced_design <- .time_course_design(
            target_values,
            scaled_time,
            nuisance_values,
            atlas@provenance$reference_level,
            atlas@provenance$comparison_level,
            include_interaction = FALSE
        )
        if (qr(reduced_design)$rank < ncol(reduced_design)) {
            return(.new_permutation_evidence(
                status = "not-identifiable",
                n_requested = n_permutations,
                seed = seed,
                diagnostic = "non-identifiable-reduced-permutation-design"
            ))
        }
        reduced_models <- lapply(seq_len(ncol(score_matrix)), function(j) {
            fit <- stats::lm.fit(reduced_design, score_matrix[, j])
            list(fitted = fit$fitted.values, residuals = fit$residuals)
        })
        null_max <- vapply(permutation_plan, function(index) {
            effects <- vapply(reduced_models, function(model) {
                reconstructed <- model$fitted + model$residuals[index]
                result <- .fit_independent_time_course(
                    reconstructed,
                    target_values,
                    observed_time,
                    nuisance_values,
                    atlas@provenance$reference_level,
                    atlas@provenance$comparison_level
                )
                if (identical(result$status, "estimable")) {
                    result$estimate
                } else {
                    NA_real_
                }
            }, numeric(1L))
            max(abs(effects), na.rm = TRUE)
        }, numeric(1L))
        method <- "within-time-reduced-model-residual-permutation"
        design_digest <- ranking$design_digest[[1L]]
    }
    if (any(!is.finite(null_max))) {
        return(.new_permutation_evidence(
            status = "not-identifiable",
            n_requested = n_permutations,
            seed = seed,
            diagnostic = "failed-time-course-null-replicate"
        ))
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
        cohort_digest = ranking$cohort_digest[[1L]],
        design_digest = design_digest
    )
}

.time_course_plot_data <- function(provenance, observations) {
    merge(
        observations,
        provenance$time_course_observations,
        by = "primary_sample",
        all.x = TRUE,
        sort = FALSE
    )
}

.plot_independent_time_course <- function(
    observations,
    provenance,
    ranking = NULL,
    title = "Independent destructive-time-course evidence",
    subtitle = "Observed time is fixed; trajectories are exploratory linear fits"
) {
    data <- .time_course_plot_data(provenance, observations)
    data <- data[data$available, , drop = FALSE]
    lines <- provenance$time_course_display_lines
    cells <- provenance$time_course_cells
    score_range <- range(data$score)
    score_span <- diff(score_range)
    if (!is.finite(score_span) || score_span == 0) score_span <- 1
    label_offset <- stats::setNames(
        c(-0.08, -0.18) * score_span,
        c(provenance$reference_level, provenance$comparison_level)
    )
    cells$label_y <- score_range[[1L]] +
        label_offset[cells$condition]
    cells$label <- paste0("n=", cells$count)
    trajectory_note <- if (identical(
        provenance$display_trajectory_variant,
        "time-course-adjusted"
    )) {
        "adjusted lines use reference/zero nuisance values;"
    } else {
        "unadjusted lines;"
    }
    effect_summary <- provenance$time_course_effect_summary
    interval_text <- ifelse(
        is.finite(effect_summary$effect_conf_low) &
            is.finite(effect_summary$effect_conf_high),
        sprintf(
            "%.2f [%.2f, %.2f]",
            effect_summary$estimate,
            effect_summary$effect_conf_low,
            effect_summary$effect_conf_high
        ),
        sprintf("%.2f [not estimated]", effect_summary$estimate)
    )
    names(interval_text) <- effect_summary$component_label
    if (!is.null(ranking) && nrow(ranking)) {
        facet_labels <- stats::setNames(
            sprintf(
                "%s\nrank %d\ninteraction %s",
                ranking$component_label,
                ranking$proposal_rank,
                interval_text[ranking$component_label]
            ),
            ranking$component_label
        )
    } else {
        facet_labels <- stats::setNames(
            sprintf(
                "%s\ninteraction %s",
                effect_summary$component_label,
                interval_text
            ),
            effect_summary$component_label
        )
    }
    ggplot2::ggplot(
        data,
        ggplot2::aes(
            x = .data[["scaled_time"]],
            y = .data[["score"]]
        )
    ) +
        ggplot2::geom_line(
            data = lines,
            mapping = ggplot2::aes(
                x = .data[["scaled_time"]],
                y = .data[["fitted_score"]],
                colour = .data[["condition"]],
                group = .data[["condition"]]
            ),
            linewidth = 0.75,
            inherit.aes = FALSE
        ) +
        ggplot2::geom_point(
            mapping = ggplot2::aes(
                shape = .data[["condition"]],
                fill = .data[["condition"]]
            ),
            size = 2.2,
            stroke = 0.55,
            colour = "#111111"
        ) +
        ggplot2::geom_text(
            data = cells,
            mapping = ggplot2::aes(
                x = .data[["scaled_time"]],
                y = .data[["label_y"]],
                label = .data[["label"]],
                colour = .data[["condition"]]
            ),
            size = 2.7,
            inherit.aes = FALSE
        ) +
        ggplot2::geom_point(
            data = cells[cells$count == 0L, , drop = FALSE],
            mapping = ggplot2::aes(
                x = .data[["scaled_time"]],
                y = .data[["label_y"]]
            ),
            shape = 4,
            size = 3,
            stroke = 0.8,
            colour = "#B2182B",
            inherit.aes = FALSE
        ) +
        ggplot2::scale_colour_manual(
            values = stats::setNames(
                c("#111111", "#B2182B"),
                c(
                    provenance$reference_level,
                    provenance$comparison_level
                )
            )
        ) +
        ggplot2::scale_fill_manual(
            values = stats::setNames(
                c("#FFFFFF", "#B2182B"),
                c(
                    provenance$reference_level,
                    provenance$comparison_level
                )
            )
        ) +
        ggplot2::scale_shape_manual(
            values = stats::setNames(
                c(21, 24),
                c(
                    provenance$reference_level,
                    provenance$comparison_level
                )
            )
        ) +
        ggplot2::facet_wrap(
            ggplot2::vars(component_label),
            labeller = ggplot2::labeller(component_label = facet_labels)
        ) +
        ggplot2::coord_cartesian(xlim = c(-0.08, 1.08), clip = "off") +
        ggplot2::labs(
            title = title,
            subtitle = paste(strwrap(subtitle, width = 72L), collapse = "\n"),
            x = sprintf(
                "Observed time, scaled 0\u20131 (%s)",
                provenance$time_field
            ),
            y = "Standardized oriented component score",
            colour = "Condition",
            fill = "Condition",
            shape = "Condition",
            caption = paste(strwrap(paste(
                "Counts show independent biological samples per design cell;",
                trajectory_note,
                "lines cannot select or confirm a component"
            ), width = 80L), collapse = "\n")
        ) +
        theme_landscapeR()
}
