#!/usr/bin/env Rscript

devtools::load_all(quiet = TRUE)

proof_dir <- file.path(".github", "landing-proof", "issue-177")
dir.create(proof_dir, recursive = TRUE, showWarnings = FALSE)
protocol <- k1_acceptance_protocol("2")

cell_grid <- function(control, replicates) {
    grid <- expand.grid(
        n = protocol$grids$generic_double_well$varying$n,
        p = protocol$grids$generic_double_well$varying$p,
        KEEP.OUT.ATTRS = FALSE,
        stringsAsFactors = FALSE
    )
    grid$control <- control
    grid$canonical_cell <- paste0(
        "control=", control, ";n=", grid$n, ";p=", grid$p
    )
    grid$n_requested <- replicates
    grid
}

generic <- cell_grid("generic_double_well", 100L)
pure_noise <- cell_grid("pure_noise", 200L)
single_well <- cell_grid("single_well", 200L)
cells <- rbind(generic, pure_noise, single_well)
n_scaled <- (log2(cells$n) - log2(8)) / (log2(192) - log2(8))
p_scaled <- (log10(cells$p) - 2) / (log10(20000) - 2)
positive <- cells$control == "generic_double_well"
cells$replicate_pass_rate <- ifelse(
    positive,
    pmin(0.99, pmax(0.18, 0.30 + 0.75 * n_scaled - 0.17 * p_scaled)),
    pmax(0.92, 0.995 - 0.025 * p_scaled - 0.02 * (1 - n_scaled))
)
cells$n_completed <- cells$n_requested
cells$n_passed <- as.integer(round(
    cells$n_requested * cells$replicate_pass_rate
))
cells$wilson_95_lower <- pmax(0, cells$replicate_pass_rate - 0.04)
cells$false_double_well_rate <- ifelse(
    positive,
    NA_real_,
    pmax(0, 0.01 + 0.035 * (1 - n_scaled) + 0.005 * p_scaled)
)
cells$false_target_selection_rate <- ifelse(
    positive,
    NA_real_,
    pmax(0, 0.008 + 0.03 * (1 - n_scaled) + 0.005 * p_scaled)
)
cells$complete_cell <- TRUE
cells$cell_pass <- cells$replicate_pass_rate >= 0.90 &
    cells$wilson_95_lower >= 0.80 &
    (positive | (
        cells$false_double_well_rate <= 0.05 &
        cells$false_target_selection_rate <= 0.05
    ))

shared <- data.frame(
    n = 15L,
    p = 1000L,
    control = "shared_baseline_missing_cells",
    canonical_cell =
        "control=shared_baseline_missing_cells;design_cell=1",
    n_requested = 100L,
    replicate_pass_rate = 1,
    n_completed = 100L,
    n_passed = 100L,
    wilson_95_lower = 0.963,
    false_double_well_rate = NA_real_,
    false_target_selection_rate = NA_real_,
    complete_cell = TRUE,
    cell_pass = TRUE,
    stringsAsFactors = FALSE
)
cells <- rbind(cells, shared)
cells <- cells[, c(
    "canonical_cell", "control", "n", "p", "n_requested", "n_completed",
    "n_passed", "replicate_pass_rate", "wilson_95_lower",
    "false_double_well_rate", "false_target_selection_rate",
    "complete_cell", "cell_pass"
)]

summary_fixture <- structure(list(
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
    complete_execution = TRUE,
    digest = "development-only-not-an-acceptance-digest"
), class = c("K1AcceptanceSummary", "list"))

pass_plot <- plot_k1_acceptance_summary(summary_fixture, "pass_rate")
false_plot <- plot_k1_acceptance_summary(summary_fixture, "false_positive")
ggplot2::ggsave(
    file.path(proof_dir, "lower-tail-pass-rate-surface.png"),
    pass_plot,
    width = 100,
    height = 100,
    units = "mm",
    dpi = 450,
    bg = "white"
)
ggplot2::ggsave(
    file.path(proof_dir, "lower-tail-false-positive-surface.png"),
    false_plot,
    width = 100,
    height = 100,
    units = "mm",
    dpi = 450,
    bg = "white"
)
writeLines(
    scientific_caption(pass_plot),
    file.path(proof_dir, "lower-tail-pass-rate-caption.txt")
)
writeLines(
    scientific_caption(false_plot),
    file.path(proof_dir, "lower-tail-false-positive-caption.txt")
)

development_task <- data.frame(
    task_id = "issue-177-shared-baseline-development-proof",
    control = "shared_baseline_missing_cells",
    seed_root = 177001L,
    stringsAsFactors = FALSE
)
development_task$stream_seeds <- list(c(
    generation = 177001L,
    association = 177002L
))
source <- landscapeR:::.k1_acceptance_shared_baseline_source(
    development_task,
    protocol
)
analysis <- protocol$execution_contracts$shared_baseline_missing_cells_analysis
specification <- analysis_specification(
    id = "issue-177-shared-baseline-development-proof",
    target_field = analysis$target_field,
    target_type = analysis$target_type,
    reference_level = analysis$reference_level,
    comparison_level = analysis$comparison_level,
    claim_intent = analysis$claim_intent
)
config <- PipelineConfig(
    strategies = list(Decomposer = protocol$strategies$decomposer),
    params = list(svd = protocol$execution_contracts$svd),
    dataset = metadata(source)$dataset_id,
    analysis = specification
)
discovery <- run_pipeline(source, config)
atlas <- associate_metadata(
    discovery@value,
    specification = specification,
    dataset_id = config@dataset,
    n_resamples = 0L,
    seed = 177002L,
    sequential_internal = TRUE
)
atlas <- landscapeR:::.k1_label_baseline_atlas(
    atlas,
    source
)
proposal <- propose_component(atlas)
stopifnot(
    is(proposal, "ComponentAbstention"),
    identical(proposal@reason, "non-identifiable-design")
)
design_plot <- plot(atlas)
ggplot2::ggsave(
    file.path(proof_dir, "shared-baseline-missing-cell-design.png"),
    design_plot,
    width = 100,
    height = 100,
    units = "mm",
    dpi = 450,
    bg = "white"
)
writeLines(
    scientific_caption(design_plot),
    file.path(proof_dir, "shared-baseline-missing-cell-caption.txt")
)
utils::write.table(
    data.frame(
        observed_design = c(
            "control at time 0 only",
            "treated at times 0, 1, 2, and 3"
        ),
        independent_biological_units = c(3L, 12L),
        duplicated_controls = c(FALSE, FALSE),
        proposal_class = c(class(proposal)[[1L]], class(proposal)[[1L]]),
        outcome = c(proposal@reason, proposal@reason),
        stringsAsFactors = FALSE
    ),
    file.path(proof_dir, "shared-baseline-safety-result.tsv"),
    sep = "\t",
    quote = FALSE,
    row.names = FALSE
)

workload <- data.frame(
    control = c(
        "Double-well recovery", "Pure noise", "Single well",
        "Shared-baseline safety", "Synchronized AML"
    ),
    grid_cells = c(32L, 32L, 32L, 1L, 9L),
    replicates_per_cell = c(100L, 200L, 200L, 100L, 100L),
    tasks = c(3200L, 6400L, 6400L, 100L, 900L),
    execution_status = rep("defined; production seeds not derived", 5L),
    stringsAsFactors = FALSE
)
utils::write.table(
    workload,
    file.path(proof_dir, "version-2-workload.tsv"),
    sep = "\t",
    quote = FALSE,
    row.names = FALSE
)
