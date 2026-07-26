#!/usr/bin/env Rscript

devtools::load_all(quiet = TRUE)
source(file.path(
    "tests",
    "testthat",
    "helper-independent-time-course.R"
))

output_dir <- file.path(".github", "landing-proof", "issue-81")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

specification <- independent_time_course_specification("batch")
atlas <- associate_metadata(
    independent_time_course_fixture(),
    specification = specification,
    non_analytical_fields = "sample_id",
    dataset_id = "issue-81-planted-control",
    n_resamples = 199L,
    seed = 8101L
)
proposal <- propose_component(
    atlas,
    n_permutations = 199L,
    seed = 8102L
)

ggplot2::ggsave(
    file.path(output_dir, "trajectory-atlas.png"),
    plot(atlas),
    width = 100,
    height = 100,
    units = "mm",
    dpi = 300,
    bg = "white"
)

ggplot2::ggsave(
    file.path(output_dir, "trajectory-proposal.png"),
    plot(proposal),
    width = 100,
    height = 100,
    units = "mm",
    dpi = 300,
    bg = "white"
)

ggplot2::ggsave(
    file.path(output_dir, "search-aware-null.png"),
    plot(proposal_permutation_evidence(proposal)),
    width = 100,
    height = 100,
    units = "mm",
    dpi = 300,
    bg = "white"
)

missing_cells <- matrix(
    c(4L, 0L, 4L, 4L, 4L, 0L),
    nrow = 2L,
    byrow = TRUE,
    dimnames = list(c("control", "treatment"), c("0", "1", "2"))
)
missing_atlas <- associate_metadata(
    independent_time_course_fixture(cell_sizes = missing_cells),
    specification = specification,
    non_analytical_fields = "sample_id",
    dataset_id = "issue-81-missing-cells",
    n_resamples = 49L,
    seed = 8103L
)
missing_proposal <- propose_component(missing_atlas)

ggplot2::ggsave(
    file.path(output_dir, "missing-cell-design.png"),
    plot(missing_atlas),
    width = 100,
    height = 100,
    units = "mm",
    dpi = 300,
    bg = "white"
)

ggplot2::ggsave(
    file.path(output_dir, "design-abstention.png"),
    plot(missing_proposal),
    width = 100,
    height = 100,
    units = "mm",
    dpi = 300,
    bg = "white"
)
