# Object-specific visual-evidence adapters.
#
# These adapters normalize stored scientific evidence for rendering. They do
# not define a generalized renderer and do not grant alternative renderers any
# authority to alter scientific results.

.publication_panel_letters <- function(n) {
    if (length(n) != 1L || !is.numeric(n) || is.na(n) ||
        !is.finite(n) || n < 0L || n > .Machine$integer.max ||
        n != as.integer(n)) {
        .stop_landscapeR_validation(
            "panel count must be one non-negative integer"
        )
    }
    if (n == 0L) return(character())
    vapply(seq_len(as.integer(n)), function(index) {
        label <- ""
        while (index > 0L) {
            remainder <- (index - 1L) %% length(LETTERS)
            label <- paste0(LETTERS[[remainder + 1L]], label)
            index <- (index - 1L) %/% length(LETTERS)
        }
        label
    }, character(1L), USE.NAMES = FALSE)
}

.cross_sectional_panel_keys <- function(observations) {
    keys <- unique(observations[
        ,
        c("metadata_field", "component_label"),
        drop = FALSE
    ])
    keys$panel_letter <- .publication_panel_letters(nrow(keys))
    keys
}

.proposal_panel_terms <- function(observations) {
    components <- unique(observations$component_label)
    letters <- .publication_panel_letters(length(components))
    stats::setNames(
        sprintf(
            "The declared target observations are shown for component %s",
            components
        ),
        letters
    )
}

.atlas_panel_terms <- function(observations) {
    keys <- .cross_sectional_panel_keys(observations)
    stats::setNames(
        sprintf(
            "%s observations are shown against component %s",
            keys$metadata_field,
            keys$component_label
        ),
        keys$panel_letter
    )
}

.target_visual_evidence <- function(stored_visual_evidence, target_field) {
    lapply(stored_visual_evidence, function(value) {
        if (is.data.frame(value) && "metadata_field" %in% names(value)) {
            return(value[
                value$metadata_field == target_field,
                ,
                drop = FALSE
            ])
        }
        value
    })
}

.cross_sectional_visual_display <- function(
    observations,
    associations,
    stored_visual_evidence,
    ranking = NULL,
    recommended_component = NA_integer_,
    comparison_level = NA_character_,
    target_field = NA_character_,
    reference_level = NA_character_
) {
    available <- observations[observations$available, , drop = FALSE]
    categorical <- available[
        available$metadata_type == "categorical",
        ,
        drop = FALSE
    ]
    categorical$display_fill <- rep(
        .landscapeR_colour("paper"),
        nrow(categorical)
    )
    if (.is_scalar_nonempty_text(target_field) &&
        .is_scalar_nonempty_text(reference_level) &&
        .is_scalar_nonempty_text(comparison_level)) {
        target_row <- categorical$metadata_field == target_field
        categorical$display_fill[
            target_row & categorical$metadata_value == reference_level
        ] <- .landscapeR_colour("nuisance")
        categorical$display_fill[
            target_row & categorical$metadata_value == comparison_level
        ] <- .landscapeR_colour("focal")
    }
    numeric <- available[
        available$metadata_type %in% c("continuous", "ordered"),
        ,
        drop = FALSE
    ]
    diagnostic_keys <- unique(associations[
        associations$evidence_variant == "unadjusted" &
            associations$diagnostic == "possible-nonmonotone-association",
        c("metadata_field", "component_label"),
        drop = FALSE
    ])
    diagnostics <- unique(observations[
        ,
        c("metadata_field", "component_label"),
        drop = FALSE
    ])
    diagnostic_match <- paste(
        diagnostics$metadata_field,
        diagnostics$component_label,
        sep = "\r"
    ) %in% paste(
        diagnostic_keys$metadata_field,
        diagnostic_keys$component_label,
        sep = "\r"
    )
    diagnostics$diagnostic <- ifelse(
        diagnostic_match,
        "possible-nonmonotone-association",
        ""
    )
    diagnostics$display_label <- ifelse(
        diagnostic_match,
        "\u25b3 non-monotone",
        ""
    )
    max_atom_count <- if (nrow(available)) {
        max(available$atom_count)
    } else {
        1L
    }
    display <- list(
        categorical_observations = categorical,
        numeric_observations = numeric,
        monotone_fit = stored_visual_evidence$monotone_fit,
        flexible_fit = stored_visual_evidence$flexible_fit,
        diagnostic_labels = diagnostics,
        max_atom_count = max_atom_count,
        show_atom_guide = any(available$atom_count > 1L)
    )
    if (!is.null(ranking) && nrow(ranking)) {
        display$facet_labels <- stats::setNames(
            sprintf(
                "%s  |  rank %d  |  |effect| = %.2f",
                ranking$component_label,
                ranking$proposal_rank,
                ranking$effect_magnitude
            ),
            ranking$component_label
        )
        recommended <- available[
            available$component == recommended_component,
            ,
            drop = FALSE
        ]
        marker_range <- diff(range(recommended$score))
        if (!is.finite(marker_range) || marker_range == 0) marker_range <- 1
        display$categorical_marker <- if (nrow(categorical)) {
            data.frame(
                component_label = unique(recommended$component_label),
                metadata_value = if (.is_scalar_nonempty_text(
                    comparison_level
                )) {
                    comparison_level
                } else {
                    recommended$metadata_value[[1L]]
                },
                score = max(recommended$score) + 0.12 * marker_range,
                stringsAsFactors = FALSE
            )
        } else {
            data.frame(
                component_label = character(),
                metadata_value = character(),
                score = numeric()
            )
        }
        display$numeric_marker <- if (nrow(numeric)) {
            data.frame(
                component_label = unique(recommended$component_label),
                metadata_numeric = max(
                    recommended$metadata_numeric,
                    na.rm = TRUE
                ),
                score = max(recommended$score) + 0.12 * marker_range,
                stringsAsFactors = FALSE
            )
        } else {
            data.frame(
                component_label = character(),
                metadata_numeric = numeric(),
                score = numeric()
            )
        }
    }
    list(display = display, diagnostics = diagnostics)
}

