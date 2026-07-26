test_that("independent time course fits the declared standardized interaction", {
    atlas <- associate_metadata(
        independent_time_course_fixture(),
        specification = independent_time_course_specification("batch"),
        non_analytical_fields = "sample_id",
        n_resamples = 19L,
        seed = 8101L
    )

    expect_s4_class(atlas, "MetadataAssociationAtlas")
    expect_identical(atlas@sampling_design@kind, "independent_time_course")
    expect_identical(
        atlas_provenance(atlas)$association_strategy,
        "independent-time-course-linear-v1"
    )
    expect_identical(atlas_provenance(atlas)$time_field, "day")
    expect_equal(atlas_provenance(atlas)$time_range, c(0, 2))
    expect_equal(range(atlas_provenance(atlas)$scaled_time), c(0, 1))
    expect_identical(
        atlas_provenance(atlas)$time_transform,
        "(time - min(time)) / (max(time) - min(time))"
    )
    expect_identical(atlas_provenance(atlas)$model_engine, "stats::lm")
    expect_match(
        atlas_provenance(atlas)$scientific_model_formula_adjusted,
        "condition \\* scaled_time"
    )

    condition <- atlas_associations(atlas)
    condition <- condition[
        condition$metadata_field == "condition",
        ,
        drop = FALSE
    ]
    expect_setequal(
        unique(condition$evidence_variant),
        c(
            "pooled-descriptive",
            "time-course-unadjusted",
            "time-course-adjusted"
        )
    )
    expect_false(any(condition$proposal_eligible[
        condition$evidence_variant == "pooled-descriptive"
    ]))
    expect_true(all(condition$proposal_eligible[
        condition$evidence_variant != "pooled-descriptive"
    ]))
    adjusted <- condition[
        condition$evidence_variant == "time-course-adjusted",
        ,
        drop = FALSE
    ]
    expect_identical(
        adjusted$estimand,
        rep("standardized-condition-time-interaction", 2L)
    )
    expect_gt(abs(adjusted$estimate[adjusted$component == 1L]), 1)
    expect_lt(abs(adjusted$estimate[adjusted$component == 2L]), 1e-8)
    expect_identical(
        adjusted$resampling_method,
        rep("condition-time-cell-bootstrap", 2L)
    )
    expect_identical(adjusted$n_resamples, rep(19L, 2L))
    expect_true(all(nzchar(adjusted$cohort_digest)))
    expect_true(all(nzchar(adjusted$design_digest)))
    expect_true(all(nzchar(adjusted$resampling_plan_digest)))
    expect_s3_class(plot(atlas), "ggplot")
})

test_that("time-course proposal and confirmation use only the primary effect", {
    atlas <- associate_metadata(
        independent_time_course_fixture(),
        specification = independent_time_course_specification("batch"),
        non_analytical_fields = "sample_id",
        n_resamples = 9L,
        seed = 8102L
    )
    proposal <- propose_component(atlas)

    expect_s4_class(proposal, "ComponentProposal")
    expect_identical(proposal@recommended_component, 1L)
    expect_identical(
        unique(proposal_ranking(proposal)$evidence_variant),
        "time-course-adjusted"
    )
    expect_s3_class(plot(proposal), "ggplot")
    confirmed <- confirm_component(
        proposal,
        index = 1L,
        decision = "accept",
        rationale = "The planted destructive-time interaction is recovered."
    )
    expect_identical(confirmed@selected_component, 1L)
    expect_identical(confirmed@proposal_decision, "accepted")
    restored <- unserialize(serialize(atlas, NULL))
    expect_identical(atlas_digest(restored), atlas_digest(atlas))
})

test_that("time-course resampling is deterministic and preserves design cells", {
    first <- associate_metadata(
        independent_time_course_fixture(),
        specification = independent_time_course_specification(),
        non_analytical_fields = c("sample_id", "batch"),
        n_resamples = 13L,
        seed = 8103L
    )
    second <- associate_metadata(
        independent_time_course_fixture(),
        specification = independent_time_course_specification(),
        non_analytical_fields = c("sample_id", "batch"),
        n_resamples = 13L,
        seed = 8103L
    )

    expect_identical(atlas_associations(first), atlas_associations(second))
    plan <- atlas_provenance(first)$resampling_plan
    expect_identical(plan$method, "condition-time-cell-bootstrap")
    expect_identical(unname(plan$cell_counts), rep(4L, 6L))
    expect_identical(plan$n_resamples, 13L)
})

