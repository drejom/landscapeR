# Shared scientific-caption contract

.scientific_caption_text <- function(x, field, required = FALSE) {
    if (is.null(x) || (length(x) == 1L && is.na(x))) {
        if (required) {
            .stop_landscapeR_validation(
                paste0(field, " must be one non-empty string")
            )
        }
        return(NA_character_)
    }
    if (!is.character(x) || length(x) != 1L || !grepl("\\S", x)) {
        .stop_landscapeR_validation(
            paste0(field, " must be one non-empty string or NA")
        )
    }
    x
}

.scientific_caption_terms <- function(x, field, deduplicate = TRUE) {
    if (is.null(x)) return(character())
    if (!is.character(x) || anyNA(x) || any(!grepl("\\S", x))) {
        .stop_landscapeR_validation(
            paste0(field, " must contain only non-empty strings")
        )
    }
    if (isTRUE(deduplicate)) x[!duplicated(x)] else x
}

.new_scientific_caption_view <- function(
    title,
    experiment_label = NA_character_,
    molecular_layer = NA_character_,
    molecular_layer_count = NA_integer_,
    target_field = NA_character_,
    oriented_levels = character(),
    direction = NA_character_,
    sampling_unit = NA_character_,
    time_field = NA_character_,
    time_unit = NA_character_,
    subject_field = NA_character_,
    nuisance_fields = character(),
    panels = character(),
    encodings = character(),
    estimand = NA_character_,
    design = NA_character_,
    uncertainty = NA_character_,
    missingness = NA_character_,
    threshold = NA_character_,
    claim_boundary,
    state = c(
        "complete", "partial", "missing", "calibrated",
        "uncalibrated", "abstention"
    ),
    .validate = TRUE
) {
    state <- match.arg(state)
    panels <- .scientific_caption_terms(
        panels, "panels", deduplicate = FALSE
    )
    if (length(panels) &&
        (is.null(names(panels)) ||
            any(!grepl("^[A-Z]+$", names(panels))) ||
            anyDuplicated(names(panels)))) {
        .stop_landscapeR_validation(
            "panels must have unique uppercase alphabetic names"
        )
    }
    view <- list(
        title = .scientific_caption_text(title, "title", required = TRUE),
        experiment_label = .scientific_caption_text(
            experiment_label, "experiment_label"
        ),
        molecular_layer = .scientific_caption_text(
            molecular_layer, "molecular_layer"
        ),
        molecular_layer_count = if (
            length(molecular_layer_count) == 1L &&
                is.numeric(molecular_layer_count) &&
                (is.na(molecular_layer_count) ||
                    (is.finite(molecular_layer_count) &&
                        molecular_layer_count == as.integer(molecular_layer_count) &&
                        molecular_layer_count > 0L))
        ) {
            as.integer(molecular_layer_count)
        } else {
            .stop_landscapeR_validation(
                "molecular_layer_count must be one positive integer or NA"
            )
        },
        target_field = .scientific_caption_text(
            target_field, "target_field"
        ),
        oriented_levels = .scientific_caption_terms(
            oriented_levels, "oriented_levels"
        ),
        direction = .scientific_caption_text(direction, "direction"),
        sampling_unit = .scientific_caption_text(
            sampling_unit, "sampling_unit"
        ),
        time_field = .scientific_caption_text(time_field, "time_field"),
        time_unit = .scientific_caption_text(time_unit, "time_unit"),
        subject_field = .scientific_caption_text(
            subject_field, "subject_field"
        ),
        nuisance_fields = .scientific_caption_terms(
            nuisance_fields, "nuisance_fields"
        ),
        panels = panels,
        encodings = .scientific_caption_terms(encodings, "encodings"),
        estimand = .scientific_caption_text(estimand, "estimand"),
        design = .scientific_caption_text(design, "design"),
        uncertainty = .scientific_caption_text(
            uncertainty, "uncertainty"
        ),
        missingness = .scientific_caption_text(
            missingness, "missingness"
        ),
        threshold = .scientific_caption_text(threshold, "threshold"),
        claim_boundary = .scientific_caption_text(
            claim_boundary, "claim_boundary", required = TRUE
        ),
        state = state
    )
    class(view) <- c("landscapeR_scientific_caption_view", "list")
    if (isTRUE(.validate)) .validate_scientific_caption_view(view)
    view
}

