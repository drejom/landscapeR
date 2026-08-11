#!/usr/bin/env Rscript

devtools::load_all(quiet = TRUE)

artifact_name <- "k1-stage0-acceptance-v2-780f4b10ea21923a"
artifact_dir <- file.path("inst", "benchmarks", artifact_name)
proof_dir <- file.path(".github", "landing-proof", "issue-51-phase-b1")
stopifnot(verify_k1_acceptance_artifact(artifact_dir))
dir.create(proof_dir, recursive = TRUE, showWarnings = FALSE)

summary <- readRDS(file.path(artifact_dir, "summary.rds"))
pass_plot <- plot_k1_acceptance_summary(summary, "pass_rate")
false_plot <- plot_k1_acceptance_summary(summary, "false_positive")

ggplot2::ggsave(
    file.path(proof_dir, "pass-rate-surface.png"),
    pass_plot,
    width = 100,
    height = 100,
    units = "mm",
    dpi = 450,
    bg = "white"
)
ggplot2::ggsave(
    file.path(proof_dir, "false-positive-surface.png"),
    false_plot,
    width = 100,
    height = 100,
    units = "mm",
    dpi = 450,
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
utils::write.csv(
    summary$cells,
    file.path(proof_dir, "cell-summary.csv"),
    row.names = FALSE
)
