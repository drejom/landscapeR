# Stored typed evidence for legacy Stage 1 and Stage 2 scientific plots

.stage_plot_evidence_stages <- c("stage1", "stage2")

.stage_plot_source_digest <- function(std, stage) {
    scientific_result <- switch(
        stage,
        stage1 = stage_result(std, "stage1", required = FALSE),
        stage2 = list(
            stage1 = stage_result(std, "stage1", required = FALSE),
            stage2 = stage_result(std, "stage2", required = FALSE)
        )
    )
    digest::digest(
        list(
            stage = stage,
            experiments = experiments(std),
            colData = colData(std),
            sampleMap = sampleMap(std),
            ground_truth = std@ground_truth,
            scientific_result = scientific_result
        ),
        algo = "sha256"
    )
}

.plot_evidence_frame_errors <- function(
    value, label, required_columns, numeric_columns = character()
) {
    errors <- character()
    if (!is.data.frame(value)) {
        return(sprintf("%s must be a data frame", label))
    }
    missing <- setdiff(required_columns, names(value))
    if (length(missing)) {
        errors <- c(errors, sprintf(
            "%s is missing columns: %s",
            label,
            paste(missing, collapse = ", ")
        ))
    }
    present_numeric <- intersect(numeric_columns, names(value))
    invalid_numeric <- present_numeric[!vapply(
        value[present_numeric],
        function(column) is.numeric(column) && all(is.finite(column)),
        logical(1L)
    )]
    if (length(invalid_numeric)) {
        errors <- c(errors, sprintf(
            "%s has invalid numeric columns: %s",
            label,
            paste(invalid_numeric, collapse = ", ")
        ))
    }
    errors
}

.is_positive_whole <- function(value) {
    is.numeric(value) && all(is.finite(value)) &&
        all(value >= 1L) && all(value == as.integer(value))
}

