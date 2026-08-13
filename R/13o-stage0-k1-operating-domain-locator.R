# K=1 real-experiment operating-domain locator (issue #192)

setOldClass(c("K1ExperimentDiagnostics", "list"))
setOldClass(c("K1OperatingDomainLocation", "list"))

.k1_experiment_diagnostics_version <- "k1-experiment-diagnostics-v1"
.k1_operating_location_version <- "k1-operating-domain-location-v1"

.k1_locator_numeric_range <- function(x, field, integer = FALSE) {
    if (!is.numeric(x) || !length(x) || length(x) > 2L ||
            anyNA(x) || any(!is.finite(x)) || any(x <= 0) ||
            (integer && any(!vapply(x, .is_whole_number, logical(1L), 1L)))) {
        .stop_landscapeR_validation(sprintf(
            "%s must contain one value or a finite positive two-value range",
            field
        ))
    }
    value <- sort(unique(x))
    if (integer) as.integer(value) else as.numeric(value)
}

.validate_k1_experiment_diagnostics <- function(x) {
    payload <- unclass(x)
    observed_digest <- payload$digest
    payload$digest <- NULL
    valid <- inherits(x, "K1ExperimentDiagnostics") &&
        identical(names(x), c(
            "version", "feature_count", "signal_strength",
            "noise_reference", "effective_signal_ratio",
            "covariance_regime", "signal_regime", "design", "digest"
        )) &&
        identical(x$version, .k1_experiment_diagnostics_version) &&
        identical(observed_digest,
            digest::digest(payload, algo = "sha256")) &&
        is.integer(x$feature_count) && length(x$feature_count) %in% 1:2 &&
        all(is.finite(x$feature_count)) && all(x$feature_count > 0L) &&
        !is.unsorted(x$feature_count, strictly = FALSE) &&
        is.numeric(x$signal_strength) &&
        length(x$signal_strength) %in% 1:2 &&
        all(is.finite(x$signal_strength)) && all(x$signal_strength > 0) &&
        !is.unsorted(x$signal_strength, strictly = FALSE) &&
        is.numeric(x$noise_reference) &&
        length(x$noise_reference) %in% 1:2 &&
        all(is.finite(x$noise_reference)) && all(x$noise_reference > 0) &&
        !is.unsorted(x$noise_reference, strictly = FALSE) &&
        is.numeric(x$effective_signal_ratio) &&
        length(x$effective_signal_ratio) %in% 1:2 &&
        all(is.finite(x$effective_signal_ratio)) &&
        all(x$effective_signal_ratio > 0) &&
        !is.unsorted(x$effective_signal_ratio, strictly = FALSE) &&
        is.character(x$covariance_regime) &&
        length(x$covariance_regime) == 1L && nzchar(x$covariance_regime) &&
        is.character(x$signal_regime) &&
        length(x$signal_regime) == 1L && nzchar(x$signal_regime) &&
        is.list(x$design) && length(x$design) > 0L &&
        all(vapply(x$design, function(value) {
            is.numeric(value) && length(value) %in% 1:2 &&
                !anyNA(value) && all(is.finite(value)) && all(value >= 0) &&
                !is.unsorted(value, strictly = FALSE)
        }, logical(1L)))
    if (!valid) {
        .stop_landscapeR_validation(
            "K1 experiment diagnostics are invalid or have been altered"
        )
    }
    invisible(TRUE)
}

