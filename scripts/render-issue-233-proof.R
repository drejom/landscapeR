#!/usr/bin/env Rscript

# Reproducible compact empty-state layout proof for issue #233.
suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))

output_dir <- file.path(".github", "landing-proof", "issue-233")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

primary <- sprintf("sample_%02d", seq_len(10L))
assay_ids <- sprintf("rna_%02d", seq_len(10L))
se <- SummarizedExperiment::SummarizedExperiment(
    assays = list(logcounts = matrix(
        seq_len(50L),
        nrow = 5L,
        dimnames = list(sprintf("gene_%02d", 1:5), assay_ids)
    ))
)
data <- StateTransitionData(
    experiments = list(rna = se),
    colData = S4Vectors::DataFrame(
        condition = factor(
            rep(c("control", "treatment"), each = 5L),
            levels = c("control", "treatment")
        ),
        batch = factor(
            rep(c("batch_1", "batch_2"), each = 5L),
            levels = c("batch_1", "batch_2")
        ),
        sample_id = primary,
        row.names = primary
    ),
    sampleMap = S4Vectors::DataFrame(
        assay = factor(rep("rna", 10L), levels = "rna"),
        primary = primary,
        colname = assay_ids
    )
)
data <- declare_sampling_design(data, cross_sectional())
coords <- cbind(
    PC1 = c(-1.5, -1.2, -0.9, -0.5, -0.2, 0.3, 0.6, 1, 1.3, 1.6),
    PC2 = c(-0.8, 0.4, -0.3, 0.6, 0.1, -0.5, 0.5, -0.2, 0.7, -0.4)
)
md <- metadata(data)
md$stage1 <- DecompositionResult(
    V_star = c(1, 0, 0, 0, 0),
    sigma = 1,
    coords = list(coords[, 1L]),
    V_k = diag(5)[, 1:2, drop = FALSE],
    sigma_k = matrix(c(2, 1), nrow = 1L),
    coords_k = list(coords),
    k = 2L
)
metadata(data) <- md

invalid_target <- associate_metadata(
    data,
    specification = analysis_specification(
        id = "issue-233-invalid-target",
        target_field = "condition",
        target_type = "continuous",
        continuous_direction = "increasing"
    ),
    non_analytical_fields = "sample_id",
    dataset_id = "Issue 233 empty-state fixture"
)
confounded_data <- data
colData(confounded_data)$batch <- colData(confounded_data)$condition
confounded <- associate_metadata(
    confounded_data,
    specification = analysis_specification(
        id = "issue-233-confounded-target",
        target_field = "condition",
        target_type = "binary",
        reference_level = "control",
        comparison_level = "treatment",
        nuisance_fields = "batch"
    ),
    non_analytical_fields = "sample_id",
    dataset_id = "Issue 233 empty-state fixture"
)
component_abstention <- propose_component(confounded)

figures <- list(
    association_abstention = plot(invalid_target),
    component_abstention = plot(component_abstention)
)
for (name in names(figures)) {
    figure <- figures[[name]]
    save_landscapeR_plot(
        figure,
        file.path(output_dir, paste0(name, ".png")),
        width_mm = 100,
        height_mm = 100,
        dpi = 300
    )
    writeLines(
        strwrap(scientific_caption(figure), width = 100L),
        file.path(output_dir, paste0(name, "-caption.txt"))
    )
    save_landscapeR_plot(
        figure,
        file.path(output_dir, paste0(name, "-reduced.png")),
        width_mm = 80,
        height_mm = 80,
        dpi = 300
    )
}

writeLines(
    c(
        "# Issue #233 compact empty-state layout proof",
        "",
        "The association-abstention surface uses the shared compact layout",
        "tokens: a grey ABSTENTION tag, a public reason in the subtitle, and",
        "the recorded diagnostic in black. It does not imply an estimand or",
        "draw a substitute scientific result.",
        "",
        "The component-abstention surface uses the same status hierarchy when",
        "no finite component ranking is available. Both figures preserve the",
        "intentional whitespace needed for title, reason, and diagnostic text",
        "without leaving an unexplained empty plotting panel.",
        "",
        "Native outputs are 100 x 100 mm; reduced outputs are 80 x 80 mm.",
        "Inspect both at final size before publication.",
        "",
        "Reproduce with `Rscript scripts/render-issue-233-proof.R`.",
        "",
        "Claim status: implementation proof; no biological claim."
    ),
    file.path(output_dir, "README.md")
)
