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
    signature(strategy = "RepeatedTimeCourseLmerAssociationStrategy"),
    function(strategy) "repeated-time-course-lmer-v1"
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
    fixed <- stats::model.matrix(
        .repeated_fixed_formula(names(nuisance_values)),
        data = frame,
        contrasts.arg = list(
            target = stats::contr.treatment(2L, base = 1L)
        )
    )
    if (qr(fixed)$rank < ncol(fixed)) {
        return("non-identifiable-design: rank-deficient-fixed-effect-design")
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
    fixed <- stats::model.matrix(
        .repeated_fixed_formula(names(nuisance_values)),
        data = frame,
        contrasts.arg = list(
            target = stats::contr.treatment(2L, base = 1L)
        )
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
                contrasts = list(
                    target = stats::contr.treatment(2L, base = 1L)
                ),
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
        return(list(
            indices = list(),
            replicate_subject_ids = list(),
            source_subject_ids = list(),
            digest = NA_character_,
            method = "condition-stratified-subject-trajectory-bootstrap",
            unit = "complete-subject",
            n_resamples = 0L,
            seed = seed
        ))
    }
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
    plans <- lapply(seq_len(n_resamples), function(replicate_index) {
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
    })
    indices <- lapply(plans, `[[`, "indices")
    replicate_subject_ids <- lapply(plans, `[[`, "subject")
    source_subject_ids <- lapply(plans, `[[`, "source_subject")
    list(
        indices = indices,
        replicate_subject_ids = replicate_subject_ids,
        source_subject_ids = source_subject_ids,
        digest = digest::digest(
            list(
                seed = seed,
                strata = strata,
                indices = indices,
                replicate_subject_ids = replicate_subject_ids,
                source_subject_ids = source_subject_ids
            ),
            algo = "sha256",
            serialize = TRUE
        ),
        method = "condition-stratified-subject-trajectory-bootstrap",
        unit = "complete-subject",
        n_resamples = n_resamples,
        seed = seed
    )
}

