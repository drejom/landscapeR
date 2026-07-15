test_that("plot_spectrum returns a ggplot on a fresh StateTransitionData", {
    std <- synthetic_control(n = 40L, p = 500L, K = 2L, signal = 30, seed = 1L)
    p <- plot_spectrum(std)
    expect_s3_class(p, "gg")
})

test_that("plot_components returns a ggplot after Stage 1 has run", {
    std <- synthetic_control(n = 40L, p = 500L, K = 2L, signal = 30, seed = 1L)
    ctor <- get_strategy("Decomposer", "hogsvd_averaged")
    std2 <- suppressWarnings(decompose(ctor(), std))@value
    p <- plot_components(std2, colour_by = "planted_group")
    expect_s3_class(p, "gg")
})

test_that("plot_decomposition returns a ggplot after Stage 1 has run", {
    std <- synthetic_control(n = 40L, p = 500L, K = 2L, signal = 30, seed = 1L)
    ctor <- get_strategy("Decomposer", "hogsvd_averaged")
    std2 <- suppressWarnings(decompose(ctor(), std))@value
    p <- plot_decomposition(std2)
    expect_s3_class(p, "gg")
})

test_that("plot_decomposition with component=2 returns a ggplot", {
    std <- synthetic_control(n = 40L, p = 500L, K = 2L, signal = 30, seed = 1L)
    ctor <- get_strategy("Decomposer", "hogsvd_averaged")
    std2 <- suppressWarnings(decompose(ctor(), std))@value
    p <- plot_decomposition(std2, component = 2L)
    expect_s3_class(p, "gg")
})

test_that("plot_decomposition component=2 annotation uses component-2 axis", {
    std <- synthetic_control(n = 40L, p = 500L, K = 2L, signal = 30, seed = 1L)
    ctor <- get_strategy("Decomposer", "hogsvd_averaged")
    std2 <- suppressWarnings(decompose(ctor(), std))@value
    p <- plot_decomposition(std2, component = 2L)
    subtitle <- p$labels$subtitle
    expect_match(subtitle, "component 2")
})

test_that("plot_spectrum errors on empty StateTransitionData", {
    # plot_spectrum needs at least one experiment
    expect_error(plot_spectrum(empty_std()), regexp = NULL)
})

test_that("plot_decomposition errors when Stage 1 is absent", {
    std <- synthetic_control(n = 10L, p = 20L, K = 2L, signal = 30, seed = 1L)
    expect_error(plot_decomposition(std), "Stage 1 has not been run")
})

test_that("plot_components errors when Stage 1 is absent", {
    std <- synthetic_control(n = 10L, p = 20L, K = 2L, signal = 30, seed = 1L)
    expect_error(
        plot_components(std),
        "Stage 1 has not been run",
        class = "landscapeR_validation_error"
    )
})

component_gallery_fixture <- function() {
    n <- 24L
    primary <- sprintf("p%02d", seq_len(n))
    assay_names <- sprintf("rna_%02d", seq_len(n))
    assay_order <- c(
        7L, 2L, 19L, 4L, 23L, 6L, 1L, 8L, 17L, 10L, 3L, 12L,
        21L, 14L, 5L, 16L, 9L, 18L, 11L, 20L, 13L, 22L, 15L, 24L
    )
    cd_order <- c(
        24L, 1L, 23L, 2L, 22L, 3L, 21L, 4L, 20L, 5L, 19L, 6L,
        18L, 7L, 17L, 8L, 16L, 9L, 15L, 10L, 14L, 11L, 13L, 12L
    )
    condition <- rep(c("CTL", "CM"), length.out = n)
    sample_weeks <- seq(0, by = 1.5, length.out = n)
    cd <- S4Vectors::DataFrame(
        condition = condition[cd_order],
        sample_weeks = sample_weeks[cd_order],
        row.names = primary[cd_order]
    )
    assay_primary <- primary[assay_order]
    assay_colnames <- assay_names[assay_order]
    se <- SummarizedExperiment::SummarizedExperiment(
        assays = list(logcounts = matrix(
            seq_len(5L * n),
            nrow = 5L,
            dimnames = list(sprintf("g%d", 1:5), assay_colnames)
        ))
    )
    map_order <- rev(seq_len(n))
    sm <- S4Vectors::DataFrame(
        assay = factor(rep("rna", n), levels = "rna"),
        primary = assay_primary[map_order],
        colname = assay_colnames[map_order]
    )
    std <- StateTransitionData(
        experiments = list(rna = se),
        colData = cd,
        sampleMap = sm
    )
    original_index <- match(assay_primary, primary)
    coords <- cbind(
        PC1 = sin(original_index / 3),
        PC2 = ifelse(condition[original_index] == "CM", 2, -2) +
            original_index / 30,
        PC3 = cos(original_index / 4)
    )
    md <- metadata(std)
    md$stage1 <- DecompositionResult(
        V_star = c(1, 0, 0, 0, 0),
        sigma = 1,
        coords = list(coords[, 1L]),
        V_k = diag(5)[, 1:3, drop = FALSE],
        sigma_k = matrix(c(3, 2, 1), nrow = 1L),
        coords_k = list(coords),
        k = 3L
    )
    metadata(std) <- md
    std
}

