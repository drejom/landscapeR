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
    expect_match(caption, "complete-subject axis bootstrap")
    expect_match(caption, "cm1 at time 2, cm1 at time 3")
    expect_match(caption, "crosses mark a scientific quantity")
    expect_false(grepl(caption, paste(capture.output(print(plot)), collapse = "\n"),
        fixed = TRUE))
})

test_that("repeated-subject future execution matches sequential evidence", {
    skip_if_not_installed("future")
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
