test_that("repeated-subject templates preserve exact subject-time removals", {
    templates <- k1_repeated_subject_template()

    expect_identical(names(templates), c(
        "complete", "isolated_observation_loss", "terminal_dropout",
        "condition_dependent_loss"
    ))
    expect_identical(
        nrow(templates$complete$retained_observations), 32L
    )
    expect_identical(
        nrow(templates$isolated_observation_loss$removed_observations), 1L
    )
    expect_identical(
        templates$terminal_dropout$removed_observations$weeks, c(2, 3)
    )
    expect_true(all(
        templates$condition_dependent_loss$removed_observations$condition ==
            "CM"
    ))
    expect_true(all(vapply(templates, function(template) {
        identical(template$resampling_unit, "complete subject trajectory") &&
            identical(template$sampling_design, "longitudinal")
    }, logical(1L))))
    expect_error(
        k1_repeated_subject_template("unknown"),
        class = "landscapeR_validation_error"
    )
})

test_that("repeated-subject generator is deterministic and auditable", {
    first <- synthetic_k1_repeated_subject_control(
        "terminal_dropout", p = 20L, seed = 19001L
    )
    second <- synthetic_k1_repeated_subject_control(
        "terminal_dropout", p = 20L, seed = 19001L
    )

    expect_identical(first, second)
    expect_identical(first@sampling_design@kind, "longitudinal")
    expect_identical(first@sampling_design@subject_id_col, "mouse_id")
    expect_identical(first@sampling_design@time_col, "weeks")
    expect_equal(dim(assay(experiments(first)[[1L]])), c(20L, 30L))
    info <- k1_repeated_subject_control_info(first)
    expect_identical(info$n_intended, 32L)
    expect_identical(info$n_retained, 30L)
    expect_identical(
        info$template$removed_observations$reason,
        rep("terminal_dropout", 2L)
    )
    observed <- as.data.frame(colData(first))
    expect_false(any(
        observed$mouse_id == "cm1" & observed$weeks %in% c(2, 3)
    ))
    expect_true(any(vapply(first@provenance, function(record) {
        identical(record@implementation,
            "k1_incomplete_repeated_subject_v1")
    }, logical(1L))))
})

test_that("explicit removal validation rejects ambiguous sampling damage", {
    expect_error(
        synthetic_k1_aml_longitudinal_control(
            subjects_per_condition = 4L, times = 0:3, p = 10L,
            removed_observations = data.frame(
                mouse_id = "unknown", weeks = 2, reason = "failure",
                stringsAsFactors = FALSE
            )
        ),
        class = "landscapeR_validation_error"
    )
    expect_error(
        synthetic_k1_aml_longitudinal_control(
            subjects_per_condition = 4L, times = 0:3, p = 10L,
            dropout_subjects = "cm1",
            removed_observations = data.frame(
                mouse_id = "cm1", weeks = 3, reason = "duplicate",
                stringsAsFactors = FALSE
            )
        ),
        "overlap",
        class = "landscapeR_validation_error"
    )
})

