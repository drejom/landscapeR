repeated_time_course_fixture <- function(
    subjects_per_condition = 8L,
    times = c(0, 1, 2, 3),
    slope_divergence = 1.8,
    slope_scale = 0.18,
    dropout = character(),
    irregular = FALSE
) {
    conditions <- c("control", "treatment")
    subjects <- unlist(lapply(conditions, function(condition) {
        paste0(substr(condition, 1L, 1L), seq_len(subjects_per_condition))
    }))
    subject_condition <- rep(conditions, each = subjects_per_condition)
    rows <- do.call(rbind, lapply(seq_along(subjects), function(i) {
        subject <- subjects[[i]]
        observed <- times
        if (subject %in% dropout) observed <- observed[-length(observed)]
        if (irregular) {
            offset <- 0.08 * ((i %% 3L) - 1L) * seq_along(observed)
            offset[c(1L, length(offset))] <- 0
            observed <- observed + offset
        }
        data.frame(
            mouse_id = subject,
            condition = subject_condition[[i]],
            day = observed,
            stringsAsFactors = FALSE
        )
    }))
    rows$condition <- factor(
        rows$condition,
        levels = conditions
    )
    subject_index <- match(rows$mouse_id, subjects)
    within_condition_index <- rep(
        seq_len(subjects_per_condition),
        times = length(conditions)
    )
    centered_subject <- within_condition_index[subject_index] -
        mean(seq_len(subjects_per_condition))
    random_intercept <- 0.12 * sin(subject_index)
    random_slope <- slope_scale * centered_subject /
        max(1, abs(centered_subject))
    observation_noise <- 0.08 * sin(seq_len(nrow(rows)) * 1.7)
    pc1 <- random_intercept +
        (0.6 + random_slope) * rows$day +
        slope_divergence *
            (rows$condition == "treatment") * rows$day +
        observation_noise
    pc2 <- 0.15 * cos(subject_index) +
        (0.9 - random_slope) * rows$day +
        rev(observation_noise)
    n <- nrow(rows)
    primary <- sprintf("sample_%03d", seq_len(n))
    assay_ids <- sprintf("rna_%03d", seq_len(n))
    se <- SummarizedExperiment::SummarizedExperiment(
        assays = list(logcounts = matrix(
            seq_len(5L * n),
            nrow = 5L,
            dimnames = list(sprintf("gene_%02d", 1:5), assay_ids)
        ))
    )
    metadata_frame <- S4Vectors::DataFrame(
        condition = rows$condition,
        day = rows$day,
        mouse_id = rows$mouse_id,
        batch = factor(ifelse(subject_index %% 2L, "A", "B")),
        row.names = primary
    )
    std <- StateTransitionData(
        experiments = list(rna = se),
        colData = metadata_frame,
        sampleMap = S4Vectors::DataFrame(
            assay = factor(rep("rna", n), levels = "rna"),
            primary = primary,
            colname = assay_ids
        )
    )
    std <- declare_sampling_design(
        std,
        longitudinal("mouse_id", "day", "days")
    )
    stage1 <- DecompositionResult(
        V_star = c(1, 0, 0, 0, 0),
        sigma = 1,
        coords = list(pc1),
        V_k = diag(5)[, 1:2, drop = FALSE],
        sigma_k = matrix(c(2, 1), nrow = 1L),
        coords_k = list(cbind(PC1 = pc1, PC2 = pc2)),
        k = 2L
    )
    md <- metadata(std)
    md$stage1 <- stage1
    md$dataset_id <- "repeated-time-control"
    metadata(std) <- md
    std
}

repeated_time_course_specification <- function(
    nuisance_fields = character()
) {
    analysis_specification(
        id = "repeated-time-course",
        target_field = "condition",
        target_type = "binary",
        reference_level = "control",
        comparison_level = "treatment",
        nuisance_fields = nuisance_fields,
        claim_intent = "exploratory"
    )
}
