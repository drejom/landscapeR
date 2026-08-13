test_that("governed destructive templates cover thin, unequal, and damaged designs", {
    templates <- k1_independent_time_course_template()

    expect_identical(names(templates), c(
        "balanced_1", "balanced_2", "balanced_3", "unequal_1_2_3",
        "isolated_library_failure", "missing_internal_cell"
    ))
    expect_equal(templates$balanced_1$retained_cells, matrix(
        1L, 2L, 4L,
        dimnames = list(c("CTL", "CM"), as.character(0:3))
    ))
    expect_setequal(
        as.integer(templates$unequal_1_2_3$retained_cells), 1:3
    )
    expect_identical(
        templates$isolated_library_failure$intended_cells["CM", "2"], 3L
    )
    expect_identical(
        templates$isolated_library_failure$retained_cells["CM", "2"], 2L
    )
    expect_identical(
        templates$isolated_library_failure$removed_observations$reason,
        "sequencing_library_failure"
    )
    expect_identical(
        templates$missing_internal_cell$retained_cells["CM", "2"], 0L
    )
    expect_error(
        k1_independent_time_course_template("unknown"),
        class = "landscapeR_validation_error"
    )
})

test_that("destructive controls are deterministic and retain exact sampling audits", {
    first <- synthetic_k1_independent_time_course_control(
        "isolated_library_failure", p = 30L, seed = 18901L
    )
    second <- synthetic_k1_independent_time_course_control(
        "isolated_library_failure", p = 30L, seed = 18901L
    )

    expect_identical(first, second)
    expect_identical(first@sampling_design@kind, "independent_time_course")
    expect_identical(first@sampling_design@subject_id_col, character())
    expect_identical(first@sampling_design@time_col, "collection_time")
    expect_s4_class(first@ground_truth, "K1IndependentTimeCourseGroundTruth")
    expect_equal(dim(assay(experiments(first)[[1L]])), c(30L, 23L))
    units <- as.character(colData(first)$biological_unit)
    expect_length(unique(units), 23L)
    expect_identical(anyDuplicated(units), 0L)
    info <- k1_independent_time_course_control_info(first)
    expect_identical(info$sampling$n_intended, 24L)
    expect_identical(info$sampling$n_retained, 23L)
    expect_identical(info$sampling$retained_cells["CM", "2"], 2L)
    expect_identical(
        info$sampling$missingness, "isolated_library_failure"
    )
    expect_identical(
        first@provenance[[1L]]@implementation,
        "k1_independent_destructive_time_course_v1"
    )
})

test_that("missing internal cells remain absent without imputation or rebalancing", {
    control <- synthetic_k1_independent_time_course_control(
        "missing_internal_cell", p = 20L, seed = 18902L
    )
    observed <- table(
        factor(colData(control)$condition, levels = c("CTL", "CM")),
        factor(colData(control)$collection_time, levels = 0:3)
    )
    expected <- k1_independent_time_course_template(
        "missing_internal_cell"
    )$retained_cells

    expect_equal(unname(observed), unname(expected))
    expect_identical(sum(observed), 14L)
    expect_identical(observed["CM", "2"], 0L)
    expect_identical(
        k1_independent_time_course_control_info(control)$sampling$
            mean_retained_per_declared_cell,
        1.75
    )
})

test_that("destructive control validation rejects invalid scientific inputs", {
    expect_error(
        synthetic_k1_independent_time_course_control(p = 1L),
        class = "landscapeR_validation_error"
    )
    expect_error(
        run_k1_independent_time_course_calibration(
            p = 1L, replicates = 1L
        ),
        class = "landscapeR_validation_error"
    )
    expect_error(
        synthetic_k1_independent_time_course_control(
            time_signal = 2, condition_time_signal = 2
        ),
        class = "landscapeR_validation_error"
    )
    expect_error(
        k1_independent_time_course_control_info(
            synthetic_k1_aml_longitudinal_control(
                subjects_per_condition = 3L, times = 0:3, p = 10L
            )
        ),
        class = "landscapeR_validation_error"
    )
})