test_that("operating evidence separates recovery, identifiability, and model support", {
    assessment <- run_k1_repeated_subject_calibration(
        replicates = 1L, p = 20L, axis_resamples = 2L,
        seed = 19002L, sequential_internal = TRUE
    )

    expect_s3_class(assessment, "K1RepeatedSubjectAssessment")
    expect_match(assessment$digest, "^[0-9a-f]{64}$")
    expect_identical(assessment$execution$account$n_requested, 4L)
    expect_identical(assessment$execution$account$n_completed, 4L)
    expect_true(all(assessment$replicates$recovery_met))
    complete <- assessment$replicates$template_id == "complete"
    isolated <- assessment$replicates$template_id ==
        "isolated_observation_loss"
    dropout <- assessment$replicates$template_id %in% c(
        "terminal_dropout", "condition_dependent_loss"
    )
    expect_true(all(assessment$replicates$model_estimable[complete | isolated]))
    expect_false(any(assessment$replicates$model_estimable[dropout]))
    expect_true(all(
        assessment$replicates$outcome[dropout] ==
            "recovered_downstream_nonestimable"
    ))
    expect_true(all(grepl(
        "fewer-than-three-observations-per-subject",
        assessment$replicates$model_diagnostic[dropout]
    )))
    evidence <- assessment$execution$values[[which(complete)]]$evidence
    expect_s3_class(evidence, "K1RepeatedSubjectReplicateEvidence")
    expect_identical(
        evidence$identifiability$resampling_unit,
        "complete-subject-trajectory"
    )
    expect_identical(
        evidence$identifiability$resampling_method,
        "condition-stratified-subject-trajectory-bootstrap"
    )
    expect_identical(evidence$identifiability$n_requested, 2L)
    expect_identical(evidence$identifiability$n_completed, 2L)
    expect_identical(
        evidence$metadata_nomination$nominated_component,
        assessment$replicates$nominated_component[complete][[1L]]
    )
    expect_true(all(vapply(
        assessment$execution$values,
        function(value) {
            is.list(value$evidence$identifiability$replicates) &&
                length(value$evidence$identifiability$replicates) == 2L
        }, logical(1L)
    )))

    contradictory_audit <- assessment
    contradictory_audit$sampling_audit$complete <-
        k1_repeated_subject_template("terminal_dropout")
    payload <- unclass(contradictory_audit)
    payload$digest <- NULL
    contradictory_audit$digest <- digest::digest(payload, algo = "sha256")
    expect_error(
        plot_k1_repeated_subject_calibration(contradictory_audit),
        class = "landscapeR_validation_error"
    )

    contradictory_outcome <- assessment
    contradictory_outcome$replicates$outcome[[1L]] <-
        "recovery_below_threshold"
    contradictory_outcome$cells <-
        landscapeR:::.k1_repeated_cell_summary(
            contradictory_outcome$replicates
        )
    payload <- unclass(contradictory_outcome)
    payload$digest <- NULL
    contradictory_outcome$digest <- digest::digest(payload, algo = "sha256")
    expect_error(
        plot_k1_repeated_subject_calibration(contradictory_outcome),
        class = "landscapeR_validation_error"
    )

    contradictory_nested <- assessment
    contradictory_nested$execution$values[[1L]]$evidence$
        identifiability$n_completed <- 999L
    execution_payload <- contradictory_nested$execution[
        c("values", "account", "provenance")
    ]
    contradictory_nested$execution$digest <- digest::digest(
        execution_payload, algo = "sha256", serialize = TRUE
    )
    payload <- unclass(contradictory_nested)
    payload$digest <- NULL
    contradictory_nested$digest <- digest::digest(payload, algo = "sha256")
    expect_error(
        plot_k1_repeated_subject_calibration(contradictory_nested),
        class = "landscapeR_validation_error"
    )

    contradictory_provenance <- assessment
    contradictory_provenance$execution$values[[1L]]$evidence$
        identifiability$replicates[[1L]]$target_replicate_component <- 999L
    execution_payload <- contradictory_provenance$execution[
        c("values", "account", "provenance")
    ]
    contradictory_provenance$execution$digest <- digest::digest(
        execution_payload, algo = "sha256", serialize = TRUE
    )
    payload <- unclass(contradictory_provenance)
    payload$digest <- NULL
    contradictory_provenance$digest <- digest::digest(
        payload, algo = "sha256"
    )
    expect_error(
        plot_k1_repeated_subject_calibration(contradictory_provenance),
        class = "landscapeR_validation_error"
    )

    invented_draws <- assessment
    nested <- invented_draws$execution$values[[1L]]$evidence$identifiability
    nested$replicates[[1L]]$source_primary[] <- "invented_sample"
    nested$replicates[[1L]]$replicate_subject[] <- "invented_subject"
    observed_draws <- lapply(nested$replicates, function(replicate) list(
        source_primary = replicate$source_primary,
        replicate_subject = replicate$replicate_subject
    ))
    nested$plan_digest <- digest::digest(list(
        method = nested$resampling_method,
        unit = nested$resampling_unit,
        n_requested = nested$n_requested,
        draws = observed_draws
    ), algo = "sha256", serialize = TRUE)
    invented_draws$execution$values[[1L]]$evidence$identifiability <- nested
    execution_payload <- invented_draws$execution[
        c("values", "account", "provenance")
    ]
    invented_draws$execution$digest <- digest::digest(
        execution_payload, algo = "sha256", serialize = TRUE
    )
    payload <- unclass(invented_draws)
    payload$digest <- NULL
    invented_draws$digest <- digest::digest(payload, algo = "sha256")
    expect_error(
        plot_k1_repeated_subject_calibration(invented_draws),
        class = "landscapeR_validation_error"
    )

    nested_row_mismatches <- list(
        recovery = function(x) {
            x$replicates$target_loading_cosine[[1L]] <- 0.123
            x
        },
        model = function(x) {
            x$replicates$model_estimable[[1L]] <- FALSE
            x
        },
        identifiability = function(x) {
            x$replicates$axis_refits_completed[[1L]] <- 0L
            x
        },
        nomination = function(x) {
            x$replicates$nomination_agrees_with_target[[1L]] <-
                !x$replicates$nomination_agrees_with_target[[1L]]
            x
        }
    )
    for (mutate_assessment in nested_row_mismatches) {
        contradictory <- mutate_assessment(assessment)
        contradictory$cells <- landscapeR:::.k1_repeated_cell_summary(
            contradictory$replicates
        )
        payload <- unclass(contradictory)
        payload$digest <- NULL
        contradictory$digest <- digest::digest(payload, algo = "sha256")
        expect_error(
            plot_k1_repeated_subject_calibration(contradictory),
            class = "landscapeR_validation_error"
        )
    }

    invalid_statuses <- list(
        recovery = c("recovery", "status"),
        model = c("repeated_subject_model", "status"),
        nomination = c("metadata_nomination", "status")
    )
    for (path in invalid_statuses) {
        contradictory <- assessment
        contradictory$execution$values[[1L]]$evidence[[path[[1L]]]][
            path[[2L]]
        ] <- "garbage"
        execution_payload <- contradictory$execution[
            c("values", "account", "provenance")
        ]
        contradictory$execution$digest <- digest::digest(
            execution_payload, algo = "sha256", serialize = TRUE
        )
        payload <- unclass(contradictory)
        payload$digest <- NULL
        contradictory$digest <- digest::digest(payload, algo = "sha256")
        expect_error(
            plot_k1_repeated_subject_calibration(contradictory),
            class = "landscapeR_validation_error"
        )
    }

    contradictory_account <- assessment
    contradictory_account$execution$account$completed[[1L]] <- FALSE
    execution_payload <- contradictory_account$execution[
        c("values", "account", "provenance")
    ]
    contradictory_account$execution$digest <- digest::digest(
        execution_payload, algo = "sha256", serialize = TRUE
    )
    payload <- unclass(contradictory_account)
    payload$digest <- NULL
    contradictory_account$digest <- digest::digest(payload, algo = "sha256")
    expect_error(
        plot_k1_repeated_subject_calibration(contradictory_account),
        class = "landscapeR_validation_error"
    )
})

