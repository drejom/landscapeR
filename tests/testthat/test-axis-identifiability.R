test_that("component alignment jointly recovers swaps and sign changes", {
    reference <- diag(3)
    replicate <- reference[, c(2, 3, 1), drop = FALSE]
    replicate[, 2] <- -replicate[, 2]

    alignment <- landscapeR:::.match_component_loadings(
        reference,
        replicate
    )

    expect_identical(alignment$assignment$reference_component, 1:3)
    expect_identical(alignment$assignment$replicate_component, c(3L, 1L, 2L))
    expect_equal(alignment$assignment$absolute_similarity, rep(1, 3))
    expect_identical(alignment$assignment$orientation, c(1L, 1L, -1L))
    expect_equal(alignment$assignment$assignment_margin, rep(1, 3))
    expect_equal(alignment$total_similarity, 3)
    expect_equal(alignment$global_assignment_margin, 2)
})

test_that("component alignment exposes ambiguity instead of matching greedily", {
    reference <- diag(2)
    replicate <- matrix(
        c(cos(pi / 4), sin(pi / 4), cos(pi / 4), -sin(pi / 4)),
        nrow = 2
    )

    alignment <- landscapeR:::.match_component_loadings(
        reference,
        replicate
    )

    expect_equal(alignment$similarity, matrix(sqrt(0.5), 2, 2))
    expect_equal(alignment$assignment$assignment_margin, c(0, 0))
    expect_equal(alignment$global_assignment_margin, 0)
    expect_length(alignment$competing_assignments, 2)
})

test_that("component alignment retains missing matches", {
    reference <- diag(3)
    replicate <- reference[, 1:2, drop = FALSE]

    alignment <- landscapeR:::.match_component_loadings(
        reference,
        replicate
    )

    expect_identical(alignment$assignment$reference_component, 1:3)
    expect_equal(sum(alignment$assignment$matched), 2)
    expect_true(is.na(alignment$assignment$replicate_component[[3L]]))
    expect_true(is.na(alignment$assignment$absolute_similarity[[3L]]))
})

test_that("principal angles distinguish an axis from its stable plane", {
    reference <- diag(3)
    rotated <- cbind(
        c(sqrt(0.5), sqrt(0.5), 0),
        c(-sqrt(0.5), sqrt(0.5), 0),
        c(0, 0, 1)
    )

    axis_angle <- landscapeR:::.principal_angles(
        reference[, 1, drop = FALSE],
        rotated[, 1, drop = FALSE]
    )
    plane_angles <- landscapeR:::.principal_angles(
        reference[, 1:2, drop = FALSE],
        rotated[, 1:2, drop = FALSE]
    )

    expect_equal(axis_angle, pi / 4)
    expect_equal(plane_angles, c(0, 0), tolerance = 1e-12)
})

test_that("decomposition strategies declare their alignment geometry", {
    expect_identical(
        component_loading_geometry(new("SvdDecomposer")),
        "feature-loading-cosine"
    )
    expect_identical(
        component_loading_geometry(new("HogsvdAveraged")),
        "feature-loading-cosine"
    )
    expect_identical(
        component_loading_geometry(new("HogsvdPrereduced")),
        "feature-loading-cosine"
    )
})

