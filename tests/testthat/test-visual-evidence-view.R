visual_caption_fixture <- function(state = "complete") {
    landscapeR:::.new_scientific_caption_view(
        title = "Stored visual evidence",
        experiment_label = "Pogona development series",
        sampling_unit = "independent embryo",
        panels = c(A = "Points show recorded observations"),
        encodings = "Red marks the declared focal contrast",
        missingness = if (state %in% c("partial", "missing")) {
            "One requested observation is unavailable"
        } else {
            NA_character_
        },
        uncertainty = if (identical(state, "partial")) {
            "Nine of ten requested resamples completed"
        } else {
            NA_character_
        },
        claim_boundary = if (identical(state, "abstention")) {
            "No component is identified"
        } else {
            "Evidence is descriptive and does not establish biological validity"
        },
        state = state
    )
}

test_that("visual evidence views expose validated stored figure evidence", {
    view <- landscapeR:::.new_visual_evidence_view(
        surface = "atlas",
        state = "partial",
        observations = data.frame(
            component = 1L,
            score = 0.4,
            available = TRUE
        ),
        summaries = data.frame(
            component = 1L,
            estimate = 0.3
        ),
        diagnostics = data.frame(
            component = 1L,
            diagnostic = "possible-nonmonotone-association"
        ),
        display_data = list(
            numeric_observations = data.frame(component = 1L, score = 0.4),
            missing_count = 1L
        ),
        caption_view = visual_caption_fixture("partial")
    )

    expect_s4_class(view, "VisualEvidenceView")
    expect_identical(visual_evidence_surface(view), "atlas")
    expect_identical(visual_evidence_state(view), "partial")
    expect_identical(
        visual_evidence_observations(view),
        view@observations
    )
    expect_identical(visual_evidence_summaries(view), view@summaries)
    expect_identical(visual_evidence_diagnostics(view), view@diagnostics)
    expect_identical(
        visual_evidence_display(view, "missing_count"),
        1L
    )
    expect_identical(
        visual_evidence_display_names(view),
        c("numeric_observations", "missing_count")
    )
    expect_match(
        visual_evidence_caption(view),
        "Pogona development series",
        fixed = TRUE
    )
    expect_false("provenance" %in% slotNames(view))

    restored <- unserialize(serialize(view, NULL))
    expect_identical(restored, view)
    expect_true(validObject(restored))
})

test_that("visual evidence views reject malformed or recomputable payloads", {
    expect_error(
        landscapeR:::.new_visual_evidence_view(
            surface = "unknown",
            state = "complete",
            caption_view = visual_caption_fixture()
        ),
        "surface is not supported",
        class = "landscapeR_validation_error"
    )
    expect_error(
        landscapeR:::.new_visual_evidence_view(
            surface = "atlas",
            state = "complete",
            display_data = list(provenance = list(seed = 1L)),
            caption_view = visual_caption_fixture()
        ),
        "must not expose provenance",
        class = "landscapeR_validation_error"
    )
    expect_error(
        landscapeR:::.new_visual_evidence_view(
            surface = "abstention",
            state = "abstention",
            caption_view = visual_caption_fixture()
        ),
        "caption state must match",
        class = "landscapeR_validation_error"
    )
    expect_error(
        visual_evidence_display(
            landscapeR:::.new_visual_evidence_view(
                surface = "atlas",
                state = "complete",
                caption_view = visual_caption_fixture()
            ),
            "not_recorded"
        ),
        "is not recorded",
        class = "landscapeR_validation_error"
    )
})

test_that("permutation views preserve partial and failed evidence states", {
    digest <- paste(rep("a", 64L), collapse = "")
    partial <- landscapeR:::.new_permutation_evidence(
        method = "label-permutation",
        status = "partial",
        n_requested = 3L,
        n_completed = 2L,
        observed_max_effect = 0.5,
        null_max_effect = c(0.1, NA_real_, 0.2),
        search_aware_p_value = 1 / 3,
        seed = 94L,
        cohort_digest = digest,
        design_digest = digest,
        diagnostic = "one null refit failed"
    )
    failed <- landscapeR:::.new_permutation_evidence(
        method = "label-permutation",
        status = "not-identifiable",
        n_requested = 3L,
        n_completed = 0L,
        null_max_effect = rep(NA_real_, 3L),
        seed = 94L,
        cohort_digest = digest,
        design_digest = digest,
        diagnostic = "all null refits failed"
    )

    partial_view <- visual_evidence(partial)
    failed_view <- visual_evidence(failed)
    partial_caption <- gsub(
        "[[:space:]]+",
        " ",
        visual_evidence_caption(partial_view)
    )

    expect_identical(visual_evidence_state(partial_view), "partial")
    expect_match(
        partial_caption,
        "2 of 3 requested null refits completed; 1 failed",
        fixed = TRUE
    )
    expect_match(
        partial_caption,
        "search-aware p-value is 0.333",
        fixed = TRUE
    )
    expect_identical(visual_evidence_state(failed_view), "missing")
    expect_match(
        visual_evidence_caption(failed_view),
        "No search-aware permutation distribution is available",
        fixed = TRUE
    )
    expect_false(grepl(
        "search-aware p-value =",
        visual_evidence_caption(failed_view),
        fixed = TRUE
    ))
})