test_that("target-axis bootstrap remains independent of model abstention", {
    assessment <- run_k1_repeated_subject_calibration(
        template_ids = "terminal_dropout", replicates = 1L,
        p = 20L, axis_resamples = 3L, seed = 19006L,
        sequential_internal = TRUE
    )

    expect_false(assessment$replicates$model_estimable[[1L]])
    expect_true(assessment$replicates$axis_identifiability_evaluable[[1L]])
    expect_identical(
        assessment$execution$values[[1L]]$evidence$identifiability$n_requested,
        3L
    )
    expect_identical(
        assessment$execution$values[[1L]]$evidence$identifiability$n_completed,
        3L
    )
})

test_that("partial target-axis bootstrap evidence remains visible", {
    assessment <- run_k1_repeated_subject_calibration(
        template_ids = "complete", replicates = 1L,
        p = 20L, axis_resamples = 3L, seed = 19008L,
        sequential_internal = TRUE
    )
    evidence <- assessment$execution$values[[1L]]$evidence$identifiability
    evidence$replicates[[1L]]$status <- "execution_failure"
    evidence$replicates[[1L]]$target_absolute_similarity <- NA_real_
    evidence$replicates[[1L]]$target_replicate_component <- NA_integer_
    evidence$replicates[[1L]]$assignment_margin <- NA_real_
    evidence$replicates[[1L]]$diagnostic <- "declared-test-interruption"
    evidence$n_completed <- 2L
    evidence$status <- "partial"
    evidence$mean_absolute_similarity <- mean(vapply(
        evidence$replicates[-1L],
        function(replicate) replicate$target_absolute_similarity,
        numeric(1L)
    ))
    assessment$execution$values[[1L]]$evidence$identifiability <- evidence
    assessment$execution$values[[1L]]$row$
        axis_identifiability_evaluable <- TRUE
    assessment$execution$values[[1L]]$row$
        axis_mean_absolute_similarity <- evidence$mean_absolute_similarity
    assessment$execution$values[[1L]]$row$axis_refits_completed <- 2L
    assessment$replicates$axis_identifiability_evaluable[[1L]] <- TRUE
    assessment$replicates$axis_mean_absolute_similarity[[1L]] <-
        evidence$mean_absolute_similarity
    assessment$replicates$axis_refits_completed[[1L]] <- 2L
    assessment$cells <- landscapeR:::.k1_repeated_cell_summary(
        assessment$replicates
    )
    execution_payload <- assessment$execution[
        c("values", "account", "provenance")
    ]
    assessment$execution$digest <- digest::digest(
        execution_payload, algo = "sha256", serialize = TRUE
    )
    payload <- unclass(assessment)
    payload$digest <- NULL
    assessment$digest <- digest::digest(payload, algo = "sha256")

    plot <- plot_k1_repeated_subject_calibration(assessment)
    display <- attr(plot, "landscapeR_k1_repeated_map_data")
    axis_row <- display$panel == "B  Axis identifiability"
    expect_equal(
        display$probability[axis_row], evidence$mean_absolute_similarity
    )
    expect_identical(
        as.character(display$execution_state[axis_row]),
        "Partial computation"
    )
})

