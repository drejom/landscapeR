# Repeated-subject time-course component interpretation (ADR 0020; issue #82)

#' Repeated-subject correlated random-slope association strategy
#'
#' Fits a binary between-subject condition, deterministically scaled observed
#' time, their interaction, optional nuisance fields, and correlated
#' subject-specific random intercepts and time slopes. The condition-by-time
#' interaction is the proposal-eligible effect.
#'
#' @rdname AssociationStrategy-class
#' @export
setClass(
    "RepeatedTimeCourseLmerAssociationStrategy",
    contains = "AssociationStrategy",
    slots = c(
        observed_time = "numeric",
        study_time_range = "numeric",
        subject = "character",
        nuisance_values = "list",
        reference_level = "character",
        comparison_level = "character"
    ),
    prototype = list(
        observed_time = numeric(),
        study_time_range = numeric(),
        subject = character(),
        nuisance_values = list(),
        reference_level = character(),
        comparison_level = character()
    )
)

.repeated_association_result <- function(result, strategy) {
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
        strategy = "RepeatedTimeCourseLmerAssociationStrategy",
        data = "StateTransitionData",
        values = "ANY"
    ),
    function(strategy, data, values) {
        identical(data@sampling_design@kind, "longitudinal") &&
            !is.null(.binary_level_order(values))
    }
)

#' @rdname associate_component
#' @export
setMethod(
    "associate_component",
    signature(
        strategy = "RepeatedTimeCourseLmerAssociationStrategy",
        scores = "numeric",
        values = "ANY"
    ),
    function(strategy, scores, values) {
        result <- .fit_repeated_time_course(
            scores = scores,
            target = values,
            observed_time = strategy@observed_time,
            subject = strategy@subject,
            nuisance_values = strategy@nuisance_values,
            reference_level = strategy@reference_level,
            comparison_level = strategy@comparison_level,
            study_time_range = strategy@study_time_range
        )
        .repeated_association_result(result, strategy)
    }
)

#' @rdname association_strategy_id
#' @export
setMethod(
    "association_strategy_id",
    signature(strategy = "RepeatedTimeCourseLmerAssociationStrategy"),
    function(strategy) "repeated-time-course-lmer-v1"
)

#' @rdname association_contract
#' @export
setMethod(
    "association_contract",
    signature(strategy = "RepeatedTimeCourseLmerAssociationStrategy"),
    function(strategy) {
        .new_association_contract(
            sampling_designs = "longitudinal",
            target_types = "binary",
            estimand = "standardized-condition-time-interaction",
            cohort_policy = "complete-subject-trajectories",
            diagnostic_prefix = "none",
            abstention_statuses = c(
                "not-estimable", "non-convergent", "singular"
            ),
            refit_policy = "condition-stratified-complete-subject",
            evidence_version = .repeated_time_evidence_version
        )
    }
)

#' @rdname refit_association
#' @export
setMethod(
    "refit_association",
    signature(
        strategy = "RepeatedTimeCourseLmerAssociationStrategy",
        scores = "numeric",
        values = "ANY",
        index = "integer"
    ),
    function(strategy, scores, values, index, context = list()) {
        unknown <- setdiff(
            names(context),
            c("subject", "orientation_multiplier")
        )
        if (length(unknown)) {
            .stop_landscapeR_validation(sprintf(
                "repeated time-course refitting received unknown context '%s'",
                unknown[[1L]]
            ))
        }
        subject <- context$subject %||% strategy@subject[index]
        if (length(subject) != length(index)) {
            .stop_landscapeR_validation(
                "resampled subject identity must align with resampling index"
            )
        }
        result <- .fit_repeated_time_course(
            scores[index],
            values[index],
            strategy@observed_time[index],
            as.character(subject),
            lapply(strategy@nuisance_values, `[`, index),
            strategy@reference_level,
            strategy@comparison_level,
            orientation_multiplier = context$orientation_multiplier %||% NULL,
            study_time_range = strategy@study_time_range
        )
        .repeated_association_result(result, strategy)
    }
)

