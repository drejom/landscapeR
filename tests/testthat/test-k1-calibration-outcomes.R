calibration_outcome_fixture <- function() {
    protocol <- k1_acceptance_protocol()
    cells <- c(
        "control=aml_synchronized;subjects_per_condition=4;p=100",
        "control=aml_synchronized;subjects_per_condition=7;p=100",
        "control=aml_synchronized;subjects_per_condition=12;p=10000",
        "control=aml_synchronized;subjects_per_condition=12;p=100"
    )
    tasks <- data.frame(
        task_id = paste0("outcome-", seq_along(cells)),
        control = "aml_synchronized",
        n = NA_integer_,
        p = c(100L, 100L, 10000L, 100L),
        subjects_per_condition = c(4L, 7L, 12L, 12L),
        replicate_index = 1L,
        seed_root = seq_along(cells),
        canonical_cell = cells,
        stringsAsFactors = FALSE
    )
    tasks$stream_seeds <- replicate(nrow(tasks), 1L, simplify = FALSE)
    provenance <- function(status = "estimable", diagnostic = "") list(
        version = "1.0.0",
        evidence_status = "independent_acceptance",
        generator_and_decomposition = list(fixture = TRUE),
        atlas = list(
            time_course_models = lapply(1:2, function(component) list(
                component = component,
                unadjusted = list(status = status, diagnostic = diagnostic),
                adjusted = list(status = status, diagnostic = diagnostic)
            ))
        ),
        proposal = list(fixture = TRUE),
        identifiability = list(fixture = TRUE),
        stage2 = list(fixture = TRUE)
    )
    result <- function(index, cosine, model_status = "estimable",
                       diagnostic = "", recurrence = 0.9,
                       completion = 0.95, status = "success") {
        evidence <- provenance(model_status, diagnostic)
        metrics <- if (status == "success") list(
            target_loading_cosine = cosine,
            target_subspace_angle_deg = acos(cosine) * 180 / pi,
            mean_bootstrap_subspace_angle_deg = if (
                is.finite(recurrence)
            ) 8 else NA_real_,
            q95_bootstrap_subspace_angle_deg = if (
                is.finite(recurrence)
            ) 12 else NA_real_,
            target_component = 2L,
            nuisance_component = 1L,
            target_proposal_rank = 1L,
            nuisance_proposal_rank = 2L,
            target_unadjusted_estimate = if (
                model_status == "estimable"
            ) -1 else NA_real_,
            target_adjusted_estimate = if (
                model_status == "estimable"
            ) -1 else NA_real_,
            nuisance_unadjusted_estimate = if (
                model_status == "estimable"
            ) 0.1 else NA_real_,
            nuisance_adjusted_estimate = if (
                model_status == "estimable"
            ) 0.1 else NA_real_,
            target_unadjusted_status = "estimable-exploratory-only",
            target_adjusted_status = "estimable-exploratory-only",
            nuisance_unadjusted_status = "estimable-exploratory-only",
            nuisance_adjusted_status = "estimable-exploratory-only",
            target_index_recurrence = recurrence,
            mean_matched_loading_cosine = recurrence,
            identifiability_completion_rate = completion,
            stage2_ineligible = TRUE,
            orientation_recurrence = recurrence,
            rank_one_fraction = recurrence,
            matched_fraction = recurrence,
            acceptance_evidence_status = "independent_acceptance",
            acceptance_provenance = evidence,
            acceptance_provenance_digest = digest::digest(
                evidence,
                algo = "sha256"
            )
        ) else list()
        structure(list(
            artifact_version = protocol$artifact_version,
            task_id = tasks$task_id[[index]],
            control = "aml_synchronized",
            canonical_cell = tasks$canonical_cell[[index]],
            replicate_index = 1L,
            status = status,
            reason = if (status == "success") "" else "worker stopped",
            metrics = metrics,
            protocol_digest = protocol$digest,
            runner_contract = protocol$execution_contracts$version
        ), class = c("K1AcceptanceReplicate", "list"))
    }
    list(
        protocol = protocol,
        tasks = tasks,
        results = list(
            result(
                1L,
                0.98,
                model_status = "singular",
                diagnostic = "singular-random-effects-covariance",
                recurrence = NA_real_,
                completion = 0
            ),
            result(2L, 0.98),
            result(3L, 0.70),
            result(4L, 0.98, status = "failure")
        )
    )
}

