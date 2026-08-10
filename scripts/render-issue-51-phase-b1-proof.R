#!/usr/bin/env Rscript

devtools::load_all(quiet = TRUE)

proof_dir <- file.path(".github", "landing-proof", "issue-51-phase-b1")
dir.create(proof_dir, recursive = TRUE, showWarnings = FALSE)
protocol <- k1_acceptance_protocol()

cell_grid <- function(control, varying) {
    grid <- expand.grid(
        n = varying$n,
        p = varying$p,
        KEEP.OUT.ATTRS = FALSE,
        stringsAsFactors = FALSE
    )
    grid$control <- control
    grid$canonical_cell <- paste0(
        "control=", control, ";n=", grid$n, ";p=", grid$p
    )
    grid
}

generic <- cell_grid(
    "generic_double_well",
    protocol$grids$generic_double_well$varying
)
pure_noise <- cell_grid(
    "pure_noise",
    protocol$grids$negative_controls$varying
)
single_well <- cell_grid(
    "single_well",
    protocol$grids$negative_controls$varying
)
cells <- rbind(generic, pure_noise, single_well)

n_scaled <- (cells$n - min(cells$n)) / (max(cells$n) - min(cells$n))
p_scaled <- log10(cells$p) / max(log10(cells$p))
is_generic <- cells$control == "generic_double_well"
cells$n_requested <- ifelse(is_generic, 100L, 200L)
cells$n_completed <- cells$n_requested
cells$replicate_pass_rate <- ifelse(
    is_generic,
    pmin(0.99, 0.68 + 0.32 * n_scaled - 0.08 * p_scaled),
    pmax(0.88, 0.99 - 0.03 * p_scaled - 0.02 * (1 - n_scaled))
)
cells$n_passed <- as.integer(round(
    cells$n_requested * cells$replicate_pass_rate
))
cells$wilson_95_lower <- pmax(0, cells$replicate_pass_rate - 0.04)
cells$false_double_well_rate <- ifelse(
    is_generic,
    NA_real_,
    pmax(0, 0.075 - 0.06 * n_scaled + 0.015 * p_scaled)
)
cells$false_target_selection_rate <- ifelse(
    is_generic,
    NA_real_,
    pmax(0, 0.065 - 0.05 * n_scaled + 0.01 * p_scaled)
)
cells$complete_cell <- cells$n != min(cells$n)
cells$cell_pass <- cells$complete_cell &
    cells$replicate_pass_rate >=
        protocol$pass_rules$minimum_cell_pass_rate &
    cells$wilson_95_lower >=
        protocol$pass_rules$minimum_cell_wilson_95_lower_bound
negative_gate <- is_generic |
    (cells$false_double_well_rate <=
        protocol$thresholds$negative_controls$
            maximum_false_double_well_rate_per_control_cell &
    cells$false_target_selection_rate <=
        protocol$thresholds$negative_controls$
            maximum_false_target_selection_rate_per_control_cell)
cells$cell_pass <- cells$cell_pass & negative_gate
cells <- cells[, c(
    "canonical_cell", "control", "n", "p", "n_requested", "n_completed",
    "n_passed", "replicate_pass_rate", "wilson_95_lower",
    "false_double_well_rate", "false_target_selection_rate",
    "complete_cell", "cell_pass"
)]

summary <- structure(list(
    artifact_version = "proof-fixture",
    protocol_id = protocol$protocol_id,
    protocol_digest = protocol$digest,
    runner_contract = protocol$execution_contracts$version,
    claim_status = "development_only_visual_fixture",
    n_requested = sum(cells$n_requested),
    n_completed = sum(cells$n_completed),
    cells = cells,
    display_thresholds = list(
        minimum_cell_pass_rate =
            protocol$pass_rules$minimum_cell_pass_rate,
        minimum_cell_wilson_95_lower_bound =
            protocol$pass_rules$minimum_cell_wilson_95_lower_bound,
        maximum_negative_false_positive_rate =
            protocol$thresholds$negative_controls$
                maximum_false_double_well_rate_per_control_cell
    ),
    supported_minimum_n = NA_integer_,
    complete_execution = FALSE,
    digest = "development-only-not-an-acceptance-digest"
), class = c("K1AcceptanceSummary", "list"))

pass_plot <- plot_k1_acceptance_summary(summary, "pass_rate")
false_plot <- plot_k1_acceptance_summary(summary, "false_positive")
ggplot2::ggsave(
    file.path(proof_dir, "pass-rate-surface.png"),
    pass_plot,
    width = 180,
    height = 75,
    units = "mm",
    dpi = 180,
    bg = "white"
)
ggplot2::ggsave(
    file.path(proof_dir, "false-positive-surface.png"),
    false_plot,
    width = 150,
    height = 120,
    units = "mm",
    dpi = 180,
    bg = "white"
)
writeLines(
    scientific_caption(pass_plot),
    file.path(proof_dir, "pass-rate-caption.txt")
)
writeLines(
    scientific_caption(false_plot),
    file.path(proof_dir, "false-positive-caption.txt")
)

workload <- data.frame(
    phase = c("B1", "B1", "B1", "later"),
    control = c(
        "Double-well recovery", "Pure noise", "Single well",
        "Synchronized AML"
    ),
    grid_cells = c(20L, 16L, 16L, 9L),
    replicates_per_cell = c(100L, 200L, 200L, 100L),
    tasks = c(2000L, 3200L, 3200L, 900L),
    execution_status = c(
        "runner implemented; not executed",
        "runner implemented; not executed",
        "runner implemented; not executed",
        "blocked until issue #67 acceptance"
    ),
    stringsAsFactors = FALSE
)
utils::write.table(
    workload,
    file.path(proof_dir, "frozen-workload.tsv"),
    sep = "\t",
    quote = FALSE,
    row.names = FALSE
)
