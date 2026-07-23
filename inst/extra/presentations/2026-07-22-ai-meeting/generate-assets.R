# Reproducible scientific assets for the 22 July 2026 landscapeR talk.
# Run from the package root with:
# Rscript inst/extra/presentations/2026-07-22-ai-meeting/generate-assets.R

devtools::load_all(quiet = TRUE)

deck_dir <- file.path(
    "inst", "extra", "presentations", "2026-07-22-ai-meeting"
)
asset_dir <- file.path(deck_dir, "assets")
dir.create(asset_dir, recursive = TRUE, showWarnings = FALSE)

branch_colours <- c(
    "shared early state" = "#8A96A3",
    "branch A" = "#45C7D8",
    "branch B" = "#E8A74A"
)
landscape_colours <- c("#1B1530", "#4B285F", "#98445F", "#E8784A", "#F4D88A")
stage_colours <- c(
    "stage 1" = "#D9E1E8",
    "stage 2" = "#AFC6D4",
    "stage 3" = "#7AABB9",
    "stage 4" = "#4C899F",
    "stage 5" = "#225F78"
)
deck_theme <- function(base_size = 15) {
    ggplot2::theme_minimal(base_size = base_size, base_family = "Helvetica") +
        ggplot2::theme(
            plot.background = ggplot2::element_rect(fill = "#07101D", colour = NA),
            panel.background = ggplot2::element_rect(fill = "#07101D", colour = NA),
            panel.grid.major = ggplot2::element_line(colour = "#253344", linewidth = 0.35),
            panel.grid.minor = ggplot2::element_blank(),
            text = ggplot2::element_text(colour = "#EAF1F5"),
            axis.text = ggplot2::element_text(colour = "#AEBAC5"),
            axis.title = ggplot2::element_text(colour = "#D7E2E8"),
            legend.background = ggplot2::element_rect(fill = "#07101D", colour = NA),
            legend.key = ggplot2::element_rect(fill = "#07101D", colour = NA),
            legend.text = ggplot2::element_text(colour = "#D7E2E8"),
            legend.title = ggplot2::element_blank(),
            plot.margin = ggplot2::margin(12, 16, 10, 12)
        )
}
save_asset <- function(plot, filename, width, height) {
    ggplot2::ggsave(
        file.path(asset_dir, filename), plot,
        width = width, height = height, units = "in", dpi = 180,
        bg = "#07101D"
    )
}

# Generate independent destructive samples, embed them in expression space,
# and recover the first two axes using landscapeR's registered SVD.
control <- synthetic_branching_control(
    n_per_stage = 6L,
    p = 240L,
    noise_sd = 0.055,
    seed = 220726L
)
svd_constructor <- get_strategy("Decomposer", "svd")
decomposed <- suppressWarnings(decompose(
    svd_constructor(list(k_components = 4L)), control
))@value

scores <- dr_coords_k(metadata(decomposed)$stage1)[[1L]][, 1:2, drop = FALSE]
truth <- as.data.frame(colData(control))
truth_matrix <- as.matrix(truth[, c("trunk_coord", "branch_coord")])
association <- stats::cor(scores, truth_matrix)

# For two axes the optimal one-to-one assignment is explicit and deterministic.
direct <- abs(association[1, 1]) + abs(association[2, 2])
crossed <- abs(association[1, 2]) + abs(association[2, 1])
assignment <- if (direct >= crossed) c(1L, 2L) else c(2L, 1L)
recovered <- cbind(
    developmental = scores[, assignment[1L]],
    divergence = scores[, assignment[2L]]
)
for (j in seq_len(2L)) {
    orientation <- sign(stats::cor(recovered[, j], truth_matrix[, j]))
    recovered[, j] <- recovered[, j] * orientation
}
plot_data <- cbind(truth, as.data.frame(recovered))

unlabelled_state_space <- ggplot2::ggplot(
    plot_data,
    ggplot2::aes(x = developmental, y = divergence)
) +
    ggplot2::geom_point(
        shape = 21,
        size = 3.1,
        stroke = 0.8,
        fill = "#7E8B98",
        colour = "#CBD5DC",
        alpha = 0.82
    ) +
    ggplot2::labs(
        x = "Recovered coordinate 1",
        y = "Recovered coordinate 2"
    ) +
    deck_theme()
