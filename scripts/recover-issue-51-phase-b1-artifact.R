#!/usr/bin/env Rscript

library(targets)
library(landscapeR)

required_path <- function(variable) {
    value <- Sys.getenv(variable, unset = "")
    if (!nzchar(value) || !dir.exists(value)) {
        stop(variable, " must name an existing directory", call. = FALSE)
    }
    normalizePath(value, mustWork = TRUE)
}

run_root <- required_path("LANDSCAPER_K1_RUN_ROOT")
source_root <- required_path("LANDSCAPER_K1_RECOVERY_SOURCE_ROOT")
script_argument <- grep("^--file=", commandArgs(FALSE), value = TRUE)
stopifnot(length(script_argument) == 1L)
recovery_files <- c(
    procedure = sub("^--file=", "", script_argument),
    result_contract = file.path(
        source_root,
        "R",
        "13j-stage0-k1-acceptance-runner.R"
    ),
    summary_contract = file.path(
        source_root,
        "R",
        "13k-stage0-k1-acceptance-summary.R"
    )
)
recovery_files <- stats::setNames(
    normalizePath(unname(recovery_files), mustWork = TRUE),
    names(recovery_files)
)

patch_environment <- new.env(parent = asNamespace("landscapeR"))
sys.source(recovery_files[["result_contract"]], patch_environment)
sys.source(recovery_files[["summary_contract"]], patch_environment)
namespace <- asNamespace("landscapeR")
for (binding in c(
    ".k1_acceptance_validate_metrics",
    ".k1_acceptance_wilson_lower",
    ".k1_acceptance_payload_digest",
    ".k1_acceptance_publish",
    ".k1_acceptance_verify_artifact",
    "plot_k1_acceptance_summary"
)) {
    unlockBinding(binding, namespace)
    assign(binding, patch_environment[[binding]], envir = namespace)
    lockBinding(binding, namespace)
}

setwd(run_root)
protocol <- tar_read(k1_protocol)
manifest <- tar_read(k1_manifest)
worker_identity <- tar_read(k1_identity)
tasks <- tar_read(k1_tasks)
branch_names <- tar_branch_names("k1_result", seq_len(nrow(tasks)))
stopifnot(
    length(branch_names) == nrow(tasks),
    identical(
        worker_identity$source_revision,
        manifest$phase_a_merge_commit
    )
)

metadata <- tar_meta(fields = -tidyselect::any_of("time"))
results <- lapply(branch_names, tar_read_raw, meta = metadata)
collector_identity <- worker_identity
collector_identity$recovery <- list(
    mode = "approved_collection_only_patch",
    worker_results_modified = FALSE,
    corrections = c(
        "preserve dynamic target results as lists",
        "permit missing errors only for non-estimable landmarks",
        "round Wilson bounds to 15 decimal places before hashing",
        "use publication-quality percentage breaks in evidence figures"
    ),
    source_sha256 = vapply(
        recovery_files,
        digest::digest,
        character(1L),
        algo = "sha256",
        serialize = FALSE,
        file = TRUE
    ),
    approved_by = "Denis O'Meally",
    approved_on = "2026-08-11"
)

artifact <- landscapeR:::.k1_acceptance_publish(
    file.path(run_root, "artifacts"),
    protocol,
    manifest,
    tasks,
    results,
    worker_identity,
    collector_identity
)
stopifnot(landscapeR::verify_k1_acceptance_artifact(artifact))

summary <- readRDS(file.path(artifact, "summary.rds"))
cat("artifact=", artifact, "\n", sep = "")
cat("requested_tasks=", nrow(tasks), "\n", sep = "")
cat("complete_execution=", summary$complete_execution, "\n", sep = "")
cat("supported_minimum_n=", summary$supported_minimum_n, "\n", sep = "")
