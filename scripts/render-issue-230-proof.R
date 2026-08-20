#!/usr/bin/env Rscript

# Reproducible native, reduced-size, and colour-vision-deficiency proof for #230.
suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))
if (!requireNamespace("png", quietly = TRUE) ||
    !requireNamespace("colorspace", quietly = TRUE)) {
    stop("Issue #230 proof requires the png and colorspace packages", call. = FALSE)
}

output_dir <- file.path(".github", "landing-proof", "issue-230")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

simulate_deutan_png <- function(input, output) {
    image <- png::readPNG(input)
    rgb <- image[, , seq_len(min(3L, dim(image)[3L])), drop = FALSE]
    hex <- grDevices::rgb(
        as.vector(rgb[, , 1L]), as.vector(rgb[, , 2L]),
        as.vector(rgb[, , 3L])
    )
    unique_hex <- unique(hex)
    unique_rgb <- grDevices::col2rgb(unique_hex) / 255
    transformed <- colorspace::deutan(
        colorspace::sRGB(
            unique_rgb[1L, ], unique_rgb[2L, ], unique_rgb[3L, ]
        ),
        severity = 1
    )
    transformed_hex <- colorspace::hex(transformed)
    mapped <- transformed_hex[match(hex, unique_hex)]
    transformed_rgb <- grDevices::col2rgb(mapped) / 255
    simulated <- array(NA_real_, dim = dim(rgb))
    simulated[, , 1L] <- matrix(
        transformed_rgb[1L, ], nrow = nrow(rgb), ncol = ncol(rgb)
    )
    simulated[, , 2L] <- matrix(
        transformed_rgb[2L, ], nrow = nrow(rgb), ncol = ncol(rgb)
    )
    simulated[, , 3L] <- matrix(
        transformed_rgb[3L, ], nrow = nrow(rgb), ncol = ncol(rgb)
    )
    if (dim(image)[3L] == 4L) {
        with_alpha <- array(NA_real_, dim = dim(image))
        with_alpha[, , seq_len(3L)] <- simulated
        with_alpha[, , 4L] <- image[, , 4L]
        simulated <- with_alpha
    }
    png::writePNG(simulated, output)
    invisible(output)
}

state_data <- synthetic_control(
    n = 40L, p = 500L, K = 2L, signal = 30, seed = 23001L
)
state_cd <- colData(state_data)
state_cd$observed_time <- seq_len(nrow(state_cd))
colData(state_data) <- state_cd
stage1 <- suppressWarnings(
    decompose(get_strategy("Decomposer", "hogsvd_averaged")(), state_data)
)@value
stage2 <- estimate_dynamics(
    get_strategy("DynamicsEstimator", "kde_logdensity")(), stage1
)@value
stage1 <- prepare_plot_evidence(stage1, stage = "stage1")
stage2 <- prepare_plot_evidence(stage2, stage = "stage2")

critical_data <- synthetic_k1_double_well_control(
    n = 200L, p = 500L, beta = 4, seed = 23002L
)
critical_cd <- colData(critical_data)
critical_cd$planted_group <- critical_cd$well
colData(critical_data) <- critical_cd
stage2_critical <- suppressWarnings(
    decompose(get_strategy("Decomposer", "svd")(), critical_data)
)@value
stage2_critical <- estimate_dynamics(
    get_strategy("DynamicsEstimator", "kde_logdensity")(), stage2_critical
)@value
stage2_critical <- prepare_plot_evidence(stage2_critical, stage = "stage2")

plots <- list(
    stage1_components_categorical = plot_components(
        stage1, colour_by = "planted_group", n_components = 2L
    ),
    stage1_components_continuous = plot_components(
        stage1, colour_by = "observed_time", n_components = 2L
    ),
    stage1_decomposition = plot_decomposition(
        stage1, colour_by = "planted_group", component = 1L
    ),
    stage1_decomposition_continuous = plot_decomposition(
        stage1, colour_by = "observed_time", component = 1L
    ),
    stage2_potential_categorical = plot_potential(
        stage2, colour_by = "planted_group"
    ),
    stage2_potential_continuous = plot_potential(
        stage2, colour_by = "observed_time"
    ),
    stage2_potential_critical_points = plot_potential(
        stage2_critical, colour_by = "planted_group",
        show_critical_points = TRUE
    )
)

captions <- vapply(plots, scientific_caption, character(1L))
names(captions) <- names(plots)