test_that("plot_components canonically aligns categorical MAE metadata", {
    std <- component_gallery_fixture()
    p <- plot_components(std, colour_by = "condition", n_components = 3L)
    sm <- as.data.frame(MultiAssayExperiment::sampleMap(std))
    cd <- as.data.frame(colData(std))
    assay_samples <- colnames(experiments(std)[[1L]])
    map_idx <- match(assay_samples, sm$colname)
    expected <- cd$condition[match(sm$primary[map_idx], rownames(cd))]

    expect_identical(p$data$condition[seq_along(expected)], expected)
    expect_s3_class(p$scales$get_scales("colour"), "ScaleDiscrete")
    expect_s3_class(p$scales$get_scales("fill"), "ScaleDiscrete")
    expect_identical(
        levels(p$data$component),
        c("PC1", "PC2", "PC3")
    )
    expect_identical(
        p$labels$title,
        "Stage 1 component gallery \u2014 layer 1"
    )
    expect_false("bc" %in% names(p$data))
})

test_that("plot_components visibly renders continuous MAE metadata", {
    std <- component_gallery_fixture()
    p <- plot_components(std, colour_by = "sample_weeks", n_components = 2L)
    sm <- as.data.frame(MultiAssayExperiment::sampleMap(std))
    cd <- as.data.frame(colData(std))
    assay_samples <- colnames(experiments(std)[[1L]])
    map_idx <- match(assay_samples, sm$colname)
    expected <- cd$sample_weeks[match(sm$primary[map_idx], rownames(cd))]

    expect_identical(p$data$sample_weeks[seq_along(expected)], expected)
    expect_s3_class(p$scales$get_scales("colour"), "ScaleContinuous")
    expect_null(p$scales$get_scales("fill"))
    expect_true(any(vapply(
        p$layers,
        function(layer) inherits(layer$geom, "GeomDensity"),
        logical(1L)
    )))
    expect_true(any(vapply(
        p$layers,
        function(layer) inherits(layer$geom, "GeomRug"),
        logical(1L)
    )))
})

test_that("plot_components rejects missing and duplicate metadata fields", {
    std <- component_gallery_fixture()
    expect_error(
        plot_components(std, colour_by = "absent"),
        "not found in MAE-level colData",
        class = "landscapeR_validation_error"
    )

    duplicate <- std
    cd <- colData(duplicate)
    cd$condition_copy <- cd$condition
    names(cd)[ncol(cd)] <- "condition"
    colData(duplicate) <- cd
    expect_error(
        plot_components(duplicate, colour_by = "condition"),
        "ambiguous in MAE-level colData",
        class = "landscapeR_validation_error"
    )
})

test_that("plot_components rejects missing and ambiguous canonical mappings", {
    std <- component_gallery_fixture()
    missing <- std
    missing@sampleMap <- missing@sampleMap[-1L, ]
    expect_error(
        plot_components(missing, colour_by = "condition"),
        "missing canonical sample mapping",
        class = "landscapeR_validation_error"
    )

    ambiguous <- std
    sm <- sampleMap(ambiguous)
    duplicate_row <- sm[1L, ]
    duplicate_row$primary <- sm$primary[2L]
    sampleMap(ambiguous) <- rbind(sm, duplicate_row)
    expect_error(
        plot_components(ambiguous, colour_by = "condition"),
        "ambiguous canonical sample mapping",
        class = "landscapeR_validation_error"
    )
})
