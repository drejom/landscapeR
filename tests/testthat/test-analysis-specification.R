test_that("analysis_specification validates roles, lifecycle, and intent", {
    expect_error(
        analysis_specification(
            id = "collision",
            target_field = "group",
            target_type = "binary",
            reference_level = "control",
            comparison_level = "disease",
            nuisance_fields = "group"
        ),
        "distinct"
    )
    expect_error(
        analysis_specification(
            id = "bad-lifecycle",
            target_field = "group",
            target_type = "binary",
            reference_level = "control",
            comparison_level = "disease",
            lifecycle = "reviewed"
        ),
        "lifecycle"
    )
    expect_error(
        analysis_specification(
            id = "bad-component",
            target_field = "group",
            target_type = "binary",
            reference_level = "control",
            comparison_level = "disease",
            lifecycle = "confirmed",
            selected_component = 0L,
            proposal_digest = strrep("a", 64L),
            proposal_decision = "accepted",
            analyst_rationale = "Invalid component is rejected before use."
        ),
        "positive integer"
    )
    expect_error(
        analysis_specification(
            id = "infinite-component",
            target_field = "group",
            target_type = "binary",
            reference_level = "control",
            comparison_level = "disease",
            lifecycle = "confirmed",
            selected_component = Inf,
            proposal_digest = strrep("a", 64L),
            proposal_decision = "accepted",
            analyst_rationale = "Infinite component indexes are invalid."
        ),
        "selected_component must be a single integer"
    )
    expect_error(
        analysis_specification(
            id = "bad-intent",
            target_field = "group",
            target_type = "binary",
            reference_level = "control",
            comparison_level = "disease",
            claim_intent = "confirmed"
        ),
        "arg.*one of"
    )
})

test_that("confirmed lifecycle requires complete decision provenance", {
    base <- list(
        id = "confirmation",
        target_field = "group",
        target_type = "binary",
        reference_level = "control",
        comparison_level = "disease",
        lifecycle = "confirmed",
        selected_component = 1L
    )
    expect_error(
        do.call(analysis_specification, base),
        "proposal_digest"
    )
    expect_error(
        do.call(
            analysis_specification,
            c(base, list(
                proposal_digest = strrep("b", 64L)
            ))
        ),
        "proposal_decision"
    )
    expect_error(
        do.call(
            analysis_specification,
            c(base, list(
                proposal_digest = strrep("b", 64L),
                proposal_decision = "accepted"
            ))
        ),
        "analyst_rationale"
    )
})

test_that("PipelineConfig requires an explicit v2 analysis specification", {
    analysis <- confirmed_planted_analysis()
    config <- new("PipelineConfig", dataset = "test", analysis = analysis)
    expect_s4_class(config, "PipelineConfig")
    expect_identical(config@analysis@version, "2.0.0")
    expect_error(new("PipelineConfig", dataset = "test"), "analysis")
})

test_that("run_pipeline returns typed failures for invalid target metadata", {
    std <- synthetic_control(n = 20L, p = 50L, K = 2L, signal = 30, seed = 1L)
    missing <- analysis_specification(
        id = "missing",
        target_field = "absent",
        target_type = "binary",
        reference_level = "low",
        comparison_level = "high"
    )
    config <- new(
        "PipelineConfig",
        dataset = "test",
        strategies = list(Decomposer = "hogsvd_averaged"),
        analysis = missing
    )

    result <- run_pipeline(std, config)
    expect_identical(result@status, "failure")
    expect_match(result@reason, "not found")
})

test_that("orientation anchors remain finite non-degenerate metadata", {
    std <- synthetic_control(n = 20L, p = 50L, K = 2L, signal = 30, seed = 1L)
    colData(std)$constant_anchor <- 1
    analysis <- analysis_specification(
        id = "bad-anchor",
        target_field = "planted_group",
        target_type = "binary",
        reference_level = "low",
        comparison_level = "high",
        orientation_anchor = "constant_anchor"
    )
    config <- new(
        "PipelineConfig",
        dataset = "test",
        strategies = list(Decomposer = "hogsvd_averaged"),
        analysis = analysis
    )

    result <- run_pipeline(std, config)
    expect_identical(result@status, "failure")
    expect_match(result@reason, "orientation_anchor")
})
