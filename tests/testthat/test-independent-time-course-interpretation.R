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
    contract <- atlas_evidence_contract(atlas)
    expect_identical(contract$version, "independent-time-course-v1")
    expect_identical(contract$sampling_design, "independent_time_course")
    expect_identical(
        contract$row_counts,
        c(
            associations = 6L,
            observations = 48L,
            exclusions = 3L
        )
    )
    expect_true(all(grepl("^[[:xdigit:]]{64}$", contract$digests)))
    expect_identical(
        sort(unique(contract$cohort_members$evidence_variant)),
        sort(c(
            "pooled-descriptive",
            "time-course-unadjusted",
            "time-course-adjusted"
        ))
    )
    expect_true(validObject(atlas))
    expect_identical(atlas_provenance(atlas)$model_engine, "stats::lm")
    expect_holm_multiplicity(atlas)
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
    resample_ranking <- atlas_provenance(
        atlas
    )$time_course_resample_rankings
    rank_summary <- atlas_provenance(atlas)$time_course_rank_summary
    expect_identical(nrow(resample_ranking), 19L * 2L)
    expect_identical(
        as.integer(table(resample_ranking$resample)),
        rep(2L, 19L)
    )
    expect_true(all(vapply(
        split(resample_ranking$proposal_rank, resample_ranking$resample),
        function(ranks) identical(sort(ranks), 1:2),
        logical(1L)
    )))
    expect_identical(rank_summary$n_complete_searches, rep(19L, 2L))
    expect_equal(sum(rank_summary$rank_one_fraction), 1)
    atlas_plot <- plot(atlas)
    atlas_view <- visual_evidence(atlas)
    expect_s3_class(atlas_plot, "ggplot")
    expect_identical(
        visual_evidence_surface(atlas_view),
        "independent_time_course"
    )
    expect_true(nrow(visual_evidence_display(atlas_view, "cells")) > 0L)
    expect_null(atlas_plot$labels$caption)
    expect_match(
        gsub("\\s+", " ", scientific_caption(atlas_plot)),
        "independent biological observation"
    )
    partial_atlas <- atlas
    partial_atlas@provenance$time_course_rank_summary$n_complete_searches <-
        rep(18L, 2L)
    partial_atlas@provenance$time_course_display_state$complete_searches <-
        18L
    partial_atlas@provenance$time_course_display_state$partial_resampling <-
        TRUE
    partial_view <- visual_evidence(partial_atlas)
    expect_identical(visual_evidence_state(partial_view), "partial")
    expect_match(
        gsub("\\s+", " ", visual_evidence_caption(partial_view)),
        "18 of 19 requested complete-search resamples succeeded",
        fixed = TRUE
    )
    canonical_path <- tempfile(fileext = ".png")
    save_landscapeR_plot(
        atlas_plot,
        canonical_path,
        width_mm = 100,
        height_mm = 100,
        dpi = 72
    )
    expect_gt(file.info(canonical_path)$size, 0)
    text_layers <- vapply(
        atlas_plot$layers,
        function(layer) inherits(layer$geom, "GeomText"),
        logical(1L)
    )
    expect_true(any(text_layers))
    expect_true(all(vapply(
        atlas_plot$layers[text_layers],
        function(layer) identical(layer$show.legend, FALSE),
        logical(1L)
    )))
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

test_that("time-course resampling retains character target design cells", {
    std <- independent_time_course_fixture(include_nuisance = FALSE)
    colData(std)$condition <- as.character(colData(std)$condition)
    atlas <- associate_metadata(
        std,
        specification = independent_time_course_specification(),
        non_analytical_fields = "sample_id",
        n_resamples = 3L,
        seed = 8108L
    )

    expect_identical(
        unname(atlas_provenance(atlas)$resampling_plan$cell_counts),
        rep(4L, 6L)
    )
})

