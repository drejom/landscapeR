#!/usr/bin/env Rscript

devtools::load_all(quiet = TRUE)
sys.source(
    file.path("tests", "testthat", "helper-repeated-time-course.R"),
    envir = environment()
)

output_dir <- file.path(".github", "landing-proof", "issue-212")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

estimable <- associate_metadata(
    repeated_time_course_fixture(
        dropout = c("c1", "t1"),
        irregular = TRUE
    ),
    specification = repeated_time_course_specification("batch"),
    non_analytical_fields = "mouse_id",
    dataset_id = "Issue 212 repeated-subject example",
    n_resamples = 9L,
    seed = 212L,
    sequential_internal = TRUE
)
singular <- associate_metadata(
    repeated_time_course_fixture(slope_scale = 0),
    specification = repeated_time_course_specification(),
    non_analytical_fields = c("mouse_id", "batch"),
    dataset_id = "Issue 212 singular-model example",
    n_resamples = 0L,
    seed = 212L,
    sequential_internal = TRUE
)

plots <- list(
    estimable = plot(estimable),
    singular_abstention = plot(propose_component(singular))
)
inspection <- do.call(rbind, lapply(names(plots), function(name) {
    plot <- plots[[name]]
    save_landscapeR_plot(
        plot,
        file.path(output_dir, paste0(name, ".png")),
        width_mm = 100,
        height_mm = 100
    )
    writeLines(
        scientific_caption(plot),
        file.path(output_dir, paste0(name, "-caption.txt"))
    )
    data.frame(
        surface = name,
        width_mm = 100,
        height_mm = 100,
        caption_outside_plot = is.null(plot$labels$caption),
        stringsAsFactors = FALSE
    )
}))
utils::write.table(
    inspection,
    file.path(output_dir, "inspection.tsv"),
    sep = "\t",
    quote = FALSE,
    row.names = FALSE
)

associations <- atlas_associations(estimable)
primary <- associations[
    associations$evidence_variant == "repeated-time-course-adjusted",
    ,
    drop = FALSE
]
evidence <- data.frame(
    case = c("estimable", "singular"),
    outcome = c(
        sprintf(
            "%d adjusted effects; %d of %d refits completed",
            nrow(primary),
            sum(primary$n_resamples - primary$resample_failures),
            sum(primary$n_resamples)
        ),
        propose_component(singular)@reason
    ),
    sampling_unit = c("complete-subject trajectory", "complete-subject trajectory"),
    execution_path = c("shared association kernel", "shared association kernel"),
    stringsAsFactors = FALSE
)
utils::write.table(
    evidence,
    file.path(output_dir, "evidence.tsv"),
    sep = "\t",
    quote = FALSE,
    row.names = FALSE
)
