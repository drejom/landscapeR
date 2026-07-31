test_that("scientific stages store digest-bound plot evidence automatically", {
    std <- synthetic_control(
        n = 24L, p = 80L, K = 1L, signal = 20, seed = 114L
    )
    stage1 <- suppressWarnings(
        decompose(get_strategy("Decomposer", "svd")(), std)
    )@value
    stage1_evidence <- metadata(stage1)$stage1_plot_evidence

    expect_s4_class(stage1_evidence, "StagePlotEvidence")
    expect_silent(validObject(stage1_evidence))
    expect_named(
        stage1_evidence@displays,
        c(
            "spectrum", "component_densities",
            "component_group_densities",
            "component_group_density_status",
            "decomposition"
        )
    )
    expect_named(
        stage1_evidence@displays$component_group_densities[[1L]],
        "planted_group"
    )

    stage2 <- estimate_dynamics(
        get_strategy("DynamicsEstimator", "kde_logdensity")(),
        stage1
    )@value
    stage2_evidence <- metadata(stage2)$stage2_plot_evidence
    expect_s4_class(stage2_evidence, "StagePlotEvidence")
    expect_silent(validObject(stage2_evidence))
    expect_named(
        stage2_evidence@displays,
        c(
            "curve", "critical_points", "barrier_segments",
            "rug", "layers", "component"
        )
    )
})

test_that("StagePlotEvidence rejects malformed digest-consistent payloads", {
    malformed <- list(foo = 1)
    source_digest <- digest::digest("source", algo = "sha256")
    evidence_digest <- digest::digest(
        list(
            stage = "stage1",
            source_digest = source_digest,
            displays = malformed
        ),
        algo = "sha256"
    )
    expect_error(
        new(
            "StagePlotEvidence",
            stage = "stage1",
            source_digest = source_digest,
            displays = malformed,
            evidence_digest = evidence_digest
        ),
        "Stage 1 displays have invalid names"
    )

    std <- synthetic_control(
        n = 20L, p = 60L, K = 1L, signal = 20, seed = 119L
    )
    stage1 <- suppressWarnings(
        decompose(get_strategy("Decomposer", "svd")(), std)
    )@value
    stage1_evidence <- metadata(stage1)$stage1_plot_evidence
    stage1_displays <- stage1_evidence@displays
    stage1_displays$component_densities[[1L]]$component <- "PC999"
    stage1_digest <- digest::digest(
        list(
            stage = "stage1",
            source_digest = stage1_evidence@source_digest,
            displays = stage1_displays
        ),
        algo = "sha256"
    )
    expect_error(
        new(
            "StagePlotEvidence",
            stage = "stage1",
            source_digest = stage1_evidence@source_digest,
            displays = stage1_displays,
            evidence_digest = stage1_digest
        ),
        "component domains do not agree"
    )

    stage2 <- estimate_dynamics(
        get_strategy("DynamicsEstimator", "kde_logdensity")(),
        stage1
    )@value
    evidence <- metadata(stage2)$stage2_plot_evidence
    displays <- evidence@displays
    displays$critical_points <- data.frame(
        x = 0,
        U = 0,
        type = "saddle",
        stringsAsFactors = FALSE
    )
    evidence_digest <- digest::digest(
        list(
            stage = "stage2",
            source_digest = evidence@source_digest,
            displays = displays
        ),
        algo = "sha256"
    )
    expect_error(
        new(
            "StagePlotEvidence",
            stage = "stage2",
            source_digest = evidence@source_digest,
            displays = displays,
            evidence_digest = evidence_digest
        ),
        "critical-point types are invalid"
    )
})

test_that("legacy plot evidence is explicit, typed, and provenance-recorded", {
    std <- synthetic_control(
        n = 20L, p = 60L, K = 1L, signal = 20, seed = 115L
    )
    expect_error(
        plot_spectrum(std),
        "plot evidence is unavailable",
        class = "landscapeR_plot_evidence_unavailable"
    )

    prepared <- prepare_plot_evidence(std, stage = "stage1")
    expect_s3_class(plot_spectrum(prepared), "ggplot")
    step <- prepared@provenance[[length(prepared@provenance)]]
    expect_identical(step@contract, "StagePlotEvidence")
    expect_identical(step@implementation, "stored_typed_evidence")
})

