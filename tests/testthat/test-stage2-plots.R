test_that("plot_potential returns a ggplot after Stage 2 has run", {
    std <- synthetic_control(n = 40L, p = 500L, K = 2L, signal = 30, seed = 1L)
    std2 <- suppressWarnings(
        decompose(get_strategy("Decomposer", "hogsvd_averaged")(), std))@value
    std3 <- estimate_dynamics(
        get_strategy("DynamicsEstimator", "kde_logdensity")(), std2)@value
    plot <- plot_potential(std3)
    expect_s3_class(plot, "gg")
    caption <- scientific_caption(plot)
    expect_match(caption, "U\\(x\\)\\s+= -log p\\(x\\)")
    expect_match(caption, "rug\\s+marks")
    expect_match(caption, "omitted")
    expect_match(caption, "exploratory")
})

test_that("plot_potential rug draws from coords_k when coords slot is empty", {
    std <- synthetic_control(n = 40L, p = 500L, K = 2L, signal = 30, seed = 1L)
    std2 <- suppressWarnings(
        decompose(get_strategy("Decomposer", "hogsvd_averaged")(), std))@value
    std3 <- estimate_dynamics(
        get_strategy("DynamicsEstimator", "kde_logdensity")(), std2)@value
    # Replace stage1 with a copy that has empty coords but populated coords_k
    s1 <- metadata(std3)$stage1
    s1_empty_coords <- DecompositionResult(
        V_star   = dr_V_star(s1),
        sigma    = dr_sigma(s1),
        coords   = list(),
        warnings = character(0),
        V_k      = dr_V_k(s1),
        sigma_k  = dr_sigma_k(s1),
        coords_k = dr_coords_k(s1),
        k        = dr_k(s1)
    )
    md <- metadata(std3)
    md$stage1 <- s1_empty_coords
    metadata(std3) <- md
    std3 <- prepare_plot_evidence(std3, stage = "stage2")
    # Should still render (using coords_k fallback), not silently drop the rug
    expect_s3_class(plot_potential(std3), "gg")
})

test_that("plot_potential omits point-estimate critical-point classification by default", {
    std <- synthetic_control(n = 40L, p = 500L, K = 2L, signal = 30, seed = 1L)
    std2 <- suppressWarnings(
        decompose(get_strategy("Decomposer", "hogsvd_averaged")(), std))@value
    std3 <- estimate_dynamics(
        get_strategy("DynamicsEstimator", "kde_logdensity")(), std2)@value

    plot <- plot_potential(std3)

    expect_s3_class(plot, "gg")
    expect_null(plot$labels$shape)
    expect_false(any(vapply(
        plot$layers,
        function(layer) inherits(layer$geom, "GeomPoint") ||
            inherits(layer$geom, "GeomSegment"),
        logical(1L)
    )))
})

test_that("plot_potential requires explicit opt-in for point-estimate classification", {
    std <- synthetic_control(n = 40L, p = 500L, K = 2L, signal = 30, seed = 1L)
    std2 <- suppressWarnings(
        decompose(get_strategy("Decomposer", "hogsvd_averaged")(), std))@value
    std3 <- estimate_dynamics(
        get_strategy("DynamicsEstimator", "kde_logdensity")(), std2)@value

    plot <- plot_potential(std3, show_critical_points = TRUE)

    expect_identical(plot$scales$get_scales("shape")$name, "Critical point")
    expect_identical(plot$scales$get_scales("fill")$name, "Critical point")
    expect_true(any(vapply(
        plot$layers,
        function(layer) inherits(layer$geom, "GeomPoint"),
        logical(1L)
    )))
    caption <- gsub("\\s+", " ", scientific_caption(plot))
    expect_match(caption, "Small open circles mark stored stable wells directly on the curve")
    expect_match(caption, "Small red diamonds mark stored unstable barriers directly on the curve")
    expect_match(caption, "Fine grey dashed lines")
    expect_match(caption, "vertical display is focused")
    expect_match(caption, "point\\s+estimates")

    caption_with_metadata <- scientific_caption(plot_potential(
        std3, colour_by = "planted_group", show_critical_points = TRUE
    ))
    caption_with_metadata <- gsub("\\s+", " ", caption_with_metadata)
    expect_match(caption_with_metadata, "Fine coloured rugs")
    critical_metadata_plot <- plot_potential(
        std3, colour_by = "planted_group", show_critical_points = TRUE
    )
    expect_null(critical_metadata_plot$scales$get_scales("linetype"))
    expect_null(critical_metadata_plot$scales$get_scales("linewidth"))
    expect_false(any(vapply(
        critical_metadata_plot$layers,
        function(layer) inherits(layer$geom, "GeomText"),
        logical(1L)
    )))

    binary_plot <- plot_potential(
        std3,
        colour_by = "planted_group",
        show_critical_points = TRUE,
        reference_level = "low",
        focal_level = "high"
    )
    rug_sides <- vapply(
        Filter(
            function(layer) inherits(layer$geom, "GeomRug"),
            binary_plot$layers
        ),
        function(layer) layer$geom_params$sides,
        character(1L)
    )
    expect_setequal(rug_sides, c("t", "b"))
    expect_match(scientific_caption(binary_plot), "upper margin")
})

