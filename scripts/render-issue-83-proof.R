#!/usr/bin/env Rscript

devtools::load_all(quiet = TRUE)

output_dir <- file.path(".github", "landing-proof", "issue-83")
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
data <- StateTransitionData(
    experiments = list(
        rna = SummarizedExperiment::SummarizedExperiment(
            assays = list(logcounts = expression)
        )
    ),
    colData = S4Vectors::DataFrame(
        condition = condition,
        sample_id = primary,
        row.names = primary
    ),
    sampleMap = S4Vectors::DataFrame(
        assay = factor(rep("rna", n), levels = "rna"),
        primary = primary,
        colname = assay_ids
    )
)
data <- declare_sampling_design(data, cross_sectional())
specification <- analysis_specification(
    id = "issue-83-identifiability-proof",
    target_field = "condition",
    target_type = "binary",
    reference_level = "control",
    comparison_level = "treatment"
)
config <- new(
    "PipelineConfig",
    strategies = list(Decomposer = "svd"),
    params = list(svd = list(center = TRUE, k_components = 3L)),
    dataset = "issue-83-identifiability-proof",
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
    seed = 8301L
)
evidence <- proposal_identifiability(assessed)
identifiability_plot <- plot_component_identifiability(assessed)
caption <- scientific_caption(identifiability_plot)

save_landscapeR_plot(
    identifiability_plot,
    file.path(output_dir, "identifiability-surface.png")
)
writeLines(
    caption,
    file.path(output_dir, "identifiability-surface-caption.txt")
)
write.table(
    evidence$recurrence,
    file.path(output_dir, "component-recurrence.tsv"),
    sep = "\t",
    quote = FALSE,
    row.names = FALSE
)
write.table(
    evidence$recurrence_summary,
    file.path(output_dir, "recurrence-summary.tsv"),
    sep = "\t",
    quote = FALSE,
    row.names = FALSE
)
saveRDS(
    assessed,
    file.path(output_dir, "assessed-proposal.rds"),
    version = 3L
)