test_that("scientific mutations invalidate stored plot evidence", {
    std <- synthetic_control(
        n = 20L, p = 60L, K = 1L, signal = 20, seed = 116L
    )
    std <- suppressWarnings(
        decompose(get_strategy("Decomposer", "svd")(), std)
    )@value
    md <- metadata(std)
    md$stage1@coords_k[[1L]][1L, 1L] <-
        md$stage1@coords_k[[1L]][1L, 1L] + 1
    metadata(std) <- md

    expect_error(
        plot_components(std),
        "plot evidence is stale",
        class = "landscapeR_plot_evidence_unavailable"
    )
    refreshed <- prepare_plot_evidence(std, stage = "stage1")
    expect_s3_class(plot_components(refreshed), "ggplot")
})

test_that("Stage 2 rug evidence is bound to its Stage 1 coordinates", {
    std <- synthetic_control(
        n = 20L, p = 60L, K = 1L, signal = 20, seed = 118L
    )
    std <- suppressWarnings(
        decompose(get_strategy("Decomposer", "svd")(), std)
    )@value
    std <- estimate_dynamics(
        get_strategy("DynamicsEstimator", "kde_logdensity")(),
        std
    )@value
    md <- metadata(std)
    md$stage1@coords_k[[1L]][1L, 1L] <-
        md$stage1@coords_k[[1L]][1L, 1L] + 1
    metadata(std) <- md

    expect_error(
        plot_potential(std),
        "plot evidence is stale",
        class = "landscapeR_plot_evidence_unavailable"
    )
})

test_that("legacy renderers contain no scientific recomputation calls", {
    renderer_text <- c(
        paste(deparse(body(plot_components)), collapse = "\n"),
        paste(deparse(body(plot_spectrum)), collapse = "\n"),
        paste(deparse(body(plot_decomposition)), collapse = "\n"),
        paste(deparse(body(plot_potential)), collapse = "\n")
    )

    expect_false(any(grepl("\\bsvd\\s*\\(", renderer_text)))
    expect_false(any(grepl("geom_density\\s*\\(", renderer_text)))
    expect_false(any(grepl("\\bdensity\\s*\\(", renderer_text)))
    expect_false(any(grepl("\\bapprox\\s*\\(", renderer_text)))
    expect_false(grepl(
        "\\bmetadata\\s*\\(",
        paste(deparse(body(plot_decomposition)), collapse = "\n")
    ))
    expect_false(grepl(
        "\\bmetadata\\s*\\(",
        paste(deparse(body(plot_potential)), collapse = "\n")
    ))
})

test_that("repeated rendering preserves stored evidence identity", {
    std <- synthetic_control(
        n = 20L, p = 60L, K = 1L, signal = 20, seed = 117L
    )
    std <- suppressWarnings(
        decompose(get_strategy("Decomposer", "svd")(), std)
    )@value
    before <- metadata(std)$stage1_plot_evidence@evidence_digest

    first <- plot_components(std)
    second <- plot_components(std)

    expect_identical(scientific_caption(first), scientific_caption(second))
    expect_identical(
        metadata(std)$stage1_plot_evidence@evidence_digest,
        before
    )
})

test_that("stored spectrum retains the legacy raw-assay estimand", {
    std <- synthetic_control(
        n = 20L, p = 60L, K = 1L, signal = 20, seed = 120L
    )
    stage1 <- suppressWarnings(
        decompose(
            get_strategy("Decomposer", "svd")(list(center = TRUE)),
            std
        )
    )@value
    observed <-
        metadata(stage1)$stage1_plot_evidence@displays$spectrum$values$sv
    expected <- svd(
        t(assay(experiments(std)[[1L]])),
        nu = 0L,
        nv = 0L
    )$d
    expect_equal(observed, expected)
    expect_match(
        scientific_caption(plot_spectrum(stage1)),
        "raw, uncentred assay"
    )
})

test_that("singleton categorical levels are retained as rug-only evidence", {
    std <- synthetic_control(
        n = 20L, p = 60L, K = 1L, signal = 20, seed = 121L
    )
    stage1 <- suppressWarnings(
        decompose(get_strategy("Decomposer", "svd")(), std)
    )@value
    cd <- colData(stage1)
    cd$planted_group <- as.character(cd$planted_group)
    cd$planted_group[[1L]] <- "singleton"
    colData(stage1) <- cd
    stage1 <- prepare_plot_evidence(stage1, stage = "stage1")

    status <- metadata(stage1)$stage1_plot_evidence@
        displays$component_group_density_status[[1L]]$planted_group
    expect_identical(
        status$density_available[status$metadata_value == "singleton"],
        FALSE
    )
    expect_match(
        scientific_caption(
            plot_components(stage1, colour_by = "planted_group")
        ),
        "singleton.*rugs only"
    )
})

