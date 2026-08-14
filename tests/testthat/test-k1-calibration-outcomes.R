calibration_outcome_fixture <- function() {
    protocol <- k1_acceptance_protocol()
    cells <- c(
        "control=aml_synchronized;subjects_per_condition=4;p=100",
        "control=aml_synchronized;subjects_per_condition=7;p=100",
        "control=aml_synchronized;subjects_per_condition=12;p=10000",
        "control=aml_synchronized;subjects_per_condition=12;p=100",
        "control=aml_synchronized;subjects_per_condition=7;p=10000"
    )
    tasks <- data.frame(
        task_id = paste0("outcome-", seq_along(cells)),
        control = "aml_synchronized",
        n = NA_integer_,
        p = c(100L, 100L, 10000L, 100L, 10000L),
        subjects_per_condition = c(4L, 7L, 12L, 12L, 7L),
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
                       completion = 0.95, status = "success",
                       target_component = 2L) {
        evidence <- provenance(model_status, diagnostic)
        metrics <- if (status == "success") list(
            target_loading_cosine = cosine,
            target_subspace_angle_deg = if (is.finite(cosine)) {
                acos(cosine) * 180 / pi
            } else {
                90
            },
            mean_bootstrap_subspace_angle_deg = if (
                is.finite(recurrence)
            ) 8 else NA_real_,
            q95_bootstrap_subspace_angle_deg = if (
                is.finite(recurrence)
            ) 12 else NA_real_,
            target_component = target_component,
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
            result(4L, 0.98, status = "failure"),
            result(5L, NA_real_)
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
            "execution_failure",
            "recovery_not_evaluable"
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
    expect_identical(assessment$replicates$target_component[[2L]], 2L)
    expect_identical(assessment$replicates$nuisance_component[[2L]], 1L)
    expect_false(assessment$replicates$recovery_met[[3L]])
    expect_true(is.na(assessment$replicates$recovery_met[[4L]]))
    expect_false(assessment$replicates$recovery_evaluable[[5L]])
    expect_true(is.na(assessment$replicates$downstream_estimable[[5L]]))
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

test_that("integer-valued double component identities remain valid", {
    fixture <- calibration_outcome_fixture()
    fixture$results[[2L]]$metrics$target_component <- 2
    fixture$results[[2L]]$metrics$nuisance_component <- 1
    fixture$results[[2L]]$metrics$acceptance_provenance$atlas$
        time_course_models[[1L]]$component <- 1
    fixture$results[[2L]]$metrics$acceptance_provenance$atlas$
        time_course_models[[2L]]$component <- 2
    fixture$results[[2L]]$metrics$acceptance_provenance_digest <-
        digest::digest(
            fixture$results[[2L]]$metrics$acceptance_provenance,
            algo = "sha256"
        )

    assessment <- assess_k1_calibration_outcomes(
        fixture$results,
        fixture$tasks,
        fixture$protocol
    )

    expect_identical(
        as.character(assessment$replicates$outcome[[2L]]),
        "recovered_and_estimable"
    )
    expect_s3_class(plot_k1_calibration_outcomes(assessment), "ggplot")
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
    expect_identical(sum(assessment$cells$n_recovery_not_evaluable), 1L)
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
    plot <- plot_k1_calibration_outcomes(
        assessment,
        task_ids = c("outcome-1", "outcome-3")
    )

    expect_s3_class(plot, "ggplot")
    expect_match(
        scientific_caption(plot),
        "downstream interpretation not\\s+estimable"
    )
    expect_match(
        scientific_caption(plot),
        "cosine agreement below the recovery threshold"
    )
    expect_match(scientific_caption(plot), "known-truth\\s+synthetic")
    expect_match(scientific_caption(plot), "typed\\s+outcome\\s+table")
    expect_match(
        scientific_caption(plot),
        "upward\\s+orientation is illustrative"
    )
    expect_false(grepl(";;", scientific_caption(plot), fixed = TRUE))
    expect_setequal(
        as.character(unique(assessment$replicates$outcome)),
        assessment$outcome_levels
    )
    geometry <- attr(plot, "landscapeR_k1_schematic_data", exact = TRUE)
    expect_s3_class(geometry, "data.frame")
    expect_setequal(
        as.character(unique(geometry$direction)),
        c("Planted reference axis", "Cosine-derived unsigned angle")
    )
    expect_setequal(
        as.character(unique(geometry$panel)),
        c(
            paste(
                "A  Axis recovered\n",
                "Downstream interpretation not estimable",
                sep = ""
            ),
            paste(
                "B  Axis agreement below threshold\n",
                "Downstream not evaluated",
                sep = ""
            )
        )
    )
    expect_identical(plot$labels$colour, NULL)
    expect_null(plot$scales$get_scales("shape"))
    expect_match(scientific_caption(plot), "outcome-1,\\s+outcome-3")
})

test_that("calibration geometry excludes identity mismatch and keeps all rows", {
    fixture <- calibration_outcome_fixture()
    duplicate <- fixture$results[[1L]]
    duplicate$task_id <- "outcome-1b"
    duplicate$canonical_cell <- fixture$tasks$canonical_cell[[1L]]
    duplicate$replicate_index <- 2L
    duplicate$metrics$target_loading_cosine <- 0.96
    fixture$tasks <- rbind(
        fixture$tasks,
        transform(
            fixture$tasks[1L, , drop = FALSE],
            task_id = "outcome-1b",
            replicate_index = 2L
        )
    )
    identity_mismatch <- fixture$results[[3L]]
    identity_mismatch$metrics$target_loading_cosine <- 0.98
    identity_mismatch$metrics$target_component <- 1L
    identity_mismatch$metrics$nuisance_component <- 2L
    fixture$results <- c(fixture$results, list(duplicate))
    fixture$results[[3L]] <- identity_mismatch

    assessment <- assess_k1_calibration_outcomes(
        fixture$results,
        fixture$tasks,
        fixture$protocol
    )
    identity_geometry <- attr(
        plot_k1_calibration_outcomes(assessment),
        "landscapeR_k1_schematic_data",
        exact = TRUE
    )
    expect_false("outcome-3" %in% identity_geometry$task_id)

    fixture <- calibration_outcome_fixture()
    fixture$tasks <- rbind(
        fixture$tasks,
        transform(
            fixture$tasks[1L, , drop = FALSE],
            task_id = "outcome-1b",
            replicate_index = 2L
        )
    )
    duplicate <- fixture$results[[1L]]
    duplicate$task_id <- "outcome-1b"
    duplicate$replicate_index <- 2L
    duplicate$metrics$target_loading_cosine <- 0.96
    fixture$results <- c(fixture$results, list(duplicate))
    assessment <- assess_k1_calibration_outcomes(
        fixture$results,
        fixture$tasks,
        fixture$protocol
    )
    geometry <- attr(
        plot_k1_calibration_outcomes(assessment),
        "landscapeR_k1_schematic_data",
        exact = TRUE
    )
    expect_setequal(
        unique(geometry$task_id[
            geometry$direction == "Cosine-derived unsigned angle"
        ]),
        c("outcome-1", "outcome-1b", "outcome-2", "outcome-3")
    )

    assessment$replicates$diagnostic[[3L]] <-
        "equivalent explanatory wording"
    assessment$cells <- landscapeR:::.k1_calibration_cell_rows(
        assessment$replicates
    )
    payload <- unclass(assessment)
    payload$digest <- NULL
    assessment$digest <- digest::digest(payload, algo = "sha256")
    wording_geometry <- attr(
        plot_k1_calibration_outcomes(assessment),
        "landscapeR_k1_schematic_data",
        exact = TRUE
    )
    expect_true("outcome-3" %in% wording_geometry$task_id)
})

test_that("calibration plot handles assessments without drawable geometry", {
    fixture <- calibration_outcome_fixture()
    assessment <- assess_k1_calibration_outcomes(
        fixture$results[4L],
        fixture$tasks[4L, , drop = FALSE],
        fixture$protocol
    )

    plot <- plot_k1_calibration_outcomes(assessment)
    expect_s3_class(plot, "ggplot")
    expect_null(attr(plot, "landscapeR_k1_schematic_data", exact = TRUE))
    caption <- scientific_caption(plot)
    expect_match(caption, "AML-shaped synthetic longitudinal")
    expect_match(caption, "no completed replicate", ignore.case = TRUE)
    expect_match(caption, "loading cosine at\\s+least 0.9")
    expect_match(caption, "known-truth synthetic")
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
    testthat::local_mocked_bindings(
        .k1_calibration_runtime_identity = function() list(
            source_revision = strrep("a", 40L),
            r_version = "4.5.2",
            package_versions = c(landscapeR = "0.3.0")
        ),
        .package = "landscapeR"
    )
    root <- tempfile("k1-calibration-artifacts-")
    artifact <- publish_k1_calibration_outcomes(
        root, fixture$results,
        fixture$tasks, fixture$protocol)
    repeated <- publish_k1_calibration_outcomes(
        root, fixture$results, fixture$tasks, fixture$protocol)

    expect_true(dir.exists(artifact))
    expect_identical(repeated, artifact)
    expect_true(file.exists(file.path(artifact, "MANIFEST.tsv")))
    expect_true(verify_k1_calibration_outcomes(artifact))
    environment <- readRDS(file.path(artifact, "environment.rds"))
    expect_match(environment$runtime_identity$source_revision,
        "^[0-9a-f]{40}$")
    expect_true(length(environment$runtime_identity$package_versions) >= 1L)
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

test_that("calibration artifact publication cleans interrupted candidates", {
    fixture <- calibration_outcome_fixture()
    testthat::local_mocked_bindings(
        .k1_calibration_runtime_identity = function() list(
            source_revision = strrep("a", 40L),
            r_version = "4.5.2",
            package_versions = c(landscapeR = "0.3.0")
        ),
        .artifact_atomic_move = function(from, to) FALSE,
        .package = "landscapeR"
    )
    root <- tempfile("k1-calibration-interrupted-")

    expect_error(
        publish_k1_calibration_outcomes(
            root, fixture$results, fixture$tasks, fixture$protocol
        ),
        class = "k1_acceptance_runner_error"
    )
    expect_length(list.files(root, all.files = TRUE, no.. = TRUE), 0L)
})

test_that("calibration artifact publication cleans semantic rejection", {
    fixture <- calibration_outcome_fixture()
    testthat::local_mocked_bindings(
        .k1_calibration_runtime_identity = function() list(
            source_revision = strrep("a", 40L),
            r_version = "4.5.2",
            package_versions = c(landscapeR = "0.3.0")
        ),
        .package = "landscapeR"
    )
    root <- tempfile("k1-calibration-rejected-")

    expect_error(
        testthat::with_mocked_bindings(
            publish_k1_calibration_outcomes(
                root, fixture$results, fixture$tasks, fixture$protocol
            ),
            .k1_calibration_verify_artifact = function(artifact) {
                landscapeR:::.k1_acceptance_runner_abort(
                    "synthetic semantic rejection"
                )
            },
            .package = "landscapeR"
        ),
        "synthetic semantic rejection",
        class = "k1_acceptance_runner_error"
    )
    expect_length(list.files(root, all.files = TRUE, no.. = TRUE), 0L)
})

test_that("calibration artifact verification detects tampering", {
    fixture <- calibration_outcome_fixture()
    testthat::local_mocked_bindings(
        .k1_calibration_runtime_identity = function() list(
            source_revision = strrep("a", 40L), r_version = "4.5.2",
            package_versions = c(landscapeR = "0.3.0")
        ), .package = "landscapeR"
    )
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

test_that("calibration artifact verification detects missing payload", {
    fixture <- calibration_outcome_fixture()
    testthat::local_mocked_bindings(
        .k1_calibration_runtime_identity = function() list(
            source_revision = strrep("a", 40L), r_version = "4.5.2",
            package_versions = c(landscapeR = "0.3.0")
        ), .package = "landscapeR"
    )
    artifact <- publish_k1_calibration_outcomes(
        tempfile("k1-calibration-artifacts-"),
        fixture$results,
        fixture$tasks,
        fixture$protocol
    )
    unlink(file.path(artifact, "assessment.rds"))

    expect_error(
        verify_k1_calibration_outcomes(artifact),
        class = "k1_acceptance_runner_error"
    )
})

test_that("calibration artifact verification rejects undeclared files", {
    fixture <- calibration_outcome_fixture()
    testthat::local_mocked_bindings(
        .k1_calibration_runtime_identity = function() list(
            source_revision = strrep("a", 40L), r_version = "4.5.2",
            package_versions = c(landscapeR = "0.3.0")
        ), .package = "landscapeR"
    )
    artifact <- publish_k1_calibration_outcomes(
        tempfile("k1-calibration-artifacts-"),
        fixture$results,
        fixture$tasks,
        fixture$protocol
    )
    writeLines("undeclared", file.path(artifact, "extra.txt"))

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
    assessment <- assess_k1_calibration_outcomes(
        fixture$results, fixture$tasks, fixture$protocol)
    assessment$replicates$canonical_cell <- NULL
    payload <- unclass(assessment)
    payload$digest <- NULL
    assessment$digest <- digest::digest(payload, algo = "sha256")
    expect_error(
        plot_k1_calibration_outcomes(assessment),
        class = "landscapeR_validation_error"
    )
    assessment <- assess_k1_calibration_outcomes(
        fixture$results, fixture$tasks, fixture$protocol)
    assessment$replicates$recovery_evaluable[[1L]] <- NA
    payload <- unclass(assessment)
    payload$digest <- NULL
    assessment$digest <- digest::digest(payload, algo = "sha256")
    expect_error(
        plot_k1_calibration_outcomes(assessment),
        class = "landscapeR_validation_error"
    )
    assessment <- assess_k1_calibration_outcomes(
        fixture$results, fixture$tasks, fixture$protocol)
    assessment$source_protocol_id <- "invented"
    payload <- unclass(assessment)
    payload$digest <- NULL
    assessment$digest <- digest::digest(payload, algo = "sha256")
    expect_error(
        plot_k1_calibration_outcomes(assessment),
        class = "landscapeR_validation_error"
    )
    assessment <- assess_k1_calibration_outcomes(
        fixture$results, fixture$tasks, fixture$protocol)
    assessment$replicates$outcome[[2L]] <- "execution_failure"
    assessment$cells <- landscapeR:::.k1_calibration_cell_rows(
        assessment$replicates)
    payload <- unclass(assessment)
    payload$digest <- NULL
    assessment$digest <- digest::digest(payload, algo = "sha256")
    expect_error(
        plot_k1_calibration_outcomes(assessment),
        class = "landscapeR_validation_error"
    )
    assessment <- assess_k1_calibration_outcomes(
        fixture$results, fixture$tasks, fixture$protocol)
    assessment$replicates$downstream_estimable[[3L]] <- TRUE
    assessment$cells <- landscapeR:::.k1_calibration_cell_rows(
        assessment$replicates)
    payload <- unclass(assessment)
    payload$digest <- NULL
    assessment$digest <- digest::digest(payload, algo = "sha256")
    expect_error(
        plot_k1_calibration_outcomes(assessment),
        class = "landscapeR_validation_error"
    )
})
