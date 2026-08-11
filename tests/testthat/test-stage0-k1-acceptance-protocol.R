test_that("K=1 acceptance protocol is deterministic and content addressed", {
    first <- k1_acceptance_protocol()
    second <- k1_acceptance_protocol()

    expect_identical(first, second)
    expect_s3_class(first, "K1AcceptanceProtocol")
    expect_match(first$digest, "^[0-9a-f]{64}$")
    expect_true(validate_k1_acceptance_protocol(first))
    expect_identical(first$protocol_status, "frozen_before_acceptance")
    expect_false(first$execution$acceptance_execution_available)
    expect_identical(first$execution$phase, "definition_only")

    path <- tempfile(fileext = ".rds")
    on.exit(unlink(path), add = TRUE)
    saveRDS(first, path)
    restored <- readRDS(path)
    expect_identical(restored, first)
    expect_true(validate_k1_acceptance_protocol(restored))
})

test_that("K=1 acceptance protocol v2 extends the lower tail and preserves v1", {
    current <- k1_acceptance_protocol()
    legacy <- k1_acceptance_protocol("1")

    expect_identical(current$protocol_id, "k1-stage0-acceptance-v2")
    expect_identical(legacy$protocol_id, "k1-stage0-acceptance-v1")
    expect_false(identical(current$digest, legacy$digest))
    expect_true(validate_k1_acceptance_protocol(current))
    expect_true(validate_k1_acceptance_protocol(legacy))
    expect_identical(
        current$grids$generic_double_well$varying$n,
        c(8L, 12L, 16L, 24L, 48L, 96L, 132L, 192L)
    )
    expect_identical(
        current$grids$negative_controls$varying$n,
        current$grids$generic_double_well$varying$n
    )
    expect_identical(
        current$grids$shared_baseline_missing_cells$fixed,
        list(
            conditions = 2L,
            time_points = 4L,
            replicates_per_observed_cell = 3L,
            p = 1000L
        )
    )
    expect_identical(
        current$seed_plan$control,
        c(
            "generic_double_well", "pure_noise", "single_well",
            "aml_synchronized", "shared_baseline_missing_cells"
        )
    )
    expect_error(
        k1_acceptance_protocol("3"),
        class = "k1_acceptance_protocol_error"
    )
})

test_that("K=1 acceptance seeds remain hidden until their protocol merge", {
    protocol <- k1_acceptance_protocol()
    plan <- protocol$seed_plan

    expect_identical(
        plan$replicates_per_grid_cell,
        c(100L, 200L, 200L, 100L, 100L)
    )
    expect_false("seed" %in% names(plan))
    expect_identical(
        protocol$seed_derivation$reveal_value,
        "reviewed version 2 protocol pull-request merge commit SHA-1"
    )
    expect_identical(
        k1_acceptance_protocol("1")$seed_derivation$reveal_value,
        "phase-A pull-request merge commit SHA-1"
    )
    expect_identical(
        protocol$seed_derivation$canonical_cell_schemas$aml_synchronized,
        c("subjects_per_condition", "p")
    )
    expect_false(protocol$provenance$acceptance_results_inspected)
    expect_match(
        protocol$seed_derivation$integer_mapping,
        "task ordinal",
        fixed = TRUE
    )
    expect_match(
        k1_acceptance_protocol("1")$seed_derivation$integer_mapping,
        "modulo 2147483644",
        fixed = TRUE
    )
    expect_identical(
        protocol$separation$disclosed_calibration_root_seeds,
        c(42L, 50L, 6701L, 6702L, 6703L)
    )
    expect_identical(
        protocol$separation$reserved_calibration_rng_streams,
        c(42L, 43L, 44L, 45L, 50L, 51L,
          6701L, 6702L, 6703L, 6704L, 6705L)
    )
    expect_identical(
        unname(protocol$seed_derivation$acceptance_stream_offsets$
                   aml_synchronized),
        0:3
    )
    expect_match(protocol$seed_derivation$collision_rule, "reserved")
})

test_that("K=1 acceptance protocol freezes metrics and pass rules", {
    protocol <- k1_acceptance_protocol()

    expect_equal(
        protocol$thresholds$generic_double_well$
            maximum_mean_well_location_error,
        0.15
    )
    expect_equal(
        protocol$thresholds$negative_controls$
            maximum_false_double_well_rate_per_control_cell,
        0.05
    )
    expect_equal(
        protocol$thresholds$negative_controls$
            maximum_false_target_selection_rate_per_control_cell,
        0.05
    )
    expect_equal(protocol$pass_rules$minimum_cell_pass_rate, 0.90)
    expect_equal(
        protocol$pass_rules$minimum_cell_wilson_95_lower_bound,
        0.80
    )
    expect_identical(
        protocol$thresholds$aml_synchronized$required_target_component,
        2L
    )
    expect_match(protocol$pass_rules$barrier_height_error, "truth=2")
    expect_match(protocol$pass_rules$grid_execution, "Cartesian product")
    expect_identical(
        protocol$thresholds$aml_synchronized$
            minimum_target_index_recurrence,
        0.80
    )
    expect_identical(protocol$resampling$negative_permutations, 99L)
    expect_identical(protocol$resampling$negative_identifiability_resamples,
                     99L)
    expect_length(protocol$grids$aml_synchronized$fixed$times, 11L)
    expect_identical(
        names(protocol$grids$aml_synchronized$varying),
        c("subjects_per_condition", "p")
    )
    expect_identical(
        protocol$execution_contracts$svd,
        list(center = TRUE, k_components = 6L)
    )
    expect_identical(
        protocol$execution_contracts$kde_logdensity$bandwidth_method,
        "hpi"
    )
    expect_null(
        protocol$execution_contracts$kde_logdensity$bandwidth_value
    )
    expect_identical(
        protocol$execution_contracts$aml_synchronized_analysis$
            dropout_subjects,
        character()
    )
    expect_match(
        protocol$pass_rules$supported_minimum_n,
        "8,12,16,24,48,96,132,192"
    )
})

test_that("K=1 acceptance protocol rejects mutation and forged digests", {
    changed <- k1_acceptance_protocol()
    changed$thresholds$generic_double_well$
        maximum_subspace_angle_degrees <- 20
    expect_error(
        validate_k1_acceptance_protocol(changed),
        "differs from the frozen",
        class = "k1_acceptance_protocol_error"
    )

    forged <- k1_acceptance_protocol()
    forged$digest <- strrep("0", 64L)
    expect_error(
        validate_k1_acceptance_protocol(forged),
        "digest",
        class = "k1_acceptance_protocol_error"
    )

    expect_error(
        validate_k1_acceptance_protocol(list()),
        class = "k1_acceptance_protocol_error"
    )
})