.axis_identifiability_fixture <- function() {
    n <- 12L
    primary <- sprintf("sample_%02d", seq_len(n))
    assay_ids <- sprintf("rna_%02d", seq_len(n))
    condition <- factor(
        rep(c("control", "treatment"), each = n / 2L),
        levels = c("control", "treatment")
    )
    signal <- ifelse(condition == "treatment", 2, -2)
    expression <- rbind(
        gene_1 = signal + rep(c(-0.2, 0, 0.2), length.out = n),
        gene_2 = rep(c(-1, 1), length.out = n),
        gene_3 = seq(-0.5, 0.5, length.out = n),
        gene_4 = rep(c(-0.3, 0.1, 0.2), length.out = n),
        gene_5 = rep(c(0.2, -0.1), length.out = n),
        gene_6 = seq(0.3, -0.3, length.out = n)
    )
    colnames(expression) <- assay_ids
    se <- SummarizedExperiment::SummarizedExperiment(
        assays = list(logcounts = expression)
    )
    std <- StateTransitionData(
        experiments = list(rna = se),
        colData = S4Vectors::DataFrame(
            condition = condition,
            sample_id = primary,
            row.names = primary
        ),
        sampleMap = S4Vectors::DataFrame(
            assay = factor(rep("rna", n), levels = "rna"),
            primary = primary,
            colname = assay_ids
        )
    )
    std <- declare_sampling_design(std, cross_sectional())
    specification <- analysis_specification(
        id = "axis-identifiability-fixture",
        target_field = "condition",
        target_type = "binary",
        reference_level = "control",
        comparison_level = "treatment"
    )
    config <- new(
        "PipelineConfig",
        strategies = list(Decomposer = "svd"),
        params = list(svd = list(center = TRUE, k_components = 3L)),
        dataset = "axis-identifiability-fixture",
        analysis = specification
    )
    decomposition <- decompose(
        get_strategy("Decomposer", "svd")(config@params$svd),
        std
    )
    expect_identical(decomposition@status, "success")
    discovery <- decomposition@value
    atlas <- associate_metadata(
        discovery,
        specification = specification,
        non_analytical_fields = "sample_id",
        dataset_id = config@dataset
    )
    list(
        source = std,
        discovery = discovery,
        config = config,
        proposal = propose_component(atlas)
    )
}

test_that("identifiability assessment repeats the complete discovery search", {
    fixture <- .axis_identifiability_fixture()

    assessed <- assess_component_identifiability(
        data = fixture$source,
        proposal = fixture$proposal,
        config = fixture$config,
        non_analytical_fields = "sample_id",
        n_resamples = 7L,
        seed = 8301L
    )
    evidence <- proposal_identifiability(assessed)

    expect_s4_class(assessed, "ComponentProposal")
    expect_identical(evidence$version, "1.0.0")
    expect_identical(evidence$status, "estimable-exploratory-only")
    expect_identical(evidence$n_requested, 7L)
    expect_identical(evidence$n_completed, 7L)
    expect_length(evidence$replicates, 7L)
    expect_true(all(vapply(
        evidence$replicates,
        function(x) {
            is.matrix(x$similarity) &&
                nrow(x$ranking) == 3L &&
                identical(x$decomposition_status, "success") &&
                identical(x$association_status, "success") &&
                identical(x$proposal_status, "proposal")
        },
        logical(1L)
    )))
    expect_identical(
        evidence$resampling$unit,
        "independent-biological-observation"
    )
    expect_identical(
        evidence$resampling$method,
        "target-stratified-biological-unit-bootstrap"
    )
    expect_length(evidence$resampling$draws, 7L)
    expect_true(all(vapply(
        evidence$resampling$draws,
        function(x) length(x$source_primary) == 12L,
        logical(1L)
    )))
    expect_equal(nrow(evidence$recurrence), 21L)
    expect_equal(nrow(evidence$recurrence_summary), 3L)
    expect_true(all(c(
        "reference_component", "replicate_component",
        "absolute_similarity", "assignment_margin",
        "proposal_rank", "rank_one"
    ) %in% names(evidence$recurrence)))
    expect_true(all(c(
        "matched_fraction", "mean_absolute_similarity",
        "index_recurrence", "rank_one_fraction"
    ) %in% names(evidence$recurrence_summary)))
    expect_identical(
        evidence$target_recurrence$reference_component,
        fixture$proposal@recommended_component
    )
    expect_identical(
        evidence$failure_summary$failure_fraction,
        0
    )
    surface <- plot_component_identifiability(assessed)
    expect_s3_class(surface, "ggplot")
    expect_setequal(
        unique(surface$data$surface),
        c(
            "Spectrum", "Matching similarity", "Assignment margin",
            "Axis recurrence", "Subspace angle", "Replicate completion"
        )
    )
    expect_false(any(grepl(
        "human",
        c(surface$labels$title, surface$labels$subtitle),
        ignore.case = TRUE
    )))
    expect_true(grepl("^[[:xdigit:]]{64}$", evidence$digest))
    expect_identical(
        proposal_identifiability(unserialize(serialize(assessed, NULL))),
        evidence
    )
})
