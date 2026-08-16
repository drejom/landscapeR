test_that("plot_spectrum returns a ggplot on a fresh StateTransitionData", {
    std <- synthetic_control(n = 40L, p = 500L, K = 2L, signal = 30, seed = 1L)
    std <- prepare_plot_evidence(std, stage = "stage1")
    p <- plot_spectrum(std)
    expect_s3_class(p, "gg")
    caption <- scientific_caption(p)
    expect_match(caption, "BBP")
    expect_match(caption, "model-based\\s+detectability reference")
    expect_match(caption, "layer 1")
})

test_that("plot_components returns a ggplot after Stage 1 has run", {
    std <- synthetic_control(n = 40L, p = 500L, K = 2L, signal = 30, seed = 1L)
    ctor <- get_strategy("Decomposer", "hogsvd_averaged")
    std2 <- suppressWarnings(decompose(ctor(), std))@value
    p <- plot_components(std2, colour_by = "planted_group")
    expect_s3_class(p, "gg")
    caption <- scientific_caption(p)
    expect_match(caption, "[Cc]ategorical metadata")
    expect_match(caption, "does\\s+not rank or nominate")
    expect_null(p$labels$caption)
})

test_that("plot_decomposition returns a ggplot after Stage 1 has run", {
    std <- synthetic_control(n = 40L, p = 500L, K = 2L, signal = 30, seed = 1L)
    ctor <- get_strategy("Decomposer", "hogsvd_averaged")
    std2 <- suppressWarnings(decompose(ctor(), std))@value
    p <- plot_decomposition(std2)
    expect_s3_class(p, "gg")
    expect_false(grepl("Supply synthetic_control", p$labels$subtitle))
    caption <- scientific_caption(p)
    expect_match(caption, "rank-ordered")
    expect_match(caption, "ground-truth angle")
})

test_that("plot captions retain declared destructive and longitudinal design fields", {
    independent <- synthetic_control(
        n = 20L, p = 60L, K = 1L, signal = 20, seed = 10L
    )
    independent_cd <- colData(independent)
    independent_cd$collection_day <- seq_len(nrow(independent_cd))
    colData(independent) <- independent_cd
    independent <- declare_sampling_design(
        independent,
        independent_time_course("collection_day", "days")
    )
    independent <- prepare_plot_evidence(independent, stage = "stage1")

    longitudinal_data <- synthetic_control(
        n = 20L, p = 60L, K = 1L, signal = 20, seed = 11L
    )
    longitudinal_cd <- colData(longitudinal_data)
    longitudinal_cd$animal_id <- rep(sprintf("animal_%02d", 1:5), each = 4L)
    longitudinal_cd$collection_day <- rep(1:4, times = 5L)
    colData(longitudinal_data) <- longitudinal_cd
    longitudinal_data <- declare_sampling_design(
        longitudinal_data,
        longitudinal("animal_id", "collection_day", "days")
    )
    longitudinal_data <- prepare_plot_evidence(
        longitudinal_data,
        stage = "stage1"
    )

    independent_caption <- scientific_caption(plot_spectrum(independent))
    longitudinal_caption <- scientific_caption(plot_spectrum(longitudinal_data))
    expect_match(independent_caption, "collection day")
    expect_match(independent_caption, "days")
    expect_match(longitudinal_caption, "collection day")
    expect_match(longitudinal_caption, "days")
    expect_match(longitudinal_caption, "animal id")
})

test_that("plot_decomposition uses one effective component across unequal ranks", {
    std <- synthetic_control(
        n = 30L, p = 100L, K = 3L, signal = 25, seed = 12L
    )
    std <- suppressWarnings(
        decompose(get_strategy("Decomposer", "hogsvd_averaged")(), std)
    )@value
    md <- metadata(std)
    original <- dr_coords_k(md$stage1)
    md$stage1@coords_k[[2L]] <- original[[2L]][, 1:2, drop = FALSE]
    metadata(std) <- md
    std <- prepare_plot_evidence(std, stage = "stage1")

    expect_warning(
        plot <- plot_decomposition(std, component = 3L),
        "plotting component 2"
    )
    expected <- unlist(
        lapply(original, function(coordinates) coordinates[, 2L]),
        use.names = FALSE
    )
    expect_equal(plot$data$coord, expected)
    expect_match(scientific_caption(plot), "component 2")
    expect_identical(plot$labels$y, "Component 2 coordinate")
})

