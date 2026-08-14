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
        study_time_range = "numeric",
        nuisance_values = "list",
        reference_level = "character",
        comparison_level = "character"
    ),
    prototype = list(
        observed_time = numeric(),
        study_time_range = numeric(),
        nuisance_values = list(),
        reference_level = character(),
        comparison_level = character()
    )
)

.independent_association_result <- function(result, strategy) {
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
            comparison_level = strategy@comparison_level,
            study_time_range = strategy@study_time_range
        )
        .independent_association_result(result, strategy)
    }
)

#' @rdname association_strategy_id
#' @export
setMethod(
    "association_strategy_id",
    signature(strategy = "IndependentTimeCourseLinearAssociationStrategy"),
    function(strategy) "independent-time-course-linear-v1"
)

#' @rdname association_contract
#' @export
setMethod(
    "association_contract",
    signature(strategy = "IndependentTimeCourseLinearAssociationStrategy"),
    function(strategy) {
        .new_association_contract(
            sampling_designs = "independent_time_course",
            target_types = "binary",
            estimand = "standardized-condition-time-interaction",
            cohort_policy = "complete-condition-time-cell-observations",
            diagnostic_prefix = "non-identifiable-design:",
            abstention_statuses = c("not-estimable", "non-identifiable-design"),
            refit_policy = "condition-time-cell-observation-index",
            evidence_version = .independent_time_evidence_version
        )
    }
)

#' @rdname refit_association
#' @export
setMethod(
    "refit_association",
    signature(
        strategy = "IndependentTimeCourseLinearAssociationStrategy",
        scores = "numeric",
        values = "ANY",
        index = "integer"
    ),
    function(strategy, scores, values, index, context = list()) {
        unknown <- setdiff(names(context), "orientation_multiplier")
        if (length(unknown)) {
            .stop_landscapeR_validation(sprintf(
                "independent time-course refitting received unknown context '%s'",
                unknown[[1L]]
            ))
        }
        result <- .fit_independent_time_course(
            scores[index],
            values[index],
            strategy@observed_time[index],
            lapply(strategy@nuisance_values, `[`, index),
            strategy@reference_level,
            strategy@comparison_level,
            orientation_multiplier = context$orientation_multiplier %||% NULL,
            study_time_range = strategy@study_time_range
        )
        .independent_association_result(result, strategy)
    }
)

#' @rdname prepare_association
#' @export
setMethod(
    "prepare_association",
    signature(
        strategy = "IndependentTimeCourseLinearAssociationStrategy",
        data = "StateTransitionData",
        specification = "AnalysisSpecification",
        values = "ANY"
    ),
    function(strategy, data, specification, values) {
        contract <- .validated_association_contract(strategy)
        if (!identical(data@sampling_design@kind, "independent_time_course") ||
            !"independent_time_course" %in% contract$sampling_designs) {
            .stop_landscapeR_validation(
                "independent time-course strategy received the wrong design"
            )
        }
        observed_time_raw <- .aligned_component_metadata(
            data,
            1L,
            data@sampling_design@time_col,
            "associate_metadata",
            "observed-time field"
        )
        observed_time <- .time_values_numeric(
            observed_time_raw,
            data@sampling_design@time_col
        )
        names(observed_time) <- names(observed_time_raw)
        nuisance_values <- stats::setNames(
            lapply(specification@nuisance_fields, function(field) {
                .aligned_component_metadata(
                    data, 1L, field, "associate_metadata", "nuisance field"
                )
            }),
            specification@nuisance_fields
        )
        complete <- .time_required_complete(
            values,
            observed_time,
            nuisance_values
        )
        study_time_grid <- sort(unique(
            observed_time[is.finite(observed_time)]
        ))
        study_time_range <- if (length(study_time_grid)) {
            range(study_time_grid)
        } else {
            numeric()
        }
        retained_time <- observed_time[complete]
        retained_nuisance <- lapply(nuisance_values, `[`, complete)
        strategy_params <- list(
            observed_time = retained_time,
            study_time_range = study_time_range,
            reference_level = specification@reference_level,
            comparison_level = specification@comparison_level
        )
        unadjusted <- do.call(methods::new, c(
            list(Class = class(strategy)[[1L]]),
            strategy_params,
            list(nuisance_values = list())
        ))
        adjusted <- if (length(retained_nuisance)) {
            do.call(methods::new, c(
                list(Class = class(strategy)[[1L]]),
                strategy_params,
                list(nuisance_values = retained_nuisance)
            ))
        } else {
            NULL
        }
        .new_association_preparation(
            strategy = unadjusted,
            values = values,
            complete = complete,
            nuisance_values = retained_nuisance,
            context = list(
                adjusted_strategy = adjusted,
                observed_time = retained_time,
                study_time_grid = study_time_grid,
                study_time_range = study_time_range,
                analysis_cohort = names(values)[complete],
                excluded_cohort = names(values)[!complete]
            )
        )
    }
)