.cross_sectional_encoding_caption <- function(
    display,
    target_field = NA_character_,
    reference_level = NA_character_,
    comparison_level = NA_character_
) {
    encodings <- character()
    if (nrow(display$categorical_observations)) {
        encodings <- c(
            encodings,
            paste(
                "Boxplots summarize categorical component scores;",
                "points show individual observations"
            )
        )
        if (.is_scalar_nonempty_text(target_field) &&
            .is_scalar_nonempty_text(reference_level) &&
            .is_scalar_nonempty_text(comparison_level)) {
            encodings <- c(
                encodings,
                sprintf(
                    paste(
                        "For the declared %s to %s contrast, grey identifies",
                        "%s (reference) and red identifies %s (comparison)"
                    ),
                    reference_level,
                    comparison_level,
                    reference_level,
                    comparison_level
                )
            )
        }
    }
    if (nrow(display$numeric_observations)) {
        fit_encodings <- character()
        if (nrow(display$monotone_fit)) {
            fit_encodings <- c(fit_encodings, "black monotone fits")
        }
        if (nrow(display$flexible_fit)) {
            fit_encodings <- c(fit_encodings, "grey flexible fits")
        }
        fit_text <- if (length(fit_encodings)) {
            paste(
                paste(fit_encodings, collapse = " and "),
                "show the stored descriptive trends"
            )
        } else {
            "No fitted trend is available"
        }
        encodings <- c(
            encodings,
            paste(
                "Points show numeric observations;",
                fit_text
            )
        )
    }
    if (!length(encodings)) {
        return("No available observations are rendered")
    }
    paste0(
        paste(encodings, collapse = ". "),
        ". Point size records coincident observations"
    )
}

#' @rdname visual_evidence
#' @export
setMethod("visual_evidence", "MetadataAssociationAtlas", function(x) {
    if (x@sampling_design@kind %in% c(
        "independent_time_course", "longitudinal"
    )) {
        return(.time_course_visual_evidence(x))
    }
    target_field <- x@provenance$target_field
    reference_level <- x@provenance$reference_level
    comparison_level <- x@provenance$comparison_level
    prepared <- .cross_sectional_visual_display(
        x@observations,
        x@associations,
        x@provenance$visual_evidence,
        target_field = target_field,
        reference_level = reference_level,
        comparison_level = comparison_level
    )
    oriented <- if (.is_scalar_nonempty_text(reference_level) &&
        .is_scalar_nonempty_text(comparison_level)) {
        c(reference_level, comparison_level)
    } else {
        character()
    }
    caption_view <- .new_scientific_caption_view(
        title = "Metadata association atlas",
        experiment_label = x@dataset_id,
        molecular_layer = x@provenance$layer,
        target_field = target_field,
        oriented_levels = oriented,
        sampling_unit = "independent biological observation",
        nuisance_fields = x@provenance$nuisance_fields,
        panels = .atlas_panel_terms(x@observations),
        encodings = .cross_sectional_encoding_caption(
            prepared$display,
            target_field,
            reference_level,
            comparison_level
        ),
        estimand = "prespecified component-metadata association",
        design = x@sampling_design@kind,
        uncertainty = paste(
            "Stored intervals and diagnostics remain descriptive.",
            .association_multiplicity_caption(x@provenance)
        ),
        threshold = "No acceptance threshold is applied",
        claim_boundary = paste(
            "The atlas is exploratory and does not nominate a biological",
            "coordinate"
        ),
        state = "uncalibrated"
    )
    .new_visual_evidence_view(
        surface = "atlas",
        state = "uncalibrated",
        observations = x@observations,
        summaries = x@associations,
        diagnostics = prepared$diagnostics,
        display_data = prepared$display,
        caption_view = caption_view
    )
})

