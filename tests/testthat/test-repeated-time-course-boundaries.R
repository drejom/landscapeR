test_that("adjusted bootstrap rankings use the adjusted model family", {
    atlas <- associate_metadata(
        repeated_time_course_fixture(),
        specification = repeated_time_course_specification("batch"),
        non_analytical_fields = "mouse_id",
        n_resamples = 4L,
        seed = 8210L
    )
    provenance <- atlas_provenance(atlas)
    rankings <- provenance$time_course_resample_rankings
    adjusted <- vapply(provenance$time_course_models, function(record) {
        record$adjusted_uncertainty$bootstrap_estimates
    }, numeric(4L))

    expect_equal(
        matrix(
            rankings$estimate,
            nrow = 4L,
            ncol = 2L,
            byrow = TRUE
        ),
        adjusted
    )
    expect_identical(
        provenance$primary_evidence_variant,
        "repeated-time-course-adjusted"
    )
})

test_that("missing nuisance values exclude the complete subject trajectory", {
    std <- repeated_time_course_fixture()
    first_subject <- colData(std)$mouse_id[[1L]]
    colData(std)$batch[[1L]] <- NA
    atlas <- associate_metadata(
        std,
        specification = repeated_time_course_specification("batch"),
        non_analytical_fields = "mouse_id"
    )
    provenance <- atlas_provenance(atlas)

    expect_false(first_subject %in%
        provenance$time_course_observations$subject)
    expect_identical(provenance$time_range, c(0, 3))
    expect_true(all(
        rownames(colData(std))[colData(std)$mouse_id == first_subject] %in%
            provenance$analysis_cohort_exclusions
    ))
    expect_true(all(table(
        provenance$time_course_observations$subject
    ) == 4L))
})

