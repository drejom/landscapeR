test_that("v2 draft retains a complete binary target declaration", {
    spec <- analysis_specification(
        id = "binary-draft",
        target_field = "condition",
        target_type = "binary",
        reference_level = "control",
        comparison_level = "disease",
        nuisance_fields = "batch",
        claim_intent = "primary_confirmatory"
    )

    expect_s4_class(spec, "AnalysisSpecification")
    expect_identical(spec@version, "2.0.0")
    expect_identical(spec@lifecycle, "draft")
    expect_identical(spec@target_field, "condition")
    expect_identical(spec@target_type, "binary")
    expect_identical(spec@reference_level, "control")
    expect_identical(spec@comparison_level, "disease")
    expect_length(spec@selected_component, 0L)
    expect_length(spec@proposal_digest, 0L)
    expect_false("manual_component" %in% slotNames(spec))
    expect_error(
        analysis_specification(
            id = "legacy-argument",
            target_field = "condition",
            target_type = "binary",
            reference_level = "control",
            comparison_level = "disease",
            manual_component = 1L
        ),
        "unused argument.*manual_component"
    )
})

test_that("v2 draft rejects an incomplete binary target declaration", {
    expect_error(
        analysis_specification(
            id = "missing-comparison",
            target_field = "condition",
            target_type = "binary",
            reference_level = "control"
        ),
        "comparison_level"
    )
})

test_that("proposal lifecycle adds only a ranked-proposal digest", {
    proposal_digest <- strrep("a", 64L)
    spec <- analysis_specification(
        id = "binary-proposal",
        target_field = "condition",
        target_type = "binary",
        reference_level = "control",
        comparison_level = "disease",
        lifecycle = "proposal",
        proposal_digest = proposal_digest
    )

    expect_identical(spec@lifecycle, "proposal")
    expect_identical(spec@proposal_digest, proposal_digest)
    expect_length(spec@selected_component, 0L)
    expect_length(spec@proposal_decision, 0L)
    expect_length(spec@analyst_rationale, 0L)
})

test_that("confirmed lifecycle retains target and records the human decision", {
    proposal_digest <- strrep("b", 64L)
    spec <- analysis_specification(
        id = "binary-confirmed",
        target_field = "condition",
        target_type = "binary",
        reference_level = "control",
        comparison_level = "disease",
        lifecycle = "confirmed",
        selected_component = 2L,
        proposal_digest = proposal_digest,
        proposal_decision = "overridden",
        analyst_rationale = "Component 2 met the predeclared target-axis rule."
    )

    expect_identical(spec@lifecycle, "confirmed")
    expect_identical(spec@target_field, "condition")
    expect_identical(spec@reference_level, "control")
    expect_identical(spec@comparison_level, "disease")
    expect_identical(spec@selected_component, 2L)
    expect_identical(spec@proposal_digest, proposal_digest)
    expect_identical(spec@proposal_decision, "overridden")
    expect_match(spec@analyst_rationale, "predeclared")

    expect_error(
        analysis_specification(
            id = "bad-digest",
            target_field = "condition",
            target_type = "binary",
            reference_level = "control",
            comparison_level = "disease",
            lifecycle = "proposal",
            proposal_digest = "not-a-sha256"
        ),
        "64-character hexadecimal"
    )
    expect_error(
        analysis_specification(
            id = "whitespace-rationale",
            target_field = "condition",
            target_type = "binary",
            reference_level = "control",
            comparison_level = "disease",
            lifecycle = "confirmed",
            selected_component = 1L,
            proposal_digest = proposal_digest,
            proposal_decision = "accepted",
            analyst_rationale = "   "
        ),
        "analyst_rationale"
    )
})

test_that("ordered and continuous targets require explicit direction", {
    ordered <- analysis_specification(
        id = "ordered",
        target_field = "disease_stage",
        target_type = "ordered",
        ordered_levels = c("healthy", "at_risk", "disease")
    )
    continuous <- analysis_specification(
        id = "continuous",
        target_field = "weeks",
        target_type = "continuous",
        continuous_direction = "increasing"
    )

    expect_identical(
        ordered@ordered_levels,
        c("healthy", "at_risk", "disease")
    )
    expect_identical(continuous@continuous_direction, "increasing")
    expect_error(
        analysis_specification(
            id = "unordered",
            target_field = "disease_stage",
            target_type = "ordered"
        ),
        "ordered_levels"
    )
    expect_error(
        analysis_specification(
            id = "directionless",
            target_field = "weeks",
            target_type = "continuous"
        ),
        "continuous_direction"
    )
})

