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
    expect_s4_class(first@ground_truth, "K1AmlLongitudinalGroundTruth")
    expect_identical(first@sampling_design@kind, "longitudinal")
    expect_equal(dim(assay(experiments(first)[[1L]])), c(30L, 40L))
    truth <- aml_longitudinal_control_truth(first)
    info <- aml_longitudinal_control_info(first)
    expect_identical(truth@target_component, 2L)
    expect_identical(truth@nuisance_component, 1L)
    expect_identical(info$time_source,
                     "user-supplied")
    expect_equal(
        dim(truth@sample_scores),
        c(40L, 2L)
    )
    expect_identical(
        colnames(truth@sample_scores),
        c("collection_time", "condition_by_time")
    )
    expect_identical(
        info$claim_status,
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
    expect_s3_class(calibration, "K1AmlLongitudinalCalibrationResult")
    expect_match(calibration$digest, "^[0-9a-f]{64}$")
    expect_true(length(calibration$provenance) > 0L)
    expect_identical(calibration$evidence_status,
                     "non_evidentiary_calibration")
    expect_s4_class(calibration$decomposition, "StageResult")
    expect_identical(calibration$decomposition@status, "success")
    expect_s4_class(calibration$atlas, "MetadataAssociationAtlas")
    expect_s4_class(calibration$proposal, "ComponentProposal")
    expect_identical(calibration$proposal@recommended_component, 2L)
    expect_s4_class(calibration$identifiability, "ComponentProposal")
    identifiability <- calibration$identifiability_evidence
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
    expect_identical(calibration$config@strategies[["Decomposer"]], "svd")
    expect_identical(
        calibration$config@strategies[["DynamicsEstimator"]],
        "kde_logdensity"
    )
    expect_equal(calibration$recovery$component, c(1L, 2L))
    expect_true(all(is.finite(calibration$recovery$absolute_loading_cosine)))
    expect_true(all(is.finite(
        calibration$recovery$subspace_principal_angle_degrees
    )))
    expect_true(all(calibration$recovery$absolute_loading_cosine > 0.95))
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
    expect_error(
        synthetic_k1_aml_longitudinal_control(
            dropout_subjects = "not_a_mouse"
        ),
        class = "landscapeR_validation_error"
    )
    expect_error(
        synthetic_k1_aml_longitudinal_control(
            time_signal = 3, disease_signal = 3
        ),
        class = "landscapeR_validation_error"
    )
    expect_error(
        synthetic_k1_aml_longitudinal_control(
            seed = .Machine$integer.max - 2L
        ),
        class = "landscapeR_validation_error"
    )
    expect_error(
        k1_aml_longitudinal_calibration(n_resamples = 1.5),
        class = "landscapeR_validation_error"
    )
    expect_error(
        k1_aml_longitudinal_calibration(n_permutations = -1L),
        class = "landscapeR_validation_error"
    )
    incompatible <- landscapeR:::.aml_k1_calibration_config()
    incompatible@params$svd$k_components <- 1L
    expect_error(
        k1_aml_longitudinal_calibration(config = incompatible),
        "at least 2",
        class = "landscapeR_validation_error"
    )
})

test_that("default AML weeks retain packaged-source provenance", {
    control <- synthetic_k1_aml_longitudinal_control(
        subjects_per_condition = 3L,
        p = 10L,
        seed = 6703L
    )
    expect_identical(
        aml_longitudinal_control_info(control)$time_source,
        "inst/extdata/gse133642-sample-weeks.csv"
    )
})
