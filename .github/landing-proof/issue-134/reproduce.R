library(landscapeR)

revision <- Sys.getenv("LANDSCAPER_REVISION")
stopifnot(nzchar(revision))
stopifnot(identical(landscapeR_revision(), revision))
previous <- future::plan()
on.exit(future::plan(previous), add = TRUE)

tasks <- as.list(seq_len(8L))
task_ids <- sprintf("remote-proof:%02d", seq_along(tasks))
worker <- function(task, task_id, task_stream) stats::runif(2L) + task
assay <- matrix(seq_len(240000L), nrow = 1200L, ncol = 200L)
chunks <- c(1L, 8L, 32L, 200L)

future::plan(future::sequential)
sequential <- landscapeR:::.future_repetition(
    tasks, task_ids, 13401L, "standard", worker
)
sequential_transfer <- benchmark_future_assay(assay, chunks, 3L)

future::plan(future::cluster, workers = 2L)
preflight <- preflight_future_workers(revision, workers = 2L)
cluster <- landscapeR:::.future_repetition(
    tasks, task_ids, 13401L, "standard", worker
)
cluster_transfer <- benchmark_future_assay(assay, chunks, 3L)

stopifnot(
    identical(sequential, cluster),
    all(cluster_transfer$identical),
    identical(
        sequential_transfer$source_digest,
        cluster_transfer$source_digest
    ),
    length(unique(preflight$workers$worker_id)) == 2L
)

print(preflight$workers)
print(data.frame(
    chunk_size = cluster_transfer$chunk_size,
    chunks = cluster_transfer$chunks,
    sequential_seconds = sequential_transfer$chunk_dispatch_collect_seconds,
    cluster_seconds = cluster_transfer$chunk_dispatch_collect_seconds,
    payload_bytes = cluster_transfer$payload_bytes,
    collection_bytes = cluster_transfer$collection_bytes,
    digest_identical = cluster_transfer$identical
))
cat("execution_digest", sequential$digest, "\n")