test_that("nested bootstrap results do not depend on warnings-as-errors", {
    old_warning <- getOption("warn")
    on.exit(options(warn = old_warning), add = TRUE)
    options(warn = 2)

    assessment <- run_k1_repeated_subject_calibration(
        template_ids = "complete", replicates = 1L,
        p = 20L, axis_resamples = 2L, seed = 19007L,
        sequential_internal = TRUE
    )

    expect_true(assessment$replicates$execution_completed[[1L]])
    expect_identical(assessment$execution$account$n_failed, 0L)
})

test_that("repeated-subject calibration preserves caller RNG state", {
    set.seed(919L)
    before <- .Random.seed
    invisible(run_k1_repeated_subject_calibration(
        template_ids = "complete", replicates = 1L,
        p = 20L, axis_resamples = 1L, seed = 19009L,
        sequential_internal = TRUE
    ))
    expect_identical(.Random.seed, before)
})

test_that("repeated-subject operating map has exact data and separate caption", {
    assessment <- run_k1_repeated_subject_calibration(
        template_ids = c("complete", "terminal_dropout"),
        replicates = 1L, p = 20L, axis_resamples = 1L,
        seed = 19003L, sequential_internal = TRUE
    )
    plot <- plot_k1_repeated_subject_calibration(assessment)
    display <- attr(plot, "landscapeR_k1_repeated_map_data")
    caption <- scientific_caption(plot)

    expect_s3_class(plot, "ggplot")
    expect_identical(nrow(display), 6L)
    expect_setequal(as.character(display$panel), c(
        "A  Target-axis recovery", "B  Axis identifiability",
        "C  Random-slope model estimability"
    ))
    expect_match(caption, "complete-subject target-axis bootstrap")
    expect_match(caption, "cm1 at time 2, cm1 at time 3")
    expect_match(caption, "crosses mark a scientific quantity")
    expect_false(grepl(caption, paste(capture.output(print(plot)), collapse = "\n"),
        fixed = TRUE))
})

test_that("repeated-subject future execution matches sequential evidence", {
    skip_if_not_installed("future")
    skip_if(
        pkgload::is_dev_package("landscapeR"),
        "multisession requires the installed-package check context"
    )
    old_plan <- future::plan()
    on.exit(future::plan(old_plan), add = TRUE)
    backend_available <- tryCatch({
        suppressWarnings(future::plan(future::multisession, workers = 2L))
        probe <- future::value(future::future(1L))
        identical(probe, 1L)
    }, error = function(condition) FALSE)
    future::plan(old_plan)
    skip_if_not(backend_available, "multisession worker is unavailable")
    sequential <- run_k1_repeated_subject_calibration(
        template_ids = c("complete", "terminal_dropout"),
        replicates = 1L, p = 20L, axis_resamples = 1L,
        seed = 19004L, sequential_internal = TRUE
    )
    suppressWarnings(future::plan(future::multisession, workers = 2L))
    parallel <- run_k1_repeated_subject_calibration(
        template_ids = c("complete", "terminal_dropout"),
        replicates = 1L, p = 20L, axis_resamples = 1L,
        seed = 19004L
    )

    expect_identical(parallel$replicates, sequential$replicates)
    expect_identical(parallel$cells, sequential$cells)
    expect_identical(parallel$digest, sequential$digest)
})

test_that("repeated-subject targets graph remains backend-neutral", {
    skip_if_not_installed("targets")
    graph <- k1_repeated_subject_calibration_targets(
        artifact_root = normalizePath(tempdir()),
        controller = "gemini-repeated-subject",
        replicates = 1L, axis_resamples = 1L
    )

    expect_length(graph, 2L)
    expect_identical(
        vapply(graph, function(target) target$settings$name, character(1L)),
        c("k1_repeated_subject_assessment", "k1_repeated_subject_artifact")
    )
    expect_identical(graph[[1L]]$settings$deployment, "worker")
})
