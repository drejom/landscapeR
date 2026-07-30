caption_contract_view <- function(state = "complete", ...) {
    defaults <- list(
        title = "Coordinate identifiability across biological resamples",
        experiment_label = "Pogona sex-development series",
        molecular_layer = "RNA abundance",
        target_field = "genotype",
        oriented_levels = c("ZZ", "ZW"),
        direction = "ZW relative to ZZ",
        sampling_unit = "independent embryo",
        time_field = "developmental_stage",
        time_unit = "stage",
        subject_field = NA_character_,
        nuisance_fields = "sequencing_batch",
        panels = c(
            A = "Points show recurrence of each frozen coordinate",
            B = "Angles show stability of the enclosing subspace"
        ),
        encodings = c(
            "Red marks the nominated coordinate and black marks comparisons"
        ),
        estimand = "absolute loading cosine recurrence",
        design = "stage-stratified biological-unit bootstrap",
        uncertainty = "Nineteen of twenty requested resamples completed",
        missingness = "One failed resample remains in the denominator",
        threshold = "No acceptance threshold is applied",
        claim_boundary = paste(
            "Evidence is descriptive and does not establish biological",
            "validity"
        ),
        state = state
    )
    do.call(
        landscapeR:::.new_scientific_caption_view,
        utils::modifyList(defaults, list(...), keep.null = TRUE)
    )
}

test_that("typed caption views produce separate deterministic captions", {
    view <- caption_contract_view()
    first <- landscapeR:::.build_scientific_caption(view)
    second <- landscapeR:::.build_scientific_caption(view)
    plot <- landscapeR:::.with_scientific_caption(ggplot2::ggplot(), first)

    expect_identical(first, second)
    expect_identical(scientific_caption(plot), first)
    expect_null(plot$labels$caption)
    expect_match(first, "Pogona sex-development series", fixed = TRUE)
    expect_match(first, "RNA abundance", fixed = TRUE)
    expect_match(first, "ZW relative to ZZ", fixed = TRUE)
    expect_match(first, "independent embryo", fixed = TRUE)
    expect_match(first, "developmental_stage", fixed = TRUE)
    expect_match(first, "sequencing_batch", fixed = TRUE)
    expect_match(first, "(A)", fixed = TRUE)
    expect_match(first, "(B)", fixed = TRUE)
})

test_that("caption states expose stored uncertainty and claim boundaries", {
    cases <- list(
        partial = list(
            uncertainty = "Fourteen of twenty requested resamples completed",
            missingness = "Six failed resamples remain in the denominator",
            threshold = "No acceptance threshold is applied"
        ),
        missing = list(
            uncertainty = NA_character_,
            missingness = "Target values are unavailable for three embryos"
        ),
        calibrated = list(
            threshold = "The 0.80 recurrence threshold was calibrated in Stage 0"
        ),
        uncalibrated = list(
            threshold = "No calibrated acceptance threshold is available"
        ),
        abstention = list(
            uncertainty = "No resampling distribution was estimable",
            claim_boundary = "No unique coordinate is identified"
        )
    )
    captions <- lapply(names(cases), function(state) {
        args <- c(list(state = state), cases[[state]])
        gsub(
            "\\s+",
            " ",
            landscapeR:::.build_scientific_caption(
                do.call(caption_contract_view, args)
            )
        )
    })

    expect_match(captions[[1L]], "Fourteen of twenty")
    expect_match(captions[[2L]], "unavailable for three embryos")
    expect_match(captions[[3L]], "calibrated in Stage 0")
    expect_match(captions[[4L]], "No calibrated")
    expect_match(captions[[5L]], "No unique coordinate")
})