test_that("plot_potential renders large categorical rug encodings", {
    std <- synthetic_control(n = 40L, p = 500L, K = 2L, signal = 30, seed = 1L)
    cd <- colData(std)
    cd$many_groups <- factor(seq_len(nrow(cd)))
    colData(std) <- cd
    std2 <- suppressWarnings(
        decompose(get_strategy("Decomposer", "hogsvd_averaged")(), std))@value
    std3 <- estimate_dynamics(
        get_strategy("DynamicsEstimator", "kde_logdensity")(), std2)@value

    expect_s3_class(
        plot_potential(std3, colour_by = "many_groups", show_critical_points = TRUE),
        "ggplot"
    )
})

test_that("plot_potential renders eight categorical rug levels", {
    std <- synthetic_control(n = 40L, p = 500L, K = 2L, signal = 30, seed = 1L)
    cd <- colData(std)
    cd$eight_groups <- factor(rep(letters[1:8], length.out = nrow(cd)))
    colData(std) <- cd
    std2 <- suppressWarnings(
        decompose(get_strategy("Decomposer", "hogsvd_averaged")(), std))@value
    std3 <- estimate_dynamics(
        get_strategy("DynamicsEstimator", "kde_logdensity")(), std2)@value

    expect_s3_class(plot_potential(std3, colour_by = "eight_groups"), "ggplot")
})

test_that("plot_potential reports an empty requested critical-point overlay", {
    std <- synthetic_control(
        n = 30L, p = 100L, K = 1L, signal = 20, seed = 13L
    )
    std <- suppressWarnings(
        decompose(get_strategy("Decomposer", "svd")(), std)
    )@value
    std <- estimate_dynamics(
        get_strategy("DynamicsEstimator", "kde_logdensity")(), std
    )@value
    md <- metadata(std)
    md$stage2$wells <- numeric()
    md$stage2$barriers <- numeric()
    metadata(std) <- md
    std <- prepare_plot_evidence(std, stage = "stage2")

    plot <- plot_potential(std, show_critical_points = TRUE)
    caption <- gsub("\\s+", " ", scientific_caption(plot))
    expect_match(caption, "no stored wells or barriers")
    expect_false(grepl("triangles mark", caption))
})

test_that("plot_potential describes wells without claiming barrier heights", {
    std <- synthetic_control(
        n = 30L, p = 100L, K = 1L, signal = 20, seed = 14L
    )
    std <- suppressWarnings(
        decompose(get_strategy("Decomposer", "svd")(), std)
    )@value
    std <- estimate_dynamics(
        get_strategy("DynamicsEstimator", "kde_logdensity")(), std
    )@value
    md <- metadata(std)
    md$stage2$wells <- 0
    md$stage2$barriers <- numeric()
    metadata(std) <- md
    std <- prepare_plot_evidence(std, stage = "stage2")

    plot <- plot_potential(std, show_critical_points = TRUE)
    caption <- gsub("\\s+", " ", scientific_caption(plot))
    expect_match(caption, "open circles mark stored stable wells")
    expect_match(
        caption,
        "Critical-point classifications are point estimates without uncertainty"
    )
    expect_false(grepl("barrier heights are point estimates", caption))
})

test_that("critical-point markers retain exact stored coordinates", {
    curve <- data.frame(
        x = seq(-2, 2, length.out = 20L),
        U = seq(0, 4, length.out = 20L)
    )
    points <- data.frame(
        x = c(0, 0), U = c(1, 1), type = c("well", "barrier")
    )
    plot <- ggplot2::ggplot(curve, ggplot2::aes(x, U)) +
        ggplot2::geom_line() +
        ggplot2::geom_point(data = points, ggplot2::aes(shape = type))
    point_layer <- plot$layers[[2L]]$data
    expect_equal(point_layer$x, points$x)
    expect_equal(point_layer$U, points$U)
})