#' @rdname visual_evidence
#' @export
setMethod("visual_evidence", "ComponentProposal", function(x) {
    if (x@provenance$sampling_design %in% c(
        "independent_time_course", "longitudinal"
    )) {
        return(.time_course_visual_evidence(x))
    }
    target_observations <- x@observations[
        x@observations$metadata_field == x@target_field,
        ,
        drop = FALSE
    ]
    prepared <- .cross_sectional_visual_display(
        target_observations,
        x@ranking,
        .target_visual_evidence(
            x@provenance$visual_evidence,
            x@target_field
        ),
        ranking = x@ranking,
        recommended_component = x@recommended_component,
        comparison_level = x@comparison_level,
        target_field = x@target_field,
        reference_level = x@reference_level
    )
    prepared$display$title <- sprintf(
        "Component proposal for %s",
        x@target_field
    )
    oriented <- if (
        .is_scalar_nonempty_text(x@reference_level) &&
            .is_scalar_nonempty_text(x@comparison_level)
    ) {
        c(x@reference_level, x@comparison_level)
    } else {
        character()
    }
    caption_view <- .new_scientific_caption_view(
        title = "Effect-first component proposal",
        experiment_label = x@provenance$dataset_id,
        molecular_layer = x@provenance$layer,
        target_field = x@target_field,
        oriented_levels = oriented,
        sampling_unit = "independent biological observation",
        nuisance_fields = x@provenance$nuisance_fields,
        panels = .proposal_panel_terms(target_observations),
        encodings = paste(
            "The red diamond marks the uniquely nominated component;",
            "black and white marks retain the complete ranked search"
        ),
        estimand = x@ranking$estimand[[1L]],
        design = x@provenance$sampling_design,
        uncertainty = paste(
            "Facet labels report stored effect rank and magnitude.",
            .association_multiplicity_caption(x@provenance)
        ),
        threshold = "No acceptance threshold is applied",
        claim_boundary = paste(
            "The proposal is exploratory and does not confirm biological",
            "validity"
        ),
        state = "uncalibrated"
    )
    .new_visual_evidence_view(
        surface = "proposal",
        state = "uncalibrated",
        observations = target_observations,
        summaries = x@ranking,
        diagnostics = prepared$diagnostics,
        display_data = prepared$display,
        caption_view = caption_view
    )
})

