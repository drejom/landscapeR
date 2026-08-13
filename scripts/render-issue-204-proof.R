args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1L || !args[[1L]] %in% c("before", "after")) {
    stop("usage: Rscript scripts/render-issue-204-proof.R before|after")
}
state <- args[[1L]]

devtools::load_all(quiet = TRUE)

protocol <- k1_acceptance_protocol("3")
manifest <- k1_revised_acceptance_manifest(
    "4d2ee67653c7de2f7caf2e52da4a8f7fa05ab111",
    strrep("a", 40L),
    protocol
)

# Fabricated implementation fixture only. This renders the public plotting
# contract without running or interpreting an acceptance task.
recovered <- with(manifest$tasks, ifelse(
    control == "high_dimensional_null", FALSE,
    ifelse(
        control == "high_dimensional_signal", signal_ratio >= 1,
        ifelse(
            control == "repeated_subject",
            !design_id %in% c(
                "terminal_dropout", "condition_dependent_loss"
            ),
            design_id != "missing_internal_cell"
        )
    )
))
identity <- list(
    source_revision = strrep("a", 40L),
    r_version = paste(R.version$major, R.version$minor, sep = "."),
    package_versions = c(landscapeR = "proof-fixture")
)
results <- lapply(seq_len(nrow(manifest$tasks)), function(index) {
    recovered_here <- recovered[[index]]
    structure(list(
        version = "k1-revised-acceptance-replicate-v1",
        task_id = manifest$tasks$task_id[[index]],
        control = manifest$tasks$control[[index]],
        status = "success",
        outcome = if (recovered_here) {
            "recovered_and_estimable"
        } else "recovery_below_threshold",
        recovery = list(
            evaluable = TRUE, met = recovered_here,
            absolute_loading_cosine = if (recovered_here) 0.95 else 0.20
        ),
        downstream = list(
            estimable = if (recovered_here) TRUE else NA,
            diagnostic = "fabricated visual-proof fixture"
        ),
        scientific_evidence = list(
            fixture = TRUE, claim_status = "implementation_proof_only"
        ),
        runtime_identity = identity
    ), class = c(
        "K1RevisedAcceptanceImplementationFixture",
        "K1RevisedAcceptanceReplicate", "list"
    ))
})
summary <- summarize_k1_revised_acceptance(
    results, manifest$tasks, protocol
)
plots <- list(
    sampling = plot_k1_revised_acceptance(summary, "sampling_design"),
    signal = plot_k1_revised_acceptance(summary, "signal_regime")
)
dimensions <- list(sampling = c(250, 140), signal = c(180, 150))
proof_root <- ".github/landing-proof/issue-204"
dir.create(proof_root, recursive = TRUE, showWarnings = FALSE)
for (name in names(plots)) {
    ggplot2::ggsave(
        file.path(proof_root, paste(state, name, "operating-map.png", sep = "-")),
        plots[[name]], width = dimensions[[name]][[1L]],
        height = dimensions[[name]][[2L]], units = "mm", dpi = 220,
        bg = landscapeR_palette("semantic")[["paper"]]
    )
}
