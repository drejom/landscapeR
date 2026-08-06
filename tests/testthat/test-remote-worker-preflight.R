test_that("future worker preflight validates declared environment identity", {
    testthat::local_mocked_bindings(
        landscapeR_revision = function() "test-revision-134",
        .package = "landscapeR"
    )
    previous_plan <- future::plan()
    on.exit(future::plan(previous_plan), add = TRUE)
    future::plan(future::sequential)
    revision <- "test-revision-134"

    result <- preflight_future_workers(revision, workers = 1L)
    expect_s3_class(result, "landscapeR_worker_preflight")
    expect_true(result$workers$ok)
    expect_identical(result$expected$revision, revision)
    expect_match(result$workers$package_versions, "landscapeR=0.3.0")
    expect_match(result$digest, "^[0-9a-f]{64}$")

    condition <- tryCatch(
        preflight_future_workers("wrong-revision", workers = 1L),
        landscapeR_worker_preflight_error = identity
    )
    expect_s3_class(condition, "landscapeR_worker_preflight_error")
    expect_match(condition$diagnostics$diagnostic, "revision-mismatch")
})

test_that("incomplete worker coverage remains a typed diagnostic", {
    testthat::local_mocked_bindings(
        landscapeR_revision = function() "test-revision-134",
        .package = "landscapeR"
    )
    previous_plan <- future::plan()
    on.exit(future::plan(previous_plan), add = TRUE)
    future::plan(future::sequential)
    condition <- tryCatch(
        preflight_future_workers("test-revision-134", workers = 2L),
        landscapeR_worker_preflight_error = identity
    )
    expect_s3_class(condition, "landscapeR_worker_preflight_error")
    expect_identical(
        condition$diagnostics$diagnostic, "plan-worker-count-mismatch"
    )
})

test_that("assay transfer benchmark preserves payload across chunk sizes", {
    testthat::local_mocked_bindings(
        landscapeR_revision = function() "test-revision-134",
        .package = "landscapeR"
    )
    previous_plan <- future::plan()
    on.exit(future::plan(previous_plan), add = TRUE)
    future::plan(future::sequential)
    assay <- matrix(seq_len(120), nrow = 12L, ncol = 10L)
    dimnames(assay) <- list(
        sprintf("feature_%02d", seq_len(nrow(assay))),
        sprintf("sample_%02d", seq_len(ncol(assay)))
    )
    result <- benchmark_future_assay(
        assay, chunk_sizes = c(1L, 4L, 10L), repetitions = 1L
    )
    expect_s3_class(result, "landscapeR_future_assay_benchmark")
    expect_identical(result$chunk_size, c(1L, 4L, 10L))
    expect_identical(result$chunks, c(10L, 3L, 1L))
    expect_true(all(result$identical))
    expect_true(all(result$payload_bytes > 0))
    expect_true(all(result$collection_bytes > 0))
    expect_true(all(result$serialization_seconds >= 0))
    expect_true(all(result$global_export_collect_seconds >= 0))
    expect_true(all(result$chunk_dispatch_collect_seconds >= 0))
    expect_identical(unique(result$repetitions), 1L)
    expect_identical(unique(result$workers), 1L)
    expect_true(
        is.character(unique(result$backend)) &&
            length(unique(result$backend)) == 1L &&
            nzchar(unique(result$backend))
    )
    expect_match(unique(result$package_versions), "future=")
    expect_match(unique(result$benchmarked_at_utc), "Z$")
    expect_identical(unique(result$landscapeR_revision), "test-revision-134")
    expect_identical(unique(result$revision_status), "recorded")
})

test_that("unstamped local assay benchmarks record unavailable provenance", {
    testthat::local_mocked_bindings(
        landscapeR_revision = function() {
            landscapeR:::.worker_preflight_error("revision unavailable")
        },
        .package = "landscapeR"
    )
    result <- benchmark_future_assay(
        matrix(1:4, nrow = 2L), chunk_sizes = 2L, repetitions = 1L
    )
    expect_true(is.na(result$landscapeR_revision))
    expect_identical(result$revision_status, "unavailable")
})

test_that("oversized execution inputs remain typed validation failures", {
    assay <- matrix(1:4, nrow = 2L)
    expect_error(
        preflight_future_workers("revision", workers = 1e20),
        class = "landscapeR_validation_error"
    )
    expect_error(
        benchmark_future_assay(assay, chunk_sizes = 1e20),
        class = "landscapeR_validation_error"
    )
    expect_error(
        benchmark_future_assay(assay, repetitions = 1e20),
        class = "landscapeR_validation_error"
    )
})

test_that("future benchmark failures retain typed stage diagnostics", {
    condition <- tryCatch(
        landscapeR:::.future_benchmark_error(
            "collection failed", "chunk-dispatch-collection",
            simpleError("backend unavailable")
        ),
        landscapeR_future_benchmark_error = identity
    )
    expect_s3_class(condition, "landscapeR_future_benchmark_error")
    expect_identical(
        condition$diagnostics$stage, "chunk-dispatch-collection"
    )
    expect_identical(
        condition$diagnostics$cause_message, "backend unavailable"
    )
})

test_that("cluster plan reproduces execution and payload digests", {
    skip_if(
        pkgload::is_dev_package("landscapeR"),
        "cluster workers require the installed-package check context"
    )
    previous_plan <- future::plan()
    on.exit(future::plan(previous_plan), add = TRUE)
    tasks <- as.list(seq_len(8L))
    ids <- sprintf("remote-proof:%02d", seq_along(tasks))
    worker <- function(task, task_id, task_stream) stats::runif(2L) + task
    assay <- matrix(seq_len(2400), nrow = 120L, ncol = 20L)

    future::plan(future::sequential)
    sequential <- landscapeR:::.future_repetition(
        tasks, ids, 13401L, "standard", worker
    )
    sequential_payload <- benchmark_future_assay(
        assay, c(1L, 5L, 20L), repetitions = 1L
    )

    future::plan(future::cluster, workers = 2L)
    revision <- tryCatch(
        landscapeR_revision(),
        landscapeR_worker_preflight_error = function(condition) NULL
    )
    skip_if(is.null(revision), "installed package has no revision metadata")
    partial_condition <- tryCatch(
        preflight_future_workers(revision, workers = 1L),
        landscapeR_worker_preflight_error = identity
    )
    expect_s3_class(partial_condition, "landscapeR_worker_preflight_error")
    expect_identical(
        partial_condition$diagnostics$diagnostic,
        "plan-worker-count-mismatch"
    )
    cluster_preflight <- preflight_future_workers(
        revision, workers = 2L
    )
    cluster <- landscapeR:::.future_repetition(
        tasks, ids, 13401L, "standard", worker
    )
    cluster_payload <- benchmark_future_assay(
        assay, c(1L, 5L, 20L), repetitions = 1L
    )

    expect_true(all(cluster_preflight$workers$ok))
    expect_length(unique(cluster_preflight$workers$worker_id), 2L)
    expect_identical(cluster, sequential)
    expect_identical(
        cluster_payload$source_digest, sequential_payload$source_digest
    )
    expect_true(all(cluster_payload$identical))
})
