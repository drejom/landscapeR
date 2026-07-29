#!/usr/bin/env Rscript

devtools::load_all(quiet = TRUE)
source(file.path(
    "tests",
    "testthat",
    "helper-independent-time-course.R"
))
source(file.path(
    "tests",
    "testthat",
    "helper-repeated-time-course.R"
))

output_dir <- file.path(".github", "landing-proof", "issue-92")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

cross_sectional_fixture <- function() {
    primary <- sprintf("sample_%02d", seq_len(8L))
    assay_ids <- sprintf("rna_%02d", seq_len(8L))
    se <- SummarizedExperiment::SummarizedExperiment(
        assays = list(logcounts = matrix(
            seq_len(32L),
            nrow = 4L,
            dimnames = list(sprintf("gene_%02d", 1:4), assay_ids)
        ))
    )
    std <- StateTransitionData(
        experiments = list(rna = se),
        colData = S4Vectors::DataFrame(
            condition = factor(
                rep(c("control", "treatment"), each = 4L),
                levels = c("control", "treatment")
            ),
            sample_id = primary,
            row.names = primary
        ),
        sampleMap = S4Vectors::DataFrame(
            assay = factor(rep("rna", 8L), levels = "rna"),
            primary = primary,
            colname = assay_ids
        )
    )
    std <- declare_sampling_design(std, cross_sectional())
    coords <- cbind(
        PC1 = c(-1.4, -1.1, -0.8, -0.4, 0.5, 0.8, 1.1, 1.4),
        PC2 = c(-0.6, 0.4, -0.2, 0.5, -0.4, 0.3, -0.5, 0.6)
    )
    md <- metadata(std)
    md$stage1 <- DecompositionResult(
        V_star = c(1, 0, 0, 0),
        sigma = 1,
        coords = list(coords[, 1L]),
        V_k = diag(4)[, 1:2, drop = FALSE],
        sigma_k = matrix(c(2, 1), nrow = 1L),
        coords_k = list(coords),
        k = 2L
    )
    metadata(std) <- md
    std
}

cross_atlas <- associate_metadata(
    cross_sectional_fixture(),
    specification = analysis_specification(
        id = "issue-92-cross-sectional",
        target_field = "condition",
        target_type = "binary",
        reference_level = "control",
        comparison_level = "treatment"
    ),
    non_analytical_fields = "sample_id",
    dataset_id = "issue-92-cross-sectional"
)
independent_atlas <- associate_metadata(
    independent_time_course_fixture(),
    specification = independent_time_course_specification("batch"),
    non_analytical_fields = "sample_id",
    dataset_id = "issue-92-independent",
    seed = 9201L
)
repeated_atlas <- associate_metadata(
    repeated_time_course_fixture(),
    specification = repeated_time_course_specification("batch"),
    non_analytical_fields = "mouse_id",
    dataset_id = "issue-92-repeated",
    seed = 9202L
)

atlases <- list(
    cross_sectional = cross_atlas,
    independent_time_course = independent_atlas,
    repeated_subject = repeated_atlas
)
for (name in names(atlases)) {
    save_landscapeR_plot(
        plot(atlases[[name]]),
        file.path(output_dir, paste0(name, "-atlas.png"))
    )
}

contracts <- lapply(atlases, atlas_evidence_contract)
contract_rows <- do.call(rbind, lapply(names(contracts), function(name) {
    contract <- contracts[[name]]
    data.frame(
        workflow = name,
        version = contract$version,
        sampling_design = contract$sampling_design,
        associations = contract$row_counts[["associations"]],
        observations = contract$row_counts[["observations"]],
        exclusions = contract$row_counts[["exclusions"]],
        cohort_members = nrow(contract$cohort_members),
        stringsAsFactors = FALSE
    )
}))
write.table(
    contract_rows,
    file.path(output_dir, "evidence-contracts.tsv"),
    sep = "\t",
    quote = FALSE,
    row.names = FALSE
)
