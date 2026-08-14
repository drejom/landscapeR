#!/usr/bin/env Rscript

devtools::load_all(".", quiet = TRUE)

output <- file.path(
    ".github", "landing-proof", "issue-209",
    "publication-verification.tsv"
)
scratch <- file.path(".scratch", "issue-209-proof")
unlink(scratch, recursive = TRUE)
dir.create(scratch, recursive = TRUE, showWarnings = FALSE)

messages <- list(
    incomplete = "incomplete", missing_manifest = "incomplete",
    missing_payload = "incomplete", invalid = "invalid",
    undeclared = "undeclared", digest = "digest", atomic = "atomic"
)
abort <- function(message) stop(message, call. = FALSE)
governed <- c("evidence.rds", "summary.csv")
write_payload <- function(staging) {
    saveRDS(
        list(claim_status = "implementation_proof"),
        file.path(staging, "evidence.rds")
    )
    utils::write.csv(
        data.frame(outcome = "verified"),
        file.path(staging, "summary.csv"), row.names = FALSE
    )
}
verify <- function(artifact) {
    landscapeR:::.artifact_verify_payload(
        artifact, governed, abort, messages
    )
    invisible(TRUE)
}
publish <- function(root) {
    landscapeR:::.artifact_publish(
        root, "proof-v1", governed, write_payload, verify, abort, messages,
        ".proof-tmp-"
    )
}

root <- file.path(scratch, "published")
artifact <- publish(root)
first_address <- basename(artifact)
same_address <- identical(publish(root), artifact)
verified <- isTRUE(verify(artifact))

tampered <- file.path(scratch, "tampered")
tampered_artifact <- publish(tampered)
writeLines("changed", file.path(tampered_artifact, "summary.csv"))
tamper_rejected <- inherits(
    try(verify(tampered_artifact), silent = TRUE), "try-error"
)

result <- data.frame(
    check = c(
        "first publication verifies", "repeat uses the same address",
        "payload mutation is rejected"
    ),
    observed = c(verified, same_address, tamper_rejected),
    artifact_address = c(first_address, first_address, first_address),
    stringsAsFactors = FALSE
)
dir.create(dirname(output), recursive = TRUE, showWarnings = FALSE)
utils::write.table(
    result, output, sep = "\t", quote = FALSE, row.names = FALSE
)
cat("Wrote", output, "\n")
