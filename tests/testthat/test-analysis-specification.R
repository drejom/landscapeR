test_that("analysis_specification requires exactly one target source", {
    expect_error(analysis_specification(id = "none"), "exactly one")
    expect_error(
        analysis_specification(id = "both", target_field = "group", manual_component = 1L),
        "mutually exclusive"
    )

    by_field <- analysis_specification(id = "proposal", target_field = "group")
    by_component <- analysis_specification(id = "accepted", manual_component = 2L)
    expect_s4_class(by_field, "AnalysisSpecification")
    expect_s4_class(by_component, "AnalysisSpecification")
    expect_equal(by_component@manual_component, 2L)
})

test_that("analysis_specification validates metadata-role collisions and intent", {
    expect_error(
        analysis_specification(
            id = "collision", target_field = "group", nuisance_fields = "group"
        ),
        "distinct"
    )
    expect_error(
        analysis_specification(
            id = "bad-component", manual_component = 0L
        ),
        "positive"
    )
    expect_error(
        analysis_specification(id = "fractional", manual_component = 1.5),
        "single integer"
    )
    expect_error(
        analysis_specification(
            id = "bad-intent", manual_component = 1L, claim_intent = "confirmed"
        ),
        "arg.*one of"
    )
})

test_that("analysis specification digest is deterministic and changes with intent", {
    exploratory <- analysis_specification(
        id = "run", manual_component = 1L, claim_intent = "exploratory"
    )
    confirmatory <- analysis_specification(
        id = "run", manual_component = 1L, claim_intent = "primary_confirmatory"
    )
    expect_identical(canonical_digest(exploratory), canonical_digest(exploratory))
    expect_false(identical(canonical_digest(exploratory), canonical_digest(confirmatory)))
})

test_that("PipelineConfig requires an explicit analysis specification", {
    analysis <- analysis_specification(id = "run", manual_component = 1L)
    cfg <- new("PipelineConfig", dataset = "test", analysis = analysis)
    expect_s4_class(cfg, "PipelineConfig")
    expect_error(new("PipelineConfig", dataset = "test"), "analysis")
})

test_that("run_pipeline records analysis specification provenance", {
    std <- synthetic_control(n = 20L, p = 50L, K = 2L, signal = 30, seed = 1L)
    analysis <- analysis_specification(id = "run", manual_component = 1L)
    cfg <- new("PipelineConfig",
        dataset = "test",
        strategies = list(Decomposer = "hogsvd_averaged"),
        params = list(),
        analysis = analysis
    )
    result <- suppressWarnings(run_pipeline(std, cfg))
    step <- result@value@provenance[[1L]]
    expect_equal(step@params$analysis_specification$id, "run")
    expect_equal(step@params$analysis_specification$digest, canonical_digest(analysis))
})

test_that("run_pipeline applies manual component to Stage 2", {
    std <- synthetic_control(n = 20L, p = 50L, K = 2L, signal = 30, seed = 1L)
    cfg <- new("PipelineConfig",
        dataset = "test",
        strategies = list(Decomposer = "hogsvd_averaged", DynamicsEstimator = "kde_logdensity"),
        params = list(),
        analysis = analysis_specification(id = "component-two", manual_component = 2L)
    )
    result <- suppressWarnings(run_pipeline(std, cfg))
    expect_equal(result@status, "success")
    expect_equal(metadata(result@value)$stage2$params$component, 2L)
})

test_that("run_pipeline rejects invalid metadata and proposal-only Stage 2 intent", {
    std <- synthetic_control(n = 20L, p = 50L, K = 2L, signal = 30, seed = 1L)
    missing_field <- new("PipelineConfig",
        dataset = "test", strategies = list(Decomposer = "hogsvd_averaged"), params = list(),
        analysis = analysis_specification(id = "missing", target_field = "absent")
    )
    missing_result <- run_pipeline(std, missing_field)
    expect_equal(missing_result@status, "failure")
    expect_match(missing_result@reason, "not found")

    proposal_only <- new("PipelineConfig",
        dataset = "test", strategies = list(Decomposer = "hogsvd_averaged", DynamicsEstimator = "kde_logdensity"),
        params = list(),
        analysis = analysis_specification(id = "proposal", target_field = "planted_group")
    )
    proposal_result <- suppressWarnings(run_pipeline(std, proposal_only))
    expect_equal(proposal_result@status, "failure")
    expect_match(proposal_result@reason, "proposal only")
})