test_that("invalid independent-time design retains evidence and abstains", {
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

    model_rows <- atlas_associations(atlas)
    model_rows <- model_rows[
        model_rows$proposal_eligible,
        ,
        drop = FALSE
    ]
    expect_true(all(is.na(model_rows$estimate)))
    expect_true(all(grepl(
        "insufficient-overlapping-times",
        model_rows$diagnostic
    )))
    abstention <- propose_component(atlas)
    expect_s4_class(abstention, "ComponentAbstention")
    expect_identical(abstention@reason, "non-identifiable-design")
    expect_s3_class(plot(abstention), "ggplot")
    expect_error(
        confirm_component(
            abstention,
            1L,
            "accept",
            "No design fallback is permitted."
        ),
        "cannot confirm an abstention",
        class = "landscapeR_validation_error"
    )
})

test_that("time-course permutation respects declared exchangeability", {
    atlas <- associate_metadata(
        independent_time_course_fixture(include_nuisance = FALSE),
        specification = independent_time_course_specification(),
        non_analytical_fields = "sample_id",
        exchangeability = "not_identifiable"
    )
    abstention <- propose_component(
        atlas,
        n_permutations = 9L,
        seed = 8104L
    )

    expect_s4_class(abstention, "ComponentAbstention")
    expect_identical(abstention@reason, "permutation-not-identifiable")
    expect_identical(
        abstention_permutation_evidence(abstention)@diagnostic,
        "exchangeability-not-identifiable"
    )
})

test_that("no planted trajectory interaction remains near zero", {
    std <- independent_time_course_fixture(include_nuisance = FALSE)
    md <- metadata(std)
    common_time <- colData(std)$day
    md$stage1@coords_k[[1L]] <- cbind(
        PC1 = common_time + rep(c(-0.1, 0.1), length.out = length(common_time)),
        PC2 = 2 * common_time +
            rep(c(-0.1, 0.1), length.out = length(common_time))
    )
    metadata(std) <- md

    atlas <- associate_metadata(
        std,
        specification = independent_time_course_specification(),
        non_analytical_fields = "sample_id"
    )
    effects <- atlas_associations(atlas)
    effects <- effects[
        effects$evidence_variant == "time-course-unadjusted",
        ,
        drop = FALSE
    ]

    expect_true(all(abs(effects$estimate) < 1e-8))
})

test_that("unequal replicated cells remain eligible", {
    cell_sizes <- matrix(
        c(2L, 3L, 5L, 4L, 2L, 3L),
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
        non_analytical_fields = "sample_id",
        n_resamples = 7L,
        seed = 8105L
    )
    effects <- atlas_associations(atlas)
    effects <- effects[
        effects$evidence_variant == "time-course-unadjusted",
        ,
        drop = FALSE
    ]

    expect_true(all(is.finite(effects$estimate)))
    expect_identical(
        unname(atlas_provenance(atlas)$resampling_plan$cell_counts),
        c(2L, 3L, 5L, 4L, 2L, 3L)
    )
})

