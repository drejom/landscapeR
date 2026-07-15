#!/usr/bin/env Rscript

# Render the current categorical and continuous issue #54 gallery proof.
# The archival before.png was rendered from origin/main before the repair using
# the same deterministic fixture.

suppressPackageStartupMessages({
  devtools::load_all(".", quiet = TRUE)
  library(MultiAssayExperiment)
  library(SummarizedExperiment)
  library(S4Vectors)
})

component_gallery_fixture <- function() {
  n <- 24L
  primary <- sprintf("p%02d", seq_len(n))
  assay_names <- sprintf("rna_%02d", seq_len(n))
  assay_order <- c(
    7L, 2L, 19L, 4L, 23L, 6L, 1L, 8L, 17L, 10L, 3L, 12L,
    21L, 14L, 5L, 16L, 9L, 18L, 11L, 20L, 13L, 22L, 15L, 24L
  )
  cd_order <- c(
    24L, 1L, 23L, 2L, 22L, 3L, 21L, 4L, 20L, 5L, 19L, 6L,
    18L, 7L, 17L, 8L, 16L, 9L, 15L, 10L, 14L, 11L, 13L, 12L
  )
  condition <- rep(c("CTL", "CM"), length.out = n)
  sample_weeks <- seq(0, by = 1.5, length.out = n)

  cd <- DataFrame(
    condition = condition[cd_order],
    sample_weeks = sample_weeks[cd_order],
    row.names = primary[cd_order]
  )
  assay_primary <- primary[assay_order]
  assay_colnames <- assay_names[assay_order]
  se <- SummarizedExperiment(
    assays = list(logcounts = matrix(
      seq_len(5L * n),
      nrow = 5L,
      dimnames = list(sprintf("g%d", 1:5), assay_colnames)
    ))
  )
  map_order <- rev(seq_len(n))
  std <- StateTransitionData(
    experiments = list(rna = se),
    colData = cd,
    sampleMap = DataFrame(
      assay = factor(rep("rna", n), levels = "rna"),
      primary = assay_primary[map_order],
      colname = assay_colnames[map_order]
    )
  )

  original_index <- match(assay_primary, primary)
  coords <- cbind(
    PC1 = sin(original_index / 3),
    PC2 = ifelse(condition[original_index] == "CM", 2, -2) +
      original_index / 30,
    PC3 = cos(original_index / 4)
  )
  md <- metadata(std)
  md$stage1 <- DecompositionResult(
    V_star = c(1, 0, 0, 0, 0),
    sigma = 1,
    coords = list(coords[, 1L]),
    V_k = diag(5)[, 1:3, drop = FALSE],
    sigma_k = matrix(c(3, 2, 1), nrow = 1L),
    coords_k = list(coords),
    k = 3L
  )
  metadata(std) <- md
  std
}

output_dir <- ".github/landing-proof/issue-54"
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
std <- component_gallery_fixture()

ggplot2::ggsave(
  file.path(output_dir, "after-categorical.png"),
  plot_components(std, colour_by = "condition", n_components = 3L),
  width = 10,
  height = 5.8,
  dpi = 150
)
ggplot2::ggsave(
  file.path(output_dir, "after-continuous.png"),
  plot_components(std, colour_by = "sample_weeks", n_components = 3L),
  width = 10,
  height = 5.8,
  dpi = 150
)
cat("Rendered issue #54 categorical and continuous landing proof.\n")
