test_that("AML-shaped K=1 control is repeated, deterministic, and provenanced", {
    first <- synthetic_k1_aml_longitudinal_control(
        subjects_per_condition = 4L,
        times = c(0, 6, 10, 14.6, 19),
        p = 30L,
        seed = 6701L
    )
    second <- synthetic_k1_aml_longitudinal_control(
        subjects_per_condition = 4L,
        times = c(0, 6, 10, 14.6, 19),
        p = 30L,
        seed = 6701L
    )

    expect_identical(first, second)
    expect_s4_class(first, "StateTransitionData")
    expect_s4_class(first@ground_truth, "SubspaceGroundTruth")
    expect_identical(first@sampling_design@kind, "longitudinal")
    expect_equal(dim(assay(experiments(first)[[1L]])), c(30L, 40L))
    expect_identical(metadata(first)$aml_k1_control$target_component, 2L)
    expect_identical(metadata(first)$aml_k1_control$nuisance_component, 1L)
    expect_identical(
        metadata(first)$aml_k1_control$claim_status,
        "non_evidentiary_calibration"
    )
    expect_identical(first@provenance[[1L]]@implementation,
                     "k1_aml_longitudinal")
    expect_true(all(is.finite(assay(experiments(first)[[1L]]))))
})

test_that("AML-shaped K=1 calibration uses production contracts", {
    calibration <- k1_aml_longitudinal_calibration(
        subjects_per_condition = 12L,
        times = c(0, 6, 10, 14.6, 19),
        p = 50L,
        n_resamples = 2L,
        seed = 6702L
    )

    expect_identical(calibration$status, "success")
    expect_identical(calibration$evidence_status,
                     "non_evidentiary_calibration")
    expect_s4_class(calibration$decomposition, "StageResult")
    expect_identical(calibration$decomposition@status, "success")
    expect_s4_class(calibration$atlas, "MetadataAssociationAtlas")
    expect_s4_class(calibration$proposal, "ComponentProposal")
    expect_identical(calibration$proposal@recommended_component, 2L)
    expect_s4_class(calibration$identifiability, "ComponentProposal")
    identifiability <- proposal_identifiability(calibration$identifiability)
    expect_identical(identifiability$n_requested, 2L)
    expect_gte(identifiability$n_completed, 1L)
    effects <- atlas_associations(calibration$atlas)
    adjusted <- effects[
        effects$evidence_variant == "repeated-time-course-adjusted", ,
        drop = FALSE
    ]
    expect_true(any(adjusted$component == 2L &
                    is.finite(adjusted$effect_magnitude)))
    expect_true(is.finite(
        adjusted$effect_magnitude[adjusted$component == 2L][[1L]]
    ))
    expect_s4_class(calibration$stage2, "StageResult")
    expect_identical(calibration$stage2@status, "failure")
    expect_match(calibration$stage2@reason, "sampling design 'longitudinal'")
    expect_s3_class(plot_component_identifiability(
        calibration$identifiability
    ), "ggplot")
})

test_that("AML-shaped K=1 control validates public inputs", {
    expect_error(
        synthetic_k1_aml_longitudinal_control(subjects_per_condition = 2L),
        class = "landscapeR_validation_error"
    )
    expect_error(
        synthetic_k1_aml_longitudinal_control(times = c(1, 1, 2)),
        class = "landscapeR_validation_error"
    )
    expect_error(
        synthetic_k1_aml_longitudinal_control(dropout_subjects = NA_character_),
        class = "landscapeR_validation_error"
    )
})
