#!/usr/bin/env Rscript

repository <- normalizePath(getwd())
proof_directory <- file.path(repository, ".github", "landing-proof", "issue-135")
scratch_root <- file.path(repository, ".scratch", "issue-135-proof")
store <- file.path(scratch_root, "targets-store")
script <- file.path(scratch_root, "_targets.R")
attempts <- file.path(scratch_root, "attempts")
published <- file.path(proof_directory, "retry-artifact.rds")

unlink(scratch_root, recursive = TRUE, force = TRUE)
dir.create(attempts, recursive = TRUE, showWarnings = FALSE)
unlink(published, force = TRUE)

quote_path <- function(path) encodeString(path, quote = '"')
script_lines <- c(
    "library(targets)",
    "library(crew)",
    "controller <- crew_controller_local(name = 'proof', workers = 2L)",
    "tar_option_set(controller = controller)",
    "worker_resources <- tar_resources(crew = tar_resources_crew(controller = 'proof'))",
    "list(",
    "  tar_target(input, c(1L, 2L)),",
    paste0(
        "  tar_target(result, { path <- file.path(", quote_path(attempts),
        ", paste0(input, '.rds')); attempt <- if (file.exists(path)) readRDS(path) + 1L else 1L; ",
        "saveRDS(attempt, path); if (input == 2L && attempt == 1L) stop('deliberate first-attempt failure'); ",
        "data.frame(input = input, square = input ^ 2L, attempt = attempt) }, ",
        "pattern = map(input), error = 'continue', deployment = 'worker', storage = 'main', ",
        "retrieval = 'main', resources = worker_resources),"
    ),
    paste0(
        "  tar_target(artifact, { rows <- if (is.data.frame(result)) result else do.call(rbind, result); stopifnot(nrow(rows) == 2L); ",
        "payload <- list(rows = rows, digest = digest::digest(rows, algo = 'sha256')); ",
        "saveRDS(payload, ", quote_path(published), "); ", quote_path(published),
        " }, format = 'file', deployment = 'main'),"
    ),
    "  tar_target(verified, { payload <- readRDS(artifact); stopifnot(identical(payload$digest, digest::digest(payload$rows, algo = 'sha256'))); TRUE }, deployment = 'main')",
    ")"
)
writeLines(script_lines, script)

first <- tryCatch({
    targets::tar_make(
        script = script,
        store = store,
        use_crew = TRUE,
        reporter = "silent"
    )
    NULL
}, error = identity)
stopifnot(inherits(first, "error"), !file.exists(published))

targets::tar_make(
    script = script,
    store = store,
    use_crew = TRUE,
    reporter = "silent"
)
stopifnot(file.exists(published), isTRUE(targets::tar_read_raw("verified", store = store)))
retry_rows <- targets::tar_read_raw("result", branches = TRUE, store = store)
if (!is.data.frame(retry_rows)) retry_rows <- do.call(rbind, retry_rows)
retry_rows <- retry_rows[order(retry_rows$input), , drop = FALSE]
stopifnot(identical(retry_rows$attempt, c(1L, 2L)))

targets::tar_invalidate("result", store = store)
targets::tar_make(
    script = script,
    store = store,
    use_crew = TRUE,
    reporter = "silent"
)
invalidated_rows <- targets::tar_read_raw("result", branches = TRUE, store = store)
if (!is.data.frame(invalidated_rows)) invalidated_rows <- do.call(rbind, invalidated_rows)
invalidated_rows <- invalidated_rows[order(invalidated_rows$input), , drop = FALSE]
observed_attempts <- vapply(
    c("1.rds", "2.rds"),
    function(file) readRDS(file.path(attempts, file)),
    integer(1L)
)
stopifnot(identical(unname(observed_attempts), c(2L, 3L)))

retry_proof <- data.frame(
    phase = c("first run", "retry", "explicit invalidation"),
    successful_branch_attempts = c(1L, 1L, 2L),
    failed_then_retried_branch_attempts = c(1L, 2L, 3L),
    published = c(FALSE, TRUE, TRUE),
    verified = c(FALSE, TRUE, TRUE),
    stringsAsFactors = FALSE
)
utils::write.csv(
    retry_proof,
    file.path(proof_directory, "retry-invalidation-proof.csv"),
    row.names = FALSE
)

resource_policy <- data.frame(
    workflow_part = c(
        "Benchmark replicate branches",
        "Calibration and holdout summaries",
        "Artifact publication",
        "Artifact verification"
    ),
    execution_location = c("crew worker", "crew worker", "controller", "controller"),
    internal_future_policy = c(
        "not used",
        "current worker, sequential",
        "not used",
        "not used"
    ),
    stringsAsFactors = FALSE
)
utils::write.csv(
    resource_policy,
    file.path(proof_directory, "resource-policy.csv"),
    row.names = FALSE
)

