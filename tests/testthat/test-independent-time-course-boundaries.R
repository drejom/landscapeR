test_that("nuisance-aware time permutation uses reduced-model residuals", {
    atlas <- associate_metadata(
        independent_time_course_fixture(),
        specification = independent_time_course_specification("batch"),
        non_analytical_fields = "sample_id"
    )
    first <- propose_component(atlas, n_permutations = 9L, seed = 8110L)
    second <- propose_component(atlas, n_permutations = 9L, seed = 8110L)
    evidence <- proposal_permutation_evidence(first)

    expect_s4_class(first, "ComponentProposal")
    expect_identical(evidence@status, "complete")
    expect_identical(
        evidence@method,
        "within-time-reduced-model-residual-permutation"
    )
    expect_identical(
        evidence@null_max_effect,
        proposal_permutation_evidence(second)@null_max_effect
    )
    expect_identical(evidence@n_completed, 9L)
    expect_true(nzchar(evidence@design_digest))
})

test_that("collapsed bootstrap designs remain in the failure fraction", {
    std <- independent_time_course_fixture()
    batch <- factor(
        rep("A", nrow(colData(std))),
        levels = c("A", "B")
    )
    batch[[1L]] <- "B"
    colData(std)$batch <- batch
    atlas <- associate_metadata(
        std,
        specification = independent_time_course_specification("batch"),
        non_analytical_fields = "sample_id",
        n_resamples = 39L,
        seed = 8111L
    )
    adjusted <- atlas_associations(atlas)
    adjusted <- adjusted[
        adjusted$evidence_variant == "time-course-adjusted",
        ,
        drop = FALSE
    ]

    expect_identical(adjusted$n_resamples, rep(39L, 2L))
    expect_true(all(adjusted$resample_failures > 0L))
    expect_true(all(
        adjusted$resample_failures <= adjusted$n_resamples
    ))
})

test_that("time model records standardized orientation and engine controls", {
    atlas <- associate_metadata(
        independent_time_course_fixture(include_nuisance = FALSE),
        specification = independent_time_course_specification(),
        non_analytical_fields = "sample_id"
    )
    models <- atlas_provenance(atlas)$time_course_models

    expect_length(models, 2L)
    for (model in models) {
        scores <- model$unadjusted$standardized_scores
        expect_equal(mean(scores), 0, tolerance = 1e-12)
        expect_equal(stats::sd(scores), 1, tolerance = 1e-12)
        expect_true(model$orientation_multiplier %in% c(-1, 1))
        expect_gt(model$unadjusted$design_rank, 0L)
        expect_gt(model$unadjusted$residual_df, 0L)
    }
    provenance <- atlas_provenance(atlas)
    expect_identical(provenance$model_engine, "stats::lm")
    expect_identical(provenance$model_na_action, "stats::na.fail")
    expect_true(nzchar(provenance$model_engine_version))
    expect_true(nzchar(provenance$model_formula_digest))
    expect_identical(
        provenance$model_contrasts$target,
        "contr.treatment(2, base = 1)"
    )
})

test_that("time interaction is invariant to global contrast options", {
    std <- independent_time_course_fixture()
    specification <- independent_time_course_specification("batch")
    original <- options("contrasts")
    on.exit(options(original), add = TRUE)

    treatment_atlas <- associate_metadata(
        std,
        specification = specification,
        non_analytical_fields = "sample_id"
    )
    options(contrasts = c("contr.sum", "contr.poly"))
    sum_atlas <- associate_metadata(
        std,
        specification = specification,
        non_analytical_fields = "sample_id"
    )

    expect_identical(
        atlas_associations(treatment_atlas)$estimate,
        atlas_associations(sum_atlas)$estimate
    )
    expect_identical(
        atlas_provenance(treatment_atlas)$time_course_display_lines,
        atlas_provenance(sum_atlas)$time_course_display_lines
    )
})

