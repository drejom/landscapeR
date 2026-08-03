stage1_reduced_full_fixture <- function() {
    manifest <- stage1_benchmark_manifest()
    stratum <- landscapeR:::.stage1_benchmark_strata(manifest)[1L, , drop = FALSE]
    template <- run_stage1_benchmark_replicate(
        manifest = manifest,
        seed = manifest$seeds$seed[[1L]],
        stratum = as.list(stratum)
    )
    manifest$grid <- lapply(stratum, function(value) value[[1L]])
    template$shared_recovery_error[template$candidate == "C1_symmetric_consensus"] <- .10
    template$shared_recovery_error[template$candidate == "C2_block_scaled_svd"] <- .20
    template$response_recovery_error <- .10
    template$exclusive_leakage <- .10
    template$projection_error <- .10
    template$elapsed_sec <- ifelse(template$candidate == "C1_symmetric_consensus", 1, 1.1)
    list(manifest = manifest, template = template)
}

stage1_reduced_task_rows <- function(fixture, manifest, task) {
    rows <- fixture$template
    rows$seed <- as.integer(task$seed)
    rows$split <- manifest$seeds$split[match(rows$seed, manifest$seeds$seed)]
    rows$stratum <- paste(unlist(task$stratum[[1L]]), collapse = "|")
    rows$stratum_digest <- digest::digest(task$stratum[[1L]], algo = "sha256")
    rows$protocol_digest <- landscapeR:::.protocol_digest(manifest)
    rows$tier <- "full"
    rows
}

stage1_publication_test_paths <- function(label) {
    scratch_root <- tryCatch(
        landscapeR:::.landscapeR_scratch_root(),
        landscapeR_validation_error = function(error) {
            fallback <- file.path(tempdir(), ".scratch")
            options(landscapeR.scratch_root = fallback)
            fallback
        }
    )
    dir.create(scratch_root, recursive = TRUE, showWarnings = FALSE)
    list(
        workspace = tempfile(paste0(label, "-workspace-"), tmpdir = scratch_root),
        artifact_root = tempfile(paste0(label, "-artifacts-"), tmpdir = scratch_root)
    )
}

test_that("complete Stage 1 publication resumes, aggregates, publishes, and verifies", {
    skip_on_os("windows")
    scratch_option <- getOption("landscapeR.scratch_root")
    on.exit(options(landscapeR.scratch_root = scratch_option), add = TRUE)
    fixture <- stage1_reduced_full_fixture()
    source_commit <- paste(rep("a", 40L), collapse = "")
    paths <- stage1_publication_test_paths("stage1-full")
    workspace <- paths$workspace
    artifact_root <- paths$artifact_root
    on.exit(unlink(unlist(paths), recursive = TRUE, force = TRUE), add = TRUE)

    local_mocked_bindings(
        stage1_benchmark_manifest = function() fixture$manifest,
        .stage1_source_commit = function(require_clean = FALSE) source_commit,
        .stage1_run_task_rows = function(tier, manifest, task) {
            expect_identical(tier, "full")
            stage1_reduced_task_rows(fixture, manifest, task)
        },
        .package = "landscapeR"
    )

    task_set <- landscapeR:::.stage1_execution_tasks("full", fixture$manifest)
    identity <- landscapeR:::.stage1_execution_identity(
        "full", fixture$manifest, require_clean = TRUE
    )
    landscapeR:::.stage1_init_workspace(workspace, identity, task_set$tasks)
    resumed_key <- task_set$tasks$key[[1L]]
    landscapeR:::.stage1_run_checkpoint_task(
        workspace, task_set$tasks[1L, , drop = FALSE], "full", fixture$manifest, identity
    )
    resumed_checkpoint <- readRDS(
        landscapeR:::.stage1_workspace_task_path(workspace, resumed_key)
    )

    artifact <- execute_stage1_benchmark_full(
        artifact_root = artifact_root,
        workers = 1L,
        workspace = workspace,
        progress = "none",
        keep_workspace = TRUE
    )

    expect_true(verify_stage1_evidence_artifact(artifact))
    evidence <- read_stage1_evidence_artifact(artifact)
    progress <- stage1_benchmark_progress(workspace)
    expect_identical(progress$status, "finalized")
    expect_identical(progress$completed, 40L)
    expect_identical(progress$failed, 0L)
    expect_identical(nrow(evidence$results), 80L)
    expect_identical(evidence$selection$selected_candidate, "C1_symmetric_consensus")
    expect_identical(evidence$holdout$decision, "failed")
    expect_identical(evidence$environment$commit, source_commit)
    expect_identical(
        evidence$selection$protocol_digest,
        landscapeR:::.protocol_digest(fixture$manifest)
    )
    expect_identical(
        evidence$holdout$generator_digest,
        landscapeR:::.generator_digest()
    )
    expect_identical(
        readRDS(landscapeR:::.stage1_workspace_task_path(workspace, resumed_key))$completed_at_utc,
        resumed_checkpoint$completed_at_utc
    )
    expect_length(list.files(artifact_root, pattern = "^stage1-heterogeneous-v2-"), 1L)
    expect_length(list.files(artifact_root, pattern = "^\\.stage1-evidence-"), 0L)
})

test_that("failed Stage 1 checkpoint interrupts execution without publishing", {
    skip_on_os("windows")
    scratch_option <- getOption("landscapeR.scratch_root")
    on.exit(options(landscapeR.scratch_root = scratch_option), add = TRUE)
    fixture <- stage1_reduced_full_fixture()
    source_commit <- paste(rep("b", 40L), collapse = "")
    paths <- stage1_publication_test_paths("stage1-failed-full")
    workspace <- paths$workspace
    artifact_root <- paths$artifact_root
    on.exit(unlink(unlist(paths), recursive = TRUE, force = TRUE), add = TRUE)

    local_mocked_bindings(
        stage1_benchmark_manifest = function() fixture$manifest,
        .stage1_source_commit = function(require_clean = FALSE) source_commit,
        .stage1_run_task_rows = function(tier, manifest, task) {
            stage1_reduced_task_rows(fixture, manifest, task)
        },
        .package = "landscapeR"
    )

    task_set <- landscapeR:::.stage1_execution_tasks("full", fixture$manifest)
    identity <- landscapeR:::.stage1_execution_identity(
        "full", fixture$manifest, require_clean = TRUE
    )
    landscapeR:::.stage1_init_workspace(workspace, identity, task_set$tasks)
    task <- task_set$tasks[1L, , drop = FALSE]
    landscapeR:::.stage1_atomic_save_rds(
        list(
            key = task$key,
            identity = identity,
            seed = as.integer(task$seed),
            stratum = task$stratum[[1L]],
            status = "failed",
            rows = NULL,
            failure_reason = "synthetic interruption",
            completed_at_utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
            elapsed_sec = 0
        ),
        landscapeR:::.stage1_workspace_task_path(workspace, task$key)
    )

    expect_error(
        execute_stage1_benchmark_full(
            artifact_root = artifact_root,
            workers = 1L,
            workspace = workspace,
            progress = "none",
            keep_workspace = TRUE
        ),
        "failed task checkpoint",
        class = "stage1_execution_error"
    )
    expect_identical(readRDS(landscapeR:::.stage1_workspace_metadata_path(workspace))$status,
        "interrupted")
    expect_length(list.files(artifact_root, all.files = TRUE, no.. = TRUE), 0L)
    expect_error(
        verify_stage1_evidence_artifact(artifact_root),
        class = "stage1_evidence_error"
    )
})
