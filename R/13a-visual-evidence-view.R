# Typed visual-evidence view

.visual_evidence_surfaces <- c(
    "atlas",
    "proposal",
    "permutation",
    "abstention",
    "independent_time_course",
    "repeated_time_course",
    "aml_acceptance",
    "stage1",
    "stage2"
)

.visual_evidence_states <- c(
    "complete", "partial", "missing", "uncalibrated", "abstention"
)

.visual_evidence_view_errors <- function(
    surface,
    state,
    observations,
    summaries,
    diagnostics,
    display_data,
    caption_view
) {
    errors <- character()
    if (!is.character(surface) || length(surface) != 1L ||
        !surface %in% .visual_evidence_surfaces) {
        errors <- c(errors, "surface is not supported")
    }
    if (!is.character(state) || length(state) != 1L ||
        !state %in% .visual_evidence_states) {
        errors <- c(errors, "state is not supported")
    }
    tables <- list(
        observations = observations,
        summaries = summaries,
        diagnostics = diagnostics
    )
    malformed_tables <- !vapply(tables, is.data.frame, logical(1L))
    if (any(malformed_tables)) {
        errors <- c(
            errors,
            paste0(
                paste(names(tables)[malformed_tables], collapse = ", "),
                " must be data frames"
            )
        )
    }
    if (!is.list(display_data) ||
        (length(display_data) &&
            (is.null(names(display_data)) ||
                any(!nzchar(names(display_data))) ||
                anyDuplicated(names(display_data))))) {
        errors <- c(errors, "display_data must be a uniquely named list")
    }
    if (is.list(display_data) &&
        "provenance" %in% names(display_data)) {
        errors <- c(errors, "display_data must not expose provenance")
    }
    caption_error <- tryCatch(
        {
            .validate_scientific_caption_view(caption_view)
            NULL
        },
        error = function(condition) conditionMessage(condition)
    )
    if (!is.null(caption_error)) {
        errors <- c(
            errors,
            paste("caption_view is invalid:", caption_error)
        )
    } else if (!identical(state, caption_view$state)) {
        errors <- c(errors, "caption state must match visual evidence state")
    }
    errors
}

#' Validated evidence prepared for a scientific figure
#'
#' `VisualEvidenceView` separates scientific evidence construction from
#' presentation shaping. It contains only normalized observations, summaries,
#' diagnostics, display-ready data, structured state, and caption facts. It
#' never exposes private provenance or grants a renderer authority to recompute
#' a scientific result.
#'
#' @slot version visual-evidence schema version
#' @slot surface canonical decision-surface identifier
#' @slot state structured completeness or abstention state
#' @slot observations normalized observation table
#' @slot summaries stored estimand and uncertainty table
#' @slot diagnostics stored diagnostic table
#' @slot display_data named display-ready tables and scalar facts
#' @slot caption_view validated scientific-caption facts
#'
#' @export
setClass(
    "VisualEvidenceView",
    representation(
        version = "character",
        surface = "character",
        state = "character",
        observations = "data.frame",
        summaries = "data.frame",
        diagnostics = "data.frame",
        display_data = "list",
        caption_view = "ANY"
    ),
    prototype = prototype(
        version = "1.0.0",
        surface = character(),
        state = character(),
        observations = data.frame(),
        summaries = data.frame(),
        diagnostics = data.frame(),
        display_data = list(),
        caption_view = list()
    )
)

setValidity("VisualEvidenceView", function(object) {
    errors <- character()
    if (!identical(object@version, "1.0.0")) {
        errors <- c(errors, "version must be '1.0.0'")
    }
    errors <- c(
        errors,
        .visual_evidence_view_errors(
            surface = object@surface,
            state = object@state,
            observations = object@observations,
            summaries = object@summaries,
            diagnostics = object@diagnostics,
            display_data = object@display_data,
            caption_view = object@caption_view
        )
    )
    if (length(errors)) errors else TRUE
})

.new_visual_evidence_view <- function(
    surface,
    state,
    observations = data.frame(),
    summaries = data.frame(),
    diagnostics = data.frame(),
    display_data = list(),
    caption_view
) {
    errors <- .visual_evidence_view_errors(
        surface,
        state,
        observations,
        summaries,
        diagnostics,
        display_data,
        caption_view
    )
    if (length(errors)) {
        .stop_landscapeR_validation(paste(errors, collapse = "; "))
    }
    view <- new(
        "VisualEvidenceView",
        version = "1.0.0",
        surface = surface,
        state = state,
        observations = observations,
        summaries = summaries,
        diagnostics = diagnostics,
        display_data = display_data,
        caption_view = caption_view
    )
    validObject(view)
    view
}

.validate_visual_evidence_view <- function(view) {
    if (!is(view, "VisualEvidenceView")) {
        .stop_landscapeR_validation(
            "view must be a VisualEvidenceView"
        )
    }
    validObject(view)
    invisible(view)
}

