#!/usr/bin/env Rscript

devtools::load_all(quiet = TRUE)

output_dir <- file.path(".github", "landing-proof", "issue-80")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

primary <- sprintf("sample_%02d", 1:12)
assay_ids <- sprintf("rna_%02d", 1:12)
severity <- seq_len(12)
std <- StateTransitionData(
    experiments = list(
        rna = SummarizedExperiment::SummarizedExperiment(
            assays = list(logcounts = matrix(
                seq_len(48L),
                nrow = 4L,
                dimnames = list(sprintf("gene_%02d", 1:4), assay_ids)
            ))
        )
    ),
    colData = S4Vectors::DataFrame(
        severity = severity,
        batch = rep(c("run_1", "run_2"), 6L),
        mouse_id = sprintf("mouse_%02d", 1:12),
        row.names = primary
    ),
    sampleMap = S4Vectors::DataFrame(
        assay = factor(rep("rna", 12L), levels = "rna"),
        primary = primary,
        colname = assay_ids
    )
)
std <- declare_sampling_design(std, cross_sectional())
std_metadata <- S4Vectors::metadata(std)
std_metadata$stage1 <- DecompositionResult(
    V_star = c(1, 0, 0, 0),
    sigma = 1,
    coords = list(severity),
    V_k = diag(4)[, 1:2, drop = FALSE],
    sigma_k = matrix(c(2, 1), nrow = 1L),
    coords_k = list(cbind(
        PC1 = abs(severity - 6.5),
        PC2 = severity + rep(c(-0.35, 0.35), 6L)
    )),
    k = 2L
)
S4Vectors::metadata(std) <- std_metadata

specification <- analysis_specification(
    id = "issue-80-proof",
    target_field = "severity",
    target_type = "continuous",
    continuous_direction = "increasing",
    nuisance_fields = "batch"
)
atlas <- associate_metadata(
    std,
    specification = specification,
    non_analytical_fields = c("batch", "mouse_id"),
    n_resamples = 199L,
    seed = 7080L
)
proposal <- propose_component(
    atlas,
    n_permutations = 199L,
    seed = 8080L
)

ggplot2::ggsave(
    file.path(output_dir, "nonmonotone-atlas.png"),
    plot(atlas),
    width = 100,
    height = 100,
    units = "mm",
    dpi = 300,
    bg = "white"
)

evidence <- atlas_associations(atlas)
evidence <- evidence[evidence$metadata_field == "severity", , drop = FALSE]
evidence$component_label <- factor(
    evidence$component_label,
    levels = unique(evidence$component_label)
)
comparison <- ggplot2::ggplot(
    evidence,
    ggplot2::aes(
        x = .data[["component_label"]],
        y = .data[["estimate"]],
        shape = .data[["evidence_variant"]]
    )
) +
    ggplot2::geom_hline(yintercept = 0, colour = "#BDBDBD") +
    ggplot2::geom_errorbar(
        ggplot2::aes(
            ymin = .data[["effect_conf_low"]],
            ymax = .data[["effect_conf_high"]]
        ),
        width = 0.12,
        position = ggplot2::position_dodge(width = 0.35)
    ) +
    ggplot2::geom_point(
        size = 2.5,
        fill = "white",
        colour = "#111111",
        position = ggplot2::position_dodge(width = 0.35)
    ) +
    ggplot2::scale_shape_manual(values = c(unadjusted = 21, adjusted = 24)) +
    ggplot2::labs(
        title = "Raw and adjusted evidence remain separate",
        subtitle = "Points are rank-score effects; bars are bootstrap intervals",
        x = "Recovered component",
        y = "Association estimate",
        shape = "Evidence"
    ) +
    theme_landscapeR()

ggplot2::ggsave(
    file.path(output_dir, "raw-adjusted-evidence.png"),
    comparison,
    width = 100,
    height = 100,
    units = "mm",
    dpi = 300,
    bg = "white"
)

ggplot2::ggsave(
    file.path(output_dir, "search-aware-null.png"),
    plot(proposal_permutation_evidence(proposal)),
    width = 100,
    height = 100,
    units = "mm",
    dpi = 300,
    bg = "white"
)

confounded <- std
SummarizedExperiment::colData(confounded)$batch <-
    SummarizedExperiment::colData(confounded)$severity
confounded_atlas <- associate_metadata(
    confounded,
    specification = specification,
    non_analytical_fields = c("batch", "mouse_id")
)
adjustment_abstention <- propose_component(confounded_atlas)

ggplot2::ggsave(
    file.path(output_dir, "adjustment-abstention.png"),
    plot(adjustment_abstention),
    width = 100,
    height = 100,
    units = "mm",
    dpi = 300,
    bg = "white"
)

undeclared_atlas <- associate_metadata(
    std,
    non_analytical_fields = c("batch", "mouse_id")
)
permutation_abstention <- propose_component(
    undeclared_atlas,
    target = "severity",
    n_permutations = 199L,
    seed = 8081L
)

ggplot2::ggsave(
    file.path(output_dir, "permutation-abstention.png"),
    plot(permutation_abstention),
    width = 100,
    height = 100,
    units = "mm",
    dpi = 300,
    bg = "white"
)
