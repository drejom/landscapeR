#!/usr/bin/env Rscript

devtools::load_all(quiet = TRUE)
source("tests/testthat/helper-independent-time-course.R")

output_dir <- file.path(".github", "landing-proof", "issue-128")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

legacy_focal <- "#B2182B"
legacy_marker <- "#C61A2A"
semantic <- landscapeR_palette("semantic")

replace_binary_scales <- function(plot, focal) {
    plot +
        ggplot2::scale_colour_manual(values = c(
            control = unname(semantic[["ink"]]),
            treatment = focal
        )) +
        ggplot2::scale_fill_manual(values = c(
            control = unname(semantic[["paper"]]),
            treatment = focal
        ))
}

replace_layer_colour <- function(plot, from, to, aesthetic = "colour") {
    for (index in seq_along(plot$layers)) {
        value <- plot$layers[[index]]$aes_params[[aesthetic]]
        if (identical(value, from)) {
            plot$layers[[index]]$aes_params[[aesthetic]] <- to
        }
    }
    plot
}

time_atlas <- associate_metadata(
    independent_time_course_fixture(),
    specification = independent_time_course_specification("batch"),
    non_analytical_fields = "sample_id",
    n_resamples = 9L,
    seed = 12801L
)
time_after <- plot(time_atlas) + ggplot2::labs(subtitle = NULL)
time_before <- replace_binary_scales(time_after, legacy_focal)

primary <- sprintf("sample_%02d", 1:12)
assay_ids <- sprintf("rna_%02d", 1:12)
condition <- factor(
    rep(c("control", "treatment"), each = 6L),
    levels = c("control", "treatment")
)
cross_data <- StateTransitionData(
    experiments = list(
        rna = SummarizedExperiment::SummarizedExperiment(
            assays = list(logcounts = matrix(
                seq_len(60L),
                nrow = 5L,
                dimnames = list(sprintf("gene_%02d", 1:5), assay_ids)
            ))
        )
    ),
    colData = S4Vectors::DataFrame(
        condition = condition,
        developmental_day = rep(seq_len(6L), 2L),
        sample_id = primary,
        row.names = primary
    ),
    sampleMap = S4Vectors::DataFrame(
        assay = factor(rep("rna", 12L), levels = "rna"),
        primary = primary,
        colname = assay_ids
    )
)
cross_data <- declare_sampling_design(cross_data, cross_sectional())
cross_metadata <- S4Vectors::metadata(cross_data)
cross_metadata$stage1 <- DecompositionResult(
    V_star = c(1, 0, 0, 0, 0),
    sigma = 1,
    coords = list(seq_len(12L)),
    V_k = diag(5)[, 1:2, drop = FALSE],
    sigma_k = matrix(c(2, 1), nrow = 1L),
    coords_k = list(cbind(
        PC1 = c(seq(-1.2, -0.2, length.out = 6L),
                seq(0.2, 1.2, length.out = 6L)),
        PC2 = rep(c(-0.35, 0.35), 6L)
    )),
    k = 2L
)
S4Vectors::metadata(cross_data) <- cross_metadata
cross_specification <- analysis_specification(
    id = "Issue 128 binary contrast",
    target_field = "condition",
    target_type = "binary",
    reference_level = "control",
    comparison_level = "treatment"
)
cross_atlas <- associate_metadata(
    cross_data,
    specification = cross_specification,
    non_analytical_fields = "sample_id",
    n_resamples = 9L,
    seed = 12802L
)
proposal <- propose_component(cross_atlas)

atlas_after <- plot(cross_atlas) + ggplot2::labs(subtitle = NULL)
atlas_before <- replace_layer_colour(
    plot(cross_atlas) + ggplot2::labs(subtitle = NULL),
    unname(semantic[["nuisance"]]),
    legacy_focal
)
proposal_after <- plot(proposal) + ggplot2::labs(subtitle = NULL)
proposal_before <- replace_layer_colour(
    plot(proposal) + ggplot2::labs(subtitle = NULL),
    unname(semantic[["focal"]]),
    legacy_marker,
    aesthetic = "fill"
)

plots <- list(
    `before-time-course` = time_before,
    `after-time-course` = time_after,
    `before-association-atlas` = atlas_before,
    `after-association-atlas` = atlas_after,
    `before-component-proposal` = proposal_before,
    `after-component-proposal` = proposal_after
)
for (name in names(plots)) {
    save_landscapeR_plot(
        plots[[name]],
        file.path(output_dir, paste0(name, ".png")),
        width_mm = 100,
        height_mm = 100
    )
}
writeLines(
    scientific_caption(time_after),
    file.path(output_dir, "time-course-caption.txt")
)
writeLines(
    scientific_caption(atlas_after),
    file.path(output_dir, "association-atlas-caption.txt")
)
writeLines(
    scientific_caption(proposal_after),
    file.path(output_dir, "component-proposal-caption.txt")
)

cat("Rendered issue #128 publication-palette proof.\n")
