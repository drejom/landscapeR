#!/usr/bin/env Rscript

devtools::load_all(".", quiet = TRUE)

output_dir <- file.path(".github", "landing-proof", "issue-106")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

states <- data.frame(
    state = factor(
        c("Complete", "Partial", "Abstention"),
        levels = c("Complete", "Partial", "Abstention")
    ),
    completed = c(20L, 14L, 0L),
    requested = 20L
)

plot <- ggplot2::ggplot(states, ggplot2::aes(y = state, x = requested)) +
    ggplot2::geom_col(
        fill = "white", colour = "#111111", linewidth = 0.4, width = 0.55
    ) +
    ggplot2::geom_col(
        ggplot2::aes(x = completed),
        fill = "#C43C39", width = 0.55
    ) +
    ggplot2::geom_text(
        ggplot2::aes(
            x = requested - 0.6,
            label = paste0(completed, "/", requested)
        ),
        hjust = 1, size = 2.5, colour = "#111111"
    ) +
    ggplot2::scale_x_continuous(
        limits = c(0, 20), breaks = c(0, 5, 10, 15, 20),
        expand = c(0, 0)
    ) +
    ggplot2::labs(
        x = "Requested biological resamples",
        y = NULL,
        title = "The caption contract preserves evidence state"
    ) +
    theme_landscapeR(square = TRUE)

view <- .new_scientific_caption_view(
    title = "Scientific-caption contract across resampling outcomes",
    experiment_label = "Pogona sex-development series",
    molecular_layer = "RNA abundance",
    target_field = "genotype",
    oriented_levels = c("ZZ", "ZW"),
    sampling_unit = "independent embryo",
    panels = c(
        A = paste(
            "Bars retain the requested denominator for complete, partial,",
            "and abstention outcomes"
        )
    ),
    encodings = c(
        "Red shows completed resamples and black outlines show requests"
    ),
    design = "stage-stratified biological-unit bootstrap",
    uncertainty = "Failed resamples are retained rather than regenerated",
    missingness = "Six of twenty requested resamples did not complete",
    threshold = "No acceptance threshold is applied",
    claim_boundary = paste(
        "The visualization is descriptive and does not establish",
        "biological validity"
    ),
    state = "partial"
)
caption <- .build_scientific_caption(view)
plot <- .with_scientific_caption(plot, caption)

ggplot2::ggsave(
    file.path(output_dir, "caption-contract.png"),
    plot, width = 100, height = 100, units = "mm", dpi = 300
)
writeLines(
    scientific_caption(plot),
    file.path(output_dir, "caption-contract-caption.txt")
)
utils::write.table(
    states,
    file.path(output_dir, "caption-contract-states.tsv"),
    sep = "\t", row.names = FALSE, quote = FALSE
)