test_that("plot_decomposition with component=2 returns a ggplot", {
    std <- synthetic_control(n = 40L, p = 500L, K = 2L, signal = 30, seed = 1L)
    ctor <- get_strategy("Decomposer", "hogsvd_averaged")
    std2 <- suppressWarnings(decompose(ctor(), std))@value
    p <- plot_decomposition(std2, component = 2L)
    expect_s3_class(p, "gg")
})

test_that("plot_decomposition omits an angle without matching stored truth", {
    std <- synthetic_control(n = 40L, p = 500L, K = 2L, signal = 30, seed = 1L)
    ctor <- get_strategy("Decomposer", "hogsvd_averaged")
    std2 <- suppressWarnings(decompose(ctor(), std))@value
    p <- plot_decomposition(std2, component = 2L)
    expect_identical(
        p$labels$subtitle,
        "Layers show rank-ordered sample coordinates"
    )
    expect_false(grepl("ground-truth angle", scientific_caption(p)))
})

test_that("plot_spectrum renders typed unavailability on empty data", {
    plot <- plot_spectrum(empty_std())
    expect_s3_class(plot, "ggplot")
    expect_match(scientific_caption(plot), "No Stage 1 display is")
})

test_that("plot_decomposition renders typed unavailability without Stage 1", {
    std <- synthetic_control(n = 10L, p = 20L, K = 2L, signal = 30, seed = 1L)
    plot <- plot_decomposition(std)
    expect_s3_class(plot, "ggplot")
    expect_match(scientific_caption(plot), "No Stage 1 display is")
})