save_asset(unlabelled_state_space, "branching-state-space-unlabelled.png", 7.4, 4.8)

state_space <- ggplot2::ggplot(
    plot_data,
    ggplot2::aes(x = developmental, y = divergence)
) +
    ggplot2::geom_path(
        data = aggregate(
            cbind(developmental, divergence) ~ observed_stage + terminal_branch,
            data = plot_data,
            FUN = mean
        ),
        ggplot2::aes(group = terminal_branch, colour = terminal_branch),
        linewidth = 1.05,
        alpha = 0.65,
        show.legend = FALSE
    ) +
    ggplot2::geom_point(
        ggplot2::aes(fill = stage, colour = terminal_branch),
        shape = 21,
        size = 3.2,
        stroke = 0.9,
        alpha = 0.92
    ) +
    ggplot2::scale_colour_manual(values = branch_colours) +
    ggplot2::scale_fill_manual(values = stage_colours) +
    ggplot2::labs(
        x = "Recovered developmental coordinate",
        y = "Recovered divergence coordinate",
        fill = NULL
    ) +
    deck_theme() +
    ggplot2::theme(legend.position = "none")
save_asset(state_space, "branching-state-space.png", 7.4, 4.8)

landscape <- ggplot2::ggplot(
    plot_data,
    ggplot2::aes(x = developmental, y = divergence)
) +
    ggplot2::stat_density_2d(
        ggplot2::aes(fill = ggplot2::after_stat(level)),
        geom = "polygon",
        bins = 14,
        contour_var = "density",
        alpha = 0.96,
        colour = "#07101D",
        linewidth = 0.22
    ) +
    ggplot2::geom_point(
        size = 1.45,
        alpha = 0.58,
        colour = "#D9E1E8"
    ) +
    ggplot2::scale_fill_gradientn(
        colours = landscape_colours,
        guide = "none"
    ) +
    ggplot2::labs(
        x = "Recovered developmental coordinate",
        y = "Recovered divergence coordinate"
    ) +
    deck_theme()
save_asset(landscape, "branching-density.png", 7.4, 4.8)

loadings <- dr_V_k(metadata(decomposed)$stage1)[, assignment[2L]]
loading_orientation <- sign(stats::cor(recovered[, 2L], truth_matrix[, 2L]))
loadings <- loadings * loading_orientation
loading_data <- data.frame(
    gene = rownames(assay(experiments(control)[[1L]])),
    loading = loadings
)
loading_data <- loading_data[order(abs(loading_data$loading), decreasing = TRUE), ]
loading_data <- loading_data[seq_len(18L), ]
loading_data$gene <- factor(loading_data$gene, levels = rev(loading_data$gene))
loading_data$direction <- ifelse(loading_data$loading >= 0, "branch B", "branch A")

loading_plot <- ggplot2::ggplot(
    loading_data,
    ggplot2::aes(x = gene, y = loading, fill = direction)
) +
    ggplot2::geom_col(width = 0.72, alpha = 0.95) +
    ggplot2::coord_flip() +
    ggplot2::scale_fill_manual(values = branch_colours[c("branch A", "branch B")]) +
    ggplot2::labs(x = NULL, y = "Loading on recovered divergence coordinate") +
    deck_theme(13) +
    ggplot2::theme(
        legend.position = "bottom",
        panel.grid.major.y = ggplot2::element_blank()
    )
save_asset(loading_plot, "branching-loadings.png", 6.3, 4.8)

# Preserve the existing tested one-dimensional calibration output as a distinct
# implemented capability, regenerated through the same public package path.
double_well <- synthetic_k1_double_well_control(
    n = 240L, p = 120L, noise_sd = 0.03, seed = 50L
)
double_well_s1 <- suppressWarnings(decompose(svd_constructor(), double_well))@value
dynamics_constructor <- get_strategy("DynamicsEstimator", "kde_logdensity")
double_well_s2 <- estimate_dynamics(dynamics_constructor(), double_well_s1)@value
potential_plot <- plot_potential(
    double_well_s2,
    show_critical_points = FALSE
) +
    ggplot2::labs(x = "Recovered state coordinate", y = "U(x) = -log p(x)") +
    deck_theme(13) +
    ggplot2::theme(legend.position = "bottom")
save_asset(potential_plot, "landscaper-k1-double-well.png", 7.2, 4.6)