test_that("all-missing categorical metadata retains an explicit status schema", {
    std <- synthetic_control(
        n = 20L, p = 60L, K = 1L, signal = 20, seed = 122L
    )
    stage1 <- suppressWarnings(
        decompose(get_strategy("Decomposer", "svd")(), std)
    )@value
    cd <- colData(stage1)
    cd$all_missing_group <- rep(NA_character_, nrow(cd))
    colData(stage1) <- cd

    expect_silent(
        stage1 <- prepare_plot_evidence(stage1, stage = "stage1")
    )
    status <- metadata(stage1)$stage1_plot_evidence@
        displays$component_group_density_status[[1L]]$all_missing_group
    expect_named(
        status,
        c("metadata_value", "n_observations", "density_available")
    )
    expect_type(status$metadata_value, "character")
    expect_equal(nrow(status), 0L)
})

test_that("Stage 2 evidence retains rugs from legacy component-one coordinates", {
    std <- synthetic_control(
        n = 20L, p = 60L, K = 1L, signal = 20, seed = 123L
    )
    stage1 <- suppressWarnings(
        decompose(get_strategy("Decomposer", "svd")(), std)
    )@value
    stage2 <- estimate_dynamics(
        get_strategy("DynamicsEstimator", "kde_logdensity")(),
        stage1
    )@value
    md <- metadata(stage2)
    expected <- dr_coords(md$stage1)[[1L]]
    md$stage1@coords_k <- list()
    metadata(stage2) <- md

    prepared <- prepare_plot_evidence(stage2, stage = "stage2")
    rug <- metadata(prepared)$stage2_plot_evidence@displays$rug
    expect_equal(rug$x, expected)
    expect_s3_class(plot_potential(prepared), "ggplot")
})

test_that("component plots reject spectrum-only evidence with a typed error", {
    std <- synthetic_control(
        n = 20L, p = 60L, K = 1L, signal = 20, seed = 124L
    )
    prepared <- prepare_plot_evidence(std, stage = "stage1")

    expect_error(
        plot_components(prepared),
        "component evidence is unavailable.*decompose",
        class = "landscapeR_plot_evidence_unavailable"
    )
})

test_that("Stage 1 renderers derive component availability from stored evidence", {
    renderer_text <- paste(
        deparse(body(plot_decomposition)),
        collapse = "\n"
    )

    expect_false(grepl("\\bmetadata\\s*\\(", renderer_text))
    expect_false(grepl("dr_coords_k\\s*\\(", renderer_text))
})

test_that("numerically degenerate slices are retained as rug-only evidence", {
    std <- synthetic_control(
        n = 20L, p = 60L, K = 1L, signal = 20, seed = 126L
    )
    stage1 <- suppressWarnings(
        decompose(get_strategy("Decomposer", "svd")(), std)
    )@value
    md <- metadata(stage1)
    md$stage1@coords_k[[1L]][, 1L] <- 0
    metadata(stage1) <- md

    expect_silent(
        stage1 <- prepare_plot_evidence(stage1, stage = "stage1")
    )
    densities <- metadata(stage1)$stage1_plot_evidence@
        displays$component_densities[[1L]]
    component_one <- densities[densities$component == "PC1", , drop = FALSE]
    expect_false(any(component_one$density_available))
    expect_match(
        gsub(
            "\\s+",
            " ",
            scientific_caption(plot_components(stage1))
        ),
        "numerically degenerate.*rugs only",
        ignore.case = TRUE
    )
})

test_that("degenerate grouped densities retain their component and group identity", {
    std <- synthetic_control(
        n = 20L, p = 60L, K = 1L, signal = 20, seed = 127L
    )
    stage1 <- suppressWarnings(
        decompose(get_strategy("Decomposer", "svd")(), std)
    )@value
    group <- as.character(colData(stage1)$planted_group)
    focal_group <- unique(group)[[1L]]
    focal <- which(group == focal_group)
    md <- metadata(stage1)
    md$stage1@coords_k[[1L]][focal, 1L] <-
        10 + seq_along(focal) * 1e-9
    metadata(stage1) <- md
    stage1 <- prepare_plot_evidence(stage1, stage = "stage1")

    caption <- gsub(
        "\\s+",
        " ",
        scientific_caption(
            plot_components(stage1, colour_by = "planted_group")
        )
    )
    expect_match(
        caption,
        sprintf("PC1 \\(planted_group = %s\\)", focal_group)
    )
    expect_match(caption, "numerically degenerate", ignore.case = TRUE)
})
