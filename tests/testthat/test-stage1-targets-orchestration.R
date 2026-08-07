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