test_that("calibration outcomes separate recovery from downstream estimability", {
    fixture <- calibration_outcome_fixture()
    assessment <- assess_k1_calibration_outcomes(
        fixture$results,
        fixture$tasks,
        fixture$protocol
    )

    expect_s3_class(assessment, "K1CalibrationOutcomeAssessment")
    expect_identical(
        as.character(assessment$replicates$outcome),
        c(
            "recovered_downstream_nonestimable",
            "recovered_and_estimable",
            "recovery_below_threshold",
            "execution_failure"
        )
    )
    expect_true(assessment$replicates$recovery_met[[1L]])
    expect_false(assessment$replicates$downstream_estimable[[1L]])
    expect_true(is.na(
        assessment$replicates$mean_matched_loading_cosine[[1L]]
    ))
    expect_identical(
        assessment$replicates$target_unadjusted_estimate[[2L]],
        -1
    )
    expect_true(assessment$replicates$stage2_ineligible[[2L]])
    expect_false(assessment$replicates$recovery_met[[3L]])
    expect_true(is.na(assessment$replicates$recovery_met[[4L]]))
    expect_identical(
        assessment$canonical_recovery_criterion,
        "minimum_target_loading_cosine"
    )
    expect_false("maximum_target_subspace_angle_degrees" %in%
        assessment$gating_fields)
    expect_identical(
        assessment$claim_status,
        "retrospective_diagnostic_only"
    )
})

test_that("calibration cell denominators preserve typed outcomes", {
    fixture <- calibration_outcome_fixture()
    assessment <- assess_k1_calibration_outcomes(
        fixture$results,
        fixture$tasks,
        fixture$protocol
    )

    expect_true(all(assessment$cells$n_requested == 1L))
    expect_identical(sum(assessment$cells$n_execution_failure), 1L)
    expect_identical(sum(assessment$cells$n_recovery_evaluable), 3L)
    expect_identical(sum(assessment$cells$n_recovered), 2L)
    expect_identical(sum(assessment$cells$n_downstream_evaluable), 2L)
    expect_identical(sum(assessment$cells$n_recovered_and_estimable), 1L)
    expect_true(all(
        assessment$cells$recovery_rate_denominator ==
            "replicates with evaluable decomposition recovery"
    ))
    expect_true(all(
        assessment$cells$estimability_rate_denominator ==
            "replicates whose target axis was recovered"
    ))
})

test_that("calibration outcome plot exposes both scientific failure modes", {
    fixture <- calibration_outcome_fixture()
    assessment <- assess_k1_calibration_outcomes(
        fixture$results,
        fixture$tasks,
        fixture$protocol
    )
    plot <- plot_k1_calibration_outcomes(assessment)

    expect_s3_class(plot, "ggplot")
    expect_match(
        scientific_caption(plot),
        "recovered but downstream interpretation was not\\s+estimable"
    )
    expect_match(scientific_caption(plot), "did not recover the planted axis")
    expect_match(scientific_caption(plot), "retrospective\\s+diagnostic")
    expect_setequal(
        as.character(unique(assessment$replicates$outcome)),
        assessment$outcome_levels
    )
    expect_identical(
        plot$labels$shape,
        "Calibration outcome"
    )
    expect_length(plot$scales$get_scales("shape")$palette(4L), 4L)
})

test_that("historical acceptance summaries remain reproducible", {
    before <- k1_acceptance_protocol()
    invisible(assess_k1_calibration_outcomes(
        calibration_outcome_fixture()$results,
        calibration_outcome_fixture()$tasks,
        calibration_outcome_fixture()$protocol
    ))
    after <- k1_acceptance_protocol()

    expect_identical(after, before)
    expect_identical(after$digest, before$digest)
})

test_that("calibration artifacts replay their typed assessment", {
    fixture <- calibration_outcome_fixture()
    artifact <- publish_k1_calibration_outcomes(
        tempfile("k1-calibration-artifacts-"),
        fixture$results,
        fixture$tasks,
        fixture$protocol
    )

    expect_true(dir.exists(artifact))
    expect_true(file.exists(file.path(artifact, "MANIFEST.tsv")))
    expect_true(verify_k1_calibration_outcomes(artifact))
    stored <- readRDS(file.path(artifact, "assessment.rds"))
    expect_identical(
        stored,
        assess_k1_calibration_outcomes(
            fixture$results,
            fixture$tasks,
            fixture$protocol
        )
    )
})

test_that("calibration artifact verification detects tampering", {
    fixture <- calibration_outcome_fixture()
    artifact <- publish_k1_calibration_outcomes(
        tempfile("k1-calibration-artifacts-"),
        fixture$results,
        fixture$tasks,
        fixture$protocol
    )
    writeLines("changed", file.path(artifact, "outcome-map-caption.txt"))

    expect_error(
        verify_k1_calibration_outcomes(artifact),
        class = "k1_acceptance_runner_error"
    )
})

test_that("calibration outcome assessment rejects malformed public inputs", {
    fixture <- calibration_outcome_fixture()
    expect_error(
        assess_k1_calibration_outcomes(
            fixture$results,
            transform(fixture$tasks, control = "generic_double_well"),
            fixture$protocol
        ),
        class = "k1_acceptance_runner_error"
    )
    assessment <- assess_k1_calibration_outcomes(
        fixture$results,
        fixture$tasks,
        fixture$protocol
    )
    assessment$digest <- strrep("0", 64L)
    expect_error(
        plot_k1_calibration_outcomes(assessment),
        class = "landscapeR_validation_error"
    )
})
