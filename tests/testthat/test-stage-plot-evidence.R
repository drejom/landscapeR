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

test_that("Stage plot evidence adapts to the shared visual evidence contract", {
    std <- synthetic_control(
        n = 20L, p = 60L, K = 1L, signal = 20, seed = 121L
    )
    std <- prepare_plot_evidence(std, stage = "stage1")
    complete <- landscapeR:::.stage_visual_evidence(std, "stage1")

    expect_s4_class(complete, "VisualEvidenceView")
    expect_identical(visual_evidence_surface(complete), "stage1")
    expect_identical(visual_evidence_state(complete), "complete")
    expect_true("spectrum" %in% visual_evidence_display_names(complete))
    expect_match(visual_evidence_caption(complete), "Stage 1")

    std <- suppressWarnings(
        decompose(get_strategy("Decomposer", "svd")(), std)
    )@value
    before <- digest::digest(std, algo = "sha256")
    stored <- metadata(std)$stage1_plot_evidence
    adapted <- visual_evidence(stored)

    expect_s4_class(adapted, "VisualEvidenceView")
    expect_identical(visual_evidence_state(adapted), "complete")
    expect_identical(
        visual_evidence_display(adapted, "evidence_digest"),
        stored@evidence_digest
    )
    expect_identical(digest::digest(std, algo = "sha256"), before)

    corrupted <- stored
    corrupted@evidence_digest <- paste(rep("0", 64L), collapse = "")
    unavailable <- visual_evidence(corrupted)
    expect_s4_class(unavailable, "VisualEvidenceView")
    expect_identical(visual_evidence_state(unavailable), "missing")
    expect_match(
        visual_evidence_diagnostics(unavailable)$diagnostic,
        "invalid.*evidence_digest"
    )
    expect_false(grepl(
        "evidence_digest|stored plot evidence",
        visual_evidence_caption(unavailable)
    ))
})

test_that("missing and stale Stage evidence become typed unavailable views", {
    std <- synthetic_control(
        n = 20L, p = 60L, K = 1L, signal = 20, seed = 122L
    )
    missing <- landscapeR:::.stage_visual_evidence(std, "stage2")
    expect_s4_class(missing, "VisualEvidenceView")
    expect_identical(visual_evidence_state(missing), "missing")
    expect_match(
        visual_evidence_display(missing, "unavailable_reason"),
        "No Stage 2 display is available"
    )

    decomposed <- suppressWarnings(
        decompose(get_strategy("Decomposer", "svd")(), std)
    )@value
    md <- metadata(decomposed)
    md$stage1@coords_k[[1L]][1L, 1L] <-
        md$stage1@coords_k[[1L]][1L, 1L] + 1
    metadata(decomposed) <- md
    stale <- landscapeR:::.stage_visual_evidence(decomposed, "stage1")

    expect_s4_class(stale, "VisualEvidenceView")
    expect_identical(visual_evidence_state(stale), "missing")
    expect_match(
        visual_evidence_display(stale, "unavailable_reason"),
        "out of date"
    )
    caption <- visual_evidence_caption(stale)
    expect_false(grepl("\\(A\\)|stored visual evidence|renderer", caption))
    expect_match(caption, "underlying scientific result remains available")
})

test_that("automatic display failure cannot reverse scientific success", {
    testthat::local_mocked_bindings(
        .store_stage1_plot_evidence = function(...) {
            stop("synthetic display failure")
        },
        .package = "landscapeR"
    )
    std <- synthetic_control(
        n = 20L, p = 60L, K = 1L, signal = 20, seed = 125L
    )
    result <- suppressWarnings(
        decompose(get_strategy("Decomposer", "svd")(), std)
    )

    expect_identical(result@status, "success")
    expect_s4_class(metadata(result@value)$stage1, "DecompositionResult")
    view <- landscapeR:::.stage_visual_evidence(result@value, "stage1")
    expect_identical(visual_evidence_state(view), "missing")
    expect_match(
        visual_evidence_diagnostics(view)$diagnostic,
        "synthetic display failure"
    )
    expect_false(grepl(
        "Automatic visual evidence|synthetic display failure",
        visual_evidence_caption(view)
    ))
})