.validate_scientific_caption_view <- function(view) {
    if (!inherits(view, "landscapeR_scientific_caption_view") ||
        !is.list(view)) {
        .stop_landscapeR_validation(
            "view must be a landscapeR scientific caption view"
        )
    }
    expected <- setdiff(
        names(formals(.new_scientific_caption_view)),
        c(".validate")
    )
    if (!identical(names(view), expected)) {
        .stop_landscapeR_validation(
            "scientific caption view fields are invalid"
        )
    }
    rebuilt <- do.call(
        .new_scientific_caption_view,
        c(unclass(view), list(.validate = FALSE))
    )
    if (!identical(unclass(view), unclass(rebuilt))) {
        .stop_landscapeR_validation(
            "scientific caption view contains non-canonical values"
        )
    }
    if (length(view$oriented_levels) != 0L &&
        length(view$oriented_levels) != 2L) {
        .stop_landscapeR_validation(
            "oriented_levels must be empty or contain exactly two levels"
        )
    }
    if (!is.na(view$time_unit) && is.na(view$time_field)) {
        .stop_landscapeR_validation(
            "time_unit requires a declared time_field"
        )
    }
    if (!is.na(view$molecular_layer_count) &&
        is.na(view$molecular_layer)) {
        .stop_landscapeR_validation(
            "molecular_layer_count requires molecular_layer"
        )
    }
    if (!is.na(view$direction) && is.na(view$target_field)) {
        .stop_landscapeR_validation(
            "direction requires a declared target_field"
        )
    }
    required_by_state <- switch(
        view$state,
        partial = c("uncertainty", "missingness"),
        missing = "missingness",
        calibrated = "threshold",
        uncalibrated = "threshold",
        abstention = "claim_boundary",
        character()
    )
    absent <- required_by_state[vapply(
        view[required_by_state],
        function(value) length(value) != 1L || is.na(value) || !nzchar(value),
        logical(1L)
    )]
    if (length(absent)) {
        .stop_landscapeR_validation(paste0(
            view$state, " caption state requires stored ",
            paste(absent, collapse = " and ")
        ))
    }
    invisible(TRUE)
}

.scientific_caption_context <- function(view) {
    context <- character()
    if (!is.na(view$experiment_label)) {
        context <- paste0("The ", view$experiment_label, " experiment")
        if (!is.na(view$molecular_layer)) {
            context <- if (
                !is.na(view$molecular_layer_count) &&
                    view$molecular_layer_count > 1L
            ) {
                paste0(
                    context, " uses molecular layers ",
                    view$molecular_layer
                )
            } else {
                paste0(
                    context, " uses the ", view$molecular_layer, " layer"
                )
            }
        }
    } else if (!is.na(view$molecular_layer)) {
        context <- if (
            !is.na(view$molecular_layer_count) &&
                view$molecular_layer_count > 1L
        ) {
            paste0("Molecular layers ", view$molecular_layer)
        } else {
            paste0("The ", view$molecular_layer, " layer")
        }
    }
    if (!is.na(view$target_field)) {
        target <- paste0("the declared ", view$target_field, " target")
        if (length(view$oriented_levels) == 2L) {
            target <- paste0(
                target, " contrasts ", view$oriented_levels[[2L]],
                " with ", view$oriented_levels[[1L]]
            )
        }
        if (!is.na(view$direction)) {
            target <- paste0(target, " in the ", view$direction, " direction")
        }
        context <- if (length(context)) {
            paste(context, "to assess", target)
        } else {
            paste0("The analysis assesses ", target)
        }
    }
    if (!length(context)) return(character())
    paste0(context, ".")
}

.build_scientific_caption <- function(view) {
    .validate_scientific_caption_view(view)
    sentences <- c(
        paste0(sub("[.]$", "", view$title), "."),
        .scientific_caption_context(view)
    )
    if (length(view$panels)) {
        sentences <- c(sentences, paste(
            paste0(
                "(", names(view$panels), ") ",
                sub("[.]+$", "", view$panels), "."
            ),
            collapse = " "
        ))
    }
    if (length(view$encodings)) {
        sentences <- c(sentences, paste0(
            paste(sub("[.]+$", "", view$encodings), collapse = "; "), "."
        ))
    }
    analysis <- character()
    if (!is.na(view$sampling_unit)) {
        analysis <- c(analysis, paste0(
            "The analysis unit is ", view$sampling_unit
        ))
    }
    if (!is.na(view$design)) {
        analysis <- c(analysis, paste0("the design is ", view$design))
    }
    if (!is.na(view$estimand)) {
        analysis <- c(analysis, paste0("the estimand is ", view$estimand))
    }
    if (!is.na(view$time_field)) {
        time <- paste0("time is recorded as ", view$time_field)
        if (!is.na(view$time_unit)) time <- paste(time, "in", view$time_unit)
        analysis <- c(analysis, time)
    }
    if (!is.na(view$subject_field)) {
        analysis <- c(analysis, paste0(
            "subjects are identified by ", view$subject_field
        ))
    }
    if (length(view$nuisance_fields)) {
        analysis <- c(analysis, paste0(
            "adjustment uses ",
            paste(view$nuisance_fields, collapse = ", ")
        ))
    }
    if (length(analysis)) {
        analysis_text <- paste(analysis, collapse = "; ")
        substr(analysis_text, 1L, 1L) <- toupper(
            substr(analysis_text, 1L, 1L)
        )
        sentences <- c(sentences, paste0(
            analysis_text, "."
        ))
    }
    optional <- c(
        view$uncertainty, view$missingness, view$threshold,
        view$claim_boundary
    )
    optional <- vapply(optional, function(sentence) {
        if (is.na(sentence)) return(NA_character_)
        substr(sentence, 1L, 1L) <- toupper(substr(sentence, 1L, 1L))
        sentence
    }, character(1L))
    sentences <- c(sentences, paste0(
        sub("[.]$", "", optional[!is.na(optional)]), "."
    ))
    caption <- paste(sentences[nzchar(sentences)], collapse = " ")
    forbidden <- paste(
        c(
            "human (confirmation|review|approval|decision)",
            "developer(s)? instruction(s)?",
            "agent(s)? (workflow|review|decision)",
            "governance (workflow|decision|gate)",
            "manual confirmation",
            "implementation instruction(s)?",
            "software (enforcement|requirement)",
            "development (workflow|instruction|terminology)",
            "internal (workflow|instruction)"
        ),
        collapse = "|"
    )
    if (grepl(forbidden, caption, ignore.case = TRUE)) {
        .stop_landscapeR_validation(
            "caption contains internal governance language"
        )
    }
    paste(strwrap(caption, width = 96L), collapse = "\n")
}

