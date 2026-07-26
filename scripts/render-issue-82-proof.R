#!/usr/bin/env Rscript

devtools::load_all(quiet = TRUE)
source(file.path(
    "tests",
    "testthat",
    "helper-repeated-time-course.R"
))

output_dir <- file.path(".github", "landing-proof", "issue-82")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

save_proof <- function(filename, figure) {
    ggplot2::ggsave(
        file.path(output_dir, filename),
        figure,
        width = 100,
        height = 100,
        units = "mm",
        dpi = 300,
        bg = "white"
    )
}

specification <- repeated_time_course_specification("batch")
atlas <- associate_metadata(
    repeated_time_course_fixture(),
    specification = specification,
    non_analytical_fields = "mouse_id",
    dataset_id = "issue-82-planted-control",
    n_resamples = 49L,
    seed = 8201L
)
proposal <- propose_component(
    atlas,
    n_permutations = 49L,
    seed = 8202L
)

save_proof("trajectory-atlas.png", plot(atlas))
save_proof("trajectory-proposal.png", plot(proposal))
save_proof(
    "subject-level-null.png",
    plot(proposal_permutation_evidence(proposal))
)

dropout_atlas <- associate_metadata(
    repeated_time_course_fixture(
        dropout = c("c1", "t1"),
        irregular = TRUE
    ),
    specification = repeated_time_course_specification(),
    non_analytical_fields = c("mouse_id", "batch"),
    dataset_id = "issue-82-irregular-dropout",
    n_resamples = 19L,
    seed = 8203L
)
save_proof("irregular-dropout.png", plot(dropout_atlas))

singular_atlas <- associate_metadata(
    repeated_time_course_fixture(slope_scale = 0),
    specification = repeated_time_course_specification(),
    non_analytical_fields = c("mouse_id", "batch"),
    dataset_id = "issue-82-singular-control",
    seed = 8204L
)
singular_abstention <- propose_component(singular_atlas)
save_proof("singular-abstention.png", plot(singular_abstention))