test_that("Stage renderers consume stored evidence without recomputation", {
    std <- synthetic_control(
        n = 20L, p = 60L, K = 1L, signal = 20, seed = 128L
    )
    stage1 <- suppressWarnings(
        decompose(get_strategy("Decomposer", "svd")(), std)
    )@value
    stage2 <- estimate_dynamics(
        get_strategy("DynamicsEstimator", "kde_logdensity")(),
        stage1
    )@value

    testthat::local_mocked_bindings(
        .stage1_component_density_evidence = function(...) {
            stop("component evidence was recomputed")
        },
        .stage1_grouped_density_evidence = function(...) {
            stop("grouped evidence was recomputed")
        },
        .stage1_decomposition_evidence = function(...) {
            stop("decomposition evidence was recomputed")
        },
        .stage1_spectrum_evidence = function(...) {
            stop("spectrum evidence was recomputed")
        },
        .stage2_plot_displays = function(...) {
            stop("potential evidence was recomputed")
        },
        .package = "landscapeR"
    )

    expect_s3_class(plot_components(stage1), "ggplot")
    expect_s3_class(plot_spectrum(stage1), "ggplot")
    expect_s3_class(plot_decomposition(stage1), "ggplot")
    expect_s3_class(plot_potential(stage2), "ggplot")
})

test_that("requested Stage surface views own the canonical caption facts", {
    std <- synthetic_control(
        n = 20L, p = 60L, K = 1L, signal = 20, seed = 129L
    )
    stage1 <- suppressWarnings(
        decompose(get_strategy("Decomposer", "svd")(), std)
    )@value
    cd <- colData(stage1)
    cd$planted_group <- as.character(cd$planted_group)
    cd$planted_group[[1L]] <- "singleton"
    colData(stage1) <- cd
    stage1 <- prepare_plot_evidence(stage1, stage = "stage1")
    base_stage1 <- landscapeR:::.stage_visual_evidence(
        stage1, "stage1", colour_by = "planted_group"
    )
    component_view <- landscapeR:::.stage1_components_surface_view(
        base_stage1, "layer1", 1L, "planted_group"
    )
    expect_identical(visual_evidence_state(component_view), "partial")
    expect_identical(
        scientific_caption(plot_components(
            stage1,
            colour_by = "planted_group",
            n_components = 1L
        )),
        visual_evidence_caption(component_view)
    )
    expect_named(
        visual_evidence_display(component_view, "surface_request"),
        c("plot", "layer", "n_components", "colour_by")
    )

    stage2 <- estimate_dynamics(
        get_strategy("DynamicsEstimator", "kde_logdensity")(),
        stage1
    )@value
    base_stage2 <- landscapeR:::.stage_visual_evidence(stage2, "stage2")
    potential_view <- landscapeR:::.stage2_potential_surface_view(
        base_stage2, NULL, FALSE
    )
    expect_identical(
        scientific_caption(plot_potential(stage2)),
        visual_evidence_caption(potential_view)
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
    unavailable <- plot_spectrum(std)
    expect_s3_class(unavailable, "ggplot")
    expect_match(scientific_caption(unavailable), "No Stage 1 display is")

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

    unavailable <- plot_components(std)
    expect_s3_class(unavailable, "ggplot")
    expect_match(scientific_caption(unavailable), "current scientific result")
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

    unavailable <- plot_potential(std)
    expect_s3_class(unavailable, "ggplot")
    expect_match(scientific_caption(unavailable), "current scientific result")
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

test_that("singleton categorical levels are retained as point-only evidence", {
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
        "singleton.*baseline points only"
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

test_that("component plots render spectrum-only evidence as unavailable", {
    std <- synthetic_control(
        n = 20L, p = 60L, K = 1L, signal = 20, seed = 124L
    )
    prepared <- prepare_plot_evidence(std, stage = "stage1")

    plot <- plot_components(prepared)
    expect_s3_class(plot, "ggplot")
    expect_match(
        gsub("\\s+", " ", scientific_caption(plot)),
        "component evidence is unavailable.*decompose"
    )
})

test_that("Stage 1 renderers derive component availability from stored evidence", {
    renderer_text <- paste(
        deparse(body(plot_decomposition)),
        collapse = "\n"
    )

    expect_false(grepl("\\bmetadata\\s*\\(", renderer_text))
    expect_false(grepl("dr_coords_k\\s*\\(", renderer_text))
    expect_false(grepl("@display_data", renderer_text, fixed = TRUE))
})

test_that("numerically degenerate slices are retained as point-only evidence", {
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
        "numerically degenerate.*baseline points only",
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
        sprintf("PC1 \\(planted group = %s\\)", focal_group)
    )
    expect_match(caption, "numerically degenerate", ignore.case = TRUE)
})