register_strategy(
    "AssociationStrategy",
    "independent_time_course_linear",
    function(params = list()) {
        allowed <- c(
            "observed_time",
            "study_time_range",
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
            study_time_range = as.numeric(
                params$study_time_range %||% numeric()
            ),
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

.fit_independent_time_course <- function(
    scores,
    target,
    observed_time,
    nuisance_values,
    reference_level,
    comparison_level,
    orientation_multiplier = NULL,
    study_time_range = numeric()
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
    time_range <- if (length(study_time_range) == 2L &&
        all(is.finite(study_time_range)) &&
        study_time_range[[2L]] > study_time_range[[1L]]) {
        study_time_range
    } else {
        range(observed_time)
    }
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
    study_time_grid,
    n_resamples,
    seed
) {
    plan <- .association_resampling_plan(
        values = target,
        nuisance_values = list(
            observed_time = factor(
                observed_time,
                levels = study_time_grid
            )
        ),
        n_resamples = n_resamples,
        seed = seed
    )
    cell <- interaction(
        factor(target, levels = .binary_level_order(target)),
        factor(observed_time, levels = study_time_grid),
        drop = FALSE,
        lex.order = TRUE
    )
    counts <- as.integer(table(cell))
    names(counts) <- names(table(cell))
    policy <- .resampling_policy_reframe(
        plan$policy,
        method = "condition-time-cell-bootstrap",
        unit = "independent-biological-observation",
        design = c(
            plan$policy$design,
            list(
                study_time_grid = study_time_grid,
                cell_counts = counts
            )
        )
    )
    list(
        indices = plan$indices,
        digest = if (n_resamples) policy$digest else NA_character_,
        method = "condition-time-cell-bootstrap",
        cell_counts = counts,
        n_resamples = n_resamples,
        seed = seed,
        policy = policy
    )
}

.time_course_uncertainty <- function(
    scores,
    target,
    strategy,
    plan,
    orientation_multiplier,
    task_identity,
    sequential_internal,
    future_scheduling
) {
    tasks <- lapply(seq_along(plan$indices), function(i) list(
        index = plan$indices[[i]]
    ))
    execution <- .future_repetition(
        tasks = tasks,
        task_ids = sprintf(
            "independent:%s:bootstrap:%04d",
            task_identity,
            seq_along(tasks)
        ),
        run_seed = plan$seed,
        compute_tier = "standard",
        worker = function(task, task_id, task_stream) {
            index <- task$index
            result <- refit_association(
                strategy,
                scores,
                target,
                as.integer(index),
                context = list(
                    orientation_multiplier = orientation_multiplier
                )
            )
            if (identical(result$status, "estimable")) {
                result$estimate
            } else {
                .repetition_failure("model-not-estimable", NA_real_)
            }
        },
        sequential_internal = sequential_internal,
        future_scheduling = future_scheduling
    )
    estimates <- vapply(execution$values, function(value) {
        if (is.numeric(value) && length(value) == 1L) value else NA_real_
    }, numeric(1L))
    summary <- .resampling_summary(estimates, plan)
    summary$resampling_method <- if (length(plan$indices)) {
        "condition-time-cell-bootstrap"
    } else {
        "not-requested"
    }
    summary$bootstrap_estimates <- estimates
    summary$execution <- execution
    summary
}

.time_course_display_lines <- function(
    result,
    component,
    component_label,
    reference_level,
    comparison_level,
    target,
    nuisance_values
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
    condition <- factor(
        as.character(target),
        levels = c(reference_level, comparison_level)
    )
    grid <- do.call(rbind, lapply(
        c(reference_level, comparison_level),
        function(level) {
            observed <- result$scaled_time[condition == level]
            data.frame(
                condition = level,
                scaled_time = range(observed),
                stringsAsFactors = FALSE
            )
        }
    ))
    target_name <- grep("^target", names(coefficients), value = TRUE)
    target_name <- target_name[!grepl(":", target_name)]
    interaction_name <- grep(
        "^target.*:scaled_time$",
        names(coefficients),
        value = TRUE
    )
    target_indicator <- as.numeric(grid$condition == comparison_level)
    nuisance_reference <- .time_course_nuisance_reference(nuisance_values)
    nuisance_names <- intersect(
        names(nuisance_reference),
        names(coefficients)
    )
    nuisance_contribution <- if (length(nuisance_names)) {
        sum(
            nuisance_reference[nuisance_names] *
                coefficients[nuisance_names]
        )
    } else {
        0
    }
    grid$fitted_score <- coefficients[["(Intercept)"]] +
        coefficients[["scaled_time"]] * grid$scaled_time +
        coefficients[[target_name[[1L]]]] * target_indicator +
        coefficients[[interaction_name[[1L]]]] *
            target_indicator * grid$scaled_time +
        nuisance_contribution
    grid$component <- as.integer(component)
    grid$component_label <- component_label
    grid
}

.associate_independent_time_course <- function(
    std,
    stage1,
    specification,
    non_analytical_fields,
    dataset_id,
    n_resamples,
    seed,
    exchangeability,
    sequential_internal,
    future_scheduling
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
            "independent time-course target must be declared binary",
            interpretation_module = .independent_time_evidence_version
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
                specification_error,
                interpretation_module = .independent_time_evidence_version
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
    strategy <- .resolve_registered_association_strategy(std, target)
    if (is.null(strategy)) {
        return(.new_association_abstention(
            std,
            stage1,
            specification,
            "no unique registered strategy supports this design and target",
            reason = "unsupported-design-target",
            interpretation_module = .independent_time_evidence_version
        ))
    }
    preparation <- prepare_association(strategy, std, specification, target)
    analysis_complete <- preparation$complete
    analysis_cohort <- preparation$context$analysis_cohort
    excluded_cohort <- preparation$context$excluded_cohort
    observed_time <- preparation$context$observed_time
    study_time_grid <- preparation$context$study_time_grid
    study_time_range <- preparation$context$study_time_range
    nuisance_values <- preparation$nuisance_values
    if (length(study_time_grid) < 2L) {
        return(.new_association_abstention(
            std,
            stage1,
            specification,
            paste(
                "non-identifiable-design:",
                "observed study time has fewer than two finite values"
            ),
            reason = "non-identifiable-design",
            interpretation_module = .independent_time_evidence_version
        ))
    }
    if (!length(analysis_cohort)) {
        return(.new_association_abstention(
            std,
            stage1,
            specification,
            paste(
                "non-identifiable-design:",
                "no complete cases for target, observed time, and nuisance"
            ),
            reason = "non-identifiable-design",
            interpretation_module = .independent_time_evidence_version
        ))
    }
    target <- preparation$values[analysis_complete]
    coordinate_matrix <- coordinate_matrix[
        analysis_complete,
        ,
        drop = FALSE
    ]
    reference_level <- specification@reference_level
    comparison_level <- specification@comparison_level
    resampling_plan <- .time_course_resampling_plan(
        target,
        observed_time,
        study_time_grid,
        n_resamples,
        seed
    )
    component_labels <- colnames(coordinate_matrix)
    if (is.null(component_labels)) {
        component_labels <- paste0("PC", seq_len(ncol(coordinate_matrix)))
    }
    unadjusted_strategy <- preparation$strategy
    adjusted_strategy <- preparation$context$adjusted_strategy
    diagnostic_prefix <- association_contract(
        unadjusted_strategy
    )$diagnostic_prefix
    strategy_contracts <- list(
        unadjusted = .validated_association_contract(unadjusted_strategy)
    )
    if (length(nuisance_values)) {
        strategy_contracts$adjusted <-
            .validated_association_contract(adjusted_strategy)
    }
    adapter <- .new_assoc_execution_adapter(
        id = "independent-time-course-linear-v1",
        sampling_design = "independent_time_course",
        prepare = function(context) {
            list(
                coordinate_matrix = coordinate_matrix,
                component_labels = component_labels,
                work_items = list(list(
                    id = specification@target_field,
                    metadata_field = specification@target_field
                )),
                state = list(),
                strategy_contracts = strategy_contracts,
                exclusion_rows = list()
            )
        },
        execute_component = function(
            context,
            plan,
            work_item,
            component,
            component_label,
            scores
        ) {
            unadjusted_effect <- associate_component(
                unadjusted_strategy,
                scores,
                target
            )
            unadjusted <- unadjusted_effect$model_result
            unadjusted_uncertainty <- .time_course_uncertainty(
                scores,
                target,
                unadjusted_strategy,
                resampling_plan,
                orientation_multiplier = unadjusted$orientation_multiplier,
                task_identity = paste0(component_label, ":unadjusted"),
                sequential_internal = sequential_internal,
                future_scheduling = future_scheduling
            )
            association_rows <- list(
                .time_course_pooled_row(
                    component,
                    component_label,
                    unadjusted$standardized_scores,
                    target,
                    reference_level,
                    comparison_level
                ),
                .time_course_association_row(
                    component,
                    component_label,
                    "time-course-unadjusted",
                    unadjusted,
                    unadjusted_uncertainty,
                    reference_level,
                    comparison_level,
                    diagnostic_prefix = diagnostic_prefix
                )
            )
            adjusted <- NULL
            adjusted_uncertainty <- NULL
            if (length(nuisance_values)) {
                adjusted_effect <- associate_component(
                    adjusted_strategy,
                    scores,
                    target
                )
                adjusted <- adjusted_effect$model_result
                adjusted_uncertainty <- .time_course_uncertainty(
                    scores,
                    target,
                    adjusted_strategy,
                    resampling_plan,
                    orientation_multiplier = adjusted$orientation_multiplier,
                    task_identity = paste0(component_label, ":adjusted"),
                    sequential_internal = sequential_internal,
                    future_scheduling = future_scheduling
                )
                association_rows[[length(association_rows) + 1L]] <-
                    .time_course_association_row(
                        component,
                        component_label,
                        "time-course-adjusted",
                        adjusted,
                        adjusted_uncertainty,
                        reference_level,
                        comparison_level,
                        nuisance_fields = names(nuisance_values),
                        diagnostic_prefix = diagnostic_prefix
                    )
            }
            standardized <- unadjusted$standardized_scores
            observation <- data.frame(
                metadata_field = specification@target_field,
                component = component,
                component_label = component_label,
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
            primary_model <- if (length(nuisance_values)) {
                adjusted
            } else {
                unadjusted
            }
            display_line <- .time_course_display_lines(
                primary_model,
                component,
                component_label,
                reference_level,
                comparison_level,
                target,
                nuisance_values
            )
            model_record <- list(
                component = component,
                component_label = component_label,
                orientation_multiplier = unadjusted$orientation_multiplier,
                unadjusted = unadjusted,
                adjusted = adjusted,
                unadjusted_uncertainty = unadjusted_uncertainty,
                adjusted_uncertainty = adjusted_uncertainty
            )
            execution_records <- list(
                unadjusted = unadjusted_uncertainty$execution
            )
            if (length(nuisance_values)) {
                execution_records$adjusted <- adjusted_uncertainty$execution
            }
            list(
                association_rows = association_rows,
                observation_rows = observation,
                execution_records = execution_records,
                scientific_records = list(model_record),
                display_records = list(display_line)
            )
        },
        finalize = function(context, plan, normalized) {
            context$blueprint
        }
    )
    execution <- .execute_assoc_components(adapter, context = list())
    if (is(execution, "AssociationAbstention")) return(execution)
    associations <- execution$normalized$associations
    observations <- execution$normalized$observations
    model_records <- execution$normalized$scientific_records
    display_lines <- execution$normalized$display_records
    input_digest <- .atlas_input_digest(std)
    state_space_digest <- .atlas_state_space_digest(stage1)
    dataset_id <- .time_course_dataset_id(std, input_digest, dataset_id)
    time_min <- study_time_range[[1L]]
    time_max <- study_time_range[[2L]]
    scaled_time <- (observed_time - time_min) / (time_max - time_min)
    time_cells <- expand.grid(
        condition = c(reference_level, comparison_level),
        observed_time = study_time_grid,
        stringsAsFactors = FALSE
    )
    observed_cells <- as.data.frame(table(
        condition = factor(
            target,
            levels = c(reference_level, comparison_level)
        ),
        observed_time = factor(
            observed_time,
            levels = study_time_grid
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
    resample_ranks <- .time_course_resample_rankings(
        model_records,
        primary_variant
    )
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
    display_line_table <- do.call(rbind, display_lines)
    display_state <- .new_time_course_display_state(
        display_line_table,
        resample_ranks$summary
    )
    blueprint <- list(
        module = .independent_time_evidence_version,
        contract_sampling_design = "independent_time_course",
        version = "1.0.0",
        dataset_id = dataset_id,
        associations = associations,
        observations = observations,
        exclusions = exclusions,
        cohort_members = .time_course_cohort_members(
            associations,
            observations,
            analysis_cohort
        ),
        sampling_design = std@sampling_design,
        input_digest = input_digest,
        state_space_digest = state_space_digest,
        compute_tier = if (n_resamples > 0L) {
            "standard"
        } else {
            "inspect"
        },
        provenance = list(
            association_strategy = association_strategy_id(
                unadjusted_strategy
            ),
            association_contract = association_contract(
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
            multiplicity = .association_multiplicity_contract(),
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
            time_course_display_lines = display_line_table,
            time_course_effect_summary = effect_summary,
            time_course_cells = time_cells,
            time_course_missing_cells = time_cells[
                time_cells$count == 0L,
                ,
                drop = FALSE
            ],
            time_course_missing_cell_count = as.integer(sum(
                time_cells$count == 0L
            )),
            time_course_display_state = display_state,
            time_course_resample_rankings = resample_ranks$rankings,
            time_course_rank_summary = resample_ranks$summary,
            resampling_plan = resampling_plan
        ),
        evidence_status = "estimable-exploratory-only"
    )
    .finalize_assoc_execution(
        adapter,
        context = list(blueprint = blueprint),
        execution = execution
    )
}

.time_course_permutation_indices <- function(
    observed_time,
    n_permutations,
    seed
) {
    strata <- split(seq_along(observed_time), observed_time, drop = TRUE)
    policy <- .resampling_policy_plan(
        lifecycle = "permutation",
        method = "within-time-permutation",
        unit = "condition-by-time-cell",
        n_requested = n_permutations,
        seed = seed,
        design = list(strata = strata),
        draw_factory = function(replicate_index) {
            index <- seq_along(observed_time)
            for (stratum in strata) {
                index[stratum] <- sample(stratum, length(stratum))
            }
            index
        }
    )
    structure(policy$draws, resampling_policy = policy)
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
    seed,
    sequential_internal,
    future_scheduling
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
    components <- sort(unique(
        ranking$component[
            ranking$proposal_eligible &
                is.finite(ranking$effect_magnitude)
        ]
    ))
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
        repetition <- .future_numeric_repetition(
            tasks = permutation_plan,
            task_ids = sprintf(
                "independent-time:complete-search:label:%04d",
                seq_along(permutation_plan)
            ),
            run_seed = seed,
            compute_tier = "standard",
            worker = function(index, task_id, task_stream) {
            permuted_target <- target_values[index]
            effects <- apply(score_matrix, 2L, function(scores) {
                result <- .fit_independent_time_course(
                    scores,
                    permuted_target,
                    observed_time,
                    list(),
                    atlas@provenance$reference_level,
                    atlas@provenance$comparison_level,
                    study_time_range = atlas@provenance$time_range
                )
                if (identical(result$status, "estimable")) {
                    result$estimate
                } else {
                    NA_real_
                }
            })
            if (length(effects) && all(is.finite(effects))) {
                max(abs(effects))
            } else {
                NA_real_
            }
            },
            sequential_internal = sequential_internal,
            future_scheduling = future_scheduling,
            failure_code = "time-course-null-refit-failed"
        )
        null_max <- repetition$values
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
        repetition <- .future_numeric_repetition(
            tasks = permutation_plan,
            task_ids = sprintf(
                "independent-time:complete-search:residual:%04d",
                seq_along(permutation_plan)
            ),
            run_seed = seed,
            compute_tier = "standard",
            worker = function(index, task_id, task_stream) {
            effects <- vapply(reduced_models, function(model) {
                reconstructed <- model$fitted + model$residuals[index]
                result <- .fit_independent_time_course(
                    reconstructed,
                    target_values,
                    observed_time,
                    nuisance_values,
                    atlas@provenance$reference_level,
                    atlas@provenance$comparison_level,
                    study_time_range = atlas@provenance$time_range
                )
                if (identical(result$status, "estimable")) {
                    result$estimate
                } else {
                    NA_real_
                }
            }, numeric(1L))
            if (length(effects) && all(is.finite(effects))) {
                max(abs(effects))
            } else {
                NA_real_
            }
            },
            sequential_internal = sequential_internal,
            future_scheduling = future_scheduling,
            failure_code = "time-course-null-refit-failed"
        )
        null_max <- repetition$values
        method <- "within-time-reduced-model-residual-permutation"
        design_digest <- ranking$design_digest[[1L]]
    }
    null_max[!is.finite(null_max)] <- NA_real_
    n_completed <- sum(is.finite(null_max))
    permutation_policy <- .resampling_policy_reframe(
        attr(permutation_plan, "resampling_policy", exact = TRUE),
        method = method,
        unit = "condition-by-time-cell"
    )
    if (!n_completed) {
        return(.new_permutation_evidence(
            method = method,
            status = "not-identifiable",
            n_requested = n_permutations,
            n_completed = 0L,
            null_max_effect = null_max,
            seed = seed,
            diagnostic = "failed-time-course-null-replicate",
            resampling_policy = permutation_policy,
            execution = repetition$execution
        ))
    }
    observed <- max(
        ranking$effect_magnitude[
            ranking$proposal_eligible &
                is.finite(ranking$effect_magnitude)
        ]
    )
    n_failures <- n_permutations - n_completed
    .new_permutation_evidence(
        method = method,
        status = if (n_failures) "partial" else "complete",
        n_requested = n_permutations,
        n_completed = n_completed,
        observed_max_effect = observed,
        null_max_effect = null_max,
        search_aware_p_value = (
            1 + sum(null_max >= observed, na.rm = TRUE)
        ) / (n_permutations + 1),
        seed = seed,
        cohort_digest = ranking$cohort_digest[[1L]],
        design_digest = design_digest,
        diagnostic = if (n_failures) {
            "some-time-course-null-refits-failed"
        } else {
            ""
        },
        resampling_policy = permutation_policy,
        execution = repetition$execution
    )
}
