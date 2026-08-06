devtools::load_all(quiet = TRUE)

output <- ".github/landing-proof/issue-118"
base <- synthetic_control(
    n = 24L, p = 80L, K = 2L, signal = 20, seed = 118L
)
decomposed <- suppressWarnings(
    decompose(get_strategy("Decomposer", "hogsvd_averaged")(), base)
)@value

available <- plot_spectrum(decomposed)

partial <- decomposed
partial_coldata <- colData(partial)
partial_coldata$display_group <- factor(c(rep("shared", 23L), "singleton"))
colData(partial) <- partial_coldata
partial <- prepare_plot_evidence(partial, stage = "stage1")
partial_plot <- plot_components(partial, colour_by = "display_group")

degenerate <- decomposed
degenerate_metadata <- metadata(degenerate)
degenerate_metadata$stage1@coords_k[[1L]][, 1L] <- 0
degenerate_metadata$stage1@coords[[1L]][] <- 0
metadata(degenerate) <- degenerate_metadata
degenerate <- prepare_plot_evidence(degenerate, stage = "stage1")
degenerate_plot <- plot_components(degenerate)

stale <- decomposed
stale_metadata <- metadata(stale)
stale_metadata$stage1@coords_k[[1L]][1L, 1L] <-
    stale_metadata$stage1@coords_k[[1L]][1L, 1L] + 1
metadata(stale) <- stale_metadata
stale_plot <- plot_components(stale)

unavailable_plot <- plot_potential(base)

plots <- list(
    available = available,
    partial = partial_plot,
    degenerate = degenerate_plot,
    stale = stale_plot,
    unavailable = unavailable_plot
)
for (name in names(plots)) {
    save_landscapeR_plot(
        plots[[name]],
        file.path(output, paste0(name, ".png")),
        width_mm = 100,
        height_mm = 100
    )
    writeLines(
        scientific_caption(plots[[name]]),
        file.path(output, paste0(name, "-caption.txt"))
    )
}
