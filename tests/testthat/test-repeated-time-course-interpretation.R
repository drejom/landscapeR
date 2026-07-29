test_that("repeated time course fits the registered random-slope strategy", {
    atlas <- associate_metadata(
        repeated_time_course_fixture(),
        specification = repeated_time_course_specification("batch"),
        non_analytical_fields = "mouse_id",
        n_resamples = 9L,
        seed = 8201L
    )
    provenance <- atlas_provenance(atlas)
    adjusted <- atlas_associations(atlas)
    adjusted <- adjusted[
        adjusted$evidence_variant == "repeated-time-course-adjusted",
        ,
        drop = FALSE
    ]

    expect_s4_class(atlas, "MetadataAssociationAtlas")
    expect_identical(
        provenance$association_strategy,
        "repeated-time-course-lmer-v1"
    )
    expect_identical(provenance$model_engine, "lme4::lmer")
    expect_identical(provenance$model_optimizer, "bobyqa")
    expect_identical(
        provenance$model_optimizer_controls,
        list(maxfun = 100000L)
    )
    expect_identical(provenance$model_reml, FALSE)
    expect_identical(provenance$model_na_action, "stats::na.fail")
    expect_identical(
        provenance$scientific_random_formula,
        "(1 + scaled_time | subject)"
    )
    contract <- atlas_evidence_contract(atlas)
    expect_identical(contract$version, "repeated-time-course-v1")
    expect_identical(contract$sampling_design, "longitudinal")
    expect_identical(
        contract$row_counts,
        c(
            associations = 6L,
            observations = 128L,
            exclusions = 3L
        )
    )
    expect_true(all(grepl("^[[:xdigit:]]{64}$", contract$digests)))
    expect_identical(
        sort(unique(contract$cohort_members$evidence_variant)),
        sort(c(
            "pooled-descriptive",
            "repeated-time-course-unadjusted",
            "repeated-time-course-adjusted"
        ))
    )
    expect_true(validObject(atlas))
    expect_identical(
        adjusted$estimand,
        rep("standardized-condition-time-interaction", 2L)
    )
    expect_gt(abs(adjusted$estimate[adjusted$component == 1L]), 1)
    expect_lt(abs(adjusted$estimate[adjusted$component == 2L]), 0.1)
    expect_identical(
        adjusted$resampling_method,
        rep("condition-stratified-subject-trajectory-bootstrap", 2L)
    )
    expect_identical(adjusted$n_resamples, rep(9L, 2L))
    expect_true(all(adjusted$resample_failures >= 0L))
    expect_true(all(adjusted$resample_failures <= 9L))
    expect_true(all(vapply(
        provenance$time_course_models,
        function(record) {
            record$adjusted$design_rank > 0L &&
                is.list(record$adjusted$native_diagnostics)
        },
        logical(1L)
    )))
    expect_identical(provenance$resampling_plan$unit, "complete-subject")
    expect_true(all(vapply(
        seq_along(provenance$resampling_plan$replicate_subject_ids),
        function(i) {
            ids <- provenance$resampling_plan$replicate_subject_ids[[i]]
            sources <- provenance$resampling_plan$source_subject_ids[[i]]
            length(unique(ids)) == length(sources)
        },
        logical(1L)
    )))
    expect_s3_class(plot(atlas), "ggplot")
    proposal <- propose_component(atlas)
    expect_s4_class(proposal, "ComponentProposal")
    expect_identical(proposal@recommended_component, 1L)
    expect_identical(
        atlas_digest(unserialize(serialize(atlas, NULL))),
        atlas_digest(atlas)
    )
})

test_that("homogeneous subject trajectories retain a near-zero interaction", {
    atlas <- associate_metadata(
        repeated_time_course_fixture(slope_divergence = 0),
        specification = repeated_time_course_specification(),
        non_analytical_fields = c("mouse_id", "batch")
    )
    effects <- atlas_associations(atlas)
    effects <- effects[
        effects$evidence_variant == "repeated-time-course-unadjusted",
        ,
        drop = FALSE
    ]

    expect_true(all(is.finite(effects$estimate)))
    expect_lt(max(abs(effects$estimate)), 0.15)
})