.time_course_visual_evidence <- function(x) {
    is_atlas <- is(x, "MetadataAssociationAtlas")
    is_proposal <- is(x, "ComponentProposal")
    is_abstention <- is(x, "ComponentAbstention")
    if (!is_atlas && !is_proposal && !is_abstention) {
        .stop_landscapeR_validation(
            "time-course visual evidence requires an atlas, proposal, or abstention"
        )
    }
    provenance <- x@provenance
    ranking <- if (is_proposal || is_abstention) x@ranking else NULL
    observations <- x@observations
    data <- merge(
        observations,
        provenance$time_course_observations,
        by = "primary_sample",
        all.x = TRUE,
        sort = FALSE
    )
    data <- data[data$available, , drop = FALSE]
    lines <- provenance$time_course_display_lines
    summaries <- provenance$time_course_effect_summary
    rank_summary <- provenance$time_course_rank_summary
    display_state <- provenance$time_course_display_state
    repeated <- identical(provenance$sampling_design, "longitudinal")
    surface <- if (repeated) {
        "repeated_time_course"
    } else {
        "independent_time_course"
    }
    has_trajectories <- display_state$has_trajectories
    interval_text <- ifelse(
        is.finite(summaries$effect_conf_low) &
            is.finite(summaries$effect_conf_high),
        sprintf(
            "%.2f [%.2f, %.2f]",
            summaries$estimate,
            summaries$effect_conf_low,
            summaries$effect_conf_high
        ),
        sprintf("%.2f [not estimated]", summaries$estimate)
    )
    names(interval_text) <- summaries$component_label
    if (repeated) {
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
    } else {
        rank_text <- stats::setNames(
            ifelse(
                is.finite(rank_summary$rank_one_fraction),
                sprintf(
                    "effect rank 1 in %.0f%% of resamples",
                    100 * rank_summary$rank_one_fraction
                ),
                "resampling not requested"
            ),
            rank_summary$component_label
        )
    }
    requested_searches <- display_state$requested_searches
    complete_searches <- display_state$complete_searches
    partial_resampling <- display_state$partial_resampling
    multiple_panels <- nrow(summaries) > 1L
    panel_letters <- .publication_panel_letters(nrow(summaries))
    panel_labels <- stats::setNames(
        if (multiple_panels) {
            paste(panel_letters, summaries$component_label)
        } else {
            summaries$component_label
        },
        summaries$component_label
    )
    independent_headings <- function(labels) {
        vapply(labels, function(label) {
            index <- match(label, summaries$component_label)
            estimate <- summaries$estimate[[index]]
            lower <- summaries$effect_conf_low[[index]]
            upper <- summaries$effect_conf_high[[index]]
            if (is.finite(estimate) && is.finite(lower) && is.finite(upper)) {
                sprintf(
                    "%s\ninteraction %.2f\n95%% CI %.2f to %.2f",
                    unname(panel_labels[[label]]),
                    estimate,
                    lower,
                    upper
                )
            } else {
                sprintf(
                    "%s\ninteraction not estimated",
                    unname(panel_labels[[label]])
                )
            }
        }, character(1L))
    }
    panel_terms <- if (is_proposal && !is.null(ranking) && nrow(ranking)) {
        proposal_rank_text <- vapply(
            summaries$component_label,
            function(label) {
                index <- match(label, ranking$component_label)
                if (is.na(index)) {
                    return("proposal rank not available")
                }
                sprintf(
                    "proposal rank %d; %s",
                    ranking$proposal_rank[[index]],
                    rank_text[[label]]
                )
            },
            character(1L)
        )
        stats::setNames(
            if (has_trajectories) {
                sprintf(
                    paste(
                        "Component %s shows individual observations and",
                        "stored population trajectories; the standardized",
                        "condition-by-time interaction is %s; %s"
                    ),
                    summaries$component_label,
                    interval_text[summaries$component_label],
                    proposal_rank_text
                )
            } else {
                sprintf(
                    paste(
                        "Component %s shows individual observations; no",
                        "population trajectory or interaction interval is",
                        "estimable; %s"
                    ),
                    summaries$component_label,
                    proposal_rank_text
                )
            },
            panel_letters
        )
    } else {
        stats::setNames(
            if (has_trajectories) {
                sprintf(
                    paste(
                        "Component %s shows individual observations and stored",
                        "population trajectories; the standardized condition-by-time",
                        "interaction is %s"
                    ),
                    summaries$component_label,
                    interval_text[summaries$component_label]
                )
            } else {
                sprintf(
                    paste(
                        "Component %s shows individual observations; no population",
                        "trajectory or interaction interval is estimable"
                    ),
                    summaries$component_label
                )
            },
            panel_letters
        )
    }
    facet_labels <- if (!has_trajectories) {
        panel_labels
    } else if (!is.null(ranking) && nrow(ranking)) {
        if (repeated) {
            stats::setNames(
                sprintf(
                    "%s\nrank %d | interaction %s\n%s",
                    panel_labels[ranking$component_label],
                    ranking$proposal_rank,
                    interval_text[ranking$component_label],
                    rank_text[ranking$component_label]
                ),
                ranking$component_label
            )
        } else {
            stats::setNames(
                sprintf(
                    "%s\nrank %d\n%s",
                    independent_headings(ranking$component_label),
                    ranking$proposal_rank,
                    rank_text[ranking$component_label]
                ),
                ranking$component_label
            )
        }
    } else {
        if (repeated) {
            stats::setNames(
                sprintf(
                    "%s\ninteraction %s",
                    panel_labels[summaries$component_label],
                    interval_text
                ),
                summaries$component_label
            )
        } else {
            stats::setNames(
                independent_headings(summaries$component_label),
                summaries$component_label
            )
        }
    }
    title <- if (is_abstention) {
        sprintf("No component nominated for %s", x@target_field)
    } else if (is_proposal) {
        sprintf(
            "Component ranking: %s across time",
            x@target_field
        )
    } else if (!has_trajectories) {
        if (repeated) {
            "Repeated-subject model not estimable"
        } else {
            "Observed destructive-time-course design"
        }
    } else if (repeated) {
        "Repeated-subject time-course evidence"
    } else {
        "Independent destructive-time-course evidence"
    }
    diagnostic_values <- unique(summaries$diagnostic)
    diagnostic_values <- diagnostic_values[nzchar(diagnostic_values)]
    subtitle <- if (is_abstention) {
        .public_abstention_message(x@reason, diagnostic_values)
    } else if (is_proposal) {
        "Ranked by the prespecified condition-by-time interaction"
    } else if (!has_trajectories) {
        if (repeated) {
            .public_abstention_message(
                "non-identifiable-design",
                diagnostic_values
            )
        } else {
            paste(
                "Condition-by-time interaction is not estimable from",
                "this sampling grid"
            )
        }
    } else if (repeated) {
        "Individual trajectories and population-level linear divergence"
    } else {
        "Observed time is fixed; trajectories are exploratory linear fits"
    }
    display <- list(
        trajectories = lines,
        facet_labels = facet_labels,
        reference_level = provenance$reference_level,
        comparison_level = provenance$comparison_level,
        time_field = provenance$time_field,
        title = title,
        subtitle = subtitle,
        has_trajectories = has_trajectories
    )
    missingness <- NA_character_
    if (repeated) {
        endpoint_keys <- provenance$time_course_dropout_endpoints
        display$dropout_points <- data[
            paste(data$primary_sample, data$subject, sep = "\r") %in%
                paste(
                    endpoint_keys$primary_sample,
                    endpoint_keys$subject,
                    sep = "\r"
                ),
            ,
            drop = FALSE
        ]
        dropout_count <- provenance$time_course_dropout_subject_count
        if (dropout_count > 0L) {
            missingness <- sprintf(
                "%d subject endpoints are marked as ending before the final observed study time",
                dropout_count
            )
        }
    } else {
        cells <- provenance$time_course_cells
        score_range <- range(data$score)
        score_span <- diff(score_range)
        if (!is.finite(score_span) || score_span == 0) score_span <- 1
        offsets <- stats::setNames(
            c(-0.08, -0.18) * score_span,
            c(provenance$reference_level, provenance$comparison_level)
        )
        cells$label_y <- score_range[[1L]] + offsets[cells$condition]
        cells$label <- ifelse(
            cells$count == 0L,
            "",
            paste0("n=", cells$count)
        )
        display$cells <- cells
        missing_keys <- provenance$time_course_missing_cells
        display$missing_cells <- cells[
            paste(cells$condition, cells$observed_time, sep = "\r") %in%
                paste(
                    missing_keys$condition,
                    missing_keys$observed_time,
                    sep = "\r"
                ),
            ,
            drop = FALSE
        ]
        missing_cell_count <- provenance$time_course_missing_cell_count
        if (missing_cell_count > 0L) {
            missingness <- sprintf(
                "%d unobserved condition-by-time cells are marked with crosses",
                missing_cell_count
            )
        }
    }
    state <- if (is_abstention) {
        "abstention"
    } else if (!has_trajectories) {
        "missing"
    } else if (partial_resampling) {
        "partial"
    } else {
        "uncalibrated"
    }
    resampling_account <- if (!has_trajectories) {
        paste(
            "No interaction interval or resampling recurrence is available.",
            .association_multiplicity_caption(provenance)
        )
    } else if (!repeated) {
        paste(
            "Facet labels report stored interaction estimates and 95%",
            "intervals; resampling recurrence remains in the evidence.",
            .association_multiplicity_caption(provenance)
        )
    } else {
        paste(
            "Facet labels report stored interaction intervals and",
            "resampling recurrence.",
            .association_multiplicity_caption(provenance)
        )
    }
    if (partial_resampling) {
        resampling_account <- paste0(
            resampling_account,
            sprintf(
                "; %d of %d requested complete-search resamples succeeded; %d were incomplete",
                complete_searches,
                requested_searches,
                requested_searches - complete_searches
            )
        )
    }
    missingness_notes <- c(
        missingness,
        if (identical(state, "missing")) {
            "The declared condition-by-time interaction is not estimable"
        } else {
            NA_character_
        },
        if (identical(state, "partial")) {
            paste(
                "Incomplete resamples remain in the requested denominator;",
                "available trajectories and intervals are retained"
            )
        } else {
            NA_character_
        }
    )
    missingness_notes <- missingness_notes[
        !is.na(missingness_notes) & nzchar(missingness_notes)
    ]
    missingness_account <- if (length(missingness_notes)) {
        paste(missingness_notes, collapse = ". ")
    } else {
        NA_character_
    }
    oriented <- c(
        provenance$reference_level,
        provenance$comparison_level
    )
    caption_view <- .new_scientific_caption_view(
        title = title,
        experiment_label = if (
            .is_scalar_nonempty_text(provenance$dataset_label)
        ) provenance$dataset_label else provenance$dataset_id,
        molecular_layer = if (
            .is_scalar_nonempty_text(provenance$layer_label)
        ) provenance$layer_label else provenance$layer,
        target_field = provenance$target_field,
        oriented_levels = oriented,
        sampling_unit = if (repeated) {
            "complete subject trajectory"
        } else {
            "independent biological observation"
        },
        time_field = provenance$time_field,
        subject_field = if (repeated) provenance$subject_field else NA_character_,
        nuisance_fields = provenance$nuisance_fields,
        panels = if (multiple_panels) panel_terms else character(),
        encodings = if (repeated) {
            c(
                "Thin lines connect repeated observations from each subject.",
                if (has_trajectories) paste(
                    "Bold lines show stored population trajectories from the",
                    "rank-scale model with subject-specific random intercepts",
                    "and time slopes."
                ),
                if (nrow(display$dropout_points)) {
                    "Black crosses mark recorded early endpoints."
                }
            )
        } else {
            c(
                "Points show independent biological observations.",
                "labels give biological sample counts per design cell.",
                if (nrow(display$missing_cells)) {
                    "crosses mark unobserved condition-by-time cells."
                },
                if (has_trajectories) {
                    "lines show stored population trajectories."
                }
            )
        },
        estimand = "condition-by-time interaction on the rank scale",
        design = provenance$sampling_design,
        uncertainty = resampling_account,
        missingness = missingness_account,
        threshold = "No acceptance threshold is applied",
        claim_boundary = if (is_abstention || !has_trajectories) {
            "No unique biological coordinate is identified"
        } else {
            paste(
                "Trajectory evidence is exploratory and does not establish",
                "biological validity"
            )
        },
        state = state
    )
    .new_visual_evidence_view(
        surface = surface,
        state = state,
        observations = data,
        summaries = summaries,
        diagnostics = data.frame(
            diagnostic = diagnostic_values,
            stringsAsFactors = FALSE
        ),
        display_data = display,
        caption_view = caption_view
    )
}

