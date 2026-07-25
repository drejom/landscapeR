#!/usr/bin/env Rscript

# Render the deterministic publication-theme proof that precedes issue #79.

suppressPackageStartupMessages(
  devtools::load_all(".", quiet = TRUE)
)

set.seed(79L)
semantic <- landscapeR_palette("semantic")
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

cat("Rendered issue #79 publication-theme landing proof.\n")