test_that("a singly replicated overlapping cell causes design abstention", {
    cell_sizes <- matrix(
        c(1L, 3L, 3L, 3L, 3L, 3L),
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
    effects <- atlas_associations(atlas)
    effects <- effects[effects$proposal_eligible, , drop = FALSE]

    expect_true(all(grepl(
        "insufficient-independent-cell-replication",
        effects$diagnostic
    )))
    expect_s4_class(propose_component(atlas), "ComponentAbstention")
})

test_that("missing required nuisance values define one visible common cohort", {
    std <- independent_time_course_fixture()
    colData(std)$batch[[1L]] <- NA
    atlas <- associate_metadata(
        std,
        specification = independent_time_course_specification("batch"),
        non_analytical_fields = "sample_id"
    )
    effects <- atlas_associations(atlas)
    unadjusted <- effects[
        effects$evidence_variant == "time-course-unadjusted",
        ,
        drop = FALSE
    ]
    adjusted <- effects[
        effects$evidence_variant == "time-course-adjusted",
        ,
        drop = FALSE
    ]

    expect_true(all(is.finite(unadjusted$estimate)))
    expect_true(all(is.finite(adjusted$estimate)))
    expected_cohort <- rownames(colData(std))[-1L]
    expect_identical(
        atlas_provenance(atlas)$analysis_cohort,
        expected_cohort
    )
    expect_identical(
        atlas_provenance(atlas)$analysis_cohort_exclusions,
        rownames(colData(std))[[1L]]
    )
    expect_true(all(unadjusted$n_available == length(expected_cohort)))
    expect_identical(
        unique(unadjusted$cohort_digest),
        unique(adjusted$cohort_digest)
    )
    expect_s4_class(propose_component(atlas), "ComponentProposal")
})

test_that("an empty complete-case cohort returns typed abstention", {
    std <- independent_time_course_fixture()
    colData(std)$batch[] <- NA

    abstention <- associate_metadata(
        std,
        specification = independent_time_course_specification("batch"),
        non_analytical_fields = "sample_id"
    )

    expect_s4_class(abstention, "AssociationAbstention")
    expect_match(
        association_abstention_diagnostic(abstention),
        "non-identifiable-design: no complete cases"
    )
    expect_error(
        confirm_component(
            abstention,
            1L,
            "accept",
            "An empty cohort cannot be confirmed."
        ),
        "cannot confirm an abstention",
        class = "landscapeR_validation_error"
    )
})

test_that("target-confounded nuisance design preserves raw model evidence", {
    std <- independent_time_course_fixture()
    colData(std)$confounded <- colData(std)$condition
    specification <- independent_time_course_specification("confounded")
    atlas <- associate_metadata(
        std,
        specification = specification,
        non_analytical_fields = c("sample_id", "batch")
    )
    effects <- atlas_associations(atlas)
    unadjusted <- effects[
        effects$evidence_variant == "time-course-unadjusted",
        ,
        drop = FALSE
    ]
    adjusted <- effects[
        effects$evidence_variant == "time-course-adjusted",
        ,
        drop = FALSE
    ]

    expect_true(all(is.finite(unadjusted$estimate)))
    expect_true(all(is.na(adjusted$estimate)))
    expect_true(all(grepl(
        "rank-deficient-fixed-effect-design",
        adjusted$diagnostic
    )))
    expect_s4_class(propose_component(atlas), "ComponentAbstention")
})

test_that("non-positive residual degrees of freedom is a structural failure", {
    cell_sizes <- matrix(
        2L,
        nrow = 2L,
        ncol = 3L,
        dimnames = list(c("control", "treatment"), c("0", "1", "2"))
    )
    std <- independent_time_course_fixture(
        cell_sizes = cell_sizes,
        include_nuisance = FALSE
    )
    target <- factor(colData(std)$condition)
    time <- colData(std)$day / max(colData(std)$day)
    base <- stats::model.matrix(~ target * time)
    complement <- qr.Q(qr(base), complete = TRUE)[, 5:12, drop = FALSE]
    nuisance_fields <- paste0("z", seq_len(ncol(complement)))
    for (j in seq_along(nuisance_fields)) {
        colData(std)[[nuisance_fields[[j]]]] <- complement[, j]
    }
    atlas <- associate_metadata(
        std,
        specification = independent_time_course_specification(
            nuisance_fields
        ),
        non_analytical_fields = "sample_id"
    )
    adjusted <- atlas_associations(atlas)
    adjusted <- adjusted[
        adjusted$evidence_variant == "time-course-adjusted",
        ,
        drop = FALSE
    ]

    expect_true(all(grepl(
        "non-positive-residual-degrees-of-freedom",
        adjusted$diagnostic
    )))
})

test_that("within-time permutation repeats the complete component search", {
    atlas <- associate_metadata(
        independent_time_course_fixture(include_nuisance = FALSE),
        specification = independent_time_course_specification(),
        non_analytical_fields = "sample_id"
    )
    first <- propose_component(atlas, n_permutations = 11L, seed = 8106L)
    second <- propose_component(atlas, n_permutations = 11L, seed = 8106L)
    evidence <- proposal_permutation_evidence(first)

    expect_s4_class(first, "ComponentProposal")
    expect_identical(evidence@status, "complete")
    expect_identical(evidence@method, "within-time-label-permutation")
    expect_identical(evidence@n_completed, 11L)
    expect_identical(
        evidence@null_max_effect,
        proposal_permutation_evidence(second)@null_max_effect
    )
    expect_length(evidence@null_max_effect, 11L)
    expect_true(is.finite(evidence@search_aware_p_value))
})
