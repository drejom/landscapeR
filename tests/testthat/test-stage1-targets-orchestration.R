test_that("crew controller factory keeps scheduler policy explicit", {
    skip_if_not_installed("crew")
    skip_if_not_installed("crew.cluster")

    local <- stage1_crew_controller(
        scheduler = "local",
        name = "stage1-evidence",
        workers = 2L
    )
    expect_s3_class(local, "crew_class_controller")

    expect_error(
        stage1_crew_controller(
            scheduler = "pbs",
            name = "stage1-evidence",
            workers = 2L
        ),
        "options_cluster"
    )

    pbs_options <- crew.cluster::crew_options_pbs(
        command_submit = "qsub",
        script_directory = tempdir(),
        script_lines = "#PBS -P project-supplied-by-user",
        cores = 1L,
        walltime_hours = 1
    )
    pbs <- stage1_crew_controller(
        scheduler = "pbs",
        name = "stage1-evidence",
        workers = 2L,
        options_cluster = pbs_options
    )
    expect_s3_class(pbs, "crew_class_controller")
    expect_error(
        stage1_crew_controller(scheduler = "not-a-scheduler"),
        class = "stage1_orchestration_error"
    )
})

test_that("full evidence graph exposes scientific dependencies and one parallel layer", {
    skip_if_not_installed("targets")

    artifact_root <- tempfile("stage1-target-artifacts-")
    pipeline <- stage1_evidence_targets(
        artifact_root = artifact_root,
        controller = "stage1-evidence"
    )
    expect_type(pipeline, "list")

    expected <- c(
        "stage1_manifest",
        "stage1_identity",
        "stage1_tasks",
        "stage1_task",
        "stage1_rows",
        "stage1_results",
        "stage1_selection",
        "stage1_holdout",
        "stage1_artifact",
        "stage1_artifact_verified",
        "stage1_evidence"
    )
    expect_identical(unname(vapply(pipeline, `[[`, character(1L), "name")), expected)

    by_name <- stats::setNames(pipeline, expected)
    for (name in c(
        "stage1_manifest", "stage1_identity", "stage1_tasks",
        "stage1_task", "stage1_results"
    )) {
        expect_identical(
            as.list.environment(by_name[[name]]$settings)$deployment,
            "main"
        )
    }
    expect_identical(
        as.list.environment(by_name$stage1_rows$settings)$dimensions,
        "stage1_task"
    )
    expect_identical(
        as.list.environment(by_name$stage1_rows$settings)$resources$crew$controller,
        "stage1-evidence"
    )
    expect_identical(
        as.list.environment(by_name$stage1_selection$settings)$deployment,
        "worker"
    )
    expect_match(
        by_name$stage1_selection$command$string,
        "sequential_internal = TRUE",
        fixed = TRUE
    )
    expect_match(
        paste(deparse(body(landscapeR:::.stage1_target_holdout)), collapse = "\n"),
        "sequential_internal = TRUE",
        fixed = TRUE
    )
    expect_identical(
        as.list.environment(by_name$stage1_artifact$settings)$deployment,
        "main"
    )
    expect_identical(
        as.list.environment(by_name$stage1_artifact_verified$settings)$deployment,
        "main"
    )
})

test_that("controller choice does not change scientific graph commands", {
    skip_if_not_installed("targets")

    local <- stage1_evidence_targets(
        artifact_root = tempfile("local-artifacts-"),
        controller = "local-controller"
    )
    scheduler <- stage1_evidence_targets(
        artifact_root = tempfile("scheduler-artifacts-"),
        controller = "scheduler-controller"
    )
    names <- vapply(local, `[[`, character(1L), "name")
    scientific <- !names %in% c("stage1_artifact", "stage1_artifact_verified", "stage1_evidence")
    local_commands <- vapply(local[scientific], function(target) target$command$string, character(1L))
    scheduler_commands <- vapply(scheduler[scientific], function(target) target$command$string, character(1L))
    expect_identical(local_commands, scheduler_commands)
})