test_that("adjusted proposals display adjusted trajectory evidence", {
    atlas <- associate_metadata(
        independent_time_course_fixture(),
        specification = independent_time_course_specification("batch"),
        non_analytical_fields = "sample_id"
    )

    expect_identical(
        atlas_provenance(atlas)$display_trajectory_variant,
        "time-course-adjusted"
    )
    expect_s3_class(plot(propose_component(atlas)), "ggplot")
})

test_that("bootstrap refits preserve the observed orientation", {
    atlas <- associate_metadata(
        independent_time_course_fixture(include_nuisance = FALSE),
        specification = independent_time_course_specification(),
        non_analytical_fields = "sample_id",
        n_resamples = 39L,
        seed = 8112L
    )
    model <- atlas_provenance(atlas)$time_course_models[[1L]]
    bootstrap <- model$unadjusted_uncertainty$bootstrap_estimates
    bootstrap <- bootstrap[is.finite(bootstrap) & bootstrap != 0]

    expect_true(length(bootstrap) > 0L)
    expect_true(model$orientation_multiplier %in% c(-1, 1))
    expect_true(all(sign(bootstrap) == sign(model$unadjusted$estimate)))
})

test_that("numerically difficult designs return evidence rather than errors", {
    std <- independent_time_course_fixture()
    colData(std)$almost_time <- colData(std)$day +
        seq_len(nrow(colData(std))) * 1e-14

    expect_no_error(
        atlas <- associate_metadata(
            std,
            specification = independent_time_course_specification(
                "almost_time"
            ),
            non_analytical_fields = c("sample_id", "batch")
        )
    )
    evidence <- atlas_associations(atlas)
    diagnostics <- evidence$diagnostic[evidence$proposal_eligible]
    expect_true(all(
        diagnostics == "" |
            grepl("^non-identifiable-design:", diagnostics)
    ))
})

test_that("missing time cells remain explicit in stored and plotted evidence", {
    cell_sizes <- matrix(
        c(4L, 4L, 0L, 0L, 4L, 4L),
        nrow = 2L,
        byrow = TRUE,
        dimnames = list(c("control", "treatment"), c("0", "1", "2"))
    )
    atlas <- associate_metadata(
        independent_time_course_fixture(
            cell_sizes = cell_sizes,
            include_nuisance = FALSE
        ),
        specification = independent_time_course_specification(),
        non_analytical_fields = "sample_id"
    )
    cells <- atlas_provenance(atlas)$time_course_cells
    plot <- plot(atlas)

    expect_identical(sum(cells$count == 0L), 2L)
    expect_s3_class(plot, "ggplot")
    expect_true(any(vapply(
        plot$layers,
        function(layer) inherits(layer$geom, "GeomText"),
        logical(1L)
    )))
    expect_true(any(vapply(
        plot$layers,
        function(layer) inherits(layer$geom, "GeomPoint"),
        logical(1L)
    )))
})

test_that("repeated observations are never treated as destructive samples", {
    std <- independent_time_course_fixture(include_nuisance = FALSE)
    std@sampling_design <- longitudinal("sample_id", "day", "days")

    expect_error(
        associate_metadata(
            std,
            specification = independent_time_course_specification(),
            non_analytical_fields = "sample_id"
        ),
        "must be declared with independent_time_course",
        class = "landscapeR_validation_error"
    )
})

test_that("non-binary destructive-time targets return typed abstention", {
    std <- independent_time_course_fixture(include_nuisance = FALSE)
    colData(std)$state <- ordered(
        rep(c("early", "middle", "late"), each = 8L),
        levels = c("early", "middle", "late")
    )
    specification <- analysis_specification(
        id = "unsupported-ordered-time-course",
        target_field = "state",
        target_type = "ordered",
        ordered_levels = c("early", "middle", "late")
    )
    abstention <- associate_metadata(
        std,
        specification = specification,
        non_analytical_fields = "sample_id"
    )

    expect_s4_class(abstention, "AssociationAbstention")
    expect_match(
        association_abstention_diagnostic(abstention),
        "must be declared binary"
    )
    expect_error(
        confirm_component(
            abstention,
            1L,
            "accept",
            "Unsupported target types cannot be substituted."
        ),
        "cannot confirm an abstention",
        class = "landscapeR_validation_error"
    )
})