#' Declare diagnostics for K=1 operating-domain location
#'
#' Records observed design, feature, signal, noise, and covariance diagnostics
#' without assigning a recovery probability. One value represents a point;
#' two values represent an uncertainty interval.
#'
#' @param feature_count observed number of retained features.
#' @param spectral_signal observed spectral signal estimate or interval, on the
#'   same scale used to define the compatible calibration noise reference.
#' @param noise_reference compatible noise reference or interval.
#' @param covariance_regime declared covariance-regime identifier.
#' @param signal_regime declared signal-regime identifier.
#' @param design named design diagnostics required by the declared sampling
#'   design.
#' @return A digest-bound `K1ExperimentDiagnostics` object.
#' @export
k1_experiment_diagnostics <- function(
    feature_count, spectral_signal, noise_reference,
    covariance_regime, signal_regime, design
) {
    feature_count <- .k1_locator_numeric_range(
        feature_count, "feature_count", integer = TRUE
    )
    spectral_signal <- .k1_locator_numeric_range(
        spectral_signal, "spectral_signal"
    )
    noise_reference <- .k1_locator_numeric_range(
        noise_reference, "noise_reference"
    )
    if (!is.character(covariance_regime) ||
            length(covariance_regime) != 1L || is.na(covariance_regime) ||
            !nzchar(covariance_regime) || !is.character(signal_regime) ||
            length(signal_regime) != 1L || is.na(signal_regime) ||
            !nzchar(signal_regime) || !is.list(design) || !length(design) ||
            is.null(names(design)) || any(!nzchar(names(design))) ||
            anyDuplicated(names(design))) {
        .stop_landscapeR_validation(
            "covariance, signal, and named design diagnostics are required"
        )
    }
    design <- lapply(names(design), function(field) {
        .k1_locator_numeric_range(design[[field]], field)
    }) |>
        stats::setNames(names(design))
    effective_signal_ratio <- c(
        min(spectral_signal) / max(noise_reference),
        max(spectral_signal) / min(noise_reference)
    )
    effective_signal_ratio <- sort(unique(effective_signal_ratio))
    payload <- list(
        version = .k1_experiment_diagnostics_version,
        feature_count = feature_count,
        signal_strength = spectral_signal,
        noise_reference = noise_reference,
        effective_signal_ratio = effective_signal_ratio,
        covariance_regime = covariance_regime,
        signal_regime = signal_regime,
        design = design
    )
    result <- structure(c(payload, list(
        digest = digest::digest(payload, algo = "sha256")
    )), class = c("K1ExperimentDiagnostics", "list"))
    .validate_k1_experiment_diagnostics(result)
    result
}

.k1_locator_design_fields <- list(
    independent_time_course = c(
        "minimum_cell_size", "maximum_cell_size",
        "mean_retained_per_declared_cell"
    ),
    longitudinal = c(
        "n_subjects", "n_retained", "minimum_subject_observations"
    )
)

.k1_locator_assessment_class <- c(
    independent_time_course = "K1IndependentTimeCourseAssessment",
    longitudinal = "K1RepeatedSubjectAssessment"
)

.k1_locator_validate_assessment <- function(design, assessment) {
    expected <- .k1_locator_assessment_class[[design@kind]]
    if (is.null(expected) || !inherits(assessment, expected)) return(FALSE)
    if (identical(design@kind, "independent_time_course")) {
        .validate_k1_independent_time_assessment(assessment)
    } else {
        .validate_k1_repeated_assessment(assessment)
    }
    TRUE
}

.k1_locator_validate_any_design_assessment <- function(assessment) {
    if (inherits(assessment, "K1IndependentTimeCourseAssessment")) {
        .validate_k1_independent_time_assessment(assessment)
        return(TRUE)
    }
    if (inherits(assessment, "K1RepeatedSubjectAssessment")) {
        .validate_k1_repeated_assessment(assessment)
        return(TRUE)
    }
    FALSE
}

.k1_locator_support_levels <- function(values, interval) {
    values <- sort(unique(values[is.finite(values)]))
    if (!length(values) || min(interval) < min(values) ||
            max(interval) > max(values)) return(numeric())
    lower <- max(values[values <= min(interval)])
    upper <- min(values[values >= max(interval)])
    unique(c(lower, upper))
}

.k1_locator_design_cells <- function(cells, fields, diagnostics) {
    levels <- lapply(fields, function(field) {
        .k1_locator_support_levels(
            cells[[field]], diagnostics$design[[field]]
        )
    }) |>
        stats::setNames(fields)
    if (any(!vapply(levels, length, integer(1L)))) {
        return(cells[0L, , drop = FALSE])
    }
    keep <- rep(TRUE, nrow(cells))
    for (field in fields) {
        keep <- keep & cells[[field]] %in% levels[[field]]
    }
    cells[keep, , drop = FALSE]
}