test_that("canonical identity includes target and confirmation provenance", {
    digest_a <- strrep("a", 64L)
    base_args <- list(
        id = "identity",
        target_field = "condition",
        target_type = "binary",
        reference_level = "control",
        comparison_level = "disease",
        lifecycle = "confirmed",
        selected_component = 1L,
        proposal_digest = digest_a,
        proposal_decision = "accepted",
        analyst_rationale = "Accepted the predeclared top-ranked component."
    )
    accepted <- do.call(analysis_specification, base_args)
    overridden <- do.call(
        analysis_specification,
        utils::modifyList(base_args, list(proposal_decision = "overridden"))
    )

    expect_identical(canonical_digest(accepted), canonical_digest(accepted))
    expect_false(identical(
        canonical_digest(accepted),
        canonical_digest(overridden)
    ))
})

test_that("v1 target-only migration requires explicit missing direction", {
    legacy <- readRDS(
        testthat::test_path("fixtures", "analysis-specification-v1.rds")
    )$target_only

    expect_error(
        migrate_analysis_specification(legacy),
        "explicit target_type"
    )
    expect_error(
        migrate_analysis_specification(
            legacy,
            target_field = "different_target",
            target_type = "binary",
            reference_level = "low",
            comparison_level = "high"
        ),
        "must match the v1 target_field"
    )

    migrated <- migrate_analysis_specification(
        legacy,
        target_type = "binary",
        reference_level = "low",
        comparison_level = "high"
    )
    expect_identical(migrated@version, "2.0.0")
    expect_identical(migrated@lifecycle, "draft")
    expect_identical(migrated@target_field, "planted_group")
    expect_identical(migrated@nuisance_fields, "batch")
    expect_identical(migrated@claim_intent, "exploratory")
    expect_identical(
        migrated@migration_source_digest,
        "7c4c0d4f52fa353f3baea1ed99892b2cf02a429f297867b25e0811d40f159097"
    )

    proposal_digest <- strrep("f", 64L)
    migrated_proposal <- migrate_analysis_specification(
        legacy,
        target_type = "binary",
        reference_level = "low",
        comparison_level = "high",
        proposal_digest = proposal_digest
    )
    expect_identical(migrated_proposal@lifecycle, "proposal")
    expect_identical(migrated_proposal@proposal_digest, proposal_digest)
})

test_that("v1 manual-only migration never invents or discards target intent", {
    legacy <- readRDS(
        testthat::test_path("fixtures", "analysis-specification-v1.rds")
    )$manual_only
    proposal_digest <- strrep("c", 64L)

    expect_error(
        migrate_analysis_specification(legacy),
        "explicit target_field"
    )
    expect_error(
        migrate_analysis_specification(
            legacy,
            target_field = "condition",
            target_type = "binary",
            reference_level = "control",
            comparison_level = "disease"
        ),
        "proposal_digest"
    )

    migrated <- migrate_analysis_specification(
        legacy,
        target_field = "condition",
        target_type = "binary",
        reference_level = "control",
        comparison_level = "disease",
        proposal_digest = proposal_digest,
        proposal_decision = "overridden",
        analyst_rationale = paste(
            "Legacy component 2 was explicitly reconciled with the",
            "restored target declaration."
        )
    )
    expect_identical(migrated@lifecycle, "confirmed")
    expect_identical(migrated@selected_component, 2L)
    expect_identical(migrated@target_field, "condition")
    expect_identical(migrated@orientation_anchor, "age")
    expect_identical(migrated@claim_intent, "primary_confirmatory")
    expect_identical(
        migrated@migration_source_digest,
        "8709f4eab06f8d927002bafd1dd5725ff18c7a1238f0c623062db828bb476ff1"
    )
})

test_that("v2 migration is idempotent", {
    current <- analysis_specification(
        id = "current",
        target_field = "weeks",
        target_type = "continuous",
        continuous_direction = "increasing"
    )
    expect_identical(migrate_analysis_specification(current), current)
    expect_error(
        migrate_analysis_specification(current, target = "3.0.0"),
        "target must be '2.0.0'"
    )
})

test_that("run_pipeline permits draft Stage 1 but requires confirmation for Stage 2", {
    std <- synthetic_control(n = 20L, p = 50L, K = 2L, signal = 30, seed = 1L)
    draft <- analysis_specification(
        id = "draft-run",
        target_field = "planted_group",
        target_type = "binary",
        reference_level = "low",
        comparison_level = "high"
    )
    draft_stage1 <- new(
        "PipelineConfig",
        dataset = "test",
        strategies = list(Decomposer = "hogsvd_averaged"),
        analysis = draft
    )
    draft_stage2 <- new(
        "PipelineConfig",
        dataset = "test",
        strategies = list(
            Decomposer = "hogsvd_averaged",
            DynamicsEstimator = "kde_logdensity"
        ),
        analysis = draft
    )

    stage1_result <- suppressWarnings(run_pipeline(std, draft_stage1))
    stage2_result <- suppressWarnings(run_pipeline(std, draft_stage2))
    expect_identical(stage1_result@status, "success")
    expect_identical(stage2_result@status, "failure")
    expect_match(stage2_result@reason, "confirmed.*selected_component")
})

