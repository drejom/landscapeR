#!/usr/bin/env Rscript

# Reproducible caption/render fidelity proof for issue #231.
suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))

output_dir <- file.path(".github", "landing-proof", "issue-231")
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

atlas <- associate_metadata(
    data,
    specification = analysis_specification(
        id = "issue-231-binary",
        target_field = "condition",
        target_type = "binary",
        reference_level = "control",
        comparison_level = "treatment"
    ),
    non_analytical_fields = "sample_id",
    dataset_id = "Issue 231 binary fixture"
)
abstention <- associate_metadata(
    data,
    specification = analysis_specification(
        id = "issue-231-invalid-target",
        target_field = "condition",
        target_type = "continuous",
        continuous_direction = "increasing"
    ),
    non_analytical_fields = "sample_id",
    dataset_id = "Issue 231 binary fixture"
)

figures <- list(
    cross_sectional_atlas = plot(atlas),
    association_abstention = plot(abstention)
)
for (name in names(figures)) {
    save_landscapeR_plot(
        figures[[name]],
        file.path(output_dir, paste0(name, ".png")),
        width_mm = 100,
        height_mm = 100,
        dpi = 300
    )
    writeLines(
        strwrap(scientific_caption(figures[[name]]), width = 100L),
        file.path(output_dir, paste0(name, "-caption.txt"))
    )
    save_landscapeR_plot(
        figures[[name]],
        file.path(output_dir, paste0(name, "-reduced.png")),
        width_mm = 80,
        height_mm = 80,
        dpi = 300
    )
}

readme <- c(
    "# Issue #231 caption/render fidelity proof",
    "",
    paste(
        "The binary cross-sectional atlas renders boxplots and individual",
        "observations. Its caption describes those marks and does not claim",
        "continuous fitted curves."
    ),
    "",
    paste(
        "The association-abstention surface renders its public reason and",
        "diagnostic in black. Its caption describes that black text and does",
        "not claim a red subtitle."
    ),
    "",
    paste(
        "Inspection set: cross_sectional_atlas.png and -reduced.png;",
        "association_abstention.png and -reduced.png."
    ),
    "",
    "Reproduce with `Rscript scripts/render-issue-231-proof.R`.",
    "",
    "Claim status: implementation proof; no biological claim."
)
writeLines(readme, file.path(output_dir, "README.md"))