.stage_plot_display_errors <- function(stage, displays) {
    errors <- character()
    if (!is.list(displays) || is.null(names(displays))) return(errors)
    if (identical(stage, "stage1")) {
        allowed <- c(
            "spectrum", "component_densities",
            "component_group_densities",
            "component_group_density_status",
            "decomposition"
        )
        if (!"spectrum" %in% names(displays) ||
            any(!names(displays) %in% allowed)) {
            errors <- c(errors, "Stage 1 displays have invalid names")
        }
        spectrum <- displays$spectrum
        if (!is.list(spectrum) ||
            !all(c("values", "bbp", "n", "p") %in% names(spectrum))) {
            errors <- c(errors, "Stage 1 spectrum schema is invalid")
        } else {
            values <- spectrum$values
            errors <- c(errors, .plot_evidence_frame_errors(
                values,
                "Stage 1 spectrum values",
                c("layer", "rank", "sv"),
                c("rank", "sv")
            ))
            values_schema_ok <- is.data.frame(values) && nrow(values) > 0L &&
                all(c("layer", "rank", "sv") %in% names(values))
            spectrum_layers <- if (values_schema_ok) {
                unique(as.character(values$layer))
            } else {
                character()
            }
            ranks_are_sequential <- if (values_schema_ok) {
                all(vapply(
                    split(values$rank, values$layer),
                    function(rank) {
                        identical(as.integer(rank), seq_len(length(rank)))
                    },
                    logical(1L)
                ))
            } else {
                FALSE
            }
            if (!values_schema_ok ||
                !is.character(values$layer) || anyNA(values$layer) ||
                any(!nzchar(values$layer)) ||
                !.is_positive_whole(values$rank) ||
                any(values$sv < 0) ||
                !ranks_are_sequential) {
                errors <- c(errors, "Stage 1 spectrum domains are invalid")
            }
            if (!is.numeric(spectrum$bbp) || length(spectrum$bbp) != 1L ||
                !is.finite(spectrum$bbp) || spectrum$bbp < 0 ||
                any(!vapply(
                    spectrum[c("n", "p")],
                    function(value) {
                        is.numeric(value) && length(value) == 1L &&
                            is.finite(value) && value > 0
                    },
                    logical(1L)
                ))) {
                errors <- c(errors, "Stage 1 spectrum scalars are invalid")
            }
        }
        has_stage1 <- "decomposition" %in% names(displays)
        required_stage1 <- c(
            "component_densities",
            "component_group_densities",
            "component_group_density_status",
            "decomposition"
        )
        if (has_stage1 && !all(required_stage1 %in% names(displays))) {
            errors <- c(errors, "Stage 1 component displays are incomplete")
        }
        if ("component_densities" %in% names(displays)) {
            if (!is.list(displays$component_densities) ||
                !length(displays$component_densities) ||
                is.null(names(displays$component_densities))) {
                errors <- c(errors, "Stage 1 component densities are invalid")
            } else {
                if (exists("spectrum_layers", inherits = FALSE) &&
                    any(!names(displays$component_densities) %in%
                        spectrum_layers)) {
                    errors <- c(
                        errors,
                        "Stage 1 component-density layers do not match spectrum"
                    )
                }
                for (layer in names(displays$component_densities)) {
                    errors <- c(errors, .plot_evidence_frame_errors(
                        displays$component_densities[[layer]],
                        paste("Stage 1 component densities", layer),
                        c(
                            "coord", "density", "component",
                            "metadata_field", "metadata_value"
                        ),
                        c("coord", "density")
                    ))
                    density_frame <- displays$component_densities[[layer]]
                    if ("density_available" %in% names(density_frame) &&
                        (!is.logical(density_frame$density_available) ||
                            anyNA(density_frame$density_available))) {
                        errors <- c(
                            errors,
                            paste(
                                "Stage 1 component density availability is",
                                "invalid for", layer
                            )
                        )
                    }
                }
            }
        }
        if ("component_group_densities" %in% names(displays)) {
            grouped <- displays$component_group_densities
            if (!is.list(grouped) || !length(grouped) ||
                is.null(names(grouped))) {
                errors <- c(errors, "Stage 1 grouped densities are invalid")
            } else {
                if ("component_densities" %in% names(displays) &&
                    is.list(displays$component_densities) &&
                    !setequal(
                        names(grouped),
                        names(displays$component_densities)
                    )) {
                    errors <- c(
                        errors,
                        "Stage 1 grouped-density layers do not match components"
                    )
                }
                for (layer in names(grouped)) {
                    if (!is.list(grouped[[layer]]) ||
                        (length(grouped[[layer]]) &&
                            is.null(names(grouped[[layer]])))) {
                        errors <- c(
                            errors,
                            paste("Stage 1 grouped densities", layer, "are invalid")
                        )
                        next
                    }
                    for (field in names(grouped[[layer]])) {
                        errors <- c(errors, .plot_evidence_frame_errors(
                            grouped[[layer]][[field]],
                            paste(
                                "Stage 1 grouped densities",
                                layer,
                                field
                            ),
                            c(
                                "coord", "density", "component",
                                "metadata_field", "metadata_value"
                            ),
                            c("coord", "density")
                        ))
                        density_frame <- grouped[[layer]][[field]]
                        if ("density_available" %in% names(density_frame) &&
                            (!is.logical(density_frame$density_available) ||
                                anyNA(density_frame$density_available))) {
                            errors <- c(
                                errors,
                                paste(
                                    "Stage 1 grouped-density availability",
                                    "is invalid", layer, field
                                )
                            )
                        }
                    }
                }
            }
        }
        if ("component_group_density_status" %in% names(displays)) {
            status <- displays$component_group_density_status
            if (!is.list(status) || !length(status) ||
                is.null(names(status))) {
                errors <- c(
                    errors,
                    "Stage 1 grouped-density status is invalid"
                )
            } else {
                if ("component_densities" %in% names(displays) &&
                    is.list(displays$component_densities) &&
                    !setequal(
                        names(status),
                        names(displays$component_densities)
                    )) {
                    errors <- c(
                        errors,
                        "Stage 1 grouped-density status layers do not match"
                    )
                }
                for (layer in names(status)) {
                    if (!is.list(status[[layer]]) ||
                        (length(status[[layer]]) &&
                            is.null(names(status[[layer]])))) {
                        errors <- c(
                            errors,
                            paste(
                                "Stage 1 grouped-density status is invalid",
                                layer
                            )
                        )
                        next
                    }
                    for (field in names(status[[layer]])) {
                        value <- status[[layer]][[field]]
                        errors <- c(errors, .plot_evidence_frame_errors(
                            value,
                            paste(
                                "Stage 1 grouped-density status",
                                layer,
                                field
                            ),
                            c(
                                "metadata_value", "n_observations",
                                "density_available"
                            ),
                            "n_observations"
                        ))
                        if (is.data.frame(value) && nrow(value) &&
                            (!is.character(value$metadata_value) ||
                                anyNA(value$metadata_value) ||
                                !.is_positive_whole(value$n_observations) ||
                                !is.logical(value$density_available) ||
                                anyNA(value$density_available) ||
                                any(value$density_available !=
                                    (value$n_observations >= 2L)))) {
                            errors <- c(
                                errors,
                                paste(
                                    "Stage 1 grouped-density status domains",
                                    "are invalid",
                                    layer,
                                    field
                                )
                            )
                        }
                    }
                }
            }
        }
        if (has_stage1) {
            decomposition <- displays$decomposition
            if (!is.list(decomposition) ||
                !all(c("coordinates", "truth_angles") %in%
                    names(decomposition))) {
                errors <- c(errors, "Stage 1 decomposition schema is invalid")
            } else {
                errors <- c(
                    errors,
                    .plot_evidence_frame_errors(
                        decomposition$coordinates,
                        "Stage 1 decomposition coordinates",
                        c(
                            "sample", "layer", "component",
                            "coord", "sample_ord"
                        ),
                        c("sample", "component", "coord", "sample_ord")
                    ),
                    .plot_evidence_frame_errors(
                        decomposition$truth_angles,
                        "Stage 1 truth angles",
                        c("component", "angle_degrees"),
                        c("component", "angle_degrees")
                    )
                )
                coordinates <- decomposition$coordinates
                truth_angles <- decomposition$truth_angles
                component_domain <- if (is.data.frame(coordinates) &&
                    "component" %in% names(coordinates) &&
                    length(coordinates$component)) {
                    sort(unique(as.integer(coordinates$component)))
                } else {
                    integer()
                }
                coordinate_layers <- if (is.data.frame(coordinates) &&
                    "layer" %in% names(coordinates)) {
                    unique(as.character(coordinates$layer))
                } else {
                    character()
                }
                if (!is.data.frame(coordinates) || !nrow(coordinates) ||
                    ("component_densities" %in% names(displays) &&
                        is.list(displays$component_densities) &&
                        !setequal(
                            coordinate_layers,
                            names(displays$component_densities)
                        )) ||
                        !.is_positive_whole(coordinates$sample) ||
                        !.is_positive_whole(coordinates$component) ||
                        !.is_positive_whole(coordinates$sample_ord)) {
                    errors <- c(
                        errors,
                        "Stage 1 decomposition-coordinate domains are invalid"
                    )
                }
                coordinate_components <- split(
                    coordinates$component,
                    coordinates$layer
                )
                coordinate_components <- lapply(
                    coordinate_components,
                    function(value) sort(unique(as.integer(value)))
                )
                contiguous_components <- length(coordinate_components) &&
                    all(vapply(
                        coordinate_components,
                        function(value) {
                            length(value) &&
                                identical(value, seq_len(max(value)))
                        },
                        logical(1L)
                    ))
                pooled_components <- if (
                    "component_densities" %in% names(displays) &&
                    is.list(displays$component_densities)
                ) {
                    lapply(displays$component_densities, function(value) {
                        sort(unique(as.integer(sub("^PC", "", value$component))))
                    })
                } else {
                    list()
                }
                pooled_matches <- setequal(
                    names(pooled_components),
                    names(coordinate_components)
                ) && all(vapply(
                    names(pooled_components),
                    function(layer) {
                        identical(
                            pooled_components[[layer]],
                            coordinate_components[[layer]]
                        )
                    },
                    logical(1L)
                ))
                grouped_matches <- TRUE
                if ("component_group_densities" %in% names(displays) &&
                    is.list(displays$component_group_densities)) {
                    for (layer_name in
                        names(displays$component_group_densities)) {
                        layer <-
                            displays$component_group_densities[[layer_name]]
                        for (value in layer) {
                            if (nrow(value) &&
                                !identical(
                                    sort(unique(as.integer(
                                        sub("^PC", "", value$component)
                                    ))),
                                    coordinate_components[[layer_name]]
                                )) {
                                grouped_matches <- FALSE
                            }
                        }
                    }
                }
                truth_matches <- !nrow(truth_angles) ||
                    all(truth_angles$component %in% component_domain)
                if (!contiguous_components || !pooled_matches ||
                    !grouped_matches || !truth_matches) {
                    errors <- c(
                        errors,
                        "Stage 1 component domains do not agree"
                    )
                }
                if (is.data.frame(truth_angles) &&
                    (!.is_positive_whole(truth_angles$component) ||
                        any(truth_angles$angle_degrees < 0) ||
                        any(truth_angles$angle_degrees > 90))) {
                    errors <- c(
                        errors,
                        "Stage 1 truth-angle domains are invalid"
                    )
                }
            }
        }
    } else if (identical(stage, "stage2")) {
        required <- c(
            "curve", "critical_points", "barrier_segments",
            "rug", "layers", "component"
        )
        if (!setequal(names(displays), required)) {
            errors <- c(errors, "Stage 2 displays have invalid names")
        }
        frame_specs <- list(
            curve = list(c("x", "U"), c("x", "U")),
            critical_points = list(c("x", "U", "type"), c("x", "U")),
            barrier_segments = list(
                c("x", "xend", "y", "yend"),
                c("x", "xend", "y", "yend")
            ),
            rug = list(c("x", "layer"), "x")
        )
        for (name in intersect(names(frame_specs), names(displays))) {
            errors <- c(errors, .plot_evidence_frame_errors(
                displays[[name]],
                paste("Stage 2", name),
                frame_specs[[name]][[1L]],
                frame_specs[[name]][[2L]]
            ))
        }
        if ("layers" %in% names(displays) &&
            (!length(displays$layers) ||
                !.is_positive_whole(displays$layers))) {
            errors <- c(errors, "Stage 2 layers are invalid")
        }
        if ("component" %in% names(displays) &&
            (length(displays$component) != 1L ||
                !.is_positive_whole(displays$component))) {
            errors <- c(errors, "Stage 2 component is invalid")
        }
        if ("critical_points" %in% names(displays) &&
            is.data.frame(displays$critical_points) &&
            any(!displays$critical_points$type %in% c("well", "barrier"))) {
            errors <- c(errors, "Stage 2 critical-point types are invalid")
        }
        if (all(c("rug", "layers") %in% names(displays)) &&
            is.data.frame(displays$rug) &&
            ("layer" %in% names(displays$rug)) &&
            (!.is_positive_whole(displays$rug$layer) ||
                any(!displays$rug$layer %in% displays$layers))) {
            errors <- c(errors, "Stage 2 rug layers are invalid")
        }
    }
    errors
}

