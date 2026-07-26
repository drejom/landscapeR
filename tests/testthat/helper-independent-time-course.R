independent_time_course_fixture <- function(
    cell_sizes = matrix(
        4L,
        nrow = 2L,
        ncol = 3L,
        dimnames = list(c("control", "treatment"), c("0", "1", "2"))
    ),
    include_nuisance = TRUE
) {
    rows <- list()
    for (condition in rownames(cell_sizes)) {
        for (time in colnames(cell_sizes)) {
            size <- cell_sizes[[condition, time]]
            if (size < 1L) next
            rows[[length(rows) + 1L]] <- data.frame(
                condition = condition,
                day = as.numeric(time),
                replicate = seq_len(size),
                stringsAsFactors = FALSE
            )
        }
    }
    design <- do.call(rbind, rows)
    n <- nrow(design)
    primary <- sprintf("sample_%03d", seq_len(n))
    assay_ids <- sprintf("rna_%03d", seq_len(n))
    design$condition <- factor(
        design$condition,
        levels = c("control", "treatment")
    )
    within_cell <- ave(
        design$replicate,
        interaction(design$condition, design$day),
        FUN = function(x) seq_along(x) - mean(seq_along(x))
    )
    pc1 <- design$day +
        2.4 * (design$condition == "treatment") * design$day +
        0.08 * within_cell
    pc2 <- 1.3 * design$day + 0.08 * rev(within_cell)
    se <- SummarizedExperiment::SummarizedExperiment(
        assays = list(logcounts = matrix(
            seq_len(5L * n),
            nrow = 5L,
            dimnames = list(sprintf("gene_%02d", 1:5), assay_ids)
        ))
    )
    metadata_frame <- S4Vectors::DataFrame(
        condition = design$condition,
        day = design$day,
        sample_id = primary,
        row.names = primary
    )
    if (include_nuisance) {
        metadata_frame$batch <- factor(
            ifelse(design$replicate %% 2L, "A", "B"),
            levels = c("A", "B")
        )
    }
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
        independent_time_course("day", "days")
    )
    coordinates <- cbind(PC1 = pc1, PC2 = pc2)
    stage1 <- DecompositionResult(
        V_star = c(1, 0, 0, 0, 0),
        sigma = 1,
        coords = list(coordinates[, 1L]),
        V_k = diag(5)[, 1:2, drop = FALSE],
        sigma_k = matrix(c(2, 1), nrow = 1L),
        coords_k = list(coordinates),
        k = 2L
    )
    md <- metadata(std)
    md$stage1 <- stage1
    md$dataset_id <- "independent-time-control"
    metadata(std) <- md
    std
}

independent_time_course_specification <- function(
    nuisance_fields = character()
) {
    analysis_specification(
        id = "independent-time-course",
        target_field = "condition",
        target_type = "binary",
        reference_level = "control",
        comparison_level = "treatment",
        nuisance_fields = nuisance_fields,
        claim_intent = "exploratory"
    )
}
