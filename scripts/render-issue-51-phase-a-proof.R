#!/usr/bin/env Rscript

devtools::load_all(quiet = TRUE)

output_dir <- file.path(".github", "landing-proof", "issue-51-phase-a")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

protocol <- k1_acceptance_protocol()
validate_k1_acceptance_protocol(protocol)

summary <- data.frame(
    property = c(
        "protocol_status", "acceptance_execution_available",
        "generic_n_grid", "generic_p_grid", "minimum_cell_pass_rate",
        "minimum_cell_wilson_95_lower_bound",
        "maximum_false_double_well_rate", "replicate_plan",
        "protocol_digest"
    ),
    frozen_value = c(
        protocol$protocol_status,
        protocol$execution$acceptance_execution_available,
        paste(protocol$grids$generic_double_well$varying$n, collapse = ","),
        paste(protocol$grids$generic_double_well$varying$p, collapse = ","),
        protocol$pass_rules$minimum_cell_pass_rate,
        protocol$pass_rules$minimum_cell_wilson_95_lower_bound,
        protocol$thresholds$negative_controls$
            maximum_false_double_well_rate_per_control_cell,
        paste(paste(
            protocol$seed_plan$control,
            protocol$seed_plan$replicates_per_grid_cell,
            sep = "="
        ), collapse = ";"),
        protocol$digest
    ),
    stringsAsFactors = FALSE
)

utils::write.table(
    summary, file.path(output_dir, "protocol-summary.tsv"),
    sep = "\t", row.names = FALSE, quote = FALSE
)