.repeated_time_uncertainty <- function(
    scores,
    target,
    observed_time,
    subject,
    nuisance_values,
    reference_level,
    comparison_level,
    plan,
    orientation_multiplier,
    study_time_range
) {
    estimates <- vapply(seq_along(plan$indices), function(i) {
        index <- plan$indices[[i]]
        result <- .fit_repeated_time_course(
            scores[index],
            target[index],
            observed_time[index],
            plan$replicate_subject_ids[[i]],
            lapply(nuisance_values, `[`, index),
            reference_level,
            comparison_level,
            orientation_multiplier = orientation_multiplier,
            study_time_range = study_time_range
        )
        if (identical(result$status, "estimable")) {
            result$estimate
        } else {
            NA_real_
        }
    }, numeric(1L))
    summary <- .resampling_summary(estimates, list(digest = plan$digest))
    summary$resampling_method <- if (length(plan$indices)) {
        plan$method
    } else {
        "not-requested"
    }
    summary$bootstrap_estimates <- estimates
    summary
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
    exchangeability
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
                specification_error
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
    observed_time_raw <- .aligned_component_metadata(
        std,
        1L,
        time_field,
        "associate_metadata",
        "observed-time field"
    )
    observed_time <- .time_values_numeric(observed_time_raw)
    names(observed_time) <- names(observed_time_raw)
    subject <- as.character(.aligned_component_metadata(
        std,
        1L,
        subject_field,
        "associate_metadata",
        "subject field"
    ))
    names(subject) <- names(target)
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
    study_time_grid <- sort(unique(
        observed_time[is.finite(observed_time)]
    ))
    if (length(study_time_grid) < 2L) {
        return(.new_association_abstention(
            std,
            stage1,
            specification,
            "non-identifiable-design: fewer than two observed times",
            reason = "non-identifiable-design"
        ))
    }
    study_time_range <- range(study_time_grid)
    complete <- .time_required_complete(
        target,
        observed_time,
        c(list(subject = subject), nuisance_values)
    )
    complete_subject <- tapply(complete, subject, all)
    retained_subject <- names(complete_subject)[complete_subject]
    analysis_complete <- complete & subject %in% retained_subject
    all_sample_ids <- names(target)
    if (!any(analysis_complete)) {
        return(.new_association_abstention(
            std,
            stage1,
            specification,
            "non-identifiable-design: no complete subject trajectories",
            reason = "non-identifiable-design"
        ))
    }
    analysis_cohort <- all_sample_ids[analysis_complete]
    excluded_cohort <- all_sample_ids[!analysis_complete]
    target <- target[analysis_complete]
    observed_time <- observed_time[analysis_complete]
    subject <- subject[analysis_complete]
    nuisance_values <- lapply(nuisance_values, `[`, analysis_complete)
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
    rows <- list()
    model_records <- list()
    observations <- list()
    display_lines <- list()
    constructor <- get_strategy(
        "AssociationStrategy",
        "repeated_time_course_lmer"
    )
    for (component in seq_len(ncol(coordinate_matrix))) {
        scores <- coordinate_matrix[, component]
        unadjusted_strategy <- constructor(list(
            observed_time = observed_time,
            study_time_range = study_time_range,
            subject = subject,
            nuisance_values = list(),
            reference_level = reference_level,
            comparison_level = comparison_level
        ))
        unadjusted <- associate_component(
            unadjusted_strategy,
            scores,
            target
        )$model_result
        unadjusted_uncertainty <- .repeated_time_uncertainty(
            scores,
            target,
            observed_time,
            subject,
            list(),
            reference_level,
            comparison_level,
            plan,
            unadjusted$orientation_multiplier,
            study_time_range
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
            "repeated-time-course-unadjusted",
            unadjusted,
            unadjusted_uncertainty,
            reference_level,
            comparison_level,
            diagnostic_prefix = ""
        )
        adjusted <- NULL
        adjusted_uncertainty <- NULL
        if (length(nuisance_values)) {
            adjusted_strategy <- constructor(list(
                observed_time = observed_time,
                study_time_range = study_time_range,
                subject = subject,
                nuisance_values = nuisance_values,
                reference_level = reference_level,
                comparison_level = comparison_level
            ))
            adjusted <- associate_component(
                adjusted_strategy,
                scores,
                target
            )$model_result
            adjusted_uncertainty <- .repeated_time_uncertainty(
                scores,
                target,
                observed_time,
                subject,
                nuisance_values,
                reference_level,
                comparison_level,
                plan,
                adjusted$orientation_multiplier,
                study_time_range
            )
            rows[[length(rows) + 1L]] <- .time_course_association_row(
                component,
                component_labels[[component]],
                "repeated-time-course-adjusted",
                adjusted,
                adjusted_uncertainty,
                reference_level,
                comparison_level,
                nuisance_fields = names(nuisance_values),
                diagnostic_prefix = ""
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
            atom_count = 1L,
            available = is.finite(standardized),
            stringsAsFactors = FALSE
        )
        primary_model <- if (length(nuisance_values)) adjusted else unadjusted
        display_lines[[component]] <- .repeated_display_lines(
            primary_model,
            component,
            component_labels[[component]],
            reference_level,
            comparison_level,
            nuisance_values,
            target,
            primary_model$scaled_time
        )
        model_records[[component]] <- list(
            component = as.integer(component),
            component_label = component_labels[[component]],
            orientation_multiplier = unadjusted$orientation_multiplier,
            unadjusted = unadjusted,
            adjusted = adjusted,
            unadjusted_uncertainty = unadjusted_uncertainty,
            adjusted_uncertainty = adjusted_uncertainty
        )
    }
    associations <- do.call(rbind, rows)
    for (variant in unique(associations$evidence_variant)) {
        index <- associations$evidence_variant == variant
        associations$q_value[index] <- stats::p.adjust(
            associations$p_value[index],
            method = "BH"
        )
    }
    observations <- do.call(rbind, observations)
    rownames(associations) <- NULL
    rownames(observations) <- NULL
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
    subject_intervals <- unlist(lapply(
        split(trajectory_data$observed_time, trajectory_data$subject),
        function(values) diff(sort(unique(values)))
    ))
    subject_intervals <- subject_intervals[
        is.finite(subject_intervals) & subject_intervals > 0
    ]
    endpoint_tolerance <- if (length(subject_intervals)) {
        0.75 * stats::median(subject_intervals)
    } else {
        0
    }
    trajectory_data$dropout <- as.logical(ave(
        trajectory_data$observed_time,
        trajectory_data$subject,
        FUN = function(values) {
            max(values) <
                study_time_range[[2L]] - endpoint_tolerance
        }
    ))
    subject_summary <- unique(trajectory_data[
        ,
        c("subject", "condition", "dropout"),
        drop = FALSE
    ])
    input_digest <- .atlas_input_digest(std)
    state_space_digest <- .atlas_state_space_digest(stage1)
    dataset_id <- .time_course_dataset_id(std, input_digest, dataset_id)
    exclusions <- data.frame(
        metadata_field = setdiff(
            names(colData(std)),
            specification@target_field
        ),
        reason = vapply(
            setdiff(names(colData(std)), specification@target_field),
            function(field) {
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
            },
            character(1L)
        ),
        stringsAsFactors = FALSE
    )
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
            sampling_design = "longitudinal",
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
            endpoint_tolerance = endpoint_tolerance,
            time_course_display_lines = do.call(rbind, display_lines),
            time_course_effect_summary = effect_summary,
            subject_summary = subject_summary,
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
    validObject(atlas)
    atlas
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
    lapply(seq_len(n_permutations), function(i) {
        permuted <- sample(subject_condition, length(subject_condition))
        stats::setNames(permuted, names(subject_condition))[subject]
    })
}

.compute_repeated_time_permutation_evidence <- function(
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
    null_max <- vapply(plan, function(permuted) {
        effects <- apply(score_matrix, 2L, function(scores) {
            result <- .fit_repeated_time_course(
                scores,
                factor(
                    permuted,
                    levels = c(
                        atlas@provenance$reference_level,
                        atlas@provenance$comparison_level
                    )
                ),
                observed_time,
                subject,
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
        })
        if (all(is.finite(effects))) max(abs(effects)) else NA_real_
    }, numeric(1L))
    n_failures <- sum(!is.finite(null_max))
    n_completed <- sum(is.finite(null_max))
    if (!n_completed) {
        return(.new_permutation_evidence(
            status = "not-identifiable",
            n_requested = n_permutations,
            n_completed = 0L,
            null_max_effect = rep(NA_real_, n_permutations),
            seed = seed,
            diagnostic = "failed-subject-level-null-replicate"
        ))
    }
    status <- if (n_failures) "partial" else "complete"
    .new_permutation_evidence(
        method = "between-subject-condition-permutation",
        status = status,
        n_requested = n_permutations,
        n_completed = n_completed,
        observed_max_effect = max(ranking$effect_magnitude),
        null_max_effect = null_max,
        search_aware_p_value = (
            1 + sum(
                null_max >= max(ranking$effect_magnitude),
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
        }
    )
}

.plot_repeated_time_course <- function(
    observations,
    provenance,
    ranking = NULL,
    title = "Repeated-subject time-course evidence",
    subtitle = "Individual trajectories and population-level linear divergence"
) {
    data <- merge(
        observations,
        provenance$time_course_observations,
        by = "primary_sample",
        all.x = TRUE,
        sort = FALSE
    )
    data <- data[data$available, , drop = FALSE]
    lines <- provenance$time_course_display_lines
    has_trajectories <- nrow(lines) > 0L
    if (!has_trajectories &&
        identical(title, "Repeated-subject time-course evidence")) {
        diagnostics <- unique(
            provenance$time_course_effect_summary$diagnostic
        )
        diagnostics <- diagnostics[nzchar(diagnostics)]
        title <- "Repeated-subject model not estimable"
        subtitle <- .public_abstention_message(
            "non-identifiable-design",
            diagnostics
        )
    }
    endpoint <- ave(
        data$scaled_time,
        interaction(data$component_label, data$subject, drop = TRUE),
        FUN = max
    )
    dropout_points <- data[
        data$dropout & data$scaled_time == endpoint,
        ,
        drop = FALSE
    ]
    effect_summary <- provenance$time_course_effect_summary
    rank_summary <- provenance$time_course_rank_summary
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
    rank_text <- stats::setNames(
        ifelse(
            is.finite(rank_summary$rank_one_fraction),
            sprintf(
                "effect rank 1 in %.0f%% | fit failures %d/%d",
                100 * rank_summary$rank_one_fraction,
                rank_summary$component_fit_failures,
                rank_summary$n_resamples
            ),
            "association resampling not requested"
        ),
        rank_summary$component_label
    )
    if (!has_trajectories) {
        facet_labels <- stats::setNames(
            paste0(
                effect_summary$component_label,
                "\ninteraction not estimated"
            ),
            effect_summary$component_label
        )
    } else if (!is.null(ranking) && nrow(ranking)) {
        facet_labels <- stats::setNames(
            sprintf(
                "%s\nrank %d | interaction %s\n%s",
                ranking$component_label,
                ranking$proposal_rank,
                interval_text[ranking$component_label],
                rank_text[ranking$component_label]
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
            y = .data[["score"]],
            group = .data[["subject"]]
        )
    ) +
        ggplot2::geom_line(
            ggplot2::aes(colour = .data[["condition"]]),
            linewidth = 0.35,
            alpha = 0.32
        ) +
        ggplot2::geom_point(
            ggplot2::aes(
                shape = .data[["condition"]],
                fill = .data[["condition"]]
            ),
            size = 1.7,
            stroke = 0.45,
            colour = "#111111"
        ) +
        ggplot2::geom_point(
            data = dropout_points,
            ggplot2::aes(
                x = .data[["scaled_time"]],
                y = .data[["score"]]
            ),
            shape = 4,
            size = 2.7,
            stroke = 0.8,
            colour = "#B2182B",
            inherit.aes = FALSE
        ) +
        ggplot2::geom_line(
            data = lines,
            ggplot2::aes(
                x = .data[["scaled_time"]],
                y = .data[["fitted_score"]],
                colour = .data[["condition"]],
                group = .data[["condition"]]
            ),
            linewidth = 1,
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
                "Thin lines connect repeated observations from each subject;",
                if (has_trajectories) {
                    paste(
                        "bold lines show fitted population-level trajectories;"
                    )
                } else {
                    "no population-level trajectory is shown;"
                },
                if (nrow(dropout_points)) {
                    paste(
                        "crosses mark subjects ending before the final",
                        "study-time window;"
                    )
                } else {
                    ""
                },
                "the declared model contains correlated random intercepts",
                "and time slopes;",
                "the Stage 1 component basis is held fixed"
            ), width = 80L), collapse = "\n")
        ) +
        theme_landscapeR()
}
