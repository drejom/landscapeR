test_that("time-course renderers preserve canonical semantic colour roles", {
    atlas <- associate_metadata(
        independent_time_course_fixture(),
        specification = independent_time_course_specification("batch"),
        non_analytical_fields = "sample_id",
        n_resamples = 3L,
        seed = 128L
    )
    built <- ggplot2::ggplot_build(plot(atlas))$data
    colours <- unique(unlist(lapply(built, `[[`, "colour")))
    fills <- unique(unlist(lapply(built, `[[`, "fill")))
    semantic <- landscapeR_palette("semantic")

    expect_setequal(
        colours[nzchar(colours)],
        unname(semantic[c("nuisance", "focal", "ink")])
    )
    expect_setequal(
        fills[nzchar(fills)],
        unname(semantic[c("paper", "focal")])
    )
    expect_false(any(c("#B2182B", "#C61A2A") %in% c(colours, fills)))
})

test_that("semantic colour lookup rejects undeclared roles", {
    expect_error(
        landscapeR:::.landscapeR_colour("warning"),
        class = "landscapeR_validation_error"
    )
})