#' Extract the typed visual evidence for a scientific result
#'
#' @param x a supported landscapeR scientific result or visual-evidence view
#' @return a `VisualEvidenceView`
#' @export
setGeneric(
    "visual_evidence",
    function(x) standardGeneric("visual_evidence")
)

#' @rdname visual_evidence
#' @export
setMethod("visual_evidence", "VisualEvidenceView", function(x) {
    .validate_visual_evidence_view(x)
    x
})

#' Identify a visual-evidence decision surface
#'
#' @param view a `VisualEvidenceView`
#' @return one surface identifier
#' @export
visual_evidence_surface <- function(view) {
    .validate_visual_evidence_view(view)
    view@surface
}

#' Extract structured visual-evidence state
#'
#' @param view a `VisualEvidenceView`
#' @return one state identifier
#' @export
visual_evidence_state <- function(view) {
    .validate_visual_evidence_view(view)
    view@state
}

#' Extract visual-evidence observations
#'
#' @param view a `VisualEvidenceView`
#' @return a data frame
#' @export
visual_evidence_observations <- function(view) {
    .validate_visual_evidence_view(view)
    view@observations
}

#' Extract visual-evidence summaries
#'
#' @param view a `VisualEvidenceView`
#' @return a data frame
#' @export
visual_evidence_summaries <- function(view) {
    .validate_visual_evidence_view(view)
    view@summaries
}

#' Extract visual-evidence diagnostics
#'
#' @param view a `VisualEvidenceView`
#' @return a data frame
#' @export
visual_evidence_diagnostics <- function(view) {
    .validate_visual_evidence_view(view)
    view@diagnostics
}

#' List recorded display-ready visual-evidence items
#'
#' @param view a `VisualEvidenceView`
#' @return character vector of recorded display-data names
#' @export
visual_evidence_display_names <- function(view) {
    .validate_visual_evidence_view(view)
    names(view@display_data)
}

#' Extract one named display-ready visual-evidence item
#'
#' @param view a `VisualEvidenceView`
#' @param name one recorded display-data name
#' @return the recorded display-ready value
#' @export
visual_evidence_display <- function(view, name) {
    .validate_visual_evidence_view(view)
    if (!is.character(name) || length(name) != 1L ||
        !name %in% names(view@display_data)) {
        .stop_landscapeR_validation(
            "requested visual display item is not recorded"
        )
    }
    view@display_data[[name]]
}

.visual_evidence_displays <- function(view) {
    item_names <- visual_evidence_display_names(view)
    stats::setNames(
        lapply(
            item_names,
            function(name) visual_evidence_display(view, name)
        ),
        item_names
    )
}

.replace_visual_evidence_caption <- function(
    view,
    caption_view,
    display_data = list()
) {
    .validate_visual_evidence_view(view)
    .new_visual_evidence_view(
        surface = visual_evidence_surface(view),
        state = caption_view$state,
        observations = visual_evidence_observations(view),
        summaries = visual_evidence_summaries(view),
        diagnostics = visual_evidence_diagnostics(view),
        display_data = c(.visual_evidence_displays(view), display_data),
        caption_view = caption_view
    )
}

.visual_evidence_surface_state <- function(view) {
    if (identical(visual_evidence_state(view), "partial")) {
        "partial"
    } else {
        "uncalibrated"
    }
}

#' Build the publication caption for visual evidence
#'
#' @param view a `VisualEvidenceView`
#' @return deterministic publication-caption text
#' @export
visual_evidence_caption <- function(view) {
    .validate_visual_evidence_view(view)
    .build_scientific_caption(view@caption_view)
}

.render_unavailable_visual_evidence <- function(view) {
    .validate_visual_evidence_view(view)
    if (!identical(visual_evidence_state(view), "missing")) {
        .stop_landscapeR_validation(
            "unavailable renderer requires missing visual evidence"
        )
    }
    reason <- visual_evidence_display(view, "unavailable_reason")
    title <- switch(
        visual_evidence_surface(view),
        stage1 = "Stage 1 display unavailable",
        stage2 = "Stage 2 display unavailable",
        "Scientific display unavailable"
    )
    label <- paste(strwrap(reason, width = 42L), collapse = "\n")
    plot <- ggplot2::ggplot() +
        ggplot2::annotate(
            "text", x = 0.5, y = 0.5, label = label,
            colour = .landscapeR_colour("ink"), size = 3.5,
            lineheight = 1.1
        ) +
        ggplot2::xlim(0, 1) +
        ggplot2::ylim(0, 1) +
        ggplot2::labs(title = title, x = NULL, y = NULL) +
        ggplot2::theme_void(base_size = 9) +
        ggplot2::theme(
            plot.title = ggplot2::element_text(
                colour = .landscapeR_colour("ink"),
                face = "plain",
                size = 11,
                hjust = 0
            ),
            plot.margin = ggplot2::margin(8, 8, 8, 8)
        )
    .with_scientific_caption(plot, visual_evidence_caption(view))
}
