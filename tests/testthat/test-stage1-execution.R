test_that("execution durations are human-readable", {
    expect_identical(landscapeR:::.stage1_format_duration(65), "1m 05s")
    expect_identical(landscapeR:::.stage1_format_duration(7261), "2h 01m 01s")
    expect_identical(landscapeR:::.stage1_format_duration(NA_real_), "unknown")
})

test_that("development manifest is deterministic and explicitly non-evidentiary", {
    manifest <- stage1_development_manifest()
    expect_identical(manifest$protocol_id, "stage1-heterogeneous-development-v1")
    expect_false(manifest$evidence_eligible)
    expect_length(manifest$strata, 5L)
    expect_identical(manifest$seeds, c(1001L, 1021L))
})

test_that("scratch root resolves once for every package module", {
    old_working_directory <- getwd()
    old_option <- options(landscapeR.scratch_root = NULL)
    on.exit(setwd(old_working_directory), add = TRUE)
    on.exit(options(old_option), add = TRUE)

    repository <- tempfile("landscapeR-repository-")
    nested <- file.path(repository, "R", "nested")
    dir.create(file.path(repository, ".git"), recursive = TRUE)
    dir.create(nested, recursive = TRUE)
    on.exit(unlink(repository, recursive = TRUE, force = TRUE), add = TRUE)
    setwd(nested)

    expect_identical(
        landscapeR:::.landscapeR_scratch_root(),
        file.path(normalizePath(repository), ".scratch")
    )

    scratch_root <- tempfile("landscapeR-scratch-root-")
    options(landscapeR.scratch_root = scratch_root)
    on.exit(unlink(scratch_root, recursive = TRUE, force = TRUE), add = TRUE)

    manifest <- stage1_development_manifest()
    task_set <- landscapeR:::.stage1_execution_tasks("development", manifest)
    identity <- landscapeR:::.stage1_execution_identity("development", manifest)
    workspace <- landscapeR:::.stage1_init_workspace(NULL, identity, task_set$tasks)

    expect_true(startsWith(workspace, normalizePath(scratch_root)))
    expect_true(dir.exists(file.path(workspace, "tasks")))
    options(landscapeR.scratch_root = character())
    expect_error(
        landscapeR:::.landscapeR_scratch_root(),
        "must be one non-empty path",
        class = "landscapeR_validation_error"
    )
    options(landscapeR.scratch_root = NULL)
    outside_repository <- tempfile("landscapeR-outside-repository-")
    dir.create(outside_repository)
    on.exit(unlink(outside_repository, recursive = TRUE, force = TRUE), add = TRUE)
    expect_error(
        landscapeR:::.landscapeR_scratch_root(outside_repository),
        "repository root could not be resolved",
        class = "landscapeR_validation_error"
    )
})

test_that("local development workspace resumes complete task payloads", {
    manifest <- stage1_development_manifest()
    task_set <- landscapeR:::.stage1_execution_tasks("development", manifest)
    identity <- landscapeR:::.stage1_execution_identity("development", manifest)
    workspace <- tempfile("stage1-development-workspace-")
    landscapeR:::.stage1_init_workspace(workspace, identity, task_set$tasks)
    landscapeR:::.stage1_run_checkpoint_task(workspace, task_set$tasks[1L, , drop = FALSE],
        "development", manifest, identity)
    initial <- stage1_benchmark_progress(workspace)
    expect_identical(initial$completed, 1L)
    expect_identical(initial$total, 10L)
    expect_gte(initial$rate_per_sec, 0)

    run <- execute_stage1_benchmark_development(workspace = workspace, workers = 1L,
        progress = "none", keep_workspace = TRUE)
    expect_identical(run$tier, "development")
    expect_false(run$evidence_eligible)
    expect_equal(nrow(run$results), 20L)
    expect_true(all(run$results$tier == "development"))
    negative <- run$results[run$results$projection_case == "missing_id", , drop = FALSE]
    expect_true(all(negative$gate_expected == "typed_failure"))
    expect_true(all(negative$gate_passed))
    fresh <- execute_stage1_benchmark_development(workspace = tempfile("stage1-development-fresh-"),
        workers = 1L, progress = "none")
    compare <- setdiff(names(run$results), c("elapsed_sec", "peak_vcells_bytes"))
    expect_equal(run$results[, compare], fresh$results[, compare])
    selection_input <- run$results
    selection_input$split <- "calibration"
    expect_error(select_stage1_candidate(selection_input),
                 "non-evidentiary benchmark rows cannot select a candidate")
    expect_error(execute_stage1_benchmark_development(workspace = workspace,
        progress = "none"), class = "stage1_execution_error")
})

