test_that("development manifest is deterministic and explicitly non-evidentiary", {
    manifest <- stage1_development_manifest()
    expect_identical(manifest$protocol_id, "stage1-heterogeneous-development-v1")
    expect_false(manifest$evidence_eligible)
    expect_length(manifest$strata, 5L)
    expect_identical(manifest$seeds, c(1001L, 1021L))
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