.stage_plot_evidence_errors <- function(
    stage, source_digest, displays, evidence_digest
) {
    errors <- character()
    if (!is.character(stage) || length(stage) != 1L ||
        !stage %in% .stage_plot_evidence_stages) {
        errors <- c(errors, "stage is not supported")
    }
    if (!.is_sha256_digest(source_digest)) {
        errors <- c(errors, "source_digest must be a SHA-256 digest")
    }
    if (!is.list(displays) || is.null(names(displays)) ||
        any(!nzchar(names(displays))) || anyDuplicated(names(displays))) {
        errors <- c(errors, "displays must be a uniquely named list")
    }
    errors <- c(errors, .stage_plot_display_errors(stage, displays))
    expected_digest <- digest::digest(
        list(stage = stage, source_digest = source_digest, displays = displays),
        algo = "sha256"
    )
    if (!identical(evidence_digest, expected_digest)) {
        errors <- c(errors, "evidence_digest does not match stored evidence")
    }
    errors
}

#' Stored evidence for Stage 1 and Stage 2 scientific plots
#'
#' This internal scientific result binds display-ready curves and summaries to
#' the exact `StateTransitionData` inputs from which they were calculated.
#' Renderers validate and consume it but cannot modify or recompute it.
#'
#' @slot version evidence schema version
#' @slot stage `stage1` or `stage2`
#' @slot source_digest digest of the relevant scientific inputs
#' @slot displays uniquely named display-ready evidence
#' @slot evidence_digest digest binding the complete evidence payload
setClass(
    "StagePlotEvidence",
    representation(
        version = "character",
        stage = "character",
        source_digest = "character",
        displays = "list",
        evidence_digest = "character"
    ),
    prototype = prototype(
        version = "1.0.0",
        stage = character(),
        source_digest = character(),
        displays = list(),
        evidence_digest = character()
    )
)