.k1_locator_signal_cells <- function(cells, diagnostics) {
    effective_signal_ratio <- cells$signal_strength * ifelse(
        cells$regime_id == "growing_coherent",
        sqrt(cells$informative_feature_count), 1
    ) / cells$recovery_boundary
    cells$effective_signal_ratio <- effective_signal_ratio
    domain <- cells$regime_id == diagnostics$signal_regime &
        cells$covariance_regime == diagnostics$covariance_regime &
        is.finite(effective_signal_ratio)
    domain_cells <- cells[domain, , drop = FALSE]
    p_levels <- .k1_locator_support_levels(
        domain_cells$p, diagnostics$feature_count
    )
    ratio_support <- lapply(p_levels, function(p) {
        rows <- domain_cells[domain_cells$p == p, , drop = FALSE]
        levels <- .k1_locator_support_levels(
            rows$effective_signal_ratio,
            diagnostics$effective_signal_ratio
        )
        rows[rows$effective_signal_ratio %in% levels, , drop = FALSE]
    })
    support <- if (length(ratio_support)) do.call(rbind, ratio_support) else
        domain_cells[0L, , drop = FALSE]
    rownames(support) <- NULL
    signal_covered <- length(p_levels) > 0L &&
        all(vapply(ratio_support, nrow, integer(1L)) > 0L)
    covered <- length(p_levels) > 0L && signal_covered
    list(
        domain = domain_cells,
        support = if (covered) support else domain_cells[0L, , drop = FALSE],
        feature_covered = length(p_levels) > 0L,
        signal_covered = signal_covered,
        rectangular_coverage = covered
    )
}

.k1_empty_locator_cells <- function() data.frame()

.new_k1_operating_location <- function(
    status, reason, sampling_design, diagnostics, design_assessment,
    signal_assessment, design_cells, signal_domain_cells, signal_cells
) {
    located <- status %in% c("located_point", "located_region")
    recovery_probability <- if (located && nrow(signal_cells)) {
        range(signal_cells$recovery_probability, na.rm = TRUE)
    } else NA_real_
    if (any(!is.finite(recovery_probability))) recovery_probability <- NA_real_
    estimability_probability <- if (located && nrow(signal_cells)) {
        range(signal_cells$downstream_estimability_probability, na.rm = TRUE)
    } else NA_real_
    if (any(!is.finite(estimability_probability))) {
        estimability_probability <- NA_real_
    }
    payload <- list(
        version = .k1_operating_location_version,
        status = status,
        reason = reason,
        sampling_design = .sampling_design_provenance(sampling_design),
        diagnostics_digest = diagnostics$digest,
        design_assessment_digest = design_assessment$digest,
        signal_assessment_digest = signal_assessment$digest,
        locator = list(
            feature_count = diagnostics$feature_count,
            signal_ratio = diagnostics$effective_signal_ratio,
            design = diagnostics$design
        ),
        design_cells = design_cells,
        signal_domain_cells = signal_domain_cells,
        signal_cells = signal_cells,
        recovery_probability = recovery_probability,
        downstream_estimability_probability = estimability_probability,
        claim_status = "operating_characteristic_location_only"
    )
    structure(c(payload, list(
        digest = digest::digest(payload, algo = "sha256")
    )), class = c("K1OperatingDomainLocation", "list"))
}

.validate_k1_operating_location <- function(x) {
    payload <- unclass(x)
    observed_digest <- payload$digest
    payload$digest <- NULL
    statuses <- c("located_point", "located_region", "out_of_domain")
    valid <- inherits(x, "K1OperatingDomainLocation") &&
        identical(names(x), c(
            "version", "status", "reason", "sampling_design",
            "diagnostics_digest", "design_assessment_digest",
            "signal_assessment_digest", "locator", "design_cells",
            "signal_domain_cells", "signal_cells", "recovery_probability",
            "downstream_estimability_probability", "claim_status", "digest"
        )) && identical(x$version, .k1_operating_location_version) &&
        x$status %in% statuses && is.character(x$reason) &&
        length(x$reason) == 1L && is.data.frame(x$design_cells) &&
        is.data.frame(x$signal_domain_cells) &&
        is.data.frame(x$signal_cells) && identical(x$claim_status,
            "operating_characteristic_location_only") &&
        is.numeric(x$recovery_probability) &&
        length(x$recovery_probability) %in% 1:2 &&
        is.numeric(x$downstream_estimability_probability) &&
        length(x$downstream_estimability_probability) %in% 1:2 &&
        identical(observed_digest, digest::digest(payload, algo = "sha256"))
    if (!valid) {
        .stop_landscapeR_validation(
            "K1 operating-domain location is invalid or has been altered"
        )
    }
    if (identical(x$status, "out_of_domain") &&
            (is.finite(x$recovery_probability) ||
                is.finite(x$downstream_estimability_probability))) {
        .stop_landscapeR_validation(
            "out-of-domain evidence cannot contain extrapolated probabilities"
        )
    }
    if (x$status %in% c("located_point", "located_region") &&
            (nzchar(x$reason) || !nrow(x$design_cells) ||
                !nrow(x$signal_cells))) {
        .stop_landscapeR_validation(
            "located evidence requires exact supporting calibration cells"
        )
    }
    if (identical(x$status, "out_of_domain") && !nzchar(x$reason)) {
        .stop_landscapeR_validation(
            "out-of-domain evidence requires an explicit reason"
        )
    }
    invisible(TRUE)
}

