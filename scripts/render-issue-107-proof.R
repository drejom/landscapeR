#!/usr/bin/env Rscript

devtools::load_all(quiet = TRUE)

output_dir <- file.path(".github", "landing-proof", "issue-107")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

std <- synthetic_control(
    n = 40L, p = 500L, K = 2L, signal = 30, seed = 107L
)
md <- metadata(std)
md$dataset_id <- "Synthetic developmental state series"
metadata(std) <- md

std <- suppressWarnings(
    decompose(get_strategy("Decomposer", "hogsvd_averaged")(), std)
)@value
plots <- list(spectrum = plot_spectrum(std))
plots$components <- plot_components(
    std, colour_by = "planted_group", n_components = 4L
)
plots$decomposition <- plot_decomposition(
    std, colour_by = "planted_group", component = 1L
)
std <- estimate_dynamics(
    get_strategy("DynamicsEstimator", "kde_logdensity")(), std
)@value
plots$potential <- plot_potential(std, colour_by = "planted_group")
plots$potential_diagnostic <- plot_potential(
    std, colour_by = "planted_group", show_critical_points = TRUE
)

inspection <- do.call(rbind, lapply(names(plots), function(name) {
    plot <- plots[[name]]
    save_landscapeR_plot(
        plot,
        file.path(output_dir, paste0(name, ".png")),
        width_mm = 100,
        height_mm = 100
    )
    caption <- scientific_caption(plot)
    writeLines(
        caption,
        file.path(output_dir, paste0(name, "-caption.txt"))
    )
    data.frame(
        artifact = name,
        layers = length(plot$layers),
        caption_characters = nchar(caption),
        caption_separate = is.null(plot$labels$caption),
        stringsAsFactors = FALSE
    )
}))

write.table(
    inspection,
    file.path(output_dir, "caption-inspection.tsv"),
    sep = "\t",
    quote = FALSE,
    row.names = FALSE
)