.render_time_course_visual_evidence <- function(view) {
    data <- visual_evidence_observations(view)
    lines <- visual_evidence_display(view, "trajectories")
    reference <- visual_evidence_display(view, "reference_level")
    comparison <- visual_evidence_display(view, "comparison_level")
    repeated <- identical(
        visual_evidence_surface(view),
        "repeated_time_course"
    )
    plot <- ggplot2::ggplot(
        data,
        ggplot2::aes(
            x = .data[["scaled_time"]],
            y = .data[["score"]],
            group = if (repeated) .data[["subject"]] else NULL
        )
    )
    if (repeated) {
        plot <- plot +
            ggplot2::geom_line(
                ggplot2::aes(colour = .data[["condition"]]),
                linewidth = 0.35,
                alpha = 0.32
            ) +
            ggplot2::geom_point(
                data = visual_evidence_display(view, "dropout_points"),
                ggplot2::aes(
                    x = .data[["scaled_time"]],
                    y = .data[["score"]]
                ),
                shape = 4,
                size = 2.7,
                stroke = 0.8,
                colour = .landscapeR_colour("ink"),
                inherit.aes = FALSE
            )
    }
    plot <- plot +
        ggplot2::geom_line(
            data = lines,
            ggplot2::aes(
                x = .data[["scaled_time"]],
                y = .data[["fitted_score"]],
                colour = .data[["condition"]],
                group = .data[["condition"]]
            ),
            linewidth = if (repeated) 1 else 0.75,
            inherit.aes = FALSE
        ) +
        ggplot2::geom_point(
            ggplot2::aes(
                shape = .data[["condition"]],
                fill = .data[["condition"]]
            ),
            size = if (repeated) 1.7 else 2.2,
            stroke = 0.5,
            colour = .landscapeR_colour("ink")
        )
    if (!repeated) {
        cells <- visual_evidence_display(view, "cells")
        plot <- plot +
            ggplot2::geom_text(
                data = cells,
                ggplot2::aes(
                    x = .data[["scaled_time"]],
                    y = .data[["label_y"]],
                    label = .data[["label"]],
                    colour = .data[["condition"]]
                ),
                size = 2.7,
                show.legend = FALSE,
                inherit.aes = FALSE
            ) +
            ggplot2::geom_point(
                data = visual_evidence_display(view, "missing_cells"),
                ggplot2::aes(
                    x = .data[["scaled_time"]],
                    y = .data[["label_y"]]
                ),
                shape = 4,
                size = 3,
                stroke = 0.8,
                colour = .landscapeR_colour("ink"),
                inherit.aes = FALSE
            )
    }
    plot <- plot +
        scale_colour_landscapeR(
            "binary",
            reference_level = reference,
            focal_level = comparison
        ) +
        scale_fill_landscapeR(
            "binary",
            reference_level = reference,
            focal_level = comparison,
            values = stats::setNames(
                c(
                    .landscapeR_colour("paper"),
                    .landscapeR_colour("focal")
                ),
                c(reference, comparison)
            )
        ) +
        ggplot2::scale_shape_manual(values = stats::setNames(
            c(21, 24), c(reference, comparison)
        )) +
        ggplot2::facet_wrap(
            ggplot2::vars(component_label),
            labeller = ggplot2::labeller(
                component_label = visual_evidence_display(
                    view, "facet_labels"
                )
            )
        ) +
        ggplot2::labs(
            title = visual_evidence_display(view, "title"),
            subtitle = paste(
                strwrap(
                    visual_evidence_display(view, "subtitle"),
                    width = 72L
                ),
                collapse = "\n"
            ),
            x = sprintf(
                "Observed time, scaled 0\u20131 (%s)",
                visual_evidence_display(view, "time_field")
            ),
            y = "Standardized oriented component score",
            colour = "Condition",
            fill = "Condition",
            shape = "Condition"
        ) +
        theme_landscapeR()
    if (!repeated) {
        # Independent destructive-time-course strips use short, explicit
        # estimate/CI lines and a slightly smaller strip type at the default
        # 100 mm device so the complete heading remains inside each facet.
        plot <- plot +
            ggplot2::coord_cartesian(
                xlim = c(-0.08, 1.08),
                clip = "off"
            ) +
            ggplot2::theme(
                strip.text = ggplot2::element_text(
                    size = 6,
                    lineheight = 0.9,
                    margin = ggplot2::margin(t = 1.5, b = 1.5)
                )
            )
    }
    .with_scientific_caption(plot, visual_evidence_caption(view))
}

