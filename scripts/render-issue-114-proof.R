#!/usr/bin/env Rscript

devtools::load_all(quiet = TRUE)

output_dir <- file.path(".github", "landing-proof", "issue-114")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

std <- synthetic_control(
    n = 40L, p = 500L, K = 2L, signal = 30, seed = 114L
)
md <- metadata(std)
md$dataset_id <- "Synthetic developmental state series"
metadata(std) <- md
std <- suppressWarnings(
    decompose(get_strategy("Decomposer", "hogsvd_averaged")(), std)
)@value

plots <- list(
    spectrum = plot_spectrum(std),
    components = plot_components(
        std,
        colour_by = "planted_group",
        n_components = 4L
    ),
    decomposition = plot_decomposition(
        std,
        colour_by = "planted_group",
        component = 1L
    )
)

std <- estimate_dynamics(
    get_strategy("DynamicsEstimator", "kde_logdensity")(),
    std
)@value
plots$potential <- plot_potential(
    std,
    colour_by = "planted_group",
    show_critical_points = TRUE
)

inspection <- do.call(rbind, lapply(names(plots), function(name) {
    plot <- plots[[name]]
    path <- file.path(output_dir, paste0(name, ".png"))
    save_landscapeR_plot(
        plot,
        path,
        width_mm = 100,
        height_mm = 100
    )
    writeLines(
        scientific_caption(plot),
        file.path(output_dir, paste0(name, "-caption.txt"))
    )
    data.frame(
        plot = name,
        width_mm = 100,
        height_mm = 100,
        caption_outside_plot = is.null(plot$labels$caption),
        stringsAsFactors = FALSE
    )
}))

utils::write.table(
    inspection,
    file.path(output_dir, "inspection.tsv"),
    sep = "\t",
    quote = FALSE,
    row.names = FALSE
)

evidence <- data.frame(
    stage = c("stage1", "stage2"),
    class = c(
        class(metadata(std)$stage1_plot_evidence)[[1L]],
        class(metadata(std)$stage2_plot_evidence)[[1L]]
    ),
    digest = c(
        metadata(std)$stage1_plot_evidence@evidence_digest,
        metadata(std)$stage2_plot_evidence@evidence_digest
    ),
    stringsAsFactors = FALSE
)
utils::write.table(
    evidence,
    file.path(output_dir, "evidence.tsv"),
    sep = "\t",
    quote = FALSE,
    row.names = FALSE
)
