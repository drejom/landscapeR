#!/usr/bin/env Rscript

devtools::load_all(quiet = TRUE)
source(file.path(
    "tests", "testthat", "helper-independent-time-course.R"
))
source(file.path(
    "tests", "testthat", "helper-repeated-time-course.R"
))

output_dir <- file.path(".github", "landing-proof", "issue-94")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

cross_sectional_fixture <- function() {
    primary <- sprintf("embryo_%02d", seq_len(10L))
    assay_ids <- sprintf("rna_%02d", seq_len(10L))
    se <- SummarizedExperiment::SummarizedExperiment(
        assays = list(logcounts = matrix(
            seq_len(50L),
            nrow = 5L,
            dimnames = list(sprintf("gene_%02d", 1:5), assay_ids)
        ))
    )
    std <- StateTransitionData(
        experiments = list(rna = se),
        colData = S4Vectors::DataFrame(
            condition = factor(
                rep(c("ZZ", "ZW"), each = 5L),
                levels = c("ZZ", "ZW")
            ),
            sample_id = primary,
            row.names = primary
        ),
        sampleMap = S4Vectors::DataFrame(
            assay = factor(rep("rna", 10L), levels = "rna"),
            primary = primary,
            colname = assay_ids
        )
    )
    std <- declare_sampling_design(std, cross_sectional())
    coords <- cbind(
        PC1 = c(-1.5, -1.2, -0.9, -0.5, -0.2, 0.3, 0.6, 1, 1.3, 1.6),
        PC2 = c(-0.8, 0.4, -0.3, 0.6, 0.1, -0.5, 0.5, -0.2, 0.7, -0.4)
    )
    md <- metadata(std)
    md$dataset_id <- "Pogona genotype series"
    md$stage1 <- DecompositionResult(
        V_star = c(1, 0, 0, 0, 0),
        sigma = 1,
        coords = list(coords[, 1L]),
        V_k = diag(5)[, 1:2, drop = FALSE],
        sigma_k = matrix(c(2, 1), nrow = 1L),
        coords_k = list(coords),
        k = 2L
    )
    metadata(std) <- md
    std
}

specification <- analysis_specification(
    id = "issue-94-pogona-genotype",
    target_field = "condition",
    target_type = "binary",
    reference_level = "ZZ",
    comparison_level = "ZW"
)
cross_atlas <- associate_metadata(
    cross_sectional_fixture(),
    specification = specification,
    non_analytical_fields = "sample_id",
    dataset_id = "Pogona genotype series"
)
proposal <- propose_component(
    cross_atlas,
    n_permutations = 49L,
    seed = 9401L
)
association_abstention <- associate_metadata(
    cross_sectional_fixture(),
    specification = analysis_specification(
        id = "issue-94-invalid-target",
        target_field = "condition",
        target_type = "continuous",
        continuous_direction = "increasing"
    ),
    non_analytical_fields = "sample_id",
    dataset_id = "Pogona genotype series"
)
independent_atlas <- associate_metadata(
    independent_time_course_fixture(),
    specification = independent_time_course_specification("batch"),
    non_analytical_fields = "sample_id",
    dataset_id = "Independent developmental series",
    n_resamples = 19L,
    seed = 9402L
)
repeated_atlas <- associate_metadata(
    repeated_time_course_fixture(),
    specification = repeated_time_course_specification("batch"),
    non_analytical_fields = c("mouse_id", "batch"),
    dataset_id = "Repeated developmental series",
    n_resamples = 19L,
    seed = 9403L
)
component_abstention <- propose_component(
    associate_metadata(
        cross_sectional_fixture(),
        non_analytical_fields = "sample_id",
        dataset_id = "Pogona genotype series"
    ),
    target = "condition",
    n_permutations = 19L,
    seed = 9404L
)

objects <- list(
    cross_sectional_atlas = cross_atlas,
    component_proposal = proposal,
    permutation_uncertainty = proposal_permutation_evidence(proposal),
    association_abstention = association_abstention,
    component_abstention = component_abstention,
    independent_time_course = independent_atlas,
    repeated_time_course = repeated_atlas
)

plots <- lapply(objects, plot)
for (name in names(plots)) {
    save_landscapeR_plot(
        plots[[name]],
        file.path(output_dir, paste0(name, ".png")),
        width_mm = 100,
        height_mm = 100
    )
    writeLines(
        scientific_caption(plots[[name]]),
        file.path(output_dir, paste0(name, "-caption.txt"))
    )
}

views <- lapply(objects, visual_evidence)
inspection <- do.call(rbind, lapply(names(views), function(name) {
    view <- views[[name]]
    data.frame(
        artifact = name,
        class = class(view)[[1L]],
        surface = visual_evidence_surface(view),
        state = visual_evidence_state(view),
        observations = nrow(visual_evidence_observations(view)),
        summaries = nrow(visual_evidence_summaries(view)),
        diagnostics = nrow(visual_evidence_diagnostics(view)),
        display_items = paste(
            visual_evidence_display_names(view),
            collapse = ";"
        ),
        caption_characters = nchar(visual_evidence_caption(view)),
        stringsAsFactors = FALSE
    )
}))
write.table(
    inspection,
    file.path(output_dir, "visual-evidence-inspection.tsv"),
    sep = "\t",
    quote = FALSE,
    row.names = FALSE
)
