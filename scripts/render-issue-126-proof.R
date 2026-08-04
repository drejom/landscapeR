#!/usr/bin/env Rscript

devtools::load_all(quiet = TRUE)

output_dir <- file.path(".github", "landing-proof", "issue-126")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

n <- 12L
primary <- sprintf("sample_%02d", seq_len(n))
assay_ids <- sprintf("rna_%02d", seq_len(n))
condition <- factor(
    rep(c("control", "treatment"), each = n / 2L),
    levels = c("control", "treatment")
)
signal <- ifelse(condition == "treatment", 2, -2)
expression <- rbind(
    gene_1 = signal + rep(c(-0.2, 0, 0.2), length.out = n),
    gene_2 = rep(c(-1, 1), length.out = n),
    gene_3 = seq(-0.5, 0.5, length.out = n),
    gene_4 = rep(c(-0.3, 0.1, 0.2), length.out = n),
    gene_5 = rep(c(0.2, -0.1), length.out = n),
    gene_6 = seq(0.3, -0.3, length.out = n)
)
colnames(expression) <- assay_ids
proof_metadata <- S4Vectors::DataFrame(
    condition = condition,
    sample_id = primary,
    row.names = primary
)
data <- StateTransitionData(
    experiments = list(
        `RNA expression` = SummarizedExperiment::SummarizedExperiment(
            assays = list(logcounts = expression)
        )
    ),
    colData = proof_metadata,
    sampleMap = S4Vectors::DataFrame(
        assay = factor(rep("RNA expression", n), levels = "RNA expression"),
        primary = primary,
        colname = assay_ids
    )
)
data <- declare_sampling_design(data, cross_sectional())
specification <- analysis_specification(
    id = "Synthetic single-axis identifiability analysis",
    target_field = "condition",
    target_type = "binary",
    reference_level = "control",
    comparison_level = "treatment"
)
config <- new(
    "PipelineConfig",
    strategies = list(Decomposer = "svd"),
    params = list(svd = list(center = TRUE, k_components = 1L)),
    dataset = "Synthetic single-axis expression study",
    analysis = specification
)
discovery_result <- decompose(
    get_strategy("Decomposer", "svd")(config@params$svd),
    data
)
stopifnot(identical(discovery_result@status, "success"))
atlas <- associate_metadata(
    discovery_result@value,
    specification = specification,
    non_analytical_fields = "sample_id",
    dataset_id = config@dataset
)
proposal <- propose_component(atlas)
assessed <- assess_component_identifiability(
    data = data,
    proposal = proposal,
    config = config,
    non_analytical_fields = "sample_id",
    n_resamples = 99L,
    seed = 12601L
)
evidence <- proposal_identifiability(assessed)

plots <- list(
    primary = plot_component_identifiability(assessed),
    diagnostic = plot_component_identifiability(assessed, view = "diagnostic"),
    audit = plot_component_identifiability(assessed, view = "audit")
)
for (name in names(plots)) {
    save_landscapeR_plot(
        plots[[name]],
        file.path(output_dir, paste0(name, ".png")),
        width_mm = 100,
        height_mm = 100
    )
    writeLines(
        scientific_caption(plots[[name]]),
        file.path(output_dir, paste0(name, "-caption.txt"))
    )
}

summary <- data.frame(
    status = evidence$status,
    structured_outcome = evidence$structured_outcome,
    requested = evidence$n_requested,
    completed = evidence$n_completed,
    failed = evidence$n_failed,
    competitor_assignments = length(
        evidence$replicates[[1L]]$competing_assignments
    ),
    local_assignment_margin =
        evidence$replicates[[1L]]$assignment$assignment_margin,
    global_assignment_margin =
        evidence$replicates[[1L]]$global_assignment_margin,
    stringsAsFactors = FALSE
)
utils::write.table(
    summary,
    file.path(output_dir, "typed-status.tsv"),
    sep = "\t",
    quote = FALSE,
    row.names = FALSE
)