setValidity("StagePlotEvidence", function(object) {
    errors <- character()
    if (!identical(object@version, "1.0.0")) {
        errors <- c(errors, "version must be '1.0.0'")
    }
    errors <- c(
        errors,
        .stage_plot_evidence_errors(
            object@stage,
            object@source_digest,
            object@displays,
            object@evidence_digest
        )
    )
    if (length(errors)) errors else TRUE
})

.new_stage_plot_evidence <- function(stage, source_digest, displays) {
    evidence_digest <- digest::digest(
        list(stage = stage, source_digest = source_digest, displays = displays),
        algo = "sha256"
    )
    evidence <- new(
        "StagePlotEvidence",
        version = "1.0.0",
        stage = stage,
        source_digest = source_digest,
        displays = displays,
        evidence_digest = evidence_digest
    )
    validObject(evidence)
    evidence
}

.stage_visual_caption_view <- function(stage, state, reason = NA_character_) {
    label <- if (identical(stage, "stage1")) "Stage 1" else "Stage 2"
    .new_scientific_caption_view(
        title = paste(label, "scientific display"),
        experiment_label = NA_character_,
        sampling_unit = "biological observation",
        panels = character(),
        encodings = character(),
        missingness = if (identical(state, "missing")) {
            reason
        } else if (identical(state, "partial")) {
            "One or more stored display slices are unavailable"
        } else {
            NA_character_
        },
        uncertainty = if (identical(state, "partial")) {
            "Available slices are shown; unavailable slices are retained explicitly"
        } else {
            NA_character_
        },
        claim_boundary = if (identical(state, "missing")) {
            paste(
                label,
                "cannot be interpreted from this display; the underlying scientific result remains available"
            )
        } else {
            paste(label, "display is descriptive and does not expand the scientific claim")
        },
        state = state
    )
}