test_that("subject identity and observed time cannot become the target", {
    std <- repeated_time_course_fixture()
    subject_specification <- analysis_specification(
        id = "invalid-subject-target",
        target_field = "mouse_id",
        target_type = "binary",
        reference_level = "c1",
        comparison_level = "t1"
    )
    time_specification <- analysis_specification(
        id = "invalid-time-target",
        target_field = "day",
        target_type = "binary",
        reference_level = "0",
        comparison_level = "1"
    )

    expect_error(
        associate_metadata(
            std,
            specification = subject_specification,
            non_analytical_fields = "batch"
        ),
        "subject identity and observed time",
        class = "landscapeR_validation_error"
    )
    expect_error(
        associate_metadata(
            std,
            specification = time_specification,
            non_analytical_fields = c("mouse_id", "batch")
        ),
        "subject identity and observed time",
        class = "landscapeR_validation_error"
    )
})

test_that("condition assignment must be constant within each subject", {
    std <- repeated_time_course_fixture()
    colData(std)$condition[[2L]] <- "treatment"
    atlas <- associate_metadata(
        std,
        specification = repeated_time_course_specification(),
        non_analytical_fields = c("mouse_id", "batch")
    )
    effects <- atlas_associations(atlas)
    effects <- effects[effects$proposal_eligible, , drop = FALSE]

    expect_true(all(grepl(
        "condition-varies-within-subject",
        effects$diagnostic
    )))
    expect_s4_class(propose_component(atlas), "ComponentAbstention")
    expect_identical(
        atlas_evidence_contract(
            unserialize(serialize(atlas, NULL))
        ),
        atlas_evidence_contract(atlas)
    )
})

test_that("empty repeated-subject cohort retains its module provenance", {
    std <- repeated_time_course_fixture()
    colData(std)$batch[] <- NA
    abstention <- associate_metadata(
        std,
        specification = repeated_time_course_specification("batch"),
        non_analytical_fields = "mouse_id"
    )

    expect_s4_class(abstention, "AssociationAbstention")
    expect_identical(abstention@reason, "non-identifiable-design")
    expect_identical(
        abstention@provenance$interpretation_module,
        "repeated-time-course-v1"
    )
})

test_that("random slopes require replicated subjects with at least three times", {
    sparse <- repeated_time_course_fixture(times = c(0, 1))
    sparse_atlas <- associate_metadata(
        sparse,
        specification = repeated_time_course_specification(),
        non_analytical_fields = c("mouse_id", "batch")
    )
    sparse_effects <- atlas_associations(sparse_atlas)
    sparse_effects <- sparse_effects[
        sparse_effects$proposal_eligible,
        ,
        drop = FALSE
    ]
    unreplicated <- repeated_time_course_fixture(
        subjects_per_condition = 1L
    )
    unreplicated_atlas <- associate_metadata(
        unreplicated,
        specification = repeated_time_course_specification(),
        non_analytical_fields = c("mouse_id", "batch")
    )
    unreplicated_effects <- atlas_associations(unreplicated_atlas)
    unreplicated_effects <- unreplicated_effects[
        unreplicated_effects$proposal_eligible,
        ,
        drop = FALSE
    ]

    expect_true(all(grepl(
        "fewer-than-three",
        sparse_effects$diagnostic
    )))
    expect_true(all(grepl(
        "insufficient-subject-replication",
        unreplicated_effects$diagnostic
    )))
})