#' @rdname visual_evidence
#' @export
setMethod("visual_evidence", "PermutationEvidence", function(x) {
    state <- switch(
        x@status,
        complete = "complete",
        partial = "partial",
        "missing"
    )
    observations <- data.frame(
        replicate = seq_along(x@null_max_effect),
        max_effect = as.numeric(x@null_max_effect),
        available = is.finite(x@null_max_effect),
        stringsAsFactors = FALSE
    )
    summaries <- data.frame(
        observed_max_effect = x@observed_max_effect,
        search_aware_p_value = x@search_aware_p_value,
        n_requested = x@n_requested,
        n_completed = x@n_completed,
        n_failed = x@n_requested - x@n_completed,
        stringsAsFactors = FALSE
    )
    diagnostics <- data.frame(
        status = x@status,
        diagnostic = x@diagnostic,
        stringsAsFactors = FALSE
    )
    uncertainty <- if (x@n_requested > 0L) {
        completion <- sprintf(
            "%d of %d requested null refits completed; %d failed",
            x@n_completed,
            x@n_requested,
            x@n_requested - x@n_completed
        )
        if (is.finite(x@search_aware_p_value)) {
            paste0(
                completion,
                sprintf(
                    "; the search-aware p-value is %.3g",
                    x@search_aware_p_value
                )
            )
        } else {
            completion
        }
    } else {
        "No permutation refits were requested"
    }
    missingness <- if (identical(state, "partial")) {
        sprintf(
            "%d failed null refits remain in the requested denominator",
            x@n_requested - x@n_completed
        )
    } else if (identical(state, "missing")) {
        "No search-aware permutation distribution is available"
    } else {
        NA_character_
    }
    caption_view <- .new_scientific_caption_view(
        title = "Search-aware permutation evidence",
        encodings = if (state %in% c("complete", "partial")) {
            paste(
                "The histogram shows the stored null distribution of the",
                "maximum absolute target effect across the eligible search;",
                "the red vertical line marks the stored observed maximum"
            )
        } else {
            "Red text identifies the recorded non-estimable outcome"
        },
        estimand = "maximum absolute target effect",
        design = x@method,
        uncertainty = uncertainty,
        missingness = missingness,
        threshold = "No acceptance threshold is applied",
        claim_boundary = if (identical(state, "missing")) {
            "No search-aware p-value is reported"
        } else {
            "Permutation evidence does not alter the prespecified point ranking"
        },
        state = state
    )
    .new_visual_evidence_view(
        surface = "permutation",
        state = state,
        observations = observations,
        summaries = summaries,
        diagnostics = diagnostics,
        display_data = list(
            null_distribution = observations[
                observations$available,
                ,
                drop = FALSE
            ],
            observed_line = summaries[
                is.finite(summaries$observed_max_effect),
                ,
                drop = FALSE
            ]
        ),
        caption_view = caption_view
    )
})

