test_that("contact-sheet tile labels are bounded and suppress plot-local prose", {
    labels <- landscapeR:::.contact_sheet_tile_labels()
    expect_length(labels, 17L)
    expect_true(all(nchar(labels, type = "chars") <= 25L))
    expect_length(unique(labels), length(labels))

    plot_object <- ggplot2::ggplot(
        data.frame(x = 1, y = 1), ggplot2::aes(x, y)
    ) + ggplot2::geom_point() +
        ggplot2::labs(subtitle = "long plot-local subtitle", caption = "caption")
    tile <- landscapeR:::.contact_sheet_tile(plot_object, "cross-sectional-atlas")

    expect_equal(tile$labels$title, "Association atlas")
    expect_null(tile$labels$subtitle)
    expect_null(tile$labels$caption)
})