test_that("singular and non-convergent models remain distinct failures", {
    singular_atlas <- associate_metadata(
        repeated_time_course_fixture(slope_scale = 0),
        specification = repeated_time_course_specification(),
        non_analytical_fields = c("mouse_id", "batch")
    )
    singular_effects <- atlas_associations(singular_atlas)
    singular_effects <- singular_effects[
        singular_effects$proposal_eligible,
        ,
        drop = FALSE
    ]
    expect_true(any(grepl(
        "singular-random-effects-covariance",
        singular_effects$diagnostic
    )))
    expect_identical(
        propose_component(singular_atlas)@reason,
        "singular-model"
    )
    expect_identical(
        propose_component(singular_atlas)@version,
        "1.1.0"
    )

    testthat::local_mocked_bindings(
        .landscapeR_lmer = function(...) {
            stop("forced optimizer failure")
        },
        .package = "landscapeR"
    )
    nonconvergent_atlas <- associate_metadata(
        repeated_time_course_fixture(),
        specification = repeated_time_course_specification(),
        non_analytical_fields = c("mouse_id", "batch")
    )
    nonconvergent_effects <- atlas_associations(nonconvergent_atlas)
    nonconvergent_effects <- nonconvergent_effects[
        nonconvergent_effects$proposal_eligible,
        ,
        drop = FALSE
    ]
    expect_true(all(grepl(
        "model-non-convergent",
        nonconvergent_effects$diagnostic
    )))
    nonconvergent_abstention <- propose_component(nonconvergent_atlas)
    expect_identical(
        nonconvergent_abstention@reason,
        "non-convergent-model"
    )
    expect_identical(
        plot(nonconvergent_abstention)$labels$subtitle,
        "The declared repeated-subject model did not converge"
    )
    expect_true(all(vapply(
        atlas_provenance(
            nonconvergent_atlas
        )$time_course_models,
        function(record) {
            identical(
                record$unadjusted$native_diagnostics$error,
                "forced optimizer failure"
            )
        },
        logical(1L)
    )))
})

test_that("irregular schedules and dropout remain visible by subject", {
    atlas <- associate_metadata(
        repeated_time_course_fixture(
            dropout = c("c1", "t1"),
            irregular = TRUE
        ),
        specification = repeated_time_course_specification(),
        non_analytical_fields = c("mouse_id", "batch"),
        n_resamples = 3L,
        seed = 8202L
    )
    subject_summary <- atlas_provenance(atlas)$subject_summary

    expect_setequal(
        subject_summary$subject[subject_summary$dropout],
        c("c1", "t1")
    )
    expect_true(all(
        table(atlas_provenance(
            atlas
        )$time_course_observations$subject) >= 3L
    ))
    expect_s3_class(plot(atlas), "ggplot")
})

test_that("permutation operates on between-subject assignment", {
    atlas <- associate_metadata(
        repeated_time_course_fixture(),
        specification = repeated_time_course_specification(),
        non_analytical_fields = c("mouse_id", "batch")
    )
    proposal <- propose_component(
        atlas,
        n_permutations = 7L,
        seed = 8203L
    )
    evidence <- proposal_permutation_evidence(proposal)

    expect_true(evidence@status %in% c("complete", "partial"))
    expect_identical(
        evidence@method,
        "between-subject-condition-permutation"
    )
    expect_true(evidence@n_completed > 0L)
    expect_identical(
        evidence@n_completed +
            (evidence@n_requested - evidence@n_completed),
        evidence@n_requested
    )
    expect_length(evidence@null_max_effect, 7L)
})

test_that("repeated time-course refits are deterministic", {
    first <- associate_metadata(
        repeated_time_course_fixture(),
        specification = repeated_time_course_specification(),
        non_analytical_fields = c("mouse_id", "batch"),
        n_resamples = 5L,
        seed = 8204L
    )
    second <- associate_metadata(
        repeated_time_course_fixture(),
        specification = repeated_time_course_specification(),
        non_analytical_fields = c("mouse_id", "batch"),
        n_resamples = 5L,
        seed = 8204L
    )

    expect_identical(atlas_associations(first), atlas_associations(second))
    expect_identical(atlas_digest(first), atlas_digest(second))
})