test_that("plot_components renders typed unavailability without Stage 1", {
    std <- synthetic_control(n = 10L, p = 20L, K = 2L, signal = 30, seed = 1L)
    plot <- plot_components(std)
    expect_s3_class(plot, "ggplot")
    expect_match(scientific_caption(plot), "No Stage 1 display is")
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
    prepare_plot_evidence(std, stage = "stage1")
}

test_that("plot_decomposition renders continuous metadata and marks missing values", {
    std <- component_gallery_fixture()
    cd <- colData(std)
    cd$sample_weeks[1L] <- NA_real_
    colData(std) <- cd
    std <- prepare_plot_evidence(std, stage = "stage1")

    p <- plot_decomposition(std, colour_by = "sample_weeks")

    expect_s3_class(p$scales$get_scales("colour"), "ScaleContinuous")
    expect_s3_class(p$scales$get_scales("size"), "ScaleContinuous")
    expect_null(p$labels$caption)
    expect_match(scientific_caption(p), "Crosses mark 1 observation")
    expect_match(scientific_caption(p), "[Cc]ontinuous sample weeks")
    expect_match(scientific_caption(p), "point sizes")
    expect_true(any(vapply(
        p$layers,
        function(layer) {
            inherits(layer$geom, "GeomPoint") &&
                identical(layer$aes_params$shape, 4)
        },
        logical(1L)
    )))
})

test_that("plot_components canonically aligns categorical MAE metadata", {
    std <- component_gallery_fixture()
    p <- plot_components(std, colour_by = "condition", n_components = 3L)
    sm <- as.data.frame(MultiAssayExperiment::sampleMap(std))
    cd <- as.data.frame(colData(std))
    assay_samples <- colnames(experiments(std)[[1L]])
    map_idx <- match(assay_samples, sm$colname)
    expected <- cd$condition[match(sm$primary[map_idx], rownames(cd))]

    expect_identical(p$data$metadata_value[seq_along(expected)], expected)
    expect_s3_class(p$scales$get_scales("colour"), "ScaleDiscrete")
    expect_s3_class(p$scales$get_scales("fill"), "ScaleDiscrete")
    expect_s3_class(p$scales$get_scales("linetype"), "ScaleDiscrete")
    density_layer <- p$layers[[1L]]$data
    expect_setequal(
        unique(density_layer$metadata_value),
        unique(expected)
    )
    expect_true(all(c("coord", "density") %in% names(density_layer)))
    expect_identical(
        levels(p$data$component),
        c("PC1", "PC2", "PC3")
    )
    expect_identical(
        p$labels$title,
        "Stage 1 component distributions"
    )
    expect_false("bc" %in% names(p$data))
    expect_match(scientific_caption(p), "rna layer")
    expect_match(scientific_caption(p), "[Cc]ategorical metadata")
    expect_match(scientific_caption(p), "[Dd]ensity\\s+fills")
    expect_match(scientific_caption(p), "[Bb]aseline stems")
})

test_that("plot_components visibly renders continuous MAE metadata", {
    std <- component_gallery_fixture()
    p <- plot_components(std, colour_by = "sample_weeks", n_components = 2L)
    sm <- as.data.frame(MultiAssayExperiment::sampleMap(std))
    cd <- as.data.frame(colData(std))
    assay_samples <- colnames(experiments(std)[[1L]])
    map_idx <- match(assay_samples, sm$colname)
    expected <- cd$sample_weeks[match(sm$primary[map_idx], rownames(cd))]

    expect_identical(p$data$metadata_value[seq_along(expected)], expected)
    expect_s3_class(p$scales$get_scales("colour"), "ScaleContinuous")
    expect_s3_class(p$scales$get_scales("linewidth"), "ScaleContinuous")
    expect_null(p$scales$get_scales("fill"))
    expect_true(any(vapply(
        p$layers,
        function(layer) inherits(layer$geom, "GeomArea"),
        logical(1L)
    )))
    expect_true(any(vapply(
        p$layers,
        function(layer) inherits(layer$geom, "GeomRug"),
        logical(1L)
    )))
    expect_match(scientific_caption(p), "[Cc]ontinuous metadata")
    expect_match(scientific_caption(p), "[Bb]aseline stems additionally use width")
})

test_that("plot_components renders eight categorical linetypes", {
    std <- component_gallery_fixture()
    cd <- colData(std)
    cd$eight_groups <- factor(rep(letters[1:8], length.out = nrow(cd)))
    colData(std) <- cd
    std <- prepare_plot_evidence(std, stage = "stage1")

    p <- plot_components(std, colour_by = "eight_groups", n_components = 2L)

    expect_s3_class(p, "gg")
    expect_s3_class(p$scales$get_scales("linetype"), "ScaleDiscrete")
})

test_that("plot_components renders valid metadata without unknown-scale warnings", {
    old_warning <- options(warn = 2)
    on.exit(options(old_warning), add = TRUE)

    continuous <- component_gallery_fixture()
    continuous_cd <- colData(continuous)
    continuous_cd$sample_weeks[1L] <- NA_real_
    colData(continuous) <- continuous_cd
    continuous <- prepare_plot_evidence(continuous, stage = "stage1")

    categorical <- component_gallery_fixture()
    categorical_cd <- colData(categorical)
    categorical_cd$condition[1L] <- NA_character_
    colData(categorical) <- categorical_cd
    categorical <- prepare_plot_evidence(categorical, stage = "stage1")

    expect_no_error({
        ggplot2::ggplot_build(
            plot_components(continuous, colour_by = "sample_weeks")
        )
    })
    expect_no_error({
        ggplot2::ggplot_build(
            plot_components(categorical, colour_by = "condition")
        )
    })
})

test_that("metadata field names cannot overwrite gallery coordinates or facets", {
    std <- component_gallery_fixture()
    cd <- colData(std)
    cd$coord <- cd$sample_weeks
    cd$component <- cd$condition
    colData(std) <- cd
    std <- prepare_plot_evidence(std, stage = "stage1")
    sm <- as.data.frame(MultiAssayExperiment::sampleMap(std))
    assay_samples <- colnames(experiments(std)[[1L]])
    map_idx <- match(assay_samples, sm$colname)
    cd_idx <- match(sm$primary[map_idx], rownames(cd))

    continuous <- plot_components(std, colour_by = "coord")
    categorical <- plot_components(std, colour_by = "component")

    expect_identical(
        continuous$data$metadata_value[seq_along(cd_idx)],
        cd$coord[cd_idx]
    )
    expect_identical(
        categorical$data$metadata_value[seq_along(cd_idx)],
        cd$component[cd_idx]
    )
    expect_identical(levels(categorical$data$component), c("PC1", "PC2", "PC3"))
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
    plot <- plot_components(duplicate, colour_by = "condition")
    expect_s3_class(plot, "ggplot")
    expect_match(scientific_caption(plot), "current scientific result")
})

test_that("plot_components rejects missing and ambiguous canonical mappings", {
    std <- component_gallery_fixture()
    missing <- std
    missing@sampleMap <- missing@sampleMap[-1L, ]
    missing_plot <- plot_components(missing, colour_by = "condition")
    expect_s3_class(missing_plot, "ggplot")
    expect_match(scientific_caption(missing_plot), "current scientific result")

    ambiguous <- std
    sm <- sampleMap(ambiguous)
    duplicate_row <- sm[1L, ]
    duplicate_row$primary <- sm$primary[2L]
    sampleMap(ambiguous) <- rbind(sm, duplicate_row)
    ambiguous_plot <- plot_components(ambiguous, colour_by = "condition")
    expect_s3_class(ambiguous_plot, "ggplot")
    expect_match(scientific_caption(ambiguous_plot), "current scientific result")
})
