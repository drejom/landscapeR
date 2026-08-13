devtools::load_all(quiet = TRUE)

protocol <- k1_acceptance_protocol("3")
replicates <- unlist(protocol$workload$replicates_by_control, use.names = TRUE)
cells <- replicates / protocol$seed_plan$replicates_per_grid_cell

labels <- c(
    independent_time_course = "Destructive time courses",
    repeated_subject = "Repeated-subject time courses",
    high_dimensional_signal = "High-dimensional signal regimes",
    high_dimensional_null = "Null and near-null regimes"
)
summary <- data.frame(
    evidence_family = unname(labels[names(replicates)]),
    declared_cells = as.integer(cells),
    replicates_per_cell = protocol$seed_plan$replicates_per_grid_cell,
    requested_replicates = as.integer(replicates),
    canonical_recovery = paste0(
        "absolute loading cosine >= ",
        format(protocol$thresholds$target_axis_recovery$minimum, nsmall = 2L)
    ),
    claim_before_execution = "predeclared protocol only",
    stringsAsFactors = FALSE
)

proof_root <- ".github/landing-proof/issue-193"
dir.create(proof_root, recursive = TRUE, showWarnings = FALSE)
utils::write.csv(
    summary,
    file.path(proof_root, "revised-acceptance-contract.csv"),
    row.names = FALSE
)
writeLines(
    c(
        paste("Protocol:", protocol$protocol_id),
        paste("Digest:", protocol$digest),
        paste("Requested replicates:", protocol$workload$total_replicates),
        paste("Acceptance results inspected:",
            protocol$provenance$acceptance_results_inspected),
        paste("Execution available before merge:",
            protocol$execution$acceptance_execution_available)
    ),
    file.path(proof_root, "protocol-identity.txt")
)
