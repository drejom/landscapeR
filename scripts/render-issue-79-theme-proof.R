#!/usr/bin/env Rscript

# Render the deterministic publication-theme proof that precedes issue #79.

suppressPackageStartupMessages(
  devtools::load_all(".", quiet = TRUE)
)

set.seed(79L)
output_dir <- ".github/landing-proof/issue-79"
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

binary_data <- data.frame(
  group = factor(
    rep(c("control", "treatment"), each = 24L),
    levels = c("treatment", "control")
  ),
  time = rep(seq(0, 1, length.out = 24L), 2L),
  score = c(
    seq(-0.7, 0.5, length.out = 24L),
    seq(-0.5, 1.1, length.out = 24L)
  ) + stats::rnorm(48L, sd = 0.12)
)
binary_plot <- ggplot2::ggplot(
  binary_data,
  ggplot2::aes(time, score, colour = group)
) +
  ggplot2::geom_point(size = 1.7, alpha = 0.85) +
  ggplot2::geom_smooth(method = "lm", se = FALSE, linewidth = 0.65) +
  scale_colour_landscapeR(
    "binary",
    reference_level = "control",
    focal_level = "treatment",
    name = NULL
  ) +
  ggplot2::labs(
    title = "Declared binary contrast",
    x = "Observed time",
    y = "Component score"
  ) +
  theme_landscapeR()

categorical_data <- data.frame(
  mouse = factor(rep(sprintf("mouse %02d", 1:9), each = 4L)),
  time = rep(seq(0, 1, length.out = 4L), 9L)
)
categorical_data$score <- with(
  categorical_data,
  0.8 * time +
    rep(seq(-0.45, 0.45, length.out = 9L), each = 4L) +
    stats::rnorm(36L, sd = 0.06)
)
categorical_plot <- ggplot2::ggplot(
  categorical_data,
  ggplot2::aes(time, score, colour = mouse, group = mouse)
) +
  ggplot2::geom_line(linewidth = 0.55) +
  ggplot2::geom_point(size = 1.25) +
  scale_colour_landscapeR("categorical", name = NULL) +
  ggplot2::labs(
    title = "Repeated biological units",
    x = "Observed time",
    y = "Component score"
  ) +
  theme_landscapeR() +
  ggplot2::theme(legend.position = "none")

continuous_data <- data.frame(
  time = seq(0, 1, length.out = 60L)
)
continuous_data$score <- with(
  continuous_data,
  sin(time * pi) + stats::rnorm(60L, sd = 0.08)
)
continuous_plot <- ggplot2::ggplot(
  continuous_data,
  ggplot2::aes(time, score, colour = time)
) +
  ggplot2::geom_point(size = 1.8) +
  scale_colour_landscapeR(
    "continuous",
    name = "Observed time"
  ) +
  ggplot2::labs(
    title = "Continuous metadata",
    x = "Observed time",
    y = "Component score"
  ) +
  theme_landscapeR()

missing_std <- synthetic_control(
  n = 20L,
  p = 60L,
  K = 1L,
  signal = 20,
  seed = 79L
)
missing_cd <- colData(missing_std)
missing_cd$planted_group[1:3] <- NA_character_
colData(missing_std) <- missing_cd
missing_std <- suppressWarnings(
  decompose(get_strategy("Decomposer", "svd")(), missing_std)
)@value
missing_plot <- plot_components(
  missing_std,
  colour_by = "planted_group",
  n_components = 1L
) +
  ggplot2::labs(
    title = "Missing metadata remain visible",
    subtitle = NULL
  )

save_landscapeR_plot(
  binary_plot,
  file.path(output_dir, "binary-contrast.png")
)
save_landscapeR_plot(
  categorical_plot,
  file.path(output_dir, "categorical-units.png")
)
save_landscapeR_plot(
  continuous_plot,
  file.path(output_dir, "continuous-metadata.png")
)
save_landscapeR_plot(
  missing_plot,
  file.path(output_dir, "missing-metadata.png")
)

interpretation_primary <- sprintf("sample_%02d", 1:8)
interpretation_assay <- sprintf("rna_%02d", 1:8)
interpretation_std <- StateTransitionData(
  experiments = list(
    rna = SummarizedExperiment::SummarizedExperiment(
      assays = list(logcounts = matrix(
        seq_len(32L),
        nrow = 4L,
        dimnames = list(
          sprintf("gene_%02d", 1:4),
          interpretation_assay
        )
      ))
    )
  ),
  colData = S4Vectors::DataFrame(
    condition = factor(
      rep(c("control", "treatment"), each = 4L),
      levels = c("control", "treatment")
    ),
    mouse_id = sprintf("mouse_%02d", 1:8),
    row.names = interpretation_primary
  ),
  sampleMap = S4Vectors::DataFrame(
    assay = factor(rep("rna", 8L), levels = "rna"),
    primary = interpretation_primary,
    colname = interpretation_assay
  )
)
interpretation_std <- declare_sampling_design(
  interpretation_std,
  cross_sectional()
)
interpretation_metadata <- S4Vectors::metadata(interpretation_std)
interpretation_metadata$stage1 <- DecompositionResult(
  V_star = c(1, 0, 0, 0),
  sigma = 1,
  coords = list(1:8),
  V_k = diag(4)[, 1:2, drop = FALSE],
  sigma_k = matrix(c(2, 1), nrow = 1L),
  coords_k = list(cbind(
    PC1 = 1:8,
    PC2 = rep(c(-1, 1), 4L)
  )),
  k = 2L
)
S4Vectors::metadata(interpretation_std) <- interpretation_metadata
interpretation_atlas <- associate_metadata(
  interpretation_std,
  non_analytical_fields = "mouse_id",
  dataset_id = "synthetic-binary-control"
)
interpretation_proposal <- propose_component(
  interpretation_atlas,
  target = "condition"
)
stopifnot(methods::is(interpretation_proposal, "ComponentProposal"))

save_landscapeR_plot(
  plot(interpretation_atlas),
  file.path(output_dir, "association-atlas.png")
)
save_landscapeR_plot(
  plot(interpretation_proposal),
  file.path(output_dir, "component-proposal.png")
)

cat("Rendered issue #79 component-interpretation landing proof.\n")