.stage_plot_display_state <- function(evidence) {
    if (identical(evidence@stage, "stage1")) {
        availability <- unlist(lapply(
            evidence@displays$component_group_density_status %||% list(),
            function(layer) unlist(lapply(
                layer,
                function(status) status$density_available
            ), use.names = FALSE)
        ), use.names = FALSE)
        if (length(availability) && any(!availability)) return("partial")
    }
    if (identical(evidence@stage, "stage2") &&
        !nrow(evidence@displays$rug)) {
        return("partial")
    }
    "complete"
}

#' @rdname visual_evidence
#' @export
setMethod("visual_evidence", "StagePlotEvidence", function(x) {
    validity <- tryCatch(
        {
            validObject(x)
            NULL
        },
        error = function(condition) conditionMessage(condition)
    )
    if (!is.null(validity)) {
        stage <- if (length(x@stage) == 1L &&
            x@stage %in% .stage_plot_evidence_stages) {
            x@stage
        } else {
            "stage1"
        }
        return(.stage_unavailable_visual_evidence(
            stage,
            "This scientific display is unavailable because its stored values could not be validated",
            diagnostic = paste("stored plot evidence is invalid:", validity)
        ))
    }
    state <- .stage_plot_display_state(x)
    display_data <- c(
        x@displays,
        list(
            source_digest = x@source_digest,
            evidence_digest = x@evidence_digest
        )
    )
    .new_visual_evidence_view(
        surface = x@stage,
        state = state,
        display_data = display_data,
        caption_view = .stage_visual_caption_view(x@stage, state)
    )
})

.stage_unavailable_visual_evidence <- function(
    stage,
    reason,
    diagnostic = reason
) {
    .new_visual_evidence_view(
        surface = stage,
        state = "missing",
        diagnostics = data.frame(
            status = "unavailable",
            diagnostic = diagnostic,
            stringsAsFactors = FALSE
        ),
        display_data = list(unavailable_reason = reason),
        caption_view = .stage_visual_caption_view(stage, "missing", reason)
    )
}

.stage_visual_evidence <- function(
    std,
    stage,
    colour_by = NULL,
    caller = "stage visual evidence adapter"
) {
    if (!is(std, "StateTransitionData")) {
        .stop_landscapeR_validation(
            "stage visual evidence requires a StateTransitionData object"
        )
    }
    stage <- match.arg(stage, .stage_plot_evidence_stages)
    evidence <- metadata(std)[[paste0(stage, "_plot_evidence")]]
    if (!is(evidence, "StagePlotEvidence")) {
        failure <- metadata(std)[[paste0(stage, "_plot_evidence_failure")]]
        reason <- if (is.list(failure) &&
            .is_scalar_nonempty_text(failure$reason)) {
            failure$reason
        } else {
            sprintf(
                "No %s display is available for this scientific result",
                if (identical(stage, "stage1")) "Stage 1" else "Stage 2"
            )
        }
        public_reason <- if (is.list(failure) &&
            .is_scalar_nonempty_text(failure$reason)) {
            sprintf(
                "A %s display could not be prepared for this scientific result",
                if (identical(stage, "stage1")) "Stage 1" else "Stage 2"
            )
        } else {
            reason
        }
        return(.stage_unavailable_visual_evidence(
            stage,
            public_reason,
            diagnostic = reason
        ))
    }
    validity <- tryCatch(
        {
            validObject(evidence)
            NULL
        },
        error = function(condition) conditionMessage(condition)
    )
    if (!is.null(validity)) {
        return(.stage_unavailable_visual_evidence(
            stage,
            "This scientific display is unavailable because its stored values could not be validated",
            diagnostic = paste("stored plot evidence is invalid:", validity)
        ))
    }
    if (!identical(
        evidence@source_digest,
        .stage_plot_source_digest(std, stage)
    )) {
        return(.stage_unavailable_visual_evidence(
            stage,
            "This display is out of date for the current scientific result"
        ))
    }
    view <- visual_evidence(evidence)
    expt_list <- as.list(experiments(std))
    aligned_metadata <- if (is.null(colour_by)) {
        stats::setNames(vector("list", length(expt_list)), names(expt_list))
    } else {
        stats::setNames(
            lapply(seq_along(expt_list), function(layer) {
                .aligned_component_metadata(
                    std,
                    layer,
                    colour_by,
                    caller = caller,
                    field_label = "colour_by"
                )
            }),
            names(expt_list)
        )
    }
    display_data <- c(
        .visual_evidence_displays(view),
        list(
            caption_context = .plot_caption_context(std),
            caption_contexts = stats::setNames(
                lapply(
                    seq_along(expt_list),
                    function(layer) .plot_caption_context(std, layer)
                ),
                names(expt_list)
            ),
            aligned_metadata = aligned_metadata,
            experiment_names = names(expt_list),
            experiment_count = length(expt_list),
            experiment_observations = stats::setNames(
                vapply(expt_list, ncol, integer(1L)),
                names(expt_list)
            )
        )
    )
    .new_visual_evidence_view(
        surface = visual_evidence_surface(view),
        state = visual_evidence_state(view),
        observations = visual_evidence_observations(view),
        summaries = visual_evidence_summaries(view),
        diagnostics = visual_evidence_diagnostics(view),
        display_data = display_data,
        caption_view = .stage_visual_caption_view(
            stage,
            visual_evidence_state(view)
        )
    )
}

