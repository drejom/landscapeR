devtools::load_all(quiet = TRUE)

assessment <- run_k1_repeated_subject_calibration(
    template_ids = c(
        "complete", "isolated_observation_loss", "terminal_dropout",
        "condition_dependent_loss"
    ),
    replicates = 5L,
    p = 100L,
    noise_sd = 0.03,
    time_signal = 8,
    condition_time_signal = 3,
    axis_resamples = 5L,
    seed = 19000L,
    sequential_internal = TRUE
)

# Add one provenance-bearing scheduler interruption so the landing proof
# exercises the execution-failure encoding without assigning it a scientific
# value or including it in a scientific denominator.
interrupted <- which(
    assessment$replicates$template_id == "isolated_observation_loss"
)[[1L]]
interrupted_task <- assessment$replicates$task_id[[interrupted]]
assessment$replicates$execution_completed[[interrupted]] <- FALSE
assessment$replicates$target_loading_cosine[[interrupted]] <- NA_real_
assessment$replicates$recovery_evaluable[[interrupted]] <- FALSE
assessment$replicates$recovery_met[[interrupted]] <- NA
assessment$replicates$axis_identifiability_evaluable[[interrupted]] <- FALSE
assessment$replicates$axis_mean_absolute_similarity[[interrupted]] <- NA_real_
assessment$replicates$axis_refits_completed[[interrupted]] <- 0L
assessment$replicates$nominated_component[[interrupted]] <- NA_integer_
assessment$replicates$nomination_agrees_with_target[[interrupted]] <- NA
assessment$replicates$model_estimable[[interrupted]] <- NA
assessment$replicates$model_diagnostic[[interrupted]] <-
    "declared_visual_proof_scheduler_interruption"
assessment$replicates$outcome[[interrupted]] <- "execution_failure"
assessment$execution$values[interrupted] <- list(NULL)
assessment$execution$account$completed[[interrupted]] <- FALSE
assessment$execution$account$failure_codes[[interrupted]] <-
    "declared_visual_proof_scheduler_interruption"
assessment$execution$account$n_completed <-
    as.integer(sum(assessment$execution$account$completed))
assessment$execution$account$n_failed <-
    assessment$execution$account$n_requested -
    assessment$execution$account$n_completed
assessment$execution$provenance$declared_failure_injections <- list(
    purpose = "renderer landing proof",
    task_id = interrupted_task,
    failure_code = "declared_visual_proof_scheduler_interruption"
)
execution_payload <- assessment$execution[c("values", "account", "provenance")]
assessment$execution$digest <- digest::digest(
    execution_payload, algo = "sha256", serialize = TRUE
)
assessment$cells <- landscapeR:::.k1_repeated_cell_summary(
    assessment$replicates
)
assessment_payload <- unclass(assessment)
assessment_payload$digest <- NULL
assessment$digest <- digest::digest(assessment_payload, algo = "sha256")

plot <- plot_k1_repeated_subject_calibration(assessment)
proof_root <- ".github/landing-proof/issue-190"
dir.create(proof_root, recursive = TRUE, showWarnings = FALSE)
ggplot2::ggsave(
    file.path(proof_root, "repeated-subject-operating-map.png"),
    plot,
    width = 100,
    height = 100,
    units = "mm",
    dpi = 300,
    bg = "white"
)
utils::write.csv(
    attr(plot, "landscapeR_k1_repeated_map_data"),
    file.path(proof_root, "repeated-subject-operating-map.csv"),
    row.names = FALSE
)
writeLines(
    scientific_caption(plot),
    file.path(proof_root, "repeated-subject-operating-map-caption.txt")
)