#' @rdname visual_evidence
#' @export
setMethod("visual_evidence", "AssociationAbstention", function(x) {
    diagnostics <- data.frame(
        reason = x@reason,
        diagnostic = x@diagnostic,
        stringsAsFactors = FALSE
    )
    public_reason <- if (identical(
        x@reason,
        "inappropriate-target-type"
    )) {
        "Declared target type does not match the observed metadata"
    } else {
        "Declared adjustment is not identifiable"
    }
    caption_view <- .new_scientific_caption_view(
        title = sprintf(
            "Association not estimated for %s",
            x@target_field
        ),
        target_field = x@target_field,
        encodings = paste(
            "The title identifies the declared target; a grey tag marks abstention;",
            "the subtitle gives the public reason; black text gives the recorded",
            "diagnostic"
        ),
        design = x@sampling_design@kind,
        missingness = x@diagnostic,
        threshold = paste(
            "No acceptance threshold applies because no association",
            "estimand is available"
        ),
        claim_boundary = paste(
            "No target type or association is substituted and no biological",
            "association is reported"
        ),
        state = "abstention"
    )
    .new_visual_evidence_view(
        surface = "abstention",
        state = "abstention",
        diagnostics = diagnostics,
        display_data = list(
            annotation = x@diagnostic,
            title = sprintf(
                "Association not estimated for %s",
                x@target_field
            ),
            subtitle = public_reason
        ),
        caption_view = caption_view
    )
})