test_that("workflow result requires verified publication", {
    skip_if_not_installed("targets")

    pipeline <- stage1_evidence_targets(
        artifact_root = tempfile("verified-artifacts-"),
        controller = "stage1-evidence"
    )
    by_name <- stats::setNames(
        pipeline,
        vapply(pipeline, `[[`, character(1L), "name")
    )
    expect_match(
        paste(deparse(body(landscapeR:::.stage1_target_verified)), collapse = "\n"),
        "verify_stage1_evidence_artifact",
        fixed = TRUE
    )
    expect_match(
        by_name$stage1_evidence$command$string,
        "stage1_artifact_verified",
        fixed = TRUE
    )
})

test_that("workflow result preserves typed provenance through serialization", {
    result <- structure(
        list(
            artifact = "/tmp/stage1-artifact",
            verified = TRUE,
            protocol_id = "stage1-heterogeneous-v2",
            manifest_digest = paste(rep("a", 64L), collapse = ""),
            scientific_digest = paste(rep("b", 64L), collapse = ""),
            source_commit = paste(rep("c", 40L), collapse = "")
        ),
        class = c("stage1_evidence_workflow_result", "list")
    )
    path <- tempfile(fileext = ".rds")
    saveRDS(result, path)
    restored <- readRDS(path)
    expect_identical(restored, result)
    expect_s3_class(restored, "stage1_evidence_workflow_result")
})

test_that("scientific publication payload excludes backend timing", {
    results <- data.frame(
        candidate = c("C1", "C2"),
        shared_recovery_error = c(.1, .2),
        elapsed_sec = c(1, 100),
        peak_vcells_bytes = c(10, 20),
        completed_at_utc = c("a", "b"),
        stringsAsFactors = FALSE
    )
    scientific <- landscapeR:::.stage1_scientific_results(results)
    expect_false(any(c("elapsed_sec", "peak_vcells_bytes", "completed_at_utc") %in%
        names(scientific)))
    expect_identical(scientific$candidate, results$candidate)
})

test_that("scientific holdout payload excludes backend timing", {
    holdout <- list(
        protocol_id = "p", protocol_digest = "d", generator_digest = "g",
        split = "holdout", selected_candidate = "C1",
        all_gates_passed = TRUE, thresholds_passed = TRUE, decision = "accepted",
        rules = list(),
        summary = data.frame(
            metric = c("shared_recovery_error", "elapsed_sec", "peak_vcells_bytes"),
            estimate = c(.1, 1, 10), stringsAsFactors = FALSE
        ),
        bootstrap_measurements = list(
            "stratum:shared_recovery_error" = list(value = 1),
            "stratum:elapsed_sec" = list(value = 2)
        )
    )
    scientific <- landscapeR:::.stage1_scientific_holdout(holdout)
    expect_identical(scientific$summary$metric, "shared_recovery_error")
    expect_null(scientific$bootstrap_measurements)
    altered <- holdout
    altered$summary$estimate[altered$summary$metric == "elapsed_sec"] <- 999
    expect_identical(
        digest::digest(scientific, algo = "sha256"),
        digest::digest(landscapeR:::.stage1_scientific_holdout(altered), algo = "sha256")
    )
})

test_that("each crew branch observes installed identity independently", {
    identity <- list(
        source_commit = paste(rep("a", 40L), collapse = ""),
        r_version = paste(R.version$major, R.version$minor, sep = "."),
        package_versions = c(
            landscapeR = as.character(utils::packageVersion("landscapeR")),
            digest = as.character(utils::packageVersion("digest"))
        )
    )
    testthat::local_mocked_bindings(
        landscapeR_revision = function() paste(rep("b", 40L), collapse = ""),
        .package = "landscapeR"
    )

    expect_error(
        landscapeR:::.stage1_target_worker_preflight(identity),
        class = "landscapeR_worker_preflight_error"
    )
})