test_that("caption contract rejects invented or internal language", {
    expect_error(
        landscapeR:::.build_scientific_caption(
            caption_contract_view(
                claim_boundary = "Human confirmation is required"
            )
        ),
        "internal governance language"
    )
    expect_error(
        landscapeR:::.new_scientific_caption_view(
            title = "Test",
            panels = c("unlabelled"),
            claim_boundary = "Descriptive only"
        ),
        "unique single-letter"
    )
    forged <- caption_contract_view()
    forged$experiment_label <- character()
    expect_error(
        landscapeR:::.build_scientific_caption(forged),
        class = "landscapeR_validation_error"
    )
    expect_error(
        landscapeR:::.build_scientific_caption(
            caption_contract_view(
                claim_boundary = "Developer instructions require human review"
            )
        ),
        "internal governance language"
    )
})

test_that("caption state constrains required stored evidence", {
    expect_error(
        caption_contract_view(
            state = "partial",
            uncertainty = NA_character_
        ),
        "partial caption state requires"
    )
    expect_error(
        caption_contract_view(
            state = "missing",
            missingness = NA_character_
        ),
        "missing caption state requires"
    )
    expect_error(
        caption_contract_view(
            state = "calibrated",
            threshold = NA_character_
        ),
        "calibrated caption state requires"
    )
})

test_that("renderer and exception registries are explicit and valid", {
    expect_true(landscapeR:::.validate_scientific_caption_registry())
    registry <- landscapeR:::.scientific_caption_renderer_registry
    public_renderers <- landscapeR:::.public_scientific_caption_renderers()
    expect_setequal(
        registry$renderer,
        public_renderers
    )
    expect_identical(
        registry$policy[
            registry$renderer == "plot_component_identifiability"
        ],
        "caption-required"
    )
    pending <- registry[registry$policy == "migration-pending", ]
    expect_true(all(pending$tracking_issue %in% c(107L, 108L)))
    expect_identical(
        names(landscapeR:::.scientific_caption_exceptions),
        c(
            "renderer", "category", "rationale", "test_reference",
            "public_examples"
        )
    )
    bypass <- registry[1L, , drop = FALSE]
    bypass$policy <- "self-explanatory"
    expect_error(
        landscapeR:::.validate_scientific_caption_registry(
            registry = bypass
        ),
        "registry is invalid"
    )
    self_explanatory <- data.frame(
        renderer = "plot_component_identifiability",
        category = "self-explanatory",
        rationale = paste(
            "All applicable scientific semantics are visible in the",
            "returned plot and verified by the referenced test."
        ),
        test_reference =
            "tests/testthat/test-scientific-caption-contract.R:self-explanatory",
        public_examples = NA,
        stringsAsFactors = FALSE
    )
    registry_without_exception <- registry[
        registry$renderer != "plot_component_identifiability",
        ,
        drop = FALSE
    ]
    expect_true(landscapeR:::.validate_scientific_caption_registry(
        registry = registry_without_exception,
        exceptions = self_explanatory
    ))
    internal_exception <- landscapeR:::.scientific_caption_exceptions
    internal_plot <- landscapeR:::.plot_caption_contract_diagnostic()
    expect_s3_class(internal_plot, "ggplot")
    expect_null(scientific_caption(internal_plot))
    expect_false(internal_exception$public_examples)
    public_docs <- list.files(
        c("vignettes", "man"),
        pattern = "[.](Rmd|Rd)$",
        full.names = TRUE
    )
    documented <- vapply(
        public_docs,
        function(path) {
            any(grepl(
                internal_exception$renderer,
                readLines(path, warn = FALSE),
                fixed = TRUE
            ))
        },
        logical(1L)
    )
    expect_false(any(documented))
    internal_exception$renderer <- "plot_component_identifiability"
    expect_error(
        landscapeR:::.validate_scientific_caption_registry(
            registry = registry,
            exceptions = internal_exception
        ),
        "exception registry is invalid"
    )
    overlapping <- rbind(
        landscapeR:::.scientific_caption_exceptions,
        self_explanatory
    )
    expect_error(
        landscapeR:::.validate_scientific_caption_registry(
            registry = registry,
            exceptions = overlapping
        ),
        "exception registry is invalid"
    )
})
