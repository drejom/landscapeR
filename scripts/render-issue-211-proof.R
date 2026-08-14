#!/usr/bin/env Rscript

devtools::load_all(".", quiet = TRUE)

update_proof <- "--update" %in% commandArgs(trailingOnly = TRUE)
proof_root <- file.path(".github", "landing-proof", "issue-211")
example_root <- file.path(proof_root, "examples")
scratch_root <- file.path(".scratch", "issue-211-proof")
unlink(scratch_root, recursive = TRUE, force = TRUE)
dir.create(example_root, recursive = TRUE, showWarnings = FALSE)
dir.create(scratch_root, recursive = TRUE, showWarnings = FALSE)
on.exit(unlink(scratch_root, recursive = TRUE, force = TRUE), add = TRUE)

load_first_assignment <- function(path) {
    expressions <- parse(path, keep.source = FALSE)
    eval(expressions[[1L]], envir = .GlobalEnv)
}
load_first_assignment("tests/testthat/test-k1-calibration-outcomes.R")
load_first_assignment("tests/testthat/test-stage1-evidence.R")

benchmark_runner <- run_stage1_benchmark_replicate
benchmark_paths <- testthat::with_mocked_bindings(
    write_stage1_benchmark_artifact(
        file.path(scratch_root, "stage1-benchmark")
    ),
    .stage1_benchmark_environment = function() list(
        r_version = "4.5.2",
        package_version = "0.3.0",
        commit = strrep("c", 40L)
    ),
    run_stage1_benchmark_replicate = function(...) {
        result <- benchmark_runner(...)
        result$elapsed_sec <- 0
        result$peak_vcells_bytes <- 0
        result
    },
    .package = "landscapeR"
)
benchmark_artifact <- dirname(unname(benchmark_paths[[1L]]))

stage1_manifest <- stage1_benchmark_manifest()
calibration <- stage1_evidence_fixture("calibration")
calibration$elapsed_sec <- ifelse(
    calibration$candidate == "C1_symmetric_consensus", 1, 1.1
)
calibration$peak_vcells_bytes <- 0
selection <- select_stage1_candidate(calibration)
selection$bootstrap_executions <- list()
selection$bootstrap_measurements <- list()
holdout_results <- stage1_evidence_fixture("holdout")
holdout_results$elapsed_sec <- ifelse(
    holdout_results$candidate == "C1_symmetric_consensus", 1, 1.1
)
holdout_results$peak_vcells_bytes <- 0
holdout <- assess_stage1_holdout(
    selection$selected_candidate,
    holdout_results[
        holdout_results$candidate == selection$selected_candidate,
        ,
        drop = FALSE
    ]
)
holdout$bootstrap_executions <- list()
holdout$bootstrap_measurements <- list()
stage1_artifact <- landscapeR:::.stage1_write_full_artifact(
    file.path(scratch_root, "stage1-evidence"),
    stage1_manifest,
    rbind(calibration, holdout_results),
    selection,
    holdout,
    workers = 1L,
    source_commit = strrep("a", 40L)
)

calibration_fixture <- calibration_outcome_fixture()
calibration_artifact <- testthat::with_mocked_bindings(
    publish_k1_calibration_outcomes(
        file.path(scratch_root, "k1-calibration"),
        calibration_fixture$results,
        calibration_fixture$tasks,
        calibration_fixture$protocol
    ),
    .k1_calibration_runtime_identity = function() list(
        source_revision = strrep("b", 40L),
        r_version = paste(R.version$major, R.version$minor, sep = "."),
        package_versions = c(
            landscapeR = as.character(utils::packageVersion("landscapeR"))
        )
    ),
    .package = "landscapeR"
)

