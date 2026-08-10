test_that("negative development task completes the frozen search and topology path", {
    protocol <- k1_acceptance_protocol()
    task <- data.frame(
        task_id = "development-pure-noise",
        control = "pure_noise",
        n = 48L,
        p = 100L,
        subjects_per_condition = NA_integer_,
        replicate_index = 1L,
        seed_root = 92001L,
        canonical_cell = "development-only",
        stringsAsFactors = FALSE
    )
    task$stream_seeds <- list(c(
        generator = 92001L,
        metadata = 92002L,
        permutations = 92003L,
        identifiability = 92004L
    ))

    result <- suppressWarnings(landscapeR:::.k1_acceptance_run_task(
        task,
        protocol,
        expected_identity = NULL,
        sequential_internal = TRUE
    ))

    expect_s3_class(result, "K1AcceptanceReplicate")
    expect_identical(result$status, "success")
    expect_identical(result$control, "pure_noise")
    expect_type(result$metrics$false_double_well, "logical")
    expect_type(result$metrics$false_target_selection, "logical")
    expect_true(is.finite(result$metrics$search_aware_p_value))
    expect_true(is.finite(result$metrics$target_index_recurrence))
    expect_true(is.finite(result$metrics$mean_matched_loading_cosine))
    expect_true(is.finite(result$metrics$identifiability_completion_rate))
})

test_that("negative proposal abstention remains a failed replicate", {
    protocol <- k1_acceptance_protocol()
    task <- data.frame(
        task_id = "development-negative-abstention",
        control = "pure_noise",
        n = 48L,
        p = 100L,
        subjects_per_condition = NA_integer_,
        replicate_index = 1L,
        seed_root = 92101L,
        canonical_cell = "development-only",
        stringsAsFactors = FALSE
    )
    task$stream_seeds <- list(c(
        generator = 92101L,
        metadata = 92102L,
        permutations = 92103L,
        identifiability = 92104L
    ))
    original <- propose_component
    testthat::local_mocked_bindings(
        propose_component = function(
            atlas,
            target = NULL,
            n_permutations = 0L,
            seed = 1L,
            sequential_internal = FALSE,
            future_scheduling = NULL
        ) {
            proposal <- original(
                atlas,
                target = target,
                n_permutations = 0L,
                seed = seed,
                sequential_internal = TRUE
            )
            landscapeR:::.new_component_abstention(
                atlas = atlas,
                target = proposal@target_field,
                reason = "insufficient-resampling-support",
                ranking = proposal@ranking,
                candidate_components = proposal@recommended_component
            )
        },
        .package = "landscapeR"
    )

    result <- suppressWarnings(landscapeR:::.k1_acceptance_run_task(
        task,
        protocol,
        expected_identity = NULL,
        sequential_internal = TRUE
    ))

    expect_identical(result$status, "failure")
    expect_match(result$reason, "insufficient-resampling-support")
    expect_length(result$metrics, 0L)
})