#' @rdname prepare_association
#' @export
setMethod(
    "prepare_association",
    signature(
        strategy = "RepeatedTimeCourseLmerAssociationStrategy",
        data = "StateTransitionData",
        specification = "AnalysisSpecification",
        values = "ANY"
    ),
    function(strategy, data, specification, values) {
        contract <- .validated_association_contract(strategy)
        if (!identical(data@sampling_design@kind, "longitudinal") ||
            !"longitudinal" %in% contract$sampling_designs) {
            .stop_landscapeR_validation(
                "repeated time-course strategy received the wrong design"
            )
        }
        time_field <- data@sampling_design@time_col
        subject_field <- data@sampling_design@subject_id_col
        observed_time_raw <- .aligned_component_metadata(
            data, 1L, time_field, "associate_metadata", "observed-time field"
        )
        observed_time <- .time_values_numeric(observed_time_raw, time_field)
        names(observed_time) <- names(observed_time_raw)
        subject <- as.character(.aligned_component_metadata(
            data, 1L, subject_field, "associate_metadata", "subject field"
        ))
        names(subject) <- names(values)
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
            c(list(subject = subject), nuisance_values)
        )
        complete_subject <- tapply(complete, subject, all)
        retained_subject <- names(complete_subject)[complete_subject]
        complete <- complete & subject %in% retained_subject
        study_time_grid <- sort(unique(
            observed_time[is.finite(observed_time)]
        ))
        study_time_range <- if (length(study_time_grid)) {
            range(study_time_grid)
        } else {
            numeric()
        }
        retained_time <- observed_time[complete]
        retained_subject_values <- subject[complete]
        retained_nuisance <- lapply(nuisance_values, `[`, complete)
        strategy_params <- list(
            observed_time = retained_time,
            study_time_range = study_time_range,
            subject = retained_subject_values,
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
                subject = retained_subject_values,
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
    "repeated_time_course_lmer",
    function(params = list()) {
        allowed <- c(
            "observed_time",
            "study_time_range",
            "subject",
            "nuisance_values",
            "reference_level",
            "comparison_level"
        )
        unknown <- setdiff(names(params), allowed)
        if (length(unknown)) {
            .stop_landscapeR_validation(sprintf(
                paste0(
                    "repeated_time_course_lmer strategy received unknown ",
                    "parameter '%s'"
                ),
                unknown[[1L]]
            ))
        }
        new(
            "RepeatedTimeCourseLmerAssociationStrategy",
            observed_time = as.numeric(params$observed_time %||% numeric()),
            study_time_range = as.numeric(
                params$study_time_range %||% numeric()
            ),
            subject = as.character(params$subject %||% character()),
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

.repeated_empty_result <- function(
    diagnostic,
    status = "not-estimable",
    n_available = 0L,
    cohort_digest = NA_character_,
    design_digest = NA_character_,
    standardized_scores = numeric(),
    orientation_multiplier = 1,
    scaled_time = numeric(),
    native_diagnostics = list()
) {
    list(
        status = status,
        diagnostic = diagnostic,
        estimate = NA_real_,
        p_value = NA_real_,
        n_available = as.integer(n_available),
        n_score_ties = 0L,
        n_target_ties = 0L,
        cohort_digest = cohort_digest,
        design_digest = design_digest,
        design_rank = NA_integer_,
        residual_df = NA_integer_,
        orientation_multiplier = orientation_multiplier,
        standardized_scores = standardized_scores,
        coefficients = numeric(),
        fixed_vcov = matrix(numeric(), 0L, 0L),
        scaled_time = scaled_time,
        residual_sd = NA_real_,
        native_diagnostics = native_diagnostics
    )
}

.repeated_model_frame <- function(
    response,
    target,
    scaled_time,
    subject,
    nuisance_values,
    reference_level,
    comparison_level
) {
    frame <- data.frame(
        response = response,
        target = factor(
            as.character(target),
            levels = c(reference_level, comparison_level)
        ),
        scaled_time = scaled_time,
        subject = factor(subject),
        stringsAsFactors = FALSE
    )
    for (field in names(nuisance_values)) {
        values <- nuisance_values[[field]]
        frame[[field]] <- if (is.ordered(values) || is.numeric(values)) {
            as.numeric(values)
        } else if (is.factor(values)) {
            values
        } else {
            factor(values)
        }
    }
    frame
}

.repeated_fixed_formula <- function(nuisance_fields = character()) {
    fixed <- "response ~ target * scaled_time"
    if (length(nuisance_fields)) {
        fixed <- paste(
            fixed,
            "+",
            paste(sprintf("`%s`", nuisance_fields), collapse = " + ")
        )
    }
    stats::as.formula(fixed)
}

.repeated_lmer_formula <- function(nuisance_fields = character()) {
    stats::as.formula(paste(
        deparse(.repeated_fixed_formula(nuisance_fields)),
        "+ (1 + scaled_time | subject)"
    ))
}

.repeated_model_contrasts <- function(frame, nuisance_fields = character()) {
    factor_nuisance <- nuisance_fields[vapply(
        nuisance_fields,
        function(field) is.factor(frame[[field]]),
        logical(1L)
    )]
    c(
        list(
            target = stats::contr.treatment(
                nlevels(frame$target),
                base = 1L
            )
        ),
        stats::setNames(lapply(factor_nuisance, function(field) {
            stats::contr.treatment(nlevels(frame[[field]]), base = 1L)
        }), factor_nuisance)
    )
}

.landscapeR_lmer <- function(...) {
    lme4::lmer(...)
}

.repeated_structural_diagnostic <- function(
    target,
    observed_time,
    subject,
    nuisance_values,
    reference_level,
    comparison_level
) {
    if (anyNA(subject) || any(!nzchar(subject))) {
        return("non-identifiable-design: missing-subject-identity")
    }
    subject_condition <- split(as.character(target), subject)
    if (any(vapply(
        subject_condition,
        function(values) length(unique(values)) != 1L,
        logical(1L)
    ))) {
        return("non-identifiable-design: condition-varies-within-subject")
    }
    observations_per_subject <- table(subject)
    if (any(observations_per_subject < 3L)) {
        return(
            "non-identifiable-design: fewer-than-three-observations-per-subject"
        )
    }
    distinct_times <- tapply(observed_time, subject, function(values) {
        length(unique(values))
    })
    if (any(distinct_times < 3L)) {
        return(
            "non-identifiable-design: fewer-than-three-times-per-subject"
        )
    }
    condition_by_subject <- vapply(
        subject_condition,
        `[[`,
        character(1L),
        1L
    )
    condition_counts <- table(factor(
        condition_by_subject,
        levels = c(reference_level, comparison_level)
    ))
    if (any(condition_counts < 2L)) {
        return("non-identifiable-design: insufficient-subject-replication")
    }
    categorical_nuisance_levels <- vapply(
        nuisance_values,
        function(values) {
            if (is.numeric(values) || is.ordered(values)) return(Inf)
            length(unique(as.character(values)))
        },
        numeric(1L)
    )
    if (any(categorical_nuisance_levels < 2L)) {
        return("non-identifiable-design: rank-deficient-fixed-effect-design")
    }
    range <- range(observed_time)
    scaled_time <- (observed_time - range[[1L]]) / diff(range)
    frame <- .repeated_model_frame(
        rep.int(0, length(target)),
        target,
        scaled_time,
        subject,
        nuisance_values,
        reference_level,
        comparison_level
    )
    contrasts <- .repeated_model_contrasts(
        frame,
        names(nuisance_values)
    )
    fixed <- stats::model.matrix(
        .repeated_fixed_formula(names(nuisance_values)),
        data = frame,
        contrasts.arg = contrasts
    )
    if (qr(fixed)$rank < ncol(fixed)) {
        return("non-identifiable-design: rank-deficient-fixed-effect-design")
    }
    if (length(unique(subject)) <= qr(fixed)$rank) {
        return(
            paste0(
                "non-identifiable-design: ",
                "insufficient-biological-units-for-model-rank"
            )
        )
    }
    ""
}

.fit_repeated_time_course <- function(
    scores,
    target,
    observed_time,
    subject,
    nuisance_values,
    reference_level,
    comparison_level,
    orientation_multiplier = NULL,
    study_time_range = numeric()
) {
    if (!requireNamespace("lme4", quietly = TRUE)) {
        .stop_landscapeR_validation(
            "repeated time-course interpretation requires package 'lme4'"
        )
    }
    n <- length(scores)
    if (length(target) != n ||
        length(observed_time) != n ||
        length(subject) != n ||
        any(vapply(nuisance_values, length, integer(1L)) != n)) {
        .stop_landscapeR_validation(
            "repeated time-course model inputs must have equal lengths"
        )
    }
    complete <- .time_required_complete(
        target,
        observed_time,
        c(list(subject = subject), nuisance_values)
    ) & is.finite(scores)
    cohort_digest <- .association_cohort_digest(names(target), complete)
    if (!all(complete)) {
        return(.repeated_empty_result(
            "non-identifiable-design: incomplete-model-cohort",
            n_available = sum(complete),
            cohort_digest = cohort_digest
        ))
    }
    orientation <- .time_course_orientation(
        scores,
        target,
        reference_level,
        comparison_level,
        multiplier = orientation_multiplier
    )
    response <- orientation$standardized_scores
    if (nzchar(orientation$status)) {
        return(.repeated_empty_result(
            orientation$status,
            n_available = n,
            cohort_digest = cohort_digest,
            standardized_scores = response,
            orientation_multiplier = orientation$multiplier
        ))
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
    structural <- .repeated_structural_diagnostic(
        target,
        observed_time,
        subject,
        nuisance_values,
        reference_level,
        comparison_level
    )
    if (nzchar(structural)) {
        return(.repeated_empty_result(
            structural,
            n_available = n,
            cohort_digest = cohort_digest,
            standardized_scores = response,
            orientation_multiplier = orientation$multiplier,
            scaled_time = scaled_time
        ))
    }
    frame <- .repeated_model_frame(
        response,
        target,
        scaled_time,
        subject,
        nuisance_values,
        reference_level,
        comparison_level
    )
    contrasts <- .repeated_model_contrasts(
        frame,
        names(nuisance_values)
    )
    fixed <- stats::model.matrix(
        .repeated_fixed_formula(names(nuisance_values)),
        data = frame,
        contrasts.arg = contrasts
    )
    design_digest <- digest::digest(
        list(
            fixed = unname(fixed),
            fixed_names = colnames(fixed),
            subject = as.character(frame$subject),
            scaled_time = scaled_time
        ),
        algo = "sha256",
        serialize = TRUE
    )
    control <- lme4::lmerControl(
        optimizer = "bobyqa",
        optCtrl = list(maxfun = 100000L),
        calc.derivs = TRUE,
        check.rankX = "stop.deficient",
        check.conv.singular = lme4::.makeCC(
            action = "ignore",
            tol = 1e-4
        )
    )
    warning_messages <- character()
    fit <- tryCatch(
        withCallingHandlers(
            .landscapeR_lmer(
                formula = .repeated_lmer_formula(names(nuisance_values)),
                data = frame,
                REML = FALSE,
                na.action = stats::na.fail,
                contrasts = contrasts,
                control = control
            ),
            warning = function(warning) {
                warning_messages <<- c(
                    warning_messages,
                    conditionMessage(warning)
                )
                invokeRestart("muffleWarning")
            }
        ),
        error = function(error) error
    )
    if (inherits(fit, "error")) {
        return(.repeated_empty_result(
            paste0("model-non-convergent: ", conditionMessage(fit)),
            status = "non-convergent",
            n_available = n,
            cohort_digest = cohort_digest,
            design_digest = design_digest,
            standardized_scores = response,
            orientation_multiplier = orientation$multiplier,
            scaled_time = scaled_time,
            native_diagnostics = list(
                error = conditionMessage(fit),
                warnings = warning_messages
            )
        ))
    }
    convergence_messages <- fit@optinfo$conv$lme4$messages %||% character()
    gradient <- fit@optinfo$derivs$gradient %||% numeric()
    native_diagnostics <- list(
        warnings = warning_messages,
        convergence_messages = as.character(convergence_messages),
        optimizer_code = fit@optinfo$conv$opt,
        gradient = as.numeric(gradient),
        theta = as.numeric(lme4::getME(fit, "theta")),
        singular = lme4::isSingular(fit, tol = 1e-4)
    )
    if (length(convergence_messages) ||
        !identical(fit@optinfo$conv$opt, 0L)) {
        return(.repeated_empty_result(
            "model-non-convergent",
            status = "non-convergent",
            n_available = n,
            cohort_digest = cohort_digest,
            design_digest = design_digest,
            standardized_scores = response,
            orientation_multiplier = orientation$multiplier,
            scaled_time = scaled_time,
            native_diagnostics = native_diagnostics
        ))
    }
    if (isTRUE(native_diagnostics$singular)) {
        return(.repeated_empty_result(
            "singular-random-effects-covariance",
            status = "singular",
            n_available = n,
            cohort_digest = cohort_digest,
            design_digest = design_digest,
            standardized_scores = response,
            orientation_multiplier = orientation$multiplier,
            scaled_time = scaled_time,
            native_diagnostics = native_diagnostics
        ))
    }
    coefficients <- lme4::fixef(fit)
    fixed_vcov <- as.matrix(stats::vcov(fit))
    interaction_name <- grep(
        "^target.*:scaled_time$",
        names(coefficients),
        value = TRUE
    )
    if (length(interaction_name) != 1L) {
        return(.repeated_empty_result(
            "non-identifiable-design: missing-condition-time-coefficient",
            n_available = n,
            cohort_digest = cohort_digest,
            design_digest = design_digest,
            standardized_scores = response,
            orientation_multiplier = orientation$multiplier,
            scaled_time = scaled_time,
            native_diagnostics = native_diagnostics
        ))
    }
    estimate <- unname(coefficients[[interaction_name]])
    standard_error <- sqrt(fixed_vcov[
        interaction_name,
        interaction_name
    ])
    p_value <- 2 * stats::pnorm(
        abs(estimate / standard_error),
        lower.tail = FALSE
    )
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
        design_rank = as.integer(qr(fixed)$rank),
        residual_df = as.integer(n - qr(fixed)$rank),
        orientation_multiplier = orientation$multiplier,
        standardized_scores = response,
        coefficients = coefficients,
        fixed_vcov = fixed_vcov,
        scaled_time = scaled_time,
        residual_sd = stats::sigma(fit),
        native_diagnostics = native_diagnostics
    )
}

.repeated_resampling_plan <- function(
    target,
    subject,
    n_resamples,
    seed
) {
    subject_rows <- split(seq_along(subject), subject)
    subject_condition <- vapply(subject_rows, function(index) {
        unique(as.character(target[index]))[[1L]]
    }, character(1L))
    strata <- split(names(subject_rows), subject_condition)
    if (n_resamples == 0L) {
        policy <- .resampling_policy_plan(
            lifecycle = "bootstrap",
            method = "condition-stratified-subject-trajectory-bootstrap",
            unit = "complete-subject",
            n_requested = 0L,
            seed = seed,
            design = list(strata = strata)
        )
        return(list(
            indices = list(),
            replicate_subject_ids = list(),
            source_subject_ids = list(),
            digest = NA_character_,
            method = "condition-stratified-subject-trajectory-bootstrap",
            unit = "complete-subject",
            n_resamples = 0L,
            seed = seed,
            policy = policy
        ))
    }
    policy <- .resampling_policy_plan(
        lifecycle = "bootstrap",
        method = "condition-stratified-subject-trajectory-bootstrap",
        unit = "complete-subject",
        n_requested = n_resamples,
        seed = seed,
        design = list(strata = strata),
        draw_factory = function(replicate_index) {
            sampled <- unlist(lapply(strata, function(ids) {
                sample(ids, length(ids), replace = TRUE)
            }), use.names = FALSE)
            indices <- integer()
            new_subject <- character()
            for (draw in seq_along(sampled)) {
                rows <- subject_rows[[sampled[[draw]]]]
                indices <- c(indices, rows)
                new_subject <- c(
                    new_subject,
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
                indices = indices,
                subject = new_subject,
                source_subject = sampled
            )
        }
    )
    plans <- policy$draws
    indices <- lapply(plans, `[[`, "indices")
    replicate_subject_ids <- lapply(plans, `[[`, "subject")
    source_subject_ids <- lapply(plans, `[[`, "source_subject")
    list(
        indices = indices,
        replicate_subject_ids = replicate_subject_ids,
        source_subject_ids = source_subject_ids,
        digest = policy$digest,
        method = "condition-stratified-subject-trajectory-bootstrap",
        unit = "complete-subject",
        n_resamples = n_resamples,
        seed = seed,
        policy = policy
    )
}

.repeated_time_uncertainty <- function(
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
        index = plan$indices[[i]],
        subject = plan$replicate_subject_ids[[i]]
    ))
    execution <- .future_repetition(
        tasks = tasks,
        task_ids = sprintf(
            "repeated:%s:bootstrap:%04d",
            task_identity,
            seq_along(tasks)
        ),
        run_seed = plan$seed,
        compute_tier = "standard",
        worker = function(task, task_id, task_stream) {
            .repeated_bootstrap_refit(
                task,
                strategy,
                scores,
                target,
                orientation_multiplier
            )
        },
        sequential_internal = sequential_internal,
        future_scheduling = future_scheduling
    )
    estimates <- vapply(execution$values, function(value) {
        if (is.numeric(value) && length(value) == 1L) value else NA_real_
    }, numeric(1L))
    summary <- .resampling_summary(estimates, plan)
    summary$resampling_method <- if (length(plan$indices)) {
        plan$method
    } else {
        "not-requested"
    }
    summary$bootstrap_estimates <- estimates
    summary$execution <- execution
    summary
}

.repeated_bootstrap_refit <- function(
    task,
    strategy,
    scores,
    target,
    orientation_multiplier
) {
    result <- refit_association(
        strategy,
        scores,
        target,
        as.integer(task$index),
        context = list(
            subject = task$subject,
            orientation_multiplier = orientation_multiplier
        )
    )
    if (identical(result$status, "estimable")) {
        result$estimate
    } else {
        .repetition_failure("model-not-estimable", NA_real_)
    }
}

.repeated_display_lines <- function(
    result,
    component,
    component_label,
    reference_level,
    comparison_level,
    nuisance_values,
    target,
    scaled_time
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
    grid <- do.call(rbind, lapply(
        c(reference_level, comparison_level),
        function(condition) {
            support <- range(
                scaled_time[as.character(target) == condition],
                na.rm = TRUE
            )
            data.frame(
                condition = condition,
                scaled_time = seq(
                    support[[1L]],
                    support[[2L]],
                    length.out = 50L
                ),
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

.associate_repeated_time_course <- function(
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
                "associate_metadata(): repeated time courses require a ",
                "draft AnalysisSpecification"
            )
        )
    }
    if (!identical(specification@target_type, "binary")) {
        .stop_landscapeR_validation(
            "associate_metadata(): repeated time courses require a binary target"
        )
    }
    subject_field <- std@sampling_design@subject_id_col
    time_field <- std@sampling_design@time_col
    if (specification@target_field %in% c(subject_field, time_field)) {
        .stop_landscapeR_validation(
            paste0(
                "associate_metadata(): subject identity and observed time ",
                "cannot be the biological target"
            )
        )
    }
    if (subject_field %in% specification@nuisance_fields) {
        .stop_landscapeR_validation(
            "associate_metadata(): subject identity cannot be a nuisance field"
        )
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
                interpretation_module = .repeated_time_evidence_version
            ))
        }
        .stop_landscapeR_validation(
            paste0("associate_metadata(): ", specification_error)
        )
    }
    coordinates <- dr_coords_k(stage1)
    if (length(coordinates) != 1L) {
        .stop_landscapeR_validation(
            "associate_metadata(): issue #82 supports exactly one omic layer"
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
            interpretation_module = .repeated_time_evidence_version
        ))
    }
    preparation <- prepare_association(strategy, std, specification, target)
    analysis_complete <- preparation$complete
    analysis_cohort <- preparation$context$analysis_cohort
    excluded_cohort <- preparation$context$excluded_cohort
    observed_time <- preparation$context$observed_time
    subject <- preparation$context$subject
    study_time_grid <- preparation$context$study_time_grid
    study_time_range <- preparation$context$study_time_range
    nuisance_values <- preparation$nuisance_values
    if (length(study_time_grid) < 2L) {
        return(.new_association_abstention(
            std,
            stage1,
            specification,
            "non-identifiable-design: fewer than two observed times",
            reason = "non-identifiable-design",
            interpretation_module = .repeated_time_evidence_version
        ))
    }
    if (!any(analysis_complete)) {
        return(.new_association_abstention(
            std,
            stage1,
            specification,
            "non-identifiable-design: no complete subject trajectories",
            reason = "non-identifiable-design",
            interpretation_module = .repeated_time_evidence_version
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
    plan <- .repeated_resampling_plan(
        target,
        subject,
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
    if (identical(diagnostic_prefix, "none")) diagnostic_prefix <- ""
    excluded_fields <- setdiff(
        names(colData(std)),
        specification@target_field
    )
    exclusions <- data.frame(
        metadata_field = excluded_fields,
        reason = vapply(excluded_fields, function(field) {
            if (field == subject_field) {
                "sampling-subject-field"
            } else if (field == time_field) {
                "sampling-time-field"
            } else if (field %in% specification@nuisance_fields) {
                "declared-nuisance-field"
            } else if (field %in% non_analytical_fields) {
                "declared-non-analytical"
            } else {
                "unsupported-repeated-time-course-metadata"
            }
        }, character(1L)),
        stringsAsFactors = FALSE
    )
    strategy_contracts <- list(
        unadjusted = .validated_association_contract(unadjusted_strategy)
    )
    if (length(nuisance_values)) {
        strategy_contracts$adjusted <-
            .validated_association_contract(adjusted_strategy)
    }
    adapter <- .new_assoc_execution_adapter(
        id = "repeated-time-course-random-slope-v1",
        sampling_design = "longitudinal",
        prepare = function(context) {
            list(
                coordinate_matrix = coordinate_matrix,
                component_labels = component_labels,
                work_items = list(list(
                    id = specification@target_field,
                    metadata_field = specification@target_field
                )),
                state = list(resampling_plan = plan),
                strategy_contracts = strategy_contracts,
                exclusion_rows = list(exclusions)
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
            unadjusted <- associate_component(
                unadjusted_strategy,
                scores,
                target
            )$model_result
            unadjusted_uncertainty <- .repeated_time_uncertainty(
                scores,
                target,
                unadjusted_strategy,
                plan = plan$state$resampling_plan,
                unadjusted$orientation_multiplier,
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
                    comparison_level,
                    unadjusted$diagnostic %||% ""
                ),
                .time_course_association_row(
                    component,
                    component_label,
                    "repeated-time-course-unadjusted",
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
                adjusted <- associate_component(
                    adjusted_strategy,
                    scores,
                    target
                )$model_result
                adjusted_uncertainty <- .repeated_time_uncertainty(
                    scores,
                    target,
                    adjusted_strategy,
                    plan = plan$state$resampling_plan,
                    adjusted$orientation_multiplier,
                    task_identity = paste0(component_label, ":adjusted"),
                    sequential_internal = sequential_internal,
                    future_scheduling = future_scheduling
                )
                association_rows[[length(association_rows) + 1L]] <-
                    .time_course_association_row(
                        component,
                        component_label,
                        "repeated-time-course-adjusted",
                        adjusted,
                        adjusted_uncertainty,
                        reference_level,
                        comparison_level,
                        nuisance_fields = names(nuisance_values),
                        diagnostic_prefix = diagnostic_prefix
                    )
            }
            standardized <- unadjusted$standardized_scores
            if (length(standardized) != length(scores)) {
                standardized <- rep(NA_real_, length(scores))
            }
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
                atom_count = 1L,
                available = is.finite(standardized),
                stringsAsFactors = FALSE
            )
            primary_model <- if (length(nuisance_values)) {
                adjusted
            } else {
                unadjusted
            }
            display_line <- .repeated_display_lines(
                primary_model,
                component,
                component_label,
                reference_level,
                comparison_level,
                nuisance_values,
                target,
                primary_model$scaled_time
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
        }
    )
    execution <- .execute_assoc_components(adapter, context = list())
    if (is(execution, "AssociationAbstention")) return(execution)
    associations <- execution$normalized$associations
    observations <- execution$normalized$observations
    exclusions <- execution$normalized$exclusions
    model_records <- execution$normalized$scientific_records
    display_lines <- execution$normalized$display_records
    primary_variant <- if (length(nuisance_values)) {
        "repeated-time-course-adjusted"
    } else {
        "repeated-time-course-unadjusted"
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
    scaled_time <- (observed_time - study_time_range[[1L]]) /
        diff(study_time_range)
    trajectory_data <- data.frame(
        primary_sample = names(target),
        subject = subject,
        condition = as.character(target),
        observed_time = observed_time,
        scaled_time = scaled_time,
        stringsAsFactors = FALSE
    )
    trajectory_data$dropout <- as.logical(ave(
        trajectory_data$observed_time,
        trajectory_data$subject,
        FUN = function(values) {
            max(values) < study_time_range[[2L]]
        }
    ))
    subject_summary <- unique(trajectory_data[
        ,
        c("subject", "condition", "dropout"),
        drop = FALSE
    ])
    dropout_subjects <- subject_summary$subject[subject_summary$dropout]
    dropout_endpoints <- trajectory_data[
        trajectory_data$subject %in% dropout_subjects,
        ,
        drop = FALSE
    ]
    if (nrow(dropout_endpoints)) {
        endpoint_time <- ave(
            dropout_endpoints$scaled_time,
            dropout_endpoints$subject,
            FUN = max
        )
        dropout_endpoints <- dropout_endpoints[
            dropout_endpoints$scaled_time == endpoint_time,
            ,
            drop = FALSE
        ]
    }
    input_digest <- .atlas_input_digest(std)
    state_space_digest <- .atlas_state_space_digest(stage1)
    dataset_id <- .time_course_dataset_id(std, input_digest, dataset_id)
    display_line_table <- do.call(rbind, display_lines)
    display_state <- .new_time_course_display_state(
        display_line_table,
        resample_ranks$summary
    )
    blueprint <- list(
        module = .repeated_time_evidence_version,
        contract_sampling_design = "longitudinal",
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
            sampling_design = "longitudinal",
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
            nuisance_fields = specification@nuisance_fields,
            nuisance_values = nuisance_values,
            orientation_anchor = specification@orientation_anchor,
            component_standardization = do.call(rbind, lapply(
                seq_along(model_records),
                function(component) {
                    scores <- coordinate_matrix[, component]
                    data.frame(
                        component = as.integer(component),
                        component_label = component_labels[[component]],
                        method = "sample-mean-and-sample-SD",
                        centre = mean(scores),
                        scale = stats::sd(scores),
                        orientation_multiplier =
                            model_records[[component]]$
                                orientation_multiplier,
                        stringsAsFactors = FALSE
                    )
                }
            )),
            claim_intent = specification@claim_intent,
            subject_field = subject_field,
            time_field = time_field,
            time_unit = if (length(std@sampling_design@time_unit)) {
                std@sampling_design@time_unit
            } else {
                NA_character_
            },
            observed_time = observed_time,
            scaled_time = scaled_time,
            time_range = study_time_range,
            time_transform =
                "(time - study_min(time)) / (study_max(time) - study_min(time))",
            model_engine = "lme4::lmer",
            model_engine_version = as.character(
                utils::packageVersion("lme4")
            ),
            model_reml = FALSE,
            model_na_action = "stats::na.fail",
            model_optimizer = "bobyqa",
            model_optimizer_controls = list(maxfun = 100000L),
            model_singular_tolerance = 1e-4,
            model_contrasts = list(
                target = "contr.treatment(2, base = 1)",
                nuisance_factors = "contr.treatment(nlevels, base = 1)"
            ),
            engine_formula = paste(
                "response ~ target * scaled_time + nuisance_terms +",
                "(1 + scaled_time | subject)"
            ),
            scientific_model_formula_unadjusted = paste(
                "standardized_score ~ condition * scaled_time +",
                "(1 + scaled_time | subject)"
            ),
            scientific_model_formula_adjusted = paste(
                "standardized_score ~ condition * scaled_time",
                if (length(nuisance_values)) {
                    paste("+", paste(names(nuisance_values), collapse = " + "))
                } else {
                    ""
                },
                "+ (1 + scaled_time | subject)"
            ),
            scientific_random_formula =
                "(1 + scaled_time | subject)",
            model_formula_digest = digest::digest(
                list(
                    fixed_unadjusted =
                        "standardized_score ~ condition * scaled_time",
                    fixed_adjusted = paste(
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
                    random = "(1 + scaled_time | subject)",
                    contrasts = list(
                        target = "contr.treatment(2, base = 1)",
                        nuisance_factors =
                            "contr.treatment(nlevels, base = 1)"
                    ),
                    optimizer = "bobyqa",
                    maxfun = 100000L,
                    REML = FALSE,
                    na_action = "stats::na.fail"
                ),
                algo = "sha256",
                serialize = TRUE
            ),
            primary_evidence_variant = primary_variant,
            display_trajectory_variant = primary_variant,
            analysis_cohort = analysis_cohort,
            analysis_cohort_exclusions = excluded_cohort,
            time_course_models = model_records,
            time_course_observations = trajectory_data,
            time_course_display_lines = display_line_table,
            time_course_effect_summary = effect_summary,
            subject_summary = subject_summary,
            time_course_dropout_endpoints = dropout_endpoints,
            time_course_dropout_subject_count = as.integer(length(
                unique(dropout_endpoints$subject)
            )),
            time_course_display_state = display_state,
            subject_condition_assignment = unique(data.frame(
                subject = subject,
                condition = as.character(target),
                stringsAsFactors = FALSE
            )),
            time_course_resample_rankings = resample_ranks$rankings,
            time_course_rank_summary = resample_ranks$summary,
            resampling_plan = plan
        ),
        evidence_status = "estimable-exploratory-only"
    )
    .finalize_assoc_blueprint(blueprint, adapter$sampling_design)
}

.repeated_subject_permutation_plan <- function(
    subject,
    target,
    n_permutations,
    seed
) {
    subject_rows <- split(seq_along(subject), subject)
    subject_condition <- vapply(subject_rows, function(index) {
        unique(as.character(target[index]))[[1L]]
    }, character(1L))
    levels <- if (is.factor(target)) {
        levels(target)
    } else {
        unique(subject_condition)
    }
    comparison_subjects <- names(subject_condition)[
        subject_condition == levels[[2L]]
    ]
    comparison_count <- length(comparison_subjects)
    observed_key <- paste(sort(comparison_subjects), collapse = "\r")
    seen <- new.env(hash = TRUE, parent = emptyenv())
    policy <- .resampling_policy_plan(
        lifecycle = "permutation",
        method = "between-subject-condition-permutation",
        unit = "complete-subject",
        n_requested = n_permutations,
        seed = seed,
        design = list(
            subject_condition = subject_condition,
            comparison_count = comparison_count
        ),
        draw_factory = function(replicate_index) {
            repeat {
                selected <- sort(sample(
                    names(subject_condition),
                    comparison_count,
                    replace = FALSE
                ))
                key <- paste(selected, collapse = "\r")
                if (!identical(key, observed_key) &&
                    !exists(key, envir = seen, inherits = FALSE)) {
                    break
                }
            }
            assign(key, TRUE, envir = seen)
            permuted <- rep(levels[[1L]], length(subject_condition))
            names(permuted) <- names(subject_condition)
            permuted[selected] <- levels[[2L]]
            permuted[subject]
        }
    )
    structure(policy$draws, resampling_policy = policy)
}

.repeated_permutation_max <- function(
    permuted,
    score_matrix,
    observed_time,
    subject,
    nuisance_values,
    reference_level,
    comparison_level,
    time_range
) {
    effects <- apply(score_matrix, 2L, function(scores) {
        result <- .fit_repeated_time_course(
            scores,
            factor(permuted, levels = c(reference_level, comparison_level)),
            observed_time,
            subject,
            nuisance_values,
            reference_level,
            comparison_level,
            study_time_range = time_range
        )
        if (identical(result$status, "estimable")) {
            result$estimate
        } else {
            NA_real_
        }
    })
    if (all(is.finite(effects))) max(abs(effects)) else NA_real_
}

.compute_repeated_time_permutation_evidence <- function(
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
    eligible_ranking <- ranking[
        ranking$proposal_eligible &
            is.finite(ranking$effect_magnitude),
        ,
        drop = FALSE
    ]
    if (!nrow(eligible_ranking)) {
        return(.new_permutation_evidence(
            status = "not-identifiable",
            n_requested = n_permutations,
            seed = seed,
            diagnostic = "no-estimable-proposal-candidates"
        ))
    }
    eligible_components <- sort(unique(eligible_ranking$component))
    observed_max_effect <- max(eligible_ranking$effect_magnitude)
    observations <- atlas@observations[
        atlas@observations$metadata_field == target,
        ,
        drop = FALSE
    ]
    observations <- observations[
        observations$component %in% eligible_components,
        ,
        drop = FALSE
    ]
    components <- sort(unique(observations$component))
    if (!identical(components, eligible_components)) {
        return(.new_permutation_evidence(
            status = "not-identifiable",
            n_requested = n_permutations,
            seed = seed,
            diagnostic = "missing-eligible-component-observations"
        ))
    }
    first <- observations[
        observations$component == components[[1L]],
        ,
        drop = FALSE
    ]
    first <- first[order(first$sample_index), , drop = FALSE]
    trajectory <- atlas@provenance$time_course_observations
    trajectory <- trajectory[
        match(first$primary_sample, trajectory$primary_sample),
        ,
        drop = FALSE
    ]
    subject <- trajectory$subject
    observed_time <- trajectory$observed_time
    target_values <- factor(
        trajectory$condition,
        levels = c(
            atlas@provenance$reference_level,
            atlas@provenance$comparison_level
        )
    )
    subject_counts <- table(unique(data.frame(
        subject = subject,
        target = as.character(target_values),
        stringsAsFactors = FALSE
    ))$target)
    n_subjects <- sum(subject_counts)
    log_arrangements <- lchoose(n_subjects, subject_counts[[1L]])
    if (log(n_permutations + 1) > log_arrangements) {
        return(.new_permutation_evidence(
            status = "insufficient-support",
            n_requested = n_permutations,
            seed = seed,
            diagnostic = "insufficient-subject-level-rearrangements"
        ))
    }
    plan <- .repeated_subject_permutation_plan(
        subject,
        target_values,
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
    repetition <- .future_numeric_repetition(
        tasks = plan,
        task_ids = sprintf(
            "repeated-time:complete-search:subject-label:%04d",
            seq_along(plan)
        ),
        run_seed = seed,
        compute_tier = "standard",
        worker = function(permuted, task_id, task_stream) {
            .repeated_permutation_max(
                permuted,
                score_matrix,
                observed_time,
                subject,
                nuisance_values,
                atlas@provenance$reference_level,
                atlas@provenance$comparison_level,
                atlas@provenance$time_range
            )
        },
        sequential_internal = sequential_internal,
        future_scheduling = future_scheduling,
        failure_code = "subject-level-null-refit-failed"
    )
    null_max <- repetition$values
    n_failures <- sum(!is.finite(null_max))
    n_completed <- sum(is.finite(null_max))
    if (!n_completed) {
        return(.new_permutation_evidence(
            status = "not-identifiable",
            n_requested = n_permutations,
            n_completed = 0L,
            null_max_effect = rep(NA_real_, n_permutations),
            seed = seed,
            diagnostic = "failed-subject-level-null-replicate",
            resampling_policy = attr(
                plan,
                "resampling_policy",
                exact = TRUE
            ),
            execution = repetition$execution
        ))
    }
    status <- if (n_failures) "partial" else "complete"
    .new_permutation_evidence(
        method = "between-subject-condition-permutation",
        status = status,
        n_requested = n_permutations,
        n_completed = n_completed,
        observed_max_effect = observed_max_effect,
        null_max_effect = null_max,
        search_aware_p_value = (
            1 + sum(
                null_max >= observed_max_effect,
                na.rm = TRUE
            )
        ) / (n_permutations + 1),
        seed = seed,
        cohort_digest = ranking$cohort_digest[[1L]],
        design_digest = ranking$design_digest[[1L]],
        diagnostic = if (n_failures) {
            "some-subject-level-null-refits-failed"
        } else {
            ""
        },
        resampling_policy = attr(
            plan,
            "resampling_policy",
            exact = TRUE
        ),
        execution = repetition$execution
    )
}