.try_store_stage_plot_evidence <- function(std, stage, spectra = NULL) {
    tryCatch(
        switch(
            stage,
            stage1 = .store_stage1_plot_evidence(std, spectra = spectra),
            stage2 = .store_stage2_plot_evidence(std)
        ),
        error = function(condition) {
            md <- metadata(std)
            md[[paste0(stage, "_plot_evidence")]] <- NULL
            md[[paste0(stage, "_plot_evidence_failure")]] <- list(
                status = "unavailable",
                reason = paste(
                    "Automatic visual evidence preparation failed:",
                    conditionMessage(condition)
                )
            )
            metadata(std) <- md
            std
        }
    )
}

.stop_plot_evidence_unavailable <- function(message) {
    condition <- structure(
        list(message = message, call = sys.call(-1L)),
        class = c(
            "landscapeR_plot_evidence_unavailable",
            "landscapeR_validation_error",
            "error",
            "condition"
        )
    )
    stop(condition)
}

.stage_plot_evidence <- function(std, stage) {
    evidence <- metadata(std)[[paste0(stage, "_plot_evidence")]]
    if (!is(evidence, "StagePlotEvidence")) {
        .stop_plot_evidence_unavailable(sprintf(
            paste0(
                "%s plot evidence is unavailable; run ",
                "prepare_plot_evidence(std, stage = \"%s\")"
            ),
            if (identical(stage, "stage1")) "Stage 1" else "Stage 2",
            stage
        ))
    }
    validObject(evidence)
    current_digest <- .stage_plot_source_digest(std, stage)
    if (!identical(evidence@source_digest, current_digest)) {
        .stop_plot_evidence_unavailable(sprintf(
            paste0(
                "%s plot evidence is stale for the current scientific object; ",
                "run prepare_plot_evidence(std, stage = \"%s\")"
            ),
            if (identical(stage, "stage1")) "Stage 1" else "Stage 2",
            stage
        ))
    }
    evidence
}

.density_rows <- function(values, component, metadata_field = NA_character_,
                          metadata_value = NA_character_) {
    finite_values <- values[is.finite(values)]
    magnitude <- if (length(finite_values)) {
        max(1, abs(finite_values))
    } else {
        1
    }
    density_available <- length(finite_values) >= 2L &&
        diff(range(finite_values)) > sqrt(.Machine$double.eps) * magnitude
    if (!density_available) {
        return(data.frame(
            coord = if (length(finite_values)) mean(finite_values) else 0,
            density = 0,
            component = component,
            metadata_field = metadata_field,
            metadata_value = metadata_value,
            density_available = FALSE,
            stringsAsFactors = FALSE
        ))
    }
    estimate <- stats::density(finite_values)
    data.frame(
        coord = estimate$x,
        density = estimate$y,
        component = component,
        metadata_field = metadata_field,
        metadata_value = metadata_value,
        density_available = TRUE,
        stringsAsFactors = FALSE
    )
}

.stage1_component_density_evidence <- function(std, stage1) {
    coords <- dr_coords_k(stage1)
    layer_names <- names(as.list(experiments(std)))[seq_along(coords)]
    result <- vector("list", length(coords))
    for (layer in seq_along(coords)) {
        cmat <- coords[[layer]]
        layer_rows <- lapply(seq_len(ncol(cmat)), function(component) {
            .density_rows(
                cmat[, component],
                sprintf("PC%d", component)
            )
        })
        result[[layer]] <- do.call(rbind, layer_rows)
    }
    names(result) <- layer_names
    result
}