pkgload::load_all(repository, quiet = TRUE)
stage1_graph <- stage1_evidence_targets(
    artifact_root = file.path(scratch_root, "stage1-artifacts"),
    controller = "proof"
)
stopifnot(
    identical(
        unname(vapply(stage1_graph, `[[`, character(1L), "name")),
        c(
            "stage1_manifest", "stage1_identity", "stage1_tasks", "stage1_task",
            "stage1_rows", "stage1_results", "stage1_selection", "stage1_holdout",
            "stage1_artifact", "stage1_artifact_verified", "stage1_evidence"
        )
    )
)
timed_results <- data.frame(
    candidate = c("C1", "C2"),
    scientific_metric = c(.1, .2),
    elapsed_sec = c(1, 100),
    peak_vcells_bytes = c(10, 20),
    stringsAsFactors = FALSE
)
scientific_results <- landscapeR:::.stage1_scientific_results(timed_results)
stopifnot(!any(c("elapsed_sec", "peak_vcells_bytes") %in% names(scientific_results)))
proof_manifest <- stage1_benchmark_manifest()
proof_selection <- list(
    protocol_id = proof_manifest$protocol_id,
    protocol_digest = landscapeR:::.protocol_digest(proof_manifest),
    generator_digest = landscapeR:::.generator_digest(),
    split = "calibration",
    decision = "selected",
    selected_candidate = proof_manifest$candidates[[1L]],
    eligible = stats::setNames(c(TRUE, TRUE), proof_manifest$candidates),
    conditions = c(complete = TRUE),
    shared_recovery_difference = -0.1,
    shared_recovery_ci = c(lower = -0.2, upper = -0.05),
    exclusive_leakage_difference = 0,
    projection_difference = 0,
    bootstrap_measurements = list()
)
proof_holdout <- list(
    protocol_id = proof_manifest$protocol_id,
    protocol_digest = landscapeR:::.protocol_digest(proof_manifest),
    generator_digest = landscapeR:::.generator_digest(),
    split = "holdout",
    selected_candidate = proof_manifest$candidates[[1L]],
    all_gates_passed = TRUE,
    thresholds_passed = TRUE,
    decision = "accepted",
    rules = proof_manifest$reporting_rules,
    summary = data.frame(
        projection_case = character(), metric = character(), estimate = numeric(),
        ci_lower = numeric(), ci_upper = numeric(), stringsAsFactors = FALSE
    ),
    bootstrap_measurements = list()
)
proof_artifact <- landscapeR:::.stage1_target_publication(
    artifact_root = file.path(scratch_root, "stage1-artifacts"),
    manifest = proof_manifest,
    results = timed_results,
    selection = proof_selection,
    holdout = proof_holdout,
    identity = list(source_commit = paste(rep("a", 40L), collapse = "")),
    controller = "proof"
)
stopifnot(identical(landscapeR:::.stage1_target_verified(proof_artifact), proof_artifact))
nodes <- data.frame(
    label = c(
        "Frozen manifest\nand seed table",
        "Replicate branches\n(targets + crew)",
        "Complete grid\nvalidation",
        "Calibration and\nholdout summaries",
        "Atomic artifact\npublication",
        "Hash and identity\nverification"
    ),
    x = c(1, 2, 3, 3, 2, 1),
    y = c(3, 3, 3, 2, 2, 2),
    stringsAsFactors = FALSE
)
edges <- data.frame(
    x = c(1.35, 2.35, 3, 2.65, 1.65),
    y = c(3, 3, 2.78, 2, 2),
    xend = c(1.55, 2.65, 3, 2.35, 1.35),
    yend = c(3, 3, 2.22, 2, 2)
)
graph <- ggplot2::ggplot() +
    ggplot2::geom_segment(
        data = edges,
        ggplot2::aes(x = x, y = y, xend = xend, yend = yend),
        linewidth = 0.45,
        colour = "#4D4D4D",
        arrow = grid::arrow(length = grid::unit(2.2, "mm"), type = "closed")
    ) +
    ggplot2::geom_label(
        data = nodes,
        ggplot2::aes(x = x, y = y, label = label),
        size = 2.35,
        linewidth = 0.2,
        label.padding = grid::unit(1.8, "mm"),
        colour = "#111111",
        fill = "white"
    ) +
    ggplot2::annotate(
        "text",
        x = 2,
        y = 1.45,
        label = "A failed branch blocks publication; the next run retries only invalid work.",
        size = 2.25,
        colour = "#B2182B",
        fontface = "bold"
    ) +
    ggplot2::coord_equal(xlim = c(0.45, 3.55), ylim = c(1.2, 3.35), clip = "off") +
    theme_landscapeR() +
    ggplot2::theme(
        axis.text = ggplot2::element_blank(),
        axis.title = ggplot2::element_blank(),
        axis.ticks = ggplot2::element_blank(),
        axis.line = ggplot2::element_blank(),
        panel.grid = ggplot2::element_blank(),
        plot.margin = ggplot2::margin(6, 6, 6, 6)
    )
ggplot2::ggsave(
    file.path(proof_directory, "workflow-graph.png"),
    graph,
    width = 100,
    height = 100,
    units = "mm",
    dpi = 300,
    bg = "white"
)

cat("Issue #135 retry, invalidation, publication, and graph proof complete.\n")
