devtools::load_all(quiet = TRUE)

protocol <- k1_acceptance_protocol("5")
manifest <- k1_revised_acceptance_manifest(
    "f668e1e0f49f66b8bd8c244ca6fb667a9b39d896",
    strrep("d", 40L),
    protocol
)

# This deliberately fabricated fixture demonstrates only the renderer and
# publication contract. It does not execute or summarize acceptance outcomes.
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
    source_revision = strrep("d", 40L),
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
sampling <- plot_k1_revised_acceptance(summary, "sampling_design")
signal <- plot_k1_revised_acceptance(summary, "signal_regime")

proof_root <- ".github/landing-proof/issue-193-runner"
dir.create(proof_root, recursive = TRUE, showWarnings = FALSE)
writeLines(c(
    paste0("protocol_id=", manifest$protocol_id),
    paste0("protocol_digest=", manifest$protocol_digest),
    paste0("phase_a_merge_commit=", manifest$phase_a_merge_commit),
    paste0("fixture_runner_revision=", manifest$runner_revision),
    paste0("manifest_digest=", manifest$digest),
    paste0("requested_tasks=", nrow(manifest$tasks)),
    paste0("first_seed_root=", min(manifest$tasks$seed_root)),
    paste0(
        "last_scalar_seed=",
        max(unlist(manifest$tasks$stream_seeds, use.names = FALSE))
    ),
    "historical_stream_authentication=TRUE",
    "acceptance_executed=FALSE"
), file.path(proof_root, "manifest-summary.txt"))
plots <- list(sampling = sampling, signal = signal)
dimensions <- list(sampling = c(250, 140), signal = c(180, 150))
for (name in names(plots)) {
    ggplot2::ggsave(
        file.path(proof_root, paste0(name, "-operating-map.png")),
        plots[[name]], width = dimensions[[name]][[1L]],
        height = dimensions[[name]][[2L]], units = "mm", dpi = 300,
        bg = "white"
    )
    utils::write.csv(
        attr(plots[[name]], "landscapeR_k1_revised_map_data"),
        file.path(proof_root, paste0(name, "-operating-map.csv")),
        row.names = FALSE
    )
    writeLines(
        scientific_caption(plots[[name]]),
        file.path(proof_root, paste0(name, "-operating-map-caption.txt"))
    )
}
