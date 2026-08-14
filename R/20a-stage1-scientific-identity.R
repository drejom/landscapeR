# Backend-independent Stage 1 scientific identity projections.
#
# These helpers define which stored fields establish scientific identity. They
# deliberately exclude scheduler, timing, memory, and serialization telemetry.
# Artifact adapters and orchestration both depend on this lower-level contract.

.stage1_scientific_results <- function(results) {
    operational <- intersect(
        c("elapsed_sec", "peak_vcells_bytes", "completed_at_utc"),
        names(results)
    )
    scientific <- results[setdiff(names(results), operational)]
    for (field in intersect(
        c("exclusions", "failure_reason"), names(scientific)
    )) {
        scientific[[field]] <- as.character(scientific[[field]])
        scientific[[field]][is.na(scientific[[field]])] <- ""
    }
    scientific
}

.stage1_scientific_selection <- function(selection) {
    selection[c(
        "protocol_id", "protocol_digest", "generator_digest", "split",
        "decision", "selected_candidate", "eligible", "conditions",
        "shared_recovery_difference", "shared_recovery_ci",
        "exclusive_leakage_difference", "projection_difference"
    )]
}

.stage1_scientific_holdout <- function(holdout) {
    operational_metrics <- c("elapsed_sec", "peak_vcells_bytes")
    summary <- holdout$summary
    if (is.data.frame(summary)) {
        summary <- summary[
            !summary$metric %in% operational_metrics, , drop = FALSE
        ]
    }
    holdout[c(
        "protocol_id", "protocol_digest", "generator_digest", "split",
        "selected_candidate", "all_gates_passed", "thresholds_passed",
        "decision", "rules"
    )] |>
        c(list(summary = summary))
}