#' Locate an experiment within calibrated K=1 operating evidence
#'
#' Links observed experiment diagnostics to exact compatible calibration cells.
#' The function refuses to extrapolate when design, feature, covariance, or
#' signal/noise diagnostics are outside the supplied calibration evidence.
#'
#' @param sampling_design declared `SamplingDesign` for the experiment.
#' @param design_assessment compatible independent-time or repeated-subject
#'   calibration assessment.
#' @param signal_assessment high-dimensional calibration assessment.
#' @param diagnostics versioned output from `k1_experiment_diagnostics()`.
#' @return A typed `K1OperatingDomainLocation`.
#' @export
locate_k1_operating_domain <- function(
    sampling_design, design_assessment, signal_assessment, diagnostics
) {
    if (!is(sampling_design, "SamplingDesign") ||
            !inherits(diagnostics, "K1ExperimentDiagnostics") ||
            !inherits(signal_assessment, "K1HighDimensionalAssessment")) {
        .stop_landscapeR_validation(
            "sampling design and typed calibration diagnostics are required"
        )
    }
    .validate_k1_experiment_diagnostics(diagnostics)
    .validate_k1_high_dimensional_assessment(signal_assessment)
    if (!.k1_locator_validate_any_design_assessment(design_assessment)) {
        .stop_landscapeR_validation(paste(
            "design_assessment must be a valid independent-time or",
            "repeated-subject calibration assessment"
        ))
    }
    fields <- .k1_locator_design_fields[[sampling_design@kind]]
    compatible <- !is.null(fields) &&
        .k1_locator_validate_assessment(sampling_design, design_assessment)
    if (!compatible) {
        return(.new_k1_operating_location(
            "out_of_domain", "incompatible_sampling_design",
            sampling_design, diagnostics, design_assessment,
            signal_assessment, .k1_empty_locator_cells(),
            .k1_empty_locator_cells(),
            .k1_empty_locator_cells()
        ))
    }
    if (!all(fields %in% names(diagnostics$design))) {
        return(.new_k1_operating_location(
            "out_of_domain", "insufficient_design_diagnostics",
            sampling_design, diagnostics, design_assessment,
            signal_assessment, .k1_empty_locator_cells(),
            .k1_empty_locator_cells(),
            .k1_empty_locator_cells()
        ))
    }
    design_cells <- .k1_locator_design_cells(
        design_assessment$cells, fields, diagnostics
    )
    regime_cells <- signal_assessment$cells[
        signal_assessment$cells$regime_id == diagnostics$signal_regime &
            signal_assessment$cells$covariance_regime ==
                diagnostics$covariance_regime,
        , drop = FALSE
    ]
    signal_support <- .k1_locator_signal_cells(
        signal_assessment$cells, diagnostics
    )
    reason <- if (!nrow(design_cells)) {
        "design_out_of_range"
    } else if (!nrow(regime_cells)) {
        "covariance_or_signal_regime_out_of_domain"
    } else if (!signal_support$feature_covered) {
        "feature_count_out_of_range"
    } else if (!signal_support$signal_covered) {
        "signal_noise_out_of_range"
    } else if (!signal_support$rectangular_coverage) {
        "insufficient_calibration_coverage"
    } else ""
    if (nzchar(reason)) {
        return(.new_k1_operating_location(
            "out_of_domain", reason, sampling_design, diagnostics,
            design_assessment, signal_assessment, design_cells,
            signal_support$domain,
            .k1_empty_locator_cells()
        ))
    }
    interval <- nrow(design_cells) > 1L || nrow(signal_support$support) > 1L ||
        any(vapply(c(
        list(diagnostics$feature_count, diagnostics$effective_signal_ratio),
        diagnostics$design[fields]
    ), function(value) length(value) == 2L, logical(1L)))
    result <- .new_k1_operating_location(
        if (interval) "located_region" else "located_point", "",
        sampling_design, diagnostics, design_assessment, signal_assessment,
        design_cells, signal_support$domain, signal_support$support
    )
    .validate_k1_operating_location(result)
    result
}

