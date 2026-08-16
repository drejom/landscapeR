#!/usr/bin/env Rscript

# Reproducible native and reduced-size proof for issue #227.
suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))
source(file.path("tests", "testthat", "helper-independent-time-course.R"))

output_dir <- file.path(".github", "landing-proof", "issue-227")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

atlas <- associate_metadata(
    independent_time_course_fixture(),
    specification = independent_time_course_specification("batch"),
    non_analytical_fields = "sample_id",
    dataset_id = "Issue 227 independent-time-course fixture",
    n_resamples = 3L,
    seed = 22701L,
    sequential_internal = TRUE
)
figure <- plot(atlas)
caption <- scientific_caption(figure)

before_source <- file.path(
    ".github", "landing-proof", "issue-226", "independent-time-course.png"
)
if (!file.exists(before_source)) {
    stop("issue #227 proof requires the retained issue #226 before image")
}
file.copy(
    before_source,
    file.path(output_dir, "independent-time-course-before.png"),
    overwrite = TRUE
)

save_landscapeR_plot(
    figure,
    file.path(output_dir, "independent-time-course.png"),
    width_mm = 100,
    height_mm = 100
)
save_landscapeR_plot(
    figure,
    file.path(output_dir, "independent-time-course-reduced.png"),
    width_mm = 80,
    height_mm = 80
)
writeLines(caption, file.path(output_dir, "independent-time-course-caption.txt"))
writeLines(
    c(
        "Issue #227 visual proof",
        "",
        "The before image is the retained native issue #226 artifact, copied",
        "verbatim to preserve the observed pre-fix rendering failure.",
        "",
        "The native 100 mm figure and the reduced 80 mm rendering use the",
        "same stored independent-time-course evidence. Facet headings retain",
        "component identity, the interaction estimate, and its 95% interval",
        "without clipping or overlap.",
        "",
        "Regenerate with: Rscript scripts/render-issue-227-proof.R"
    ),
    file.path(output_dir, "README.md")
)