compact_plot <- function(plot, plot_name) {
    title <- switch(
        plot_name,
        stage1_components_categorical = "Stage 1 component distributions",
        stage1_components_continuous = "Stage 1 component distributions",
        stage1_decomposition = "Component 1 scores by molecular layer",
        stage1_decomposition_continuous = "Component 1 scores by molecular layer",
        stage2_potential_categorical = "Quasi-potential landscape",
        stage2_potential_continuous = "Quasi-potential landscape",
        stage2_potential_critical_points = "Quasi-potential landscape",
        plot$labels$title
    )
    subtitle <- switch(
        plot_name,
        stage2_potential_categorical = "U(x) = -log p(x)",
        stage2_potential_continuous = "U(x) = -log p(x)",
        stage2_potential_critical_points = "U(x) = -log p(x)",
        NULL
    )
    p <- plot + ggplot2::theme(
        plot.title = ggplot2::element_text(size = 6.5, face = "bold"),
        plot.subtitle = ggplot2::element_text(size = 5.5),
        axis.title = ggplot2::element_text(size = 5.5),
        axis.text = ggplot2::element_text(size = 4.5),
        strip.text = ggplot2::element_text(size = 5.5),
        legend.title = ggplot2::element_text(size = 4.5),
        legend.text = ggplot2::element_text(size = 4),
        legend.box = "vertical",
        legend.spacing.x = grid::unit(2, "mm"),
        panel.spacing = grid::unit(5, "mm"),
        plot.margin = ggplot2::margin(2, 2, 2, 2),
        aspect.ratio = 1
    ) +
        ggplot2::labs(title = title, subtitle = subtitle)
    p
}

for (plot_name in names(plots)) {
    native <- file.path(output_dir, paste0(plot_name, ".png"))
    reduced <- file.path(output_dir, paste0(plot_name, "-reduced.png"))
    cvd <- file.path(output_dir, paste0(plot_name, "-deutan.png"))
    save_landscapeR_plot(plots[[plot_name]], native, width_mm = 100, height_mm = 80)
    save_landscapeR_plot(
        compact_plot(plots[[plot_name]], plot_name), reduced,
        width_mm = 90,
        height_mm = 72
    )
    simulate_deutan_png(native, cvd)
    simulate_deutan_png(reduced, paste0(reduced, "-deutan.png"))
    stopifnot(
        file.exists(native), file.exists(reduced), file.exists(cvd),
        file.exists(paste0(reduced, "-deutan.png"))
    )
}

writeLines(
    captions,
    file.path(output_dir, "captions.txt")
)

before_map <- c(
    stage1_components_categorical = "stage1-components-categorical.png",
    stage1_components_continuous = "stage1-components-continuous.png",
    stage1_decomposition = "stage1-decomposition.png",
    stage2_potential_categorical = "stage2-potential.png",
    stage2_potential_critical_points = "stage2-potential-critical-points.png"
)
for (plot_name in names(before_map)) {
    source <- file.path(".github", "landing-proof", "issue-226", before_map[[plot_name]])
    destination <- file.path(output_dir, paste0(plot_name, "-before.png"))
    stopifnot(file.exists(source))
    file.copy(source, destination, overwrite = TRUE)
}

writeLines(
    c(
        "Issue #230 visual proof", "",
        "The before images are the retained issue #226 native surfaces, copied",
        "verbatim. They show colour-only rugs and thin line swatches that are",
        "difficult to read at reduced size and under colour-vision deficiency.", "",
        "The after images are generated from the current plotting functions using",
        "a fixed synthetic fixture. Categorical metadata retains colour and uses",
        "line type, shape, or directly labelled sample rows as a restrained",
        "non-colour channel. Continuous metadata uses colour and point size.",
        "No categorical or continuous metadata stems are drawn. Critical-point",
        "views place small open circles at stored wells and small red diamonds at",
        "stored barriers, directly on the potential curve. Potential-plot rows support at most",
        "four observed groups.",
        "Decomposition points use colour plus shape or size in one layer. Native",
        "100 x 80 mm and reduced 90 x 72 mm renders, plus deuteranopia-simulated",
        "native and reduced outputs, are retained for inspection.",
        "",
        "Captions are generated by scientific_caption() and retained in",
        "captions.txt. Regenerate with: Rscript scripts/render-issue-230-proof.R"
    ),
    file.path(output_dir, "README.md")
)