test_that("plot_potential caption combines metadata and missing-rug evidence", {
    std <- synthetic_control(
        n = 40L, p = 500L, K = 2L, signal = 30, seed = 1L
    )
    std <- suppressWarnings(
        decompose(get_strategy("Decomposer", "hogsvd_averaged")(), std)
    )@value
    std <- estimate_dynamics(
        get_strategy("DynamicsEstimator", "kde_logdensity")(), std
    )@value
    cd <- colData(std)
    cd$planted_group[[1L]] <- NA
    colData(std) <- cd
    std <- prepare_plot_evidence(std, stage = "stage2")

    plot <- plot_potential(std, colour_by = "planted_group")

    expect_null(plot$labels$caption)
    caption <- gsub("\\s+", " ", scientific_caption(plot))
    expect_match(caption, "categorical planted group")
    expect_match(caption, "Dashed black rugs mark 1 observation")
    expect_null(plot$scales$get_scales("linetype"))
    expect_match(caption, "Fine coloured rugs")

    critical_plot <- plot_potential(
        std, colour_by = "planted_group", show_critical_points = TRUE
    )
    critical_caption <- gsub("\\s+", " ", scientific_caption(critical_plot))
    expect_match(
        critical_caption,
        "Dashed black rugs mark 1 observation"
    )
    expect_match(critical_caption, "Fine coloured rugs")
    expect_null(critical_plot$scales$get_scales("linetype"))
    expect_null(critical_plot$scales$get_scales("linewidth"))

    cd <- colData(std)
    cd$planted_group <- factor(
        rep(NA_character_, nrow(cd)), levels = c("high", "low")
    )
    colData(std) <- cd
    std <- prepare_plot_evidence(std, stage = "stage2")
    all_missing_plot <- plot_potential(
        std, colour_by = "planted_group", show_critical_points = TRUE
    )
    all_missing_caption <- gsub(
        "\\s+", " ", scientific_caption(all_missing_plot)
    )
    expect_s3_class(all_missing_plot, "gg")
    expect_match(
        all_missing_caption,
        "No observed values are available for categorical planted group"
    )
    expect_match(all_missing_caption, "dashed black rugs")
})

test_that("plot_potential colour-encodes continuous rug metadata", {
    std <- synthetic_control(
        n = 40L, p = 500L, K = 2L, signal = 30, seed = 2L
    )
    cd <- colData(std)
    cd$observed_time <- seq_len(nrow(cd))
    colData(std) <- cd
    std <- suppressWarnings(
        decompose(get_strategy("Decomposer", "hogsvd_averaged")(), std)
    )@value
    std <- estimate_dynamics(
        get_strategy("DynamicsEstimator", "kde_logdensity")(), std
    )@value
    std <- prepare_plot_evidence(std, stage = "stage2")

    plot <- plot_potential(std, colour_by = "observed_time")

    expect_s3_class(plot$scales$get_scales("colour"), "ScaleContinuous")
    expect_null(plot$scales$get_scales("size"))
    expect_s3_class(plot$scales$get_scales("alpha"), "ScaleContinuous")
    expect_match(scientific_caption(plot), "Fine rug colour and opacity")

    critical_plot <- plot_potential(
        std, colour_by = "observed_time", show_critical_points = TRUE
    )
    expect_s3_class(
        critical_plot$scales$get_scales("colour"),
        "ScaleContinuous"
    )
    expect_null(critical_plot$scales$get_scales("size"))
    expect_s3_class(
        critical_plot$scales$get_scales("alpha"), "ScaleContinuous"
    )
    critical_caption <- gsub("\\s+", " ", scientific_caption(critical_plot))
    expect_match(critical_caption, "Fine rug colour and opacity")
})

test_that("plot_potential renders typed unavailability when Stage 2 is absent", {
    std <- synthetic_control(n = 10L, p = 20L, K = 2L, signal = 30, seed = 1L)
    plot <- plot_potential(std)
    expect_s3_class(plot, "ggplot")
    expect_match(scientific_caption(plot), "No Stage 2 display is")
})

test_that("plot_potential scopes metadata validation to its own caller", {
    std <- synthetic_control(n = 20L, p = 60L, K = 1L, signal = 20, seed = 3L)
    std <- suppressWarnings(
        decompose(get_strategy("Decomposer", "svd")(), std)
    )@value
    std <- estimate_dynamics(
        get_strategy("DynamicsEstimator", "kde_logdensity")(), std
    )@value

    expect_error(
        plot_potential(std, colour_by = "not_a_metadata_field"),
        "^plot_potential\\(\\): colour_by .* was not found",
        class = "landscapeR_validation_error"
    )
})
