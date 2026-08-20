test_that("theme_landscapeR provides the square publication grammar", {
    theme <- theme_landscapeR()

    expect_s3_class(theme, "theme")
    expect_identical(theme$aspect.ratio, 1)
    expect_s3_class(theme$panel.grid.major, "element_blank")
    expect_s3_class(theme$panel.grid.minor, "element_blank")
    expect_s3_class(theme$axis.line, "element_line")
    expect_s3_class(theme$axis.ticks, "element_line")
    expect_identical(theme$text$family, "Helvetica")
})

test_that("publication visual helpers use typed validation", {
    invalid_calls <- list(
        function() theme_landscapeR(base_size = 0),
        function() landscapeR_palette("categorical", n = 0),
        function() scale_colour_landscapeR("binary"),
        function() save_landscapeR_plot(list(), tempfile(fileext = ".png"))
    )
    for (invalid_call in invalid_calls) {
        expect_error(invalid_call(), class = "landscapeR_validation_error")
    }

    expect_error(
        save_landscapeR_plot(
            ggplot2::ggplot(data.frame(x = 1, y = 1), ggplot2::aes(x, y)) +
                ggplot2::geom_point(),
            tempfile(fileext = ".unsupported")
        ),
        class = "landscapeR_validation_error"
    )
    expect_error(
        scale_colour_landscapeR(
            "categorical",
            definitely_not_an_argument = 1
        ),
        "unused argument",
        class = "landscapeR_validation_error"
    )
})

test_that("landscapeR palettes have stable semantic roles", {
    semantic <- landscapeR_palette("semantic")
    binary <- landscapeR_palette("binary")
    categorical <- landscapeR_palette("categorical")

    expect_identical(
        semantic,
        c(
            ink = "#111111",
            paper = "#FFFFFF",
            structure = "#D9D9D9",
            focal = "#C43C39",
            nuisance = "#8A8A8A",
            missing = "#EFEFEF",
            negative = "#356A88"
        )
    )
    expect_identical(binary, c(reference = "#111111", focal = "#C43C39"))
    expect_length(categorical, 8L)
    expect_length(landscapeR_palette("categorical", n = 9L), 9L)
    expect_error(
        landscapeR_palette("binary", n = 3L),
        "only for the categorical palette"
    )
})

test_that("publication helpers reject every invalid public boundary with typed errors", {
    plot <- ggplot2::ggplot(
        data.frame(x = 1, y = 1),
        ggplot2::aes(x, y)
    ) + ggplot2::geom_point()
    invalid_calls <- list(
        function() theme_landscapeR(base_size = NA_real_),
        function() theme_landscapeR(base_family = NA_character_),
        function() theme_landscapeR(square = NA),
        function() landscapeR_palette("not-a-palette"),
        function() landscapeR_palette("categorical", n = 1.5),
        function() scale_colour_landscapeR(
            "binary", reference_level = "same", focal_level = "same"
        ),
        function() scale_fill_landscapeR(
            "binary", reference_level = "reference", focal_level = NA_character_
        ),
        function() save_landscapeR_plot(plot, NA_character_),
        function() save_landscapeR_plot(plot, tempfile(fileext = ".png"), width = 0),
        function() save_landscapeR_plot(plot, tempfile(fileext = ".png"), height = Inf),
        function() save_landscapeR_plot(plot, tempfile(fileext = ".png"), dpi = 0)
    )

    for (invalid_call in invalid_calls) {
        expect_error(invalid_call(), class = "landscapeR_validation_error")
    }
})

test_that("user-facing plot modules obtain semantic colours from the theme interface", {
    repo_root <- testthat::test_path("..", "..")
    production_files <- list.files(
        file.path(repo_root, "R"),
        pattern = "[.]R$",
        full.names = TRUE
    )
    production_files <- setdiff(
        production_files,
        file.path(repo_root, "R", "13a-plot-theme.R")
    )
    semantic_hex <- sub(
        "^#",
        "",
        unname(landscapeR_palette("semantic"))
    )
    retired_hex <- c("B2182B", "C61A2A", "2C7FB8")
    semantic_literals <- paste0(
        "#(?:",
        paste(c(semantic_hex, retired_hex), collapse = "|"),
        ")|(?:colour|fill) = \"(?:black|white|grey[0-9]*)\""
    )

    for (path in production_files) {
        source <- paste(readLines(path, warn = FALSE), collapse = "\n")
        expect_false(
            grepl(semantic_literals, source, ignore.case = TRUE),
            info = paste(path, "must use landscapeR_palette() or package scales")
        )
    }
})