test_that("incomplete bootstrap searches cannot promote a runner-up", {
    records <- list(
        list(
            component = 1L,
            component_label = "PC1",
            unadjusted_uncertainty = list(
                bootstrap_estimates = c(2, NA_real_, 2)
            )
        ),
        list(
            component = 2L,
            component_label = "PC2",
            unadjusted_uncertainty = list(
                bootstrap_estimates = c(1, 1, 1)
            )
        )
    )
    result <- .time_course_resample_rankings(
        records,
        "time-course-unadjusted"
    )
    incomplete <- result$rankings$resample == 2L
    pc2 <- result$summary[result$summary$component == 2L, , drop = FALSE]

    expect_true(all(is.na(result$rankings$proposal_rank[incomplete])))
    expect_false(any(result$rankings$complete_search[incomplete]))
    expect_identical(pc2$n_complete_searches, 2L)
    expect_identical(pc2$rank_one_count, 0L)
    expect_identical(pc2$rank_one_fraction, 0)
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
    expect_identical(
        atlas_evidence_contract(
            unserialize(serialize(atlas, NULL))
        ),
        atlas_evidence_contract(atlas)
    )
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
    design_plot <- plot(atlas)
    expect_identical(
        design_plot$labels$title,
        "Observed destructive-time-course design"
    )
    expect_match(design_plot$labels$subtitle, "not estimable")
    expect_null(design_plot$labels$caption)
    caption <- scientific_caption(design_plot)
    expect_match(
        caption,
        "interaction is not estimable"
    )
    expect_false(grepl(
        "lines show stored population trajectories",
        tolower(caption),
        fixed = TRUE
    ))
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

test_that("complete-case exclusion does not redefine the study-time scale", {
    std <- independent_time_course_fixture()
    endpoint <- colData(std)$day == 2
    colData(std)$batch[endpoint] <- NA

    atlas <- associate_metadata(
        std,
        specification = independent_time_course_specification("batch"),
        non_analytical_fields = "sample_id",
        n_resamples = 7L,
        seed = 8107L
    )
    provenance <- atlas_provenance(atlas)
    endpoint_cells <- provenance$time_course_cells[
        provenance$time_course_cells$observed_time == 2,
        ,
        drop = FALSE
    ]

    expect_identical(provenance$time_range, c(0, 2))
    expect_equal(range(provenance$scaled_time), c(0, 0.5))
    expect_identical(endpoint_cells$count, c(0L, 0L))
    view <- visual_evidence(atlas)
    expect_setequal(
        paste(
            visual_evidence_display(view, "missing_cells")$condition,
            visual_evidence_display(view, "missing_cells")$observed_time
        ),
        paste(
            provenance$time_course_missing_cells$condition,
            provenance$time_course_missing_cells$observed_time
        )
    )
    expect_identical(provenance$time_course_missing_cell_count, 2L)
    invalid_missing_count <- atlas
    invalid_missing_count@provenance$time_course_missing_cell_count <- 3L
    expect_error(
        validObject(invalid_missing_count),
        "missing-cell evidence is invalid"
    )
    invalid_display_state <- atlas
    invalid_display_state@provenance$
        time_course_display_state$partial_resampling <- TRUE
    expect_error(
        validObject(invalid_display_state),
        "display state does not match"
    )
    expect_equal(endpoint_cells$scaled_time, c(1, 1))
    expect_equal(
        as.numeric(tapply(
            provenance$time_course_display_lines$scaled_time,
            provenance$time_course_display_lines$condition,
            max
        )),
        c(0.5, 0.5)
    )
    expect_identical(
        unname(provenance$resampling_plan$cell_counts),
        c(4L, 4L, 0L, 4L, 4L, 0L)
    )
    expect_identical(provenance$resampling_plan$policy$status, "planned")
    expect_identical(
        length(provenance$resampling_plan$policy$design$strata),
        4L
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
    expect_identical(abstention@reason, "non-identifiable-design")
    expect_identical(
        abstention@provenance$interpretation_module,
        "independent-time-course-v1"
    )
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

test_that("time-course contract rejects unrelated cohort identities", {
    atlas <- associate_metadata(
        independent_time_course_fixture(include_nuisance = FALSE),
        specification = independent_time_course_specification(),
        non_analytical_fields = c("sample_id", "batch")
    )
    altered <- atlas
    altered@provenance$evidence_contract$cohort_members$primary_sample[[1L]] <-
        "unrelated-sample"

    expect_error(
        validObject(altered),
        "cohort membership does not match association evidence"
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

test_that("within-time permutation retains partial refit failures", {
    atlas <- associate_metadata(
        independent_time_course_fixture(include_nuisance = FALSE),
        specification = independent_time_course_specification(),
        non_analytical_fields = "sample_id"
    )
    original_fit <- getFromNamespace(
        ".fit_independent_time_course",
        "landscapeR"
    )
    n_calls <- 0L
    testthat::local_mocked_bindings(
        .fit_independent_time_course = function(...) {
            n_calls <<- n_calls + 1L
            if (n_calls == 1L) {
                return(list(
                    status = "non-identifiable-design",
                    estimate = NA_real_
                ))
            }
            original_fit(...)
        },
        .package = "landscapeR"
    )

    proposal <- propose_component(atlas, n_permutations = 11L, seed = 8107L)
    evidence <- proposal_permutation_evidence(proposal)
    policy <- attr(evidence, "resampling_policy", exact = TRUE)

    expect_s4_class(proposal, "ComponentProposal")
    expect_identical(evidence@status, "partial")
    expect_identical(evidence@n_requested, 11L)
    expect_identical(evidence@n_completed, 10L)
    expect_identical(sum(is.na(evidence@null_max_effect)), 1L)
    expect_identical(policy$n_failed, 1L)
    expect_identical(policy$status, "partial")
})
