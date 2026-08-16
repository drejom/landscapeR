#!/usr/bin/env Rscript

# Reproducible visual proof for issue #220.
suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))
source(file.path("tests", "testthat", "helper-independent-time-course.R"))

output_dir <- file.path(".github", "landing-proof", "issue-220")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

atlas <- associate_metadata(
    independent_time_course_fixture(),
    specification = independent_time_course_specification("batch"),
    non_analytical_fields = "sample_id",
    dataset_id = "Issue 220 independent-time-course fixture",
    n_resamples = 3L,
    seed = 22001L,
    sequential_internal = TRUE
)
proposal <- propose_component(atlas, n_permutations = 3L, seed = 22002L)

abstention_sizes <- matrix(
    c(1L, 3L, 3L, 3L, 3L, 3L),
    nrow = 2L,
    byrow = TRUE,
    dimnames = list(c("control", "treatment"), c("0", "1", "2"))
)
abstention_atlas <- associate_metadata(
    independent_time_course_fixture(
        cell_sizes = abstention_sizes,
        include_nuisance = FALSE
    ),
    specification = independent_time_course_specification(),
    non_analytical_fields = "sample_id",
    dataset_id = "Issue 220 independent-time-course abstention fixture",
    sequential_internal = TRUE
)
abstention <- propose_component(abstention_atlas)

figures <- list(
    atlas = plot(atlas),
    proposal = plot(proposal),
    abstention = plot(abstention)
)
for (name in names(figures)) {
    figure <- figures[[name]]
    save_landscapeR_plot(
        figure,
        file.path(output_dir, paste0(name, ".png")),
        width_mm = 100,
        height_mm = 100
    )
    save_landscapeR_plot(
        figure,
        file.path(output_dir, paste0(name, "-reduced.png")),
        width_mm = 80,
        height_mm = 80
    )
    writeLines(
        scientific_caption(figure),
        file.path(output_dir, paste0(name, "-caption.txt"))
    )
}

writeLines(
    c(
        "Issue #220 visual proof",
        "",
        "The atlas, proposal, and abstention surfaces use independent",
        "destructive-time-course evidence with two component panels. Each",
        "native 100 mm and reduced 80 mm figure visibly labels panels A and B",
        "in reading order, and its separate caption refers to those same",
        "letters. The abstention surface retains the typed non-estimability",
        "state without inventing trajectory evidence.",
        "",
        "A single-component regression remains in the focused test suite and",
        "confirms that one-panel figures remain unlettered.",
        "",
        "Regenerate with: Rscript scripts/render-issue-220-proof.R"
    ),
    file.path(output_dir, "README.md")
)