test_that("landscapeR colour and fill scales match declared data roles", {
    expect_s3_class(
        scale_colour_landscapeR(
            "binary",
            reference_level = "CTL",
            focal_level = "CM"
        ),
        "ScaleDiscrete"
    )
    expect_s3_class(
        scale_fill_landscapeR("categorical"),
        "ScaleDiscrete"
    )
    expect_s3_class(
        scale_colour_landscapeR("continuous"),
        "ScaleContinuous"
    )
    expect_s3_class(
        scale_fill_landscapeR("diverging"),
        "ScaleContinuous"
    )
    continuous_override <- scale_colour_landscapeR(
        "continuous",
        na.value = "pink",
        direction = 1
    )
    expect_identical(continuous_override$na.value, "pink")
    expect_identical(
        continuous_override$palette(c(0, 1)),
        c("#00204D", "#FFEA46")
    )
    binary_override <- scale_colour_landscapeR(
        "binary",
        reference_level = "control",
        focal_level = "treatment",
        values = c(control = "green", treatment = "blue")
    )
    expect_identical(
        binary_override$palette(2L),
        c(control = "green", treatment = "blue")
    )
})

test_that("binary scales name the declared focal level independently of order", {
    data <- data.frame(
        group = factor(c("CM", "CTL"), levels = c("CM", "CTL")),
        x = 1:2,
        y = 1:2
    )
    plot <- ggplot2::ggplot(
        data,
        ggplot2::aes(x, y, colour = group)
    ) +
        ggplot2::geom_point() +
        scale_colour_landscapeR(
            "binary",
            reference_level = "CTL",
            focal_level = "CM"
        )

    colours <- ggplot2::ggplot_build(plot)$data[[1L]]$colour
    expect_identical(colours, c("#C43C39", "#111111"))
    expect_error(
        scale_colour_landscapeR("binary"),
        "reference_level and focal_level"
    )
})

test_that("categorical scales render more than eight levels", {
    data <- data.frame(
        group = factor(sprintf("mouse_%02d", 1:9)),
        x = 1:9,
        y = 1:9
    )
    plot <- ggplot2::ggplot(
        data,
        ggplot2::aes(x, y, colour = group)
    ) +
        ggplot2::geom_point() +
        scale_colour_landscapeR("categorical")

    expect_no_error(ggplot2::ggplot_build(plot))
    expect_length(unique(ggplot2::ggplot_build(plot)$data[[1L]]$colour), 9L)
})

test_that("save_landscapeR_plot defaults to a 100 mm square", {
    path <- tempfile(fileext = ".png")
    on.exit(unlink(path), add = TRUE)

    returned <- save_landscapeR_plot(
        ggplot2::ggplot(data.frame(x = 1:3, y = 1:3),
                        ggplot2::aes(x, y)) +
            ggplot2::geom_point(),
        path
    )

    expect_identical(returned, normalizePath(path))
    expect_true(file.exists(path))

    header <- readBin(path, what = "raw", n = 24L)
    uint32 <- function(bytes) {
        sum(as.integer(bytes) * 256^(3:0))
    }
    width_mm <- uint32(header[17:20]) / 450 * 25.4
    height_mm <- uint32(header[21:24]) / 450 * 25.4
    expect_equal(width_mm, 100, tolerance = 25.4 / 450)
    expect_equal(height_mm, 100, tolerance = 25.4 / 450)
})

test_that("existing scientific plots use the landscapeR theme", {
    std <- synthetic_control(
        n = 20L, p = 60L, K = 1L, signal = 20, seed = 1L
    )
    std <- prepare_plot_evidence(std, stage = "stage1")
    plot <- plot_spectrum(std, n_sv = 5L)

    expect_identical(plot$theme$aspect.ratio, 1)
    expect_s3_class(plot$theme$panel.grid.major, "element_blank")
    expect_s3_class(plot$theme$axis.line, "element_line")
})

test_that("component galleries mark and label missing metadata explicitly", {
    std <- synthetic_control(
        n = 20L, p = 60L, K = 1L, signal = 20, seed = 1L
    )
    cd <- colData(std)
    cd$planted_group[1L] <- NA_character_
    colData(std) <- cd
    std <- suppressWarnings(
        decompose(get_strategy("Decomposer", "svd")(), std)
    )@value

    plot <- plot_components(std, colour_by = "planted_group")

    expect_null(plot$labels$caption)
    expect_match(
        gsub("\\s+", " ", scientific_caption(plot)),
        "Crosses at the baseline mark.*missing"
    )
    expect_true(any(vapply(
        plot$layers,
        function(layer) {
            inherits(layer$geom, "GeomPoint") &&
                identical(layer$aes_params$shape, 4)
        },
        logical(1L)
    )))
})

test_that("potential plots mark and label missing metadata explicitly", {
    std <- synthetic_control(
        n = 20L, p = 60L, K = 1L, signal = 20, seed = 2L
    )
    cd <- colData(std)
    cd$planted_group[1L] <- NA_character_
    colData(std) <- cd
    std <- suppressWarnings(
        decompose(get_strategy("Decomposer", "svd")(), std)
    )@value
    std <- estimate_dynamics(
        get_strategy("DynamicsEstimator", "kde_logdensity")(), std
    )@value

    plot <- plot_potential(std, colour_by = "planted_group")

    expect_null(plot$labels$caption)
    expect_match(
        gsub("\\s+", " ", scientific_caption(plot)),
        "Crosses in the labelled missing row mark.*missing"
    )
    expect_true(any(vapply(
        plot$layers,
        function(layer) {
            inherits(layer$geom, "GeomPoint") &&
                identical(layer$aes_params$shape, 4)
        },
        logical(1L)
    )))
})
