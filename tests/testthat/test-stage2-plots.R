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

    expect_identical(plot$labels$shape, "Critical point")
    expect_true(any(vapply(
        plot$layers,
        function(layer) inherits(layer$geom, "GeomPoint"),
        logical(1L)
    )))
    caption <- gsub("\\s+", " ", scientific_caption(plot))
    expect_match(caption, "downward triangles mark stored wells")
    expect_match(caption, "upward triangles mark stored barriers")
    expect_match(caption, "Dotted vertical segments")
    expect_match(caption, "point\\s+estimates")
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

    plot <- plot_potential(std, show_critical_points = TRUE)
    caption <- gsub("\\s+", " ", scientific_caption(plot))
    expect_match(caption, "no stored wells, barriers, or barrier-height")
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

    plot <- plot_potential(std, show_critical_points = TRUE)
    caption <- gsub("\\s+", " ", scientific_caption(plot))
    expect_match(caption, "downward triangles mark stored wells")
    expect_match(
        caption,
        "Critical-point classifications are point estimates without uncertainty"
    )
    expect_false(grepl("barrier heights are point estimates", caption))
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

    plot <- plot_potential(std, colour_by = "planted_group")

    expect_null(plot$labels$caption)
    expect_match(scientific_caption(plot), "categorical\\s+planted_group")
    expect_match(scientific_caption(plot), "Dashed rug marks\\s+1 observation")
})

test_that("plot_potential errors when Stage 2 is absent", {
    std <- synthetic_control(n = 10L, p = 20L, K = 2L, signal = 30, seed = 1L)
    expect_error(plot_potential(std), "Stage 2 has not been run")
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