test_that("run_pipeline uses selected_component from a confirmed specification", {
    std <- synthetic_control(n = 20L, p = 50L, K = 2L, signal = 30, seed = 1L)
    proposal_digest <- strrep("d", 64L)
    confirmed <- analysis_specification(
        id = "confirmed-run",
        target_field = "planted_group",
        target_type = "binary",
        reference_level = "low",
        comparison_level = "high",
        lifecycle = "confirmed",
        selected_component = 2L,
        proposal_digest = proposal_digest,
        proposal_decision = "accepted",
        analyst_rationale = "Accepted component 2 for this runner contract test."
    )
    config <- new(
        "PipelineConfig",
        dataset = "test",
        strategies = list(
            Decomposer = "hogsvd_averaged",
            DynamicsEstimator = "kde_logdensity"
        ),
        analysis = confirmed
    )

    result <- suppressWarnings(run_pipeline(std, config))
    expect_identical(result@status, "success")
    expect_identical(metadata(result@value)$stage2$params$component, 2L)
    recorded <- result@value@provenance[[1L]]@params$analysis_specification
    expect_identical(recorded$lifecycle, "confirmed")
    expect_identical(recorded$target_field, "planted_group")
    expect_identical(recorded$target_type, "binary")
    expect_identical(recorded$selected_component, 2L)
    expect_identical(recorded$proposal_decision, "accepted")
    expect_identical(recorded$digest, canonical_digest(confirmed))
    expect_false("manual_component" %in% names(recorded))
})

test_that("run_pipeline validates declared target values and component bounds", {
    std <- synthetic_control(n = 20L, p = 50L, K = 2L, signal = 30, seed = 1L)
    bad_levels <- analysis_specification(
        id = "bad-levels",
        target_field = "planted_group",
        target_type = "binary",
        reference_level = "control",
        comparison_level = "disease"
    )
    bad_level_config <- new(
        "PipelineConfig",
        dataset = "test",
        strategies = list(Decomposer = "hogsvd_averaged"),
        analysis = bad_levels
    )
    bad_level_result <- run_pipeline(std, bad_level_config)
    expect_identical(bad_level_result@status, "failure")
    expect_match(bad_level_result@reason, "declared binary levels")

    proposal_digest <- strrep("e", 64L)
    out_of_bounds <- analysis_specification(
        id = "bad-component",
        target_field = "planted_group",
        target_type = "binary",
        reference_level = "low",
        comparison_level = "high",
        lifecycle = "confirmed",
        selected_component = 999L,
        proposal_digest = proposal_digest,
        proposal_decision = "overridden",
        analyst_rationale = "Deliberately invalid component for boundary testing."
    )
    bounds_config <- new(
        "PipelineConfig",
        dataset = "test",
        strategies = list(
            Decomposer = "hogsvd_averaged",
            DynamicsEstimator = "kde_logdensity"
        ),
        analysis = out_of_bounds
    )
    bounds_result <- suppressWarnings(run_pipeline(std, bounds_config))
    expect_identical(bounds_result@status, "failure")
    expect_match(bounds_result@reason, "selected_component 999.*not available")
})

test_that("run_pipeline validates ordered and continuous target declarations", {
    std <- synthetic_control(n = 20L, p = 50L, K = 2L, signal = 30, seed = 1L)
    colData(std)$stage <- rep(c("early", "late"), length.out = 20L)
    colData(std)$weeks <- seq_len(20L)

    ordered <- analysis_specification(
        id = "ordered-boundary",
        target_field = "stage",
        target_type = "ordered",
        ordered_levels = c("early", "middle", "late")
    )
    ordered_config <- new(
        "PipelineConfig",
        dataset = "test",
        strategies = list(Decomposer = "hogsvd_averaged"),
        analysis = ordered
    )
    ordered_result <- run_pipeline(std, ordered_config)
    expect_identical(ordered_result@status, "failure")
    expect_match(ordered_result@reason, "declared ordered_levels")

    colData(std)$weeks <- as.character(colData(std)$weeks)
    continuous <- analysis_specification(
        id = "continuous-boundary",
        target_field = "weeks",
        target_type = "continuous",
        continuous_direction = "increasing"
    )
    continuous_config <- new(
        "PipelineConfig",
        dataset = "test",
        strategies = list(Decomposer = "hogsvd_averaged"),
        analysis = continuous
    )
    continuous_result <- run_pipeline(std, continuous_config)
    expect_identical(continuous_result@status, "failure")
    expect_match(continuous_result@reason, "continuous target")
})