#' @rdname visual_evidence
#' @export
setMethod("visual_evidence", "ComponentAbstention", function(x) {
    if (x@provenance$sampling_design %in% c(
        "independent_time_course", "longitudinal"
    )) {
        return(.time_course_visual_evidence(x))
    }
    finite <- x@ranking[
        is.finite(x@ranking$effect_magnitude),
        ,
        drop = FALSE
    ]
    diagnostics <- data.frame(
        reason = x@reason,
        diagnostic = unique(x@ranking$diagnostic),
        stringsAsFactors = FALSE
    )
    caption_view <- .new_scientific_caption_view(
        title = sprintf("No component nominated for %s", x@target_field),
        experiment_label = x@provenance$dataset_id,
        molecular_layer = x@provenance$layer,
        target_field = x@target_field,
        nuisance_fields = x@provenance$nuisance_fields,
        encodings = if (nrow(finite)) {
            paste(
                "Grey bars retain finite effects from the complete eligible",
                "search; no bar is highlighted as a nominated coordinate"
            )
        } else {
            "Text reports that no adjusted effect is estimable"
        },
        estimand = if (nrow(x@ranking)) {
            x@ranking$estimand[[1L]]
        } else {
            NA_character_
        },
        design = x@provenance$sampling_design,
        missingness = if (!nrow(finite)) {
            "No estimable adjusted effect is available"
        } else {
            NA_character_
        },
        threshold = "No acceptance threshold is applied",
        claim_boundary = paste(
            "No component is eligible for nomination and no runner-up is",
            "promoted"
        ),
        state = "abstention"
    )
    .new_visual_evidence_view(
        surface = "abstention",
        state = "abstention",
        observations = x@observations,
        summaries = x@ranking,
        diagnostics = diagnostics,
        display_data = list(
            finite_ranking = finite,
            title = sprintf(
                "No component nominated for %s",
                x@target_field
            ),
            subtitle = .public_abstention_message(
                x@reason,
                diagnostics$diagnostic
            ),
            empty_annotation = "No estimable adjusted effect"
        ),
        caption_view = caption_view
    )
})
