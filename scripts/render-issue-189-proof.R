devtools::load_all(quiet = TRUE)

assessment <- run_k1_independent_time_course_calibration(
    template_ids = c(
        "balanced_1", "balanced_2", "balanced_3", "unequal_1_2_3",
        "isolated_library_failure", "missing_internal_cell"
    ),
    replicates = 5L,
    p = 100L,
    noise_sd = 0.15,
    time_signal = 8,
    condition_time_signal = 3,
    seed = 18900L,
    sequential_internal = TRUE
)

# Add one provenance-bearing scheduler interruption so the landing proof
# exercises the public partial-execution state. The task is excluded from the
# scientific denominators and the intervention is retained in provenance.
interrupted <- which(
    assessment$replicates$template_id == "isolated_library_failure"
)[[1L]]
interrupted_task <- assessment$replicates$task_id[[interrupted]]
assessment$replicates$execution_completed[[interrupted]] <- FALSE
assessment$replicates$target_loading_cosine[[interrupted]] <- NA_real_
assessment$replicates$recovery_evaluable[[interrupted]] <- FALSE
assessment$replicates$recovery_met[[interrupted]] <- NA
assessment$replicates$downstream_estimable[[interrupted]] <- NA
assessment$replicates$diagnostic[[interrupted]] <-
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
execution_payload <- assessment$execution[
    c("values", "account", "provenance")
]
assessment$execution$digest <- digest::digest(
    execution_payload,
    algo = "sha256",
    serialize = TRUE
)
assessment$cells <- landscapeR:::.k1_independent_time_cell_summary(
    assessment$replicates
)
assessment_payload <- unclass(assessment)
assessment_payload$digest <- NULL
assessment$digest <- digest::digest(assessment_payload, algo = "sha256")

plot <- plot_k1_independent_time_course_calibration(assessment)
proof_root <- ".github/landing-proof/issue-189"
dir.create(proof_root, recursive = TRUE, showWarnings = FALSE)
ggplot2::ggsave(
    file.path(proof_root, "destructive-time-course-operating-map.png"),
    plot,
    width = 100,
    height = 100,
    units = "mm",
    dpi = 300,
    bg = "white"
)
utils::write.csv(
    attr(plot, "landscapeR_k1_operating_map_data"),
    file.path(proof_root, "destructive-time-course-operating-map.csv"),
    row.names = FALSE
)
writeLines(
    scientific_caption(plot),
    file.path(proof_root, "destructive-time-course-operating-map-caption.txt")
)