test_that("governed calibration separates recovery from downstream estimability", {
    assessment <- run_k1_independent_time_course_calibration(
        template_ids = c(
            "balanced_1", "balanced_3", "isolated_library_failure",
            "missing_internal_cell"
        ),
        replicates = 2L,
        p = 30L,
        seed = 18903L,
        sequential_internal = TRUE
    )

    expect_s3_class(assessment, "K1IndependentTimeCourseAssessment")
    expect_match(assessment$digest, "^[0-9a-f]{64}$")
    expect_identical(assessment$claim_status, "disclosed_calibration_only")
    expect_identical(assessment$execution$account$n_requested, 8L)
    expect_identical(assessment$execution$account$n_completed, 8L)
    expect_true(all(assessment$replicates$recovery_met))
    thin <- assessment$replicates$template_id == "balanced_1"
    expect_true(all(
        assessment$replicates$outcome[thin] ==
            "recovered_downstream_nonestimable"
    ))
    expect_identical(
        assessment$cells$downstream_estimability_probability[
            assessment$cells$template_id == "balanced_1"
        ],
        0
    )
    damaged <- assessment$cells[
        assessment$cells$template_id == "isolated_library_failure", ,
        drop = FALSE
    ]
    expect_identical(damaged$n_intended, 24L)
    expect_identical(damaged$n_retained, 23L)
    missing <- assessment$cells[
        assessment$cells$template_id == "missing_internal_cell", ,
        drop = FALSE
    ]
    expect_identical(missing$mean_retained_per_declared_cell, 1.75)

    contradictory_audit <- assessment
    contradictory_audit$sampling_audit$balanced_1 <-
        k1_independent_time_course_template("balanced_2")
    payload <- unclass(contradictory_audit)
    payload$digest <- NULL
    contradictory_audit$digest <- digest::digest(payload, algo = "sha256")
    expect_error(
        plot_k1_independent_time_course_calibration(contradictory_audit),
        class = "landscapeR_validation_error"
    )

    inconsistent <- assessment
    inconsistent$cells$recovery_probability[[1L]] <- 0.123
    payload <- unclass(inconsistent)
    payload$digest <- NULL
    inconsistent$digest <- digest::digest(payload, algo = "sha256")
    expect_error(
        plot_k1_independent_time_course_calibration(inconsistent),
        class = "landscapeR_validation_error"
    )

    contradictory_outcome <- assessment
    recovered <- which(contradictory_outcome$replicates$recovery_met %in% TRUE)[[1L]]
    contradictory_outcome$replicates$outcome[[recovered]] <-
        "recovery_below_threshold"
    contradictory_outcome$cells <-
        landscapeR:::.k1_independent_time_cell_summary(
            contradictory_outcome$replicates
        )
    payload <- unclass(contradictory_outcome)
    payload$digest <- NULL
    contradictory_outcome$digest <- digest::digest(payload, algo = "sha256")
    expect_error(
        plot_k1_independent_time_course_calibration(contradictory_outcome),
        class = "landscapeR_validation_error"
    )

    contradictory_context <- assessment
    contradictory_context$scientific_context$target_field <- "wrong_target"
    payload <- unclass(contradictory_context)
    payload$digest <- NULL
    contradictory_context$digest <- digest::digest(payload, algo = "sha256")
    expect_error(
        plot_k1_independent_time_course_calibration(contradictory_context),
        class = "landscapeR_validation_error"
    )

    contradictory_execution <- assessment
    contradictory_execution$replicates$target_loading_cosine[[1L]] <- 0.1
    contradictory_execution$replicates$recovery_met[[1L]] <- FALSE
    contradictory_execution$replicates$downstream_estimable[[1L]] <- NA
    contradictory_execution$replicates$outcome[[1L]] <-
        "recovery_below_threshold"
    contradictory_execution$cells <-
        landscapeR:::.k1_independent_time_cell_summary(
            contradictory_execution$replicates
        )
    payload <- unclass(contradictory_execution)
    payload$digest <- NULL
    contradictory_execution$digest <- digest::digest(payload, algo = "sha256")
    expect_error(
        plot_k1_independent_time_course_calibration(contradictory_execution),
        class = "landscapeR_validation_error"
    )
})

test_that("typed association abstention remains scientific non-estimability", {
    testthat::local_mocked_bindings(
        associate_metadata = function(...) structure(
            list(diagnostic = "declared design is non-identifiable"),
            class = "mock_association_abstention"
        ),
        is = function(object, class2) {
            if (identical(class2, "AssociationAbstention") &&
                    inherits(object, "mock_association_abstention")) {
                return(TRUE)
            }
            methods::is(object, class2)
        },
        association_abstention_diagnostic = function(abstention) {
            abstention$diagnostic
        },
        .package = "landscapeR"
    )
    result <- landscapeR:::.k1_independent_time_assess_one(
        "balanced_3", p = 20L, noise_sd = 0.03,
        time_signal = 8, condition_time_signal = 3,
        seed = 18908L, recovery_threshold = 0
    )

    expect_true(result$execution_completed)
    expect_identical(result$outcome, "recovered_downstream_nonestimable")
    expect_identical(result$diagnostic, "declared design is non-identifiable")
})