test_that("workspace rejects changed execution identity and corrupt checkpoints", {
    manifest <- stage1_development_manifest()
    task_set <- landscapeR:::.stage1_execution_tasks("development", manifest)
    identity <- landscapeR:::.stage1_execution_identity("development", manifest)
    workspace <- tempfile("stage1-development-workspace-")
    landscapeR:::.stage1_init_workspace(workspace, identity, task_set$tasks)
    landscapeR:::.stage1_claim_workspace(workspace)
    expect_error(landscapeR:::.stage1_claim_workspace(workspace), class = "stage1_execution_error")
    landscapeR:::.stage1_release_workspace(workspace)
    expect_error(landscapeR:::.stage1_collect_checkpoint_rows(workspace, task_set$tasks, identity),
                 class = "stage1_execution_error")
    changed <- identity
    changed$generator_digest <- paste(rep("0", 64L), collapse = "")
    expect_error(landscapeR:::.stage1_init_workspace(workspace, changed, task_set$tasks),
                 class = "stage1_execution_error")
    path <- landscapeR:::.stage1_workspace_task_path(workspace, task_set$tasks$key[[1L]])
    writeLines("not an RDS checkpoint", path)
    expect_error(landscapeR:::.stage1_read_task_checkpoint(workspace,
        task_set$tasks[1L, , drop = FALSE], identity), class = "stage1_execution_error")
    unlink(path)
    landscapeR:::.stage1_atomic_save_rds(list(key = "undeclared", status = "complete"),
        file.path(landscapeR:::.stage1_workspace_tasks_path(workspace), "undeclared.rds"))
    expect_error(stage1_benchmark_progress(workspace), class = "stage1_execution_error")
})

test_that("execute_stage1_benchmark_development aborts on failed checkpoints before running any task", {
  skip_on_os("windows")
  manifest <- stage1_development_manifest()
  task_set <- landscapeR:::.stage1_execution_tasks("development", manifest)
  identity  <- landscapeR:::.stage1_execution_identity("development", manifest)
  workspace <- tempfile("stage1-failed-cp-")
  landscapeR:::.stage1_init_workspace(workspace, identity, task_set$tasks)
  # Inject a failed checkpoint for the first task
  failed_cp <- list(
    key = task_set$tasks$key[[1L]], identity = identity,
    seed = task_set$tasks$seed[[1L]], stratum = task_set$tasks$stratum[[1L]],
    status = "failed", rows = NULL, failure_reason = "synthetic failure",
    completed_at_utc = format(Sys.time(), tz = "UTC", usetz = TRUE), elapsed_sec = 0
  )
  landscapeR:::.stage1_atomic_save_rds(
    failed_cp,
    landscapeR:::.stage1_workspace_task_path(workspace, task_set$tasks$key[[1L]])
  )
  landscapeR:::.stage1_claim_workspace(workspace)
  on.exit(landscapeR:::.stage1_release_workspace(workspace), add = TRUE)
  # Calling the checkpointed-tasks runner directly should abort immediately
  expect_error(
    landscapeR:::.stage1_execute_checkpointed_tasks(
      workspace, task_set$tasks, "development", manifest, identity,
      workers = 1L, progress = "none"),
    class = "stage1_execution_error",
    regexp = "failed task checkpoint"
  )
})

test_that(".stage1_assert_unix_platform aborts on non-Unix platform simulation", {
  # On CI (Linux/macOS) this should pass silently
  if (.Platform$OS.type == "unix") {
    expect_silent(landscapeR:::.stage1_assert_unix_platform())
  } else {
    expect_error(landscapeR:::.stage1_assert_unix_platform(), class = "stage1_execution_error")
  }
})
