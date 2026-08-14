#!/usr/bin/env Rscript

devtools::load_all(".", quiet = TRUE)

cases <- data.frame(
    artifact_family = c(
        "K=1 calibration outcomes",
        "K=1 acceptance",
        "Full Stage 1 evidence"
    ),
    publisher = c(
        "publish_k1_calibration_outcomes()",
        ".k1_acceptance_publish()",
        ".stage1_write_full_artifact()"
    ),
    verifier = c(
        "verify_k1_calibration_outcomes()",
        "verify_k1_acceptance_artifact()",
        "verify_stage1_evidence_artifact()"
    ),
    reproducible_test = c(
        "test-k1-calibration-outcomes.R",
        "test-k1-stage0-acceptance-runner.R",
        "test-stage1-evidence.R"
    ),
    stringsAsFactors = FALSE
)

run_case <- function(test_file) {
    result <- testthat::test_file(
        file.path("tests", "testthat", test_file),
        reporter = testthat::SilentReporter$new()
    )
    summary <- as.data.frame(result)
    sum(summary$failed, na.rm = TRUE) == 0L &&
        sum(summary$error, na.rm = TRUE) == 0L
}

cases$publication_verified <- vapply(
    cases$reproducible_test,
    run_case,
    logical(1L)
)
if (!all(cases$publication_verified)) {
    stop("one or more scientific artifact publication proofs failed")
}

output <- file.path(
    ".github", "landing-proof", "issue-211", "publication-matrix.tsv"
)
dir.create(dirname(output), recursive = TRUE, showWarnings = FALSE)
utils::write.table(
    cases, output, sep = "\t", quote = FALSE, row.names = FALSE
)
cat("Wrote", output, "\n")
