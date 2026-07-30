#!/usr/bin/env Rscript

devtools::load_all(quiet = TRUE)

output_dir <- file.path(".github", "landing-proof", "issue-93")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

plan_inputs <- list(
    list(
        design = "Cross-sectional observations",
        method = "stratified-biological-unit-bootstrap",
        unit = "independent-biological-observation",
        completed = rep(TRUE, 20L),
        failure = rep("", 20L)
    ),
    list(
        design = "Independent condition-by-time cells",
        method = "condition-time-cell-bootstrap",
        unit = "independent-biological-observation",
        completed = c(rep(TRUE, 14L), rep(FALSE, 6L)),
        failure = c(
            rep("", 14L),
            rep("non-estimable-refit", 6L)
        )
    ),
    list(
        design = "Repeated complete-subject trajectories",
        method = "condition-stratified-subject-trajectory-bootstrap",
        unit = "complete-subject",
        completed = rep(FALSE, 20L),
        failure = rep("non-identifiable-refit", 20L)
    )
)

accounts <- lapply(seq_along(plan_inputs), function(index) {
    input <- plan_inputs[[index]]
    plan <- landscapeR:::.resampling_policy_plan(
        lifecycle = "bootstrap",
        method = input$method,
        unit = input$unit,
        n_requested = 20L,
        seed = 9300L + index,
        design = list(proof_design = input$design),
        draw_factory = function(replicate_index) replicate_index
    )
    landscapeR:::.resampling_policy_account(
        plan,
        completed = input$completed,
        failure_codes = input$failure
    )
})

summary <- do.call(rbind, lapply(seq_along(accounts), function(index) {
    account <- accounts[[index]]
    data.frame(
        design = plan_inputs[[index]]$design,
        method = account$method,
        unit = account$unit,
        status = account$status,
        n_requested = account$n_requested,
        n_completed = account$n_completed,
        n_failed = account$n_failed,
        plan_digest = account$plan_digest,
        account_digest = account$digest,
        stringsAsFactors = FALSE
    )
}))
summary$design <- factor(summary$design, levels = rev(summary$design))
summary$label <- sprintf(
    "%s\n%d/%d completed",
    summary$status,
    summary$n_completed,
    summary$n_requested
)
summary$label_colour <- ifelse(
    summary$n_completed >= 10L,
    "white",
    "#111111"
)

semantic <- landscapeR_palette("semantic")
proof_plot <- ggplot2::ggplot(summary, ggplot2::aes(y = design)) +
    ggplot2::geom_col(
        ggplot2::aes(x = n_requested),
        width = 0.52,
        fill = unname(semantic[["missing"]]),
        colour = unname(semantic[["ink"]]),
        linewidth = 0.3
    ) +
    ggplot2::geom_col(
        ggplot2::aes(x = n_completed),
        width = 0.52,
        fill = unname(semantic[["focal"]]),
        colour = NA
    ) +
    ggplot2::geom_text(
        ggplot2::aes(
            x = n_requested / 2,
            label = label,
            colour = label_colour
        ),
        size = 2.2,
        lineheight = 0.9
    ) +
    ggplot2::scale_colour_identity() +
    ggplot2::scale_x_continuous(
        limits = c(0, 20),
        breaks = c(0, 5, 10, 15, 20),
        expand = ggplot2::expansion(mult = c(0, 0))
    ) +
    ggplot2::labs(
        x = "Resampling replicates",
        y = NULL
    ) +
    theme_landscapeR(square = FALSE) +
    ggplot2::theme(
        panel.grid.major.x = ggplot2::element_line(
            colour = "#E2E2E2",
            linewidth = 0.25
        )
    )

caption <- paste(
    "Design-preserving resampling outcomes under a shared package policy.",
    "Bars show 20 requested bootstrap replicates for representative",
    "cross-sectional, independent time-course, and repeated-subject designs;",
    "red segments show completed refits, black outlines mark the fixed",
    "requested denominator, and labels report status and completion. The",
    "cross-sectional plan completed all 20 refits,",
    "the condition-by-time-cell plan retained six failed refits and therefore",
    "reported partial evidence, and the complete-subject-trajectory plan",
    "retained all 20 failed refits and reported a non-identifiable outcome.",
    "These synthetic outcomes demonstrate deterministic accounting and typed",
    "failure semantics only; no scientific stability threshold is applied."
)

save_landscapeR_plot(
    proof_plot,
    file.path(output_dir, "resampling-policy.png")
)
writeLines(
    paste(strwrap(caption, width = 96L), collapse = "\n"),
    file.path(output_dir, "resampling-policy-caption.txt")
)
write.table(
    summary[, c(
        "design", "method", "unit", "status", "n_requested",
        "n_completed", "n_failed", "plan_digest", "account_digest"
    )],
    file.path(output_dir, "resampling-policy-summary.tsv"),
    sep = "\t",
    quote = FALSE,
    row.names = FALSE
)
saveRDS(
    accounts,
    file.path(output_dir, "resampling-policy-accounts.rds"),
    version = 3L
)
