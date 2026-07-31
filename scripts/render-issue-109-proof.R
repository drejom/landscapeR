#!/usr/bin/env Rscript

devtools::load_all(quiet = TRUE)

output_dir <- file.path(".github", "landing-proof", "issue-109")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

std <- synthetic_control(
    n = 20L, p = 60L, K = 1L, signal = 20, seed = 127L
)
stage1 <- suppressWarnings(
    decompose(get_strategy("Decomposer", "svd")(), std)
)@value
group <- as.character(colData(stage1)$planted_group)
focal_group <- unique(group)[[1L]]
focal <- which(group == focal_group)
md <- metadata(stage1)
md$stage1@coords_k[[1L]][focal, 1L] <-
    10 + seq_along(focal) * 1e-9
metadata(stage1) <- md
stage1 <- prepare_plot_evidence(stage1, stage = "stage1")

plot <- plot_components(
    stage1,
    colour_by = "planted_group",
    n_components = 3L
)
ggplot2::ggsave(
    file.path(output_dir, "degenerate-density-slice.png"),
    plot,
    width = 100,
    height = 100,
    units = "mm",
    dpi = 300
)
writeLines(
    scientific_caption(plot),
    file.path(output_dir, "degenerate-density-slice-caption.txt")
)

density_evidence <- metadata(stage1)$stage1_plot_evidence@
    displays$component_group_densities[[1L]]$planted_group
utils::write.table(
    density_evidence[!density_evidence$density_available, , drop = FALSE],
    file.path(output_dir, "unavailable-density-slices.tsv"),
    sep = "\t",
    quote = FALSE,
    row.names = FALSE
)