test_that("confounded nuisance adjustment abstains without weakening the model", {
    std <- repeated_time_course_fixture()
    colData(std)$confounded <- colData(std)$condition
    atlas <- associate_metadata(
        std,
        specification = repeated_time_course_specification("confounded"),
        non_analytical_fields = c("mouse_id", "batch")
    )
    effects <- atlas_associations(atlas)
    unadjusted <- effects[
        effects$evidence_variant == "repeated-time-course-unadjusted",
        ,
        drop = FALSE
    ]
    adjusted <- effects[
        effects$evidence_variant == "repeated-time-course-adjusted",
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
    expect_false(grepl(
        "\\|\\||\\(1 \\| subject\\)",
        atlas_provenance(atlas)$scientific_model_formula_adjusted
    ))
})

test_that("subject bootstrap preserves whole trajectories within condition", {
    atlas <- associate_metadata(
        repeated_time_course_fixture(),
        specification = repeated_time_course_specification(),
        non_analytical_fields = c("mouse_id", "batch"),
        n_resamples = 5L,
        seed = 8211L
    )
    provenance <- atlas_provenance(atlas)
    plan <- provenance$resampling_plan
    trajectory <- provenance$time_course_observations
    source_condition <- stats::setNames(
        provenance$subject_condition_assignment$condition,
        provenance$subject_condition_assignment$subject
    )

    for (i in seq_along(plan$indices)) {
        source <- plan$source_subject_ids[[i]]
        fresh <- plan$replicate_subject_ids[[i]]
        index <- plan$indices[[i]]
        expect_identical(length(unique(fresh)), length(source))
        expect_identical(length(index), nrow(trajectory))
        fresh_rows <- split(seq_along(fresh), fresh)
        expect_true(all(vapply(fresh_rows, function(rows) {
            length(unique(source_condition[
                trajectory$subject[index[rows]]
            ])) == 1L
        }, logical(1L))))
        expect_true(all(vapply(fresh_rows, function(rows) {
            source_id <- unique(trajectory$subject[index[rows]])
            identical(
                sort(trajectory$observed_time[index[rows]]),
                sort(trajectory$observed_time[
                    trajectory$subject == source_id
                ])
            )
        }, logical(1L))))
    }
})

test_that("failed bootstrap fits remain in the requested denominator", {
    atlas <- associate_metadata(
        repeated_time_course_fixture(subjects_per_condition = 3L),
        specification = repeated_time_course_specification(),
        non_analytical_fields = c("mouse_id", "batch"),
        n_resamples = 15L,
        seed = 8212L
    )
    effects <- atlas_associations(atlas)
    effects <- effects[
        effects$evidence_variant == "repeated-time-course-unadjusted",
        ,
        drop = FALSE
    ]
    summary <- atlas_provenance(atlas)$time_course_rank_summary

    expect_identical(effects$n_resamples, rep(15L, 2L))
    expect_true(all(effects$resample_failures >= 0L))
    expect_true(all(
        effects$resample_failures +
            vapply(
                atlas_provenance(atlas)$time_course_models,
                function(record) {
                    sum(is.finite(
                        record$unadjusted_uncertainty$bootstrap_estimates
                    ))
                },
                integer(1L)
            ) == 15L
    ))
    expect_identical(summary$n_resamples, rep(15L, 2L))
})

test_that("all failed null refits retain the requested denominator", {
    atlas <- associate_metadata(
        repeated_time_course_fixture(),
        specification = repeated_time_course_specification(),
        non_analytical_fields = c("mouse_id", "batch")
    )
    testthat::local_mocked_bindings(
        .landscapeR_lmer = function(...) {
            stop("planted null-refit failure")
        },
        .package = "landscapeR"
    )
    abstention <- propose_component(
        atlas,
        n_permutations = 5L,
        seed = 8217L
    )
    evidence <- abstention@permutation_evidence

    expect_identical(evidence@status, "not-identifiable")
    expect_identical(evidence@n_requested, 5L)
    expect_identical(evidence@n_completed, 0L)
    expect_length(evidence@null_max_effect, 5L)
    expect_true(all(is.na(evidence@null_max_effect)))
})

test_that("invalid exchangeability yields typed permutation abstention", {
    atlas <- associate_metadata(
        repeated_time_course_fixture(),
        specification = repeated_time_course_specification(),
        non_analytical_fields = c("mouse_id", "batch"),
        exchangeability = "not_identifiable"
    )
    abstention <- propose_component(
        atlas,
        n_permutations = 3L,
        seed = 8213L
    )

    expect_s4_class(abstention, "ComponentAbstention")
    expect_identical(abstention@reason, "permutation-not-identifiable")
    expect_identical(
        abstention@permutation_evidence@diagnostic,
        "exchangeability-not-identifiable"
    )
})

test_that("insufficient subject permutations are not fabricated", {
    atlas <- associate_metadata(
        repeated_time_course_fixture(subjects_per_condition = 3L),
        specification = repeated_time_course_specification(),
        non_analytical_fields = c("mouse_id", "batch")
    )
    abstention <- propose_component(
        atlas,
        n_permutations = 25L,
        seed = 8214L
    )

    expect_s4_class(abstention, "ComponentAbstention")
    expect_identical(abstention@reason, "insufficient-resampling-support")
    expect_identical(
        abstention@permutation_evidence@diagnostic,
        "insufficient-subject-level-rearrangements"
    )
})

test_that("repeated-model provenance freezes the complete scientific contract", {
    atlas <- associate_metadata(
        repeated_time_course_fixture(),
        specification = repeated_time_course_specification("batch"),
        non_analytical_fields = "mouse_id",
        n_resamples = 2L,
        seed = 8215L
    )
    provenance <- atlas_provenance(atlas)

    expect_match(
        provenance$scientific_model_formula_adjusted,
        "condition \\* scaled_time"
    )
    expect_match(
        provenance$scientific_model_formula_adjusted,
        "\\(1 \\+ scaled_time \\| subject\\)"
    )
    expect_false(grepl("\\|\\|", provenance$scientific_model_formula_adjusted))
    expect_true(grepl(
        "^[[:xdigit:]]{64}$",
        provenance$model_formula_digest
    ))
    expect_identical(
        provenance$model_contrasts$target,
        "contr.treatment(2, base = 1)"
    )
    expect_identical(
        nrow(provenance$subject_condition_assignment),
        length(unique(provenance$time_course_observations$subject))
    )
    standardization <- provenance$component_standardization
    raw_scores <- metadata(
        repeated_time_course_fixture()
    )$stage1@coords_k[[1L]]
    expect_identical(
        standardization$method,
        rep("sample-mean-and-sample-SD", 2L)
    )
    expect_equal(standardization$centre, unname(colMeans(raw_scores)))
    expect_equal(
        standardization$scale,
        unname(apply(raw_scores, 2L, stats::sd))
    )
})

test_that("dropout denotes an early endpoint rather than fewer visits", {
    std <- repeated_time_course_fixture(irregular = TRUE)
    subject <- colData(std)$mouse_id[[1L]]
    rows <- which(colData(std)$mouse_id == subject)
    colData(std)$day[rows[[length(rows)]]] <- 2
    atlas <- associate_metadata(
        std,
        specification = repeated_time_course_specification(),
        non_analytical_fields = c("mouse_id", "batch")
    )
    trajectory <- atlas_provenance(atlas)$time_course_observations

    expect_true(all(trajectory$dropout[trajectory$subject == subject]))
    expect_true(all(table(trajectory$subject) == 4L))
})

test_that("permutation evidence preserves its readable v1 schema", {
    legacy <- new(
        "PermutationEvidence",
        version = "1.0.0",
        method = "label-permutation",
        status = "complete",
        n_requested = 1L,
        n_completed = 1L,
        observed_max_effect = 1,
        null_max_effect = 0.5,
        search_aware_p_value = 1,
        seed = 1L,
        cohort_digest = paste(rep("a", 64L), collapse = ""),
        design_digest = NA_character_,
        diagnostic = ""
    )

    expect_true(validObject(legacy))
    expect_identical(
        readRDS(local({
            path <- tempfile(fileext = ".rds")
            saveRDS(legacy, path)
            path
        }))@version,
        "1.0.0"
    )
})

test_that("longitudinal constructor uses typed validation errors", {
    expect_error(
        longitudinal(character(), "day"),
        "subject_id must be",
        class = "landscapeR_validation_error"
    )
    expect_error(
        longitudinal("mouse_id", "mouse_id"),
        "must be distinct",
        class = "landscapeR_validation_error"
    )
    expect_error(
        longitudinal("mouse_id", "day", c("days", "weeks")),
        "time_unit must be",
        class = "landscapeR_validation_error"
    )
})

test_that("repeated plots expose uncertainty dropout and model diagnostics", {
    atlas <- associate_metadata(
        repeated_time_course_fixture(dropout = c("c1", "t1")),
        specification = repeated_time_course_specification(),
        non_analytical_fields = c("mouse_id", "batch"),
        n_resamples = 3L,
        seed = 8216L
    )
    proposal <- propose_component(atlas)
    atlas_plot <- plot(atlas)
    proposal_plot <- plot(proposal)

    expect_match(atlas_plot$labels$caption, "random\\s+intercepts")
    expect_match(atlas_plot$labels$caption, "crosses mark subjects")
    expect_false(grepl(
        "singular-random-effects-covariance|non-identifiable-design",
        plot(propose_component(associate_metadata(
            repeated_time_course_fixture(slope_scale = 0),
            specification = repeated_time_course_specification(),
            non_analytical_fields = c("mouse_id", "batch")
        )))$labels$subtitle
    ))
    expect_true(any(grepl(
        "interaction",
        unname(proposal_plot$facet$params$labeller(
            data.frame(component_label = c("PC1", "PC2"))
        )$component_label)
    )))
    expect_identical(
        landscapeR:::.public_abstention_message(
            "effect-magnitude-tie",
            character()
        ),
        "The prespecified biological effects were tied"
    )
})