.stage1_grouped_density_evidence <- function(std, stage1) {
    coords <- dr_coords_k(stage1)
    layer_names <- names(as.list(experiments(std)))[seq_along(coords)]
    fields <- names(as.data.frame(colData(std)))
    result <- vector("list", length(coords))
    status <- vector("list", length(coords))
    for (layer in seq_along(coords)) {
        cmat <- coords[[layer]]
        field_rows <- list()
        field_status <- list()
        for (field in fields) {
            values <- .component_gallery_metadata(
                std, layer, field, caller = "prepare_plot_evidence"
            )
            if (is.numeric(values)) next
            groups <- split(seq_along(values), values, drop = TRUE)
            group_names <- names(groups)
            if (is.null(group_names)) group_names <- character()
            field_status[[field]] <- data.frame(
                metadata_value = group_names,
                n_observations = as.integer(lengths(groups)),
                density_available = lengths(groups) >= 2L,
                stringsAsFactors = FALSE
            )
            component_rows <- list()
            for (component in seq_len(ncol(cmat))) {
                for (group in names(groups)) {
                    indices <- groups[[group]]
                    if (length(indices) < 2L) next
                    component_rows[[length(component_rows) + 1L]] <-
                        .density_rows(
                            cmat[indices, component],
                            sprintf("PC%d", component),
                            metadata_field = field,
                            metadata_value = group
                        )
                }
            }
            field_rows[[field]] <- if (length(component_rows)) {
                do.call(rbind, component_rows)
            } else {
                .density_rows(
                    cmat[, 1L],
                    "PC1",
                    metadata_field = field,
                    metadata_value = NA_character_
                )[FALSE, , drop = FALSE]
            }
        }
        result[[layer]] <- field_rows
        status[[layer]] <- field_status
    }
    names(result) <- layer_names
    names(status) <- layer_names
    list(densities = result, status = status)
}

.stage1_decomposition_evidence <- function(std, stage1) {
    coords <- dr_coords_k(stage1)
    layer_names <- names(as.list(experiments(std)))[seq_along(coords)]
    coordinate_rows <- lapply(seq_along(coords), function(layer) {
        cmat <- coords[[layer]]
        do.call(rbind, lapply(seq_len(ncol(cmat)), function(component) {
            values <- cmat[, component]
            data.frame(
                sample = seq_along(values),
                layer = layer_names[[layer]],
                component = component,
                coord = values,
                sample_ord = rank(values, ties.method = "first"),
                stringsAsFactors = FALSE
            )
        }))
    })
    angles <- data.frame(component = integer(), angle_degrees = numeric())
    if (!is.null(std@ground_truth) &&
        is(std@ground_truth, "SubspaceGroundTruth")) {
        n_components <- min(
            ncol(std@ground_truth@shared),
            ncol(dr_V_k(stage1))
        )
        if (n_components) {
            angle_values <- vapply(seq_len(n_components), function(component) {
                truth <- std@ground_truth@shared[, component]
                estimate <- shared_axis(stage1, j = component)
                cosine <- min(
                    1,
                    abs(sum(truth * estimate) /
                        (sqrt(sum(truth^2)) * sqrt(sum(estimate^2))))
                )
                acos(cosine) * 180 / pi
            }, numeric(1L))
            angles <- data.frame(
                component = seq_len(n_components),
                angle_degrees = angle_values
            )
        }
    }
    list(coordinates = do.call(rbind, coordinate_rows), truth_angles = angles)
}

.stage1_spectrum_evidence <- function(std, spectra = NULL) {
    layers <- as.list(experiments(std))
    if (is.null(spectra)) {
        # Preserve the legacy raw-assay spectrum as a descriptive estimand
        # distinct from any centred/pre-reduced strategy spectrum.
        spectra <- lapply(layers, function(layer) {
            svd(t(assay(layer)), nu = 0L, nv = 0L)$d
        })
    } else {
        spectra <- lapply(spectra, function(value) {
            if (is.list(value) && !is.null(value$d)) value$d else value
        })
    }
    rows <- lapply(seq_along(spectra), function(layer) {
        data.frame(
            layer = names(layers)[[layer]],
            rank = seq_along(spectra[[layer]]),
            sv = as.numeric(spectra[[layer]]),
            stringsAsFactors = FALSE
        )
    })
    n <- ncol(layers[[1L]])
    p <- nrow(layers[[1L]])
    list(
        values = do.call(rbind, rows),
        bbp = .bbp_threshold(n, p),
        n = n,
        p = p
    )
}

.store_stage1_plot_evidence <- function(std, spectra = NULL) {
    stage1 <- stage_result(std, "stage1", required = FALSE)
    displays <- list(
        spectrum = .stage1_spectrum_evidence(std, spectra)
    )
    if (!is.null(stage1)) {
        displays$component_densities <-
            .stage1_component_density_evidence(std, stage1)
        grouped <- .stage1_grouped_density_evidence(std, stage1)
        displays$component_group_densities <- grouped$densities
        displays$component_group_density_status <- grouped$status
        displays$decomposition <-
            .stage1_decomposition_evidence(std, stage1)
    }
    evidence <- .new_stage_plot_evidence(
        "stage1",
        .stage_plot_source_digest(std, "stage1"),
        displays
    )
    md <- metadata(std)
    md$stage1_plot_evidence <- evidence
    metadata(std) <- md
    std
}

