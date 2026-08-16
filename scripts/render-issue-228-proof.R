#!/usr/bin/env Rscript

# Reproducible proof that continuous component metadata renders without
# an unknown-fill-scale warning.
suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))

output_dir <- file.path(".github", "landing-proof", "issue-228")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

std <- synthetic_control(
    n = 40L, p = 500L, K = 2L, signal = 30, seed = 22801L
)
std_cd <- colData(std)
std_cd$observed_time <- seq_len(nrow(std_cd))
colData(std) <- std_cd
std <- suppressWarnings(
    decompose(get_strategy("Decomposer", "hogsvd_averaged")(), std)
)@value

old_warning <- options(warn = 2)
on.exit(options(old_warning), add = TRUE)
plot <- plot_components(std, colour_by = "observed_time", n_components = 2L)
ggplot2::ggsave(
    filename = file.path(output_dir, "continuous-component.png"),
    plot = plot,
    width = 100, height = 100, units = "mm", dpi = 300, bg = "white"
)
writeLines(
    scientific_caption(plot),
    file.path(output_dir, "continuous-component-caption.txt")
)