.scientific_caption_exceptions <- data.frame(
    renderer = character(),
    category = character(),
    rationale = character(),
    test_reference = character(),
    public_examples = logical(),
    stringsAsFactors = FALSE
)

.scientific_caption_renderer_registry <- data.frame(
    renderer = c(
        "plot_component_identifiability",
        "plot_k1_acceptance_summary",
        "plot_k1_aml_acceptance_summary",
        "plot_k1_calibration_outcomes",
        "plot_components",
        "plot_spectrum",
        "plot_decomposition",
        "plot_potential",
        "plot.PermutationEvidence",
        "plot.AssociationAbstention",
        "plot.MetadataAssociationAtlas",
        "plot.ComponentProposal",
        "plot.ComponentAbstention"
    ),
    policy = c(
        rep("caption-required", 13L)
    ),
    tracking_issue = c(
        rep(NA_integer_, 13L)
    ),
    stringsAsFactors = FALSE
)

.public_scientific_caption_renderers <- function() {
    namespace <- asNamespace("landscapeR")
    exported <- grep(
        "^plot_",
        getNamespaceExports(namespace),
        value = TRUE
    )
    s3_methods <- getNamespaceInfo(namespace, "S3methods")
    s3 <- paste0(
        "plot.",
        s3_methods[s3_methods[, 1L] == "plot", 2L]
    )
    sort(unique(c(exported, s3)))
}

.validate_scientific_caption_registry <- function(
    registry = .scientific_caption_renderer_registry,
    exceptions = .scientific_caption_exceptions,
    public_renderers = .public_scientific_caption_renderers()
) {
    allowed <- c("caption-required", "migration-pending")
    if (anyDuplicated(registry$renderer) ||
        any(!registry$policy %in% allowed) ||
        any(registry$policy == "migration-pending" &
            is.na(registry$tracking_issue))) {
        .stop_landscapeR_validation(
            "scientific caption renderer registry is invalid"
        )
    }
    if (nrow(exceptions) &&
        (anyDuplicated(exceptions$renderer) ||
            any(!exceptions$category %in%
                c("self-explanatory", "internal-development")) ||
            any(nchar(exceptions$rationale) < 40L) ||
            any(!grepl(
                "^tests/testthat/test-[^:]+[.]R(?::.+)?$",
                exceptions$test_reference
            )) ||
            any(
                exceptions$category == "self-explanatory" &
                    !exceptions$renderer %in% public_renderers
            ) ||
            any(
                exceptions$category == "internal-development" &
                    exceptions$renderer %in% public_renderers
            ) ||
            any(
                exceptions$category == "internal-development" &
                    (!grepl("^[.]", exceptions$renderer) |
                        exceptions$public_examples)
            ) ||
            any(exceptions$renderer %in% registry$renderer))) {
        .stop_landscapeR_validation(
            "scientific caption exception registry is invalid"
        )
    }
    internal <- exceptions[
        exceptions$category == "internal-development",
        ,
        drop = FALSE
    ]
    if (nrow(internal)) {
        namespace <- asNamespace("landscapeR")
        functions_exist <- vapply(
            internal$renderer,
            function(renderer) {
                exists(renderer, envir = namespace, inherits = FALSE) &&
                    is.function(get(renderer, envir = namespace))
            },
            logical(1L)
        )
        test_files <- sub(":.*$", "", internal$test_reference)
        candidate_roots <- c(".", "..", "../..", "../../..")
        tests_exist <- vapply(
            test_files,
            function(path) {
                any(file.exists(file.path(candidate_roots, path)))
            },
            logical(1L)
        )
        if (any(!functions_exist) || any(!tests_exist)) {
            .stop_landscapeR_validation(
                "internal scientific caption exception evidence is invalid"
            )
        }
    }
    public_exceptions <- exceptions$renderer[
        exceptions$category == "self-explanatory"
    ]
    if (!setequal(
        public_renderers,
        c(registry$renderer, public_exceptions)
    )) {
        .stop_landscapeR_validation(
            "scientific caption registry does not cover public renderers"
        )
    }
    invisible(TRUE)
}