.stage2_plot_displays <- function(std) {
    stage2 <- stage_result(std, "stage2", required = FALSE)
    if (is.null(stage2)) {
        .stop_plot_evidence_unavailable(
            "Stage 2 has not been run; Stage 2 plot evidence cannot be prepared"
        )
    }
    curve <- data.frame(x = stage2$x, U = stage2$U)
    critical_rows <- list()
    if (length(stage2$wells)) {
        critical_rows[[length(critical_rows) + 1L]] <- data.frame(
            x = stage2$wells,
            U = approx(stage2$x, stage2$U, stage2$wells)$y,
            type = "well",
            stringsAsFactors = FALSE
        )
    }
    if (length(stage2$barriers)) {
        critical_rows[[length(critical_rows) + 1L]] <- data.frame(
            x = stage2$barriers,
            U = approx(stage2$x, stage2$U, stage2$barriers)$y,
            type = "barrier",
            stringsAsFactors = FALSE
        )
    }
    critical_points <- if (length(critical_rows)) {
        do.call(rbind, critical_rows)
    } else {
        data.frame(
            x = numeric(), U = numeric(), type = character(),
            stringsAsFactors = FALSE
        )
    }
    segment_rows <- list()
    for (barrier in stage2$barriers) {
        barrier_u <- approx(stage2$x, stage2$U, barrier)$y
        left <- stage2$wells[stage2$wells < barrier]
        right <- stage2$wells[stage2$wells > barrier]
        if (length(left)) {
            well <- max(left)
            segment_rows[[length(segment_rows) + 1L]] <- data.frame(
                x = well, xend = well,
                y = approx(stage2$x, stage2$U, well)$y,
                yend = barrier_u
            )
        }
        if (length(right)) {
            well <- min(right)
            segment_rows[[length(segment_rows) + 1L]] <- data.frame(
                x = well, xend = well,
                y = approx(stage2$x, stage2$U, well)$y,
                yend = barrier_u
            )
        }
    }
    segments <- if (length(segment_rows)) {
        do.call(rbind, segment_rows)
    } else {
        data.frame(
            x = numeric(), xend = numeric(),
            y = numeric(), yend = numeric()
        )
    }
    stage1 <- stage_result(std, "stage1", required = FALSE)
    rug <- data.frame(
        layer = integer(),
        x = numeric(),
        stringsAsFactors = FALSE
    )
    component <- stage2$params$component %||% 1L
    coordinate_matrices <- if (!is.null(stage1) &&
        length(dr_coords_k(stage1))) {
        dr_coords_k(stage1)
    } else if (!is.null(stage1) && component == 1L &&
        length(dr_coords(stage1))) {
        lapply(dr_coords(stage1), matrix, ncol = 1L)
    } else {
        list()
    }
    layers <- integer()
    if (length(coordinate_matrices)) {
        layers <- if (isTRUE(stage2$params$pool_layers)) {
            seq_along(coordinate_matrices)
        } else {
            stage2$params$layer %||% 1L
        }
        rug <- do.call(rbind, lapply(layers, function(layer) {
            values <- coordinate_matrices[[layer]][, component]
            data.frame(
                layer = layer,
                x = values,
                stringsAsFactors = FALSE
            )
        }))
    }
    list(
        curve = curve,
        critical_points = critical_points,
        barrier_segments = segments,
        rug = rug,
        layers = layers,
        component = component
    )
}

.store_stage2_plot_evidence <- function(std) {
    evidence <- .new_stage_plot_evidence(
        "stage2",
        .stage_plot_source_digest(std, "stage2"),
        .stage2_plot_displays(std)
    )
    md <- metadata(std)
    md$stage2_plot_evidence <- evidence
    metadata(std) <- md
    std
}

#' Prepare provenance-bound evidence for Stage 1 or Stage 2 plots
#'
#' This is the explicit migration path for legacy or manually modified
#' `StateTransitionData` objects. Newly produced Stage 1 and Stage 2 results
#' store this evidence automatically.
#'
#' @param std a `StateTransitionData` object
#' @param stage `stage1` or `stage2`
#' @return `std` with typed plot evidence and a provenance record
#' @export
prepare_plot_evidence <- function(
    std,
    stage = c("stage1", "stage2")
) {
    if (!is(std, "StateTransitionData")) {
        .stop_landscapeR_validation(
            "prepare_plot_evidence(): std must be a StateTransitionData object"
        )
    }
    stage <- match.arg(stage)
    input_digest <- .stage_plot_source_digest(std, stage)
    std <- switch(
        stage,
        stage1 = .store_stage1_plot_evidence(std),
        stage2 = .store_stage2_plot_evidence(std)
    )
    record_provenance(
        std,
        stage = paste0(stage, "_plot_evidence"),
        contract = "StagePlotEvidence",
        implementation = "stored_typed_evidence",
        params = list(stage = stage),
        input_hashes = c(scientific_input = input_digest)
    )
}