acceptance_protocol <- k1_acceptance_protocol()
acceptance_manifest <- k1_acceptance_manifest(strrep("1", 40L))
acceptance_tasks <- acceptance_manifest$tasks[
    acceptance_manifest$tasks$control == "generic_double_well",
    ,
    drop = FALSE
][1L, , drop = FALSE]
acceptance_result <- structure(list(
    artifact_version = acceptance_protocol$artifact_version,
    task_id = acceptance_tasks$task_id[[1L]],
    control = acceptance_tasks$control[[1L]],
    canonical_cell = acceptance_tasks$canonical_cell[[1L]],
    replicate_index = acceptance_tasks$replicate_index[[1L]],
    status = "success",
    reason = "",
    metrics = list(
        well_error = 0.05,
        barrier_error = 0.05,
        barrier_height_error = 0.1,
        n_wells_found = 2L,
        n_barriers_found = 1L,
        subspace_angle_deg = 5
    ),
    protocol_digest = acceptance_protocol$digest,
    runner_contract = acceptance_protocol$execution_contracts$version
), class = c("K1AcceptanceReplicate", "list"))
acceptance_identity <- list(
    source_revision = strrep("1", 40L),
    r_version = paste(R.version$major, R.version$minor, sep = "."),
    package_versions = c(
        landscapeR = as.character(utils::packageVersion("landscapeR"))
    )
)
acceptance_artifact <- landscapeR:::.k1_acceptance_publish(
    file.path(scratch_root, "k1-acceptance"),
    acceptance_protocol,
    acceptance_manifest,
    acceptance_tasks,
    list(acceptance_result),
    acceptance_identity
)

cases <- data.frame(
    artifact_family = c(
        "Single-replicate Stage 1 benchmark",
        "Full Stage 1 evidence",
        "K=1 calibration outcomes",
        "K=1 acceptance"
    ),
    publisher = c(
        "write_stage1_benchmark_artifact()",
        ".stage1_write_full_artifact()",
        "publish_k1_calibration_outcomes()",
        ".k1_acceptance_publish()"
    ),
    verifier = c(
        "verify_stage1_benchmark_artifact()",
        "verify_stage1_evidence_artifact()",
        "verify_k1_calibration_outcomes()",
        "verify_k1_acceptance_artifact()"
    ),
    example = file.path(
        "examples",
        c(
            "stage1-benchmark-MANIFEST.tsv",
            "stage1-evidence-MANIFEST.tsv",
            "k1-calibration-MANIFEST.tsv",
            "k1-acceptance-MANIFEST.tsv"
        )
    ),
    stringsAsFactors = FALSE
)
artifacts <- c(
    benchmark_artifact,
    stage1_artifact,
    calibration_artifact,
    acceptance_artifact
)
cases$address <- basename(artifacts)
cases$publication_verified <- c(
    verify_stage1_benchmark_artifact(benchmark_artifact),
    verify_stage1_evidence_artifact(stage1_artifact),
    verify_k1_calibration_outcomes(calibration_artifact),
    verify_k1_acceptance_artifact(acceptance_artifact)
)
if (!all(cases$publication_verified)) {
    stop("one or more scientific artifact publication proofs failed")
}
assert_or_update <- function(source, target) {
    matches <- file.exists(target) && identical(
        landscapeR:::.artifact_file_digest(source),
        landscapeR:::.artifact_file_digest(target)
    )
    if (!matches && !update_proof) {
        stop(
            "retained proof differs from regeneration: ",
            target,
            "; rerun with --update only for a deliberate proof revision"
        )
    }
    if (!matches && !file.copy(source, target, overwrite = TRUE)) {
        stop("could not retain proof file: ", target)
    }
    invisible(TRUE)
}
for (index in seq_len(nrow(cases))) {
    assert_or_update(
        file.path(artifacts[[index]], "MANIFEST.tsv"),
        file.path(proof_root, cases$example[[index]])
    )
}

output <- file.path(proof_root, "publication-matrix.tsv")
candidate_matrix <- file.path(scratch_root, "publication-matrix.tsv")
utils::write.table(
    cases, candidate_matrix, sep = "\t", quote = FALSE, row.names = FALSE
)
assert_or_update(candidate_matrix, output)
cat("Verified", output, "and", nrow(cases), "artifact manifests\n")
