# Shared time-course interpretation primitives (ADR 0020; issue #117)

.time_values_numeric <- function(values, field = "observed time") {
    if (inherits(values, c("Date", "POSIXct", "POSIXlt"))) {
        return(as.numeric(values))
    }
    if (is.ordered(values)) return(as.numeric(values))
    if (is.numeric(values)) return(as.numeric(values))
    .stop_landscapeR_validation(sprintf(
        "observed-time field '%s' must be numeric, Date/POSIXct, or ordered",
        field
    ))
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

.time_course_resample_rankings <- function(
    model_records,
    primary_variant
) {
    adjusted_variants <- c(
        "adjusted",
        "time-course-adjusted",
        "repeated-time-course-adjusted"
    )
    uncertainty_field <- if (primary_variant %in% adjusted_variants) {
        "adjusted_uncertainty"
    } else {
        "unadjusted_uncertainty"
    }
    n_resamples <- length(
        model_records[[1L]][[uncertainty_field]]$bootstrap_estimates
    )
    estimates <- vapply(model_records, function(record) {
        record[[uncertainty_field]]$bootstrap_estimates
    }, numeric(n_resamples))
    if (!n_resamples) {
        rankings <- data.frame(
            resample = integer(),
            component = integer(),
            component_label = character(),
            estimate = numeric(),
            proposal_rank = integer(),
            estimable = logical(),
            complete_search = logical(),
            stringsAsFactors = FALSE
        )
    } else {
        if (is.null(dim(estimates))) {
            estimates <- matrix(estimates, ncol = length(model_records))
        }
        rankings <- do.call(rbind, lapply(seq_len(nrow(estimates)), function(i) {
            estimate <- estimates[i, ]
            estimable <- is.finite(estimate)
            complete_search <- all(estimable)
            proposal_rank <- rep.int(NA_integer_, length(estimate))
            if (complete_search) {
                proposal_rank <- rank(-abs(estimate), ties.method = "first")
            }
            data.frame(
                resample = as.integer(i),
                component = vapply(
                    model_records,
                    `[[`,
                    integer(1L),
                    "component"
                ),
                component_label = vapply(
                    model_records,
                    `[[`,
                    character(1L),
                    "component_label"
                ),
                estimate = estimate,
                proposal_rank = as.integer(proposal_rank),
                estimable = estimable,
                complete_search = rep.int(complete_search, length(estimate)),
                stringsAsFactors = FALSE
            )
        }))
        rownames(rankings) <- NULL
    }
    summary <- do.call(rbind, lapply(model_records, function(record) {
        component_rows <- rankings$component == record$component
        complete <- component_rows & rankings$complete_search
        ranks <- rankings$proposal_rank[complete]
        n_requested <- length(unique(rankings$resample))
        data.frame(
            component = record$component,
            component_label = record$component_label,
            n_resamples = as.integer(n_requested),
            n_complete_searches = as.integer(length(ranks)),
            component_fit_failures = as.integer(sum(
                component_rows & !rankings$estimable
            )),
            mean_rank = if (length(ranks)) mean(ranks) else NA_real_,
            rank_one_count = as.integer(sum(ranks == 1L)),
            rank_one_fraction = if (n_requested) {
                sum(ranks == 1L) / n_requested
            } else {
                NA_real_
            },
            stringsAsFactors = FALSE
        )
    }))
    list(rankings = rankings, summary = summary)
}

.time_course_nuisance_reference <- function(nuisance_values) {
    if (!length(nuisance_values)) return(numeric())
    reference <- lapply(nuisance_values, function(values) {
        if (is.ordered(values) || is.numeric(values)) {
            return(stats::median(as.numeric(values)))
        }
        factor_values <- if (is.factor(values)) values else factor(values)
        factor(
            levels(factor_values)[[1L]],
            levels = levels(factor_values)
        )
    })
    matrix <- .time_nuisance_matrix(reference)
    if (!nrow(matrix)) return(numeric())
    matrix[1L, , drop = TRUE]
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
    proposal_eligible = TRUE,
    diagnostic_prefix = "non-identifiable-design:"
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
            paste0(diagnostic_prefix, result$diagnostic %||% "unknown")
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
    comparison_level,
    non_estimable_diagnostic = ""
) {
    effect <- NULL
    if (length(scores) == length(target)) {
        effect <- .signed_rank_biserial(
            scores,
            target,
            reference_level,
            comparison_level
        )
    }
    estimable <- !is.null(effect) && is.finite(effect$estimate)
    if (!estimable) {
        effect <- list(
            estimate = NA_real_,
            n_available = 0L,
            n_score_ties = NA_integer_,
            p_value = NA_real_
        )
        scores <- rep(NA_real_, length(target))
    }
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
        diagnostic = if (estimable) {
            "descriptive-only-not-trajectory-evidence"
        } else {
            paste0(
                "descriptive-only-component-not-estimable",
                if (nzchar(non_estimable_diagnostic)) {
                    paste0(": ", non_estimable_diagnostic)
                } else {
                    ""
                }
            )
        },
        p_value = effect$p_value,
        q_value = NA_real_,
        effect_conf_low = NA_real_,
        effect_conf_high = NA_real_,
        n_resamples = 0L,
        resample_failures = 0L,
        resampling_method = "not-requested",
        resampling_plan_digest = NA_character_,
        evidence_status = if (estimable) {
            "estimable-exploratory-only"
        } else {
            "not-estimable"
        },
        stringsAsFactors = FALSE
    )
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