#' Plot a K=1 experiment against its calibrated operating domain
#'
#' @param location output from `locate_k1_operating_domain()`.
#' @return Publication-themed ggplot with exact displayed data and a separate
#'   dynamic scientific caption.
#' @export
plot_k1_operating_domain <- function(location) {
    .validate_k1_operating_location(location)
    cells <- location$signal_domain_cells
    if (!nrow(cells)) {
        display <- data.frame(
            effective_signal_ratio = numeric(),
            calibration_probability = numeric(),
            panel = character(),
            experiment_probability = numeric()
        )
    } else {
        display <- rbind(
            transform(cells, panel = "A  Target-axis recovery",
                calibration_probability = recovery_probability),
            transform(cells, panel = "B  Estimability after recovery",
                calibration_probability = downstream_estimability_probability)
        )
        display$experiment_probability <- NA_real_
    }
    ratio <- location$locator$signal_ratio
    domain_limits <- if (nrow(display)) {
        range(display$effective_signal_ratio)
    } else {
        range(c(0, ratio))
    }
    clipped_ratio <- pmin(pmax(ratio, domain_limits[[1L]]),
        domain_limits[[2L]])
    clipping <- ifelse(
        ratio < domain_limits[[1L]], "below",
        ifelse(ratio > domain_limits[[2L]], "above", "inside")
    )
    support <- location$signal_cells
    support_rows <- if (nrow(support)) rbind(
        transform(support, panel = "A  Target-axis recovery",
            probability = recovery_probability),
        transform(support, panel = "B  Estimability after recovery",
            probability = downstream_estimability_probability)
    ) else data.frame(
        effective_signal_ratio = numeric(),
        probability = numeric(), panel = character()
    )
    semantic <- landscapeR_palette("semantic")
    domain_rows <- if (nrow(display)) data.frame(
        panel = c("A  Target-axis recovery", "B  Estimability after recovery"),
        xmin = min(display$effective_signal_ratio),
        xmax = max(display$effective_signal_ratio)
    ) else data.frame(
        panel = character(), xmin = numeric(), xmax = numeric()
    )
    experiment_rows <- expand.grid(
        panel = c(
            "A  Target-axis recovery", "B  Estimability after recovery"
        ),
        boundary = seq_along(ratio),
        stringsAsFactors = FALSE
    )
    experiment_rows$actual_ratio <- ratio[experiment_rows$boundary]
    experiment_rows$plotted_ratio <- clipped_ratio[experiment_rows$boundary]
    experiment_rows$clipped <- clipping[experiment_rows$boundary]
    experiment_rows$boundary_marker <- c(
        below = "<", inside = "", above = ">"
    )[experiment_rows$clipped]
    plot <- ggplot2::ggplot(display, ggplot2::aes(
        x = .data$effective_signal_ratio,
        y = .data$calibration_probability
    )) +
        ggplot2::geom_rect(
            data = domain_rows,
            ggplot2::aes(
                xmin = xmin, xmax = xmax, ymin = -Inf, ymax = Inf
            ), inherit.aes = FALSE, fill = semantic[["structure"]],
            alpha = 0.08
        ) +
        ggplot2::geom_vline(
            data = experiment_rows,
            ggplot2::aes(xintercept = plotted_ratio),
            inherit.aes = FALSE, colour = semantic[["focal"]],
            linetype = "dashed", linewidth = 0.45
        ) +
        ggplot2::geom_text(
            data = experiment_rows[
                experiment_rows$clipped != "inside", , drop = FALSE
            ],
            ggplot2::aes(
                x = plotted_ratio, y = 0.5, label = boundary_marker
            ),
            inherit.aes = FALSE, colour = semantic[["focal"]],
            fontface = "bold", size = 5
        ) +
        ggplot2::geom_point(shape = 21, fill = semantic[["paper"]],
            colour = semantic[["ink"]], size = 2.1, stroke = 0.4) +
        ggplot2::geom_point(
            data = support_rows,
            ggplot2::aes(
                x = effective_signal_ratio,
                y = probability
            ),
            inherit.aes = FALSE, shape = 2,
            colour = semantic[["focal"]], size = 3, stroke = 0.8
        ) +
        ggplot2::facet_wrap(~ .data$panel, nrow = 1L) +
        ggplot2::scale_x_continuous(limits = domain_limits) +
        ggplot2::scale_y_continuous(limits = c(0, 1),
            breaks = c(0, 0.5, 1)) +
        ggplot2::labs(
            x = "Effective signal relative to the noise reference",
            y = "Calibration probability"
        ) +
        theme_landscapeR(square = FALSE)
    ratio_text <- paste(format(ratio, digits = 4), collapse = " to ")
    has_domain <- nrow(display) > 0L
    status_text <- if (identical(location$status, "out_of_domain") &&
            !has_domain) {
        paste(
            "The experiment is out of domain:", location$reason,
            "and no compatible calibration domain can be shown; the locator",
            "does not extrapolate a probability"
        )
    } else if (identical(location$status, "out_of_domain")) {
        paste(
            "The experiment ratio", ratio_text, "is out of domain:",
            location$reason,
            "and is marked at the nearest calibrated boundary; the locator",
            "does not extrapolate a probability"
        )
    } else if (identical(location$status, "located_region")) {
        paste("The red dashed boundaries show the experiment uncertainty",
            "region; red triangles summarize only its exact supporting cells")
    } else {
        paste("The red dashed line and triangles show the experiment point",
            "and summaries from its exact supporting calibration cells")
    }
    caption <- .new_scientific_caption_view(
        title = "Experiment location within calibrated K=1 operating evidence",
        experiment_label = "Declared real-experiment diagnostics",
        target_field = "K=1 target axis",
        sampling_unit = location$sampling_design$kind,
        panels = c(
            A = "Target-axis recovery probability in compatible calibration cells",
            B = "Downstream estimability probability after target-axis recovery"
        ),
        encodings = c(
            "Black circles are exact compatible calibration-cell summaries",
            if (has_domain) paste(
                "The pale grey band is the calibrated signal/noise domain;",
                "red dashed lines are the declared experiment point or interval"
            ) else paste(
                "No compatible calibration cells or domain band are available;",
                "the red dashed line shows only the declared diagnostic",
                "position on an uncalibrated axis"
            ),
            status_text
        ),
        design = sprintf(
            paste("%d exact design cells and %d of %d compatible signal",
                "cells support placement"),
            nrow(location$design_cells), nrow(location$signal_cells),
            nrow(location$signal_domain_cells)
        ),
        uncertainty = paste(
            "One diagnostic value is a point; two values define an interval",
            "whose supporting calibration cells are retained"
        ),
        threshold = if (has_domain) paste(
            "The calibrated-domain boundary is the observed feature, design,",
            "covariance, and effective signal/noise range; no interpolation",
            "creates new evidence"
        ) else paste(
            "A boundary cannot be defined without compatible calibration",
            "evidence; no interpolation or extrapolation creates new evidence"
        ),
        claim_boundary = paste(
            "This is an operating-characteristic locator, not a biological",
            "state-space projection or quasi-potential landscape"
        ),
        state = if (identical(location$status, "out_of_domain"))
            "abstention" else "calibrated"
    )
    plot <- .with_scientific_caption(plot, .build_scientific_caption(caption))
    attr(plot, "landscapeR_k1_operating_domain_data") <- list(
        calibration_points = display,
        support_points = support_rows,
        experiment_bounds = experiment_rows,
        domain_bands = domain_rows
    )
    attr(plot, "landscapeR_k1_operating_domain_design_cells") <-
        location$design_cells
    plot
}