test_that("operating map exposes exact evidence and a separate scientific caption", {
    assessment <- run_k1_independent_time_course_calibration(
        template_ids = c("balanced_1", "isolated_library_failure"),
        replicates = 1L,
        p = 20L,
        seed = 18904L,
        sequential_internal = TRUE
    )
    plot <- plot_k1_independent_time_course_calibration(assessment)
    display <- attr(plot, "landscapeR_k1_operating_map_data")
    caption <- scientific_caption(plot)

    expect_s3_class(plot, "ggplot")
    expect_s3_class(display, "data.frame")
    expect_identical(nrow(display), 4L)
    expect_setequal(unique(display$template_id),
        c("balanced_1", "isolated_library_failure"))
    expect_match(caption, "independently\\s+collected animal")
    expect_match(caption, "isolated_library_failure")
    expect_match(caption, "without imputation")
    expect_match(caption, "or rebalancing")
    expect_match(caption, "not an")
    expect_match(caption, "acceptance result")
    expect_false(grepl(caption, paste(capture.output(print(plot)), collapse = " "),
        fixed = TRUE))
})

test_that("calibration artifacts reproduce typed and visual derivatives", {
    skip_if_not_installed("targets")
    testthat::local_mocked_bindings(
        .k1_calibration_runtime_identity = function() list(
            source_revision = strrep("1", 40L),
            r_version = "4.5",
            package_versions = c(landscapeR = "0.0.0.9000")
        ),
        .package = "landscapeR"
    )
    assessment <- run_k1_independent_time_course_calibration(
        template_ids = c("balanced_1", "isolated_library_failure"),
        replicates = 1L,
        p = 20L,
        seed = 18905L,
        sequential_internal = TRUE
    )
    root <- tempfile("k1-independent-time-artifacts-")
    dir.create(root)
    artifact <- publish_k1_independent_time_course_calibration(root, assessment)

    expect_true(verify_k1_independent_time_course_calibration(artifact))
    expect_true(all(file.exists(file.path(artifact, c(
        "assessment.rds", "replicates.csv", "cell-summary.csv",
        "operating-map-data.csv", "operating-map.png",
        "operating-map-caption.txt", "environment.rds", "MANIFEST.tsv"
    )))))
    pipeline <- k1_independent_time_course_calibration_targets(
        artifact_root = normalizePath(root),
        template_ids = "balanced_1",
        replicates = 1L,
        p = 20L,
        seed = 18906L
    )
    expect_length(pipeline, 2L)
    expect_identical(
        vapply(pipeline, function(target) target$settings$name, character(1L)),
        c("k1_independent_time_assessment", "k1_independent_time_artifact")
    )
    undeclared <- file.path(artifact, "undeclared.txt")
    writeLines("not governed", undeclared)
    expect_error(
        verify_k1_independent_time_course_calibration(artifact),
        "undeclared files",
        class = "k1_acceptance_runner_error"
    )
    unlink(undeclared)

    environment_path <- file.path(artifact, "environment.rds")
    manifest_path <- file.path(artifact, "MANIFEST.tsv")
    environment <- readRDS(environment_path)
    original_environment <- environment
    original_manifest <- readLines(manifest_path, warn = FALSE)
    environment$runtime_identity$source_revision <- "invalid"
    saveRDS(environment, environment_path)
    manifest <- utils::read.delim(manifest_path,
        stringsAsFactors = FALSE, check.names = FALSE)
    manifest$sha256[manifest$file == "environment.rds"] <-
        landscapeR:::.k1_acceptance_file_digest(environment_path)
    utils::write.table(manifest, manifest_path, sep = "\t", quote = FALSE,
        row.names = FALSE)
    expect_error(
        verify_k1_independent_time_course_calibration(artifact),
        class = "k1_acceptance_runner_error"
    )
    saveRDS(original_environment, environment_path)
    writeLines(original_manifest, manifest_path)

    derivatives_path <- file.path(artifact, "cell-summary.csv")
    original_derivatives <- readLines(derivatives_path, warn = FALSE)
    writeLines(c(original_derivatives, "changed"), derivatives_path)
    manifest <- utils::read.delim(manifest_path,
        stringsAsFactors = FALSE, check.names = FALSE)
    manifest$sha256[manifest$file == "cell-summary.csv"] <-
        landscapeR:::.k1_acceptance_file_digest(derivatives_path)
    utils::write.table(manifest, manifest_path, sep = "\t", quote = FALSE,
        row.names = FALSE)
    expect_error(
        verify_k1_independent_time_course_calibration(artifact),
        "derivatives",
        class = "k1_acceptance_runner_error"
    )
    writeLines(original_derivatives, derivatives_path)
    writeLines(original_manifest, manifest_path)

    writeLines(c("file\tsha256", '"unterminated'), manifest_path)
    expect_error(
        verify_k1_independent_time_course_calibration(artifact),
        "manifest or digests are invalid",
        class = "k1_acceptance_runner_error"
    )
    writeLines(original_manifest, manifest_path)

    assessment_path <- file.path(artifact, "assessment.rds")
    original_assessment <- readBin(
        assessment_path, what = "raw", n = file.info(assessment_path)$size
    )
    writeLines("not an RDS payload", assessment_path)
    manifest <- utils::read.delim(manifest_path,
        stringsAsFactors = FALSE, check.names = FALSE)
    manifest$sha256[manifest$file == "assessment.rds"] <-
        landscapeR:::.k1_acceptance_file_digest(assessment_path)
    utils::write.table(manifest, manifest_path, sep = "\t", quote = FALSE,
        row.names = FALSE)
    expect_error(
        verify_k1_independent_time_course_calibration(artifact),
        "manifest or digests are invalid",
        class = "k1_acceptance_runner_error"
    )
    writeBin(original_assessment, assessment_path)
    writeLines(original_manifest, manifest_path)

    saveRDS("not an environment envelope", environment_path)
    manifest <- utils::read.delim(manifest_path,
        stringsAsFactors = FALSE, check.names = FALSE)
    manifest$sha256[manifest$file == "environment.rds"] <-
        landscapeR:::.k1_acceptance_file_digest(environment_path)
    utils::write.table(manifest, manifest_path, sep = "\t", quote = FALSE,
        row.names = FALSE)
    expect_error(
        verify_k1_independent_time_course_calibration(artifact),
        "manifest or digests are invalid",
        class = "k1_acceptance_runner_error"
    )
    saveRDS(original_environment, environment_path)
    writeLines(original_manifest, manifest_path)

    testthat::local_mocked_bindings(
        .k1_calibration_atomic_move = function(from, to) FALSE,
        .package = "landscapeR"
    )
    expect_error(
        publish_k1_independent_time_course_calibration(
            tempfile("k1-atomic-failure-"), assessment
        ),
        "atomically publish",
        class = "k1_acceptance_runner_error"
    )

    changed <- readRDS(file.path(artifact, "assessment.rds"))
    changed$replicates$diagnostic[[1L]] <- "changed"
    payload <- unclass(changed)
    payload$digest <- NULL
    changed$digest <- digest::digest(payload, algo = "sha256")
    saveRDS(changed, file.path(artifact, "assessment.rds"))
    expect_error(
        verify_k1_independent_time_course_calibration(artifact),
        class = "k1_acceptance_runner_error"
    )
})

test_that("scientific calibration is invariant across future backends", {
    skip_if_not_installed("future")
    previous <- future::plan()
    on.exit(future::plan(previous), add = TRUE)
    arguments <- list(
        template_ids = c("balanced_1", "isolated_library_failure"),
        replicates = 1L, p = 20L, seed = 18907L
    )
    future::plan(future::sequential)
    sequential <- do.call(run_k1_independent_time_course_calibration,
        arguments)
    skip_if(
        pkgload::is_dev_package("landscapeR"),
        "multisession requires the installed-package check context"
    )
    available <- suppressWarnings(tryCatch({
        future::plan(future::multisession, workers = 2L)
        identical(future::value(future::future(TRUE)), TRUE)
    }, error = function(condition) FALSE))
    if (!available) {
        if (nzchar(Sys.getenv("CI"))) {
            testthat::fail("CI must provide a working multisession backend")
        }
        skip("multisession workers are unavailable in this test context")
    }
    parallel <- do.call(run_k1_independent_time_course_calibration,
        arguments)

    expect_identical(parallel, sequential)
})
