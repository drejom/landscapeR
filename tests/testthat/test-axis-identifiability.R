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

.axis_identifiability_fixture <- function(k_components = 3L) {
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
        params = list(svd = list(
            center = TRUE,
            k_components = as.integer(k_components)
        )),
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

test_that("accepted K=1 identifiability has no invented competitor axis", {
    fixture <- .axis_identifiability_fixture(k_components = 1L)

    assessed <- assess_component_identifiability(
        data = fixture$source,
        proposal = fixture$proposal,
        config = fixture$config,
        non_analytical_fields = "sample_id",
        n_resamples = 5L,
        seed = 12601L
    )
    evidence <- proposal_identifiability(assessed)

    expect_identical(evidence$status, "estimable-exploratory-only")
    expect_identical(evidence$structured_outcome, "not-calibrated")
    expect_identical(evidence$n_requested, 5L)
    expect_identical(evidence$n_completed, 5L)
    expect_identical(evidence$n_failed, 0L)
    expect_identical(evidence$nominated_component, 1L)
    expect_equal(nrow(evidence$recurrence), 5L)
    expect_equal(nrow(evidence$recurrence_summary), 1L)
    expect_identical(evidence$target_recurrence$reference_component, 1L)
    expect_equal(evidence$target_recurrence$matched_fraction, 1)
    expect_equal(evidence$target_recurrence$index_recurrence, 1)
    expect_true(all(vapply(evidence$replicates, function(replicate) {
        nrow(replicate$assignment) == 1L &&
            identical(replicate$assignment$reference_component, 1L) &&
            identical(replicate$assignment$replicate_component, 1L) &&
            identical(replicate$assignment$orientation, 1L) &&
            is.na(replicate$assignment$assignment_margin) &&
            length(replicate$competing_assignments) == 0L &&
            is.na(replicate$global_assignment_margin)
    }, logical(1L))))
    expect_identical(
        unique(evidence$subspace_angle_summary$dimension),
        1L
    )

    primary <- plot_component_identifiability(assessed)
    diagnostic <- plot_component_identifiability(
        assessed,
        view = "diagnostic"
    )
    audit <- plot_component_identifiability(assessed, view = "audit")
    expect_s3_class(primary, "ggplot")
    expect_s3_class(diagnostic, "ggplot")
    expect_s3_class(audit, "ggplot")
    expect_setequal(
        unique(primary$data$surface),
        c(
            "A  Loading agreement (larger is better)",
            "B  Subspace rotation (smaller is better)"
        )
    )
    expect_true(all(c(
        "absolute_similarity", "maximum_angle_degrees", "effect_magnitude"
    ) %in% names(diagnostic$data)))
    expect_setequal(
        unique(audit$data$surface),
        c(
            "Spectrum", "Matching similarity", "Assignment margin",
            "Individual-axis recurrence", "Index recurrence",
            "Orientation recurrence", "Proposal rank", "Subspace angle",
            "Replicate completion"
        )
    )
    primary_caption <- gsub("\\s+", " ", scientific_caption(primary))
    diagnostic_caption <- gsub(
        "\\s+",
        " ",
        scientific_caption(diagnostic)
    )
    expect_match(
        primary_caption,
        "No stability threshold was applied",
        fixed = TRUE
    )
    expect_match(
        diagnostic_caption,
        "All 5 bootstrap replicates completed the full assessment",
        fixed = TRUE
    )
    expect_match(
        primary_caption,
        "(A) Loading agreement is the distribution",
        fixed = TRUE
    )
    expect_match(
        diagnostic_caption,
        "geometric recovery and the declared biological contrast",
        fixed = TRUE
    )
    expect_match(
        gsub("\\s+", " ", scientific_caption(audit)),
        "(C) For K=1, no competing axis exists",
        fixed = TRUE
    )
    expect_match(primary_caption, "black bars span the middle 50%", fixed = TRUE)
})

test_that("sequential identifiability stays inside an outer worker", {
    previous_plan <- future::plan()
    on.exit(future::plan(previous_plan), add = TRUE)
    future::plan(future::multicore, workers = 2L)
    fixture <- .axis_identifiability_fixture(k_components = 1L)
    original <- landscapeR:::.run_identifiability_replicate
    observed_pids <- integer()
    testthat::local_mocked_bindings(
        .run_identifiability_replicate = function(...) {
            observed_pids <<- c(observed_pids, Sys.getpid())
            original(...)
        },
        .package = "landscapeR"
    )

    assessed <- assess_component_identifiability(
        data = fixture$source,
        proposal = fixture$proposal,
        config = fixture$config,
        non_analytical_fields = "sample_id",
        n_resamples = 2L,
        seed = 12611L,
        sequential_internal = TRUE
    )

    expect_identical(observed_pids, rep(Sys.getpid(), 2L))
    expect_identical(proposal_identifiability(assessed)$n_requested, 2L)
})

test_that("K=1 evidence keeps success, abstention, and failure counts coherent", {
    fixture <- .axis_identifiability_fixture(k_components = 1L)

    setClass(
        "K1OutcomeDecomposerForTest",
        contains = "Decomposer",
        representation(params = "list")
    )
    setMethod(
        "component_loading_geometry",
        "K1OutcomeDecomposerForTest",
        function(strategy) "feature-loading-cosine"
    )
    setMethod(
        ".decompose_impl",
        signature("K1OutcomeDecomposerForTest", "StateTransitionData"),
        function(strategy, data, ...) {
            replicate_index <- S4Vectors::metadata(data)$
                identifiability_resample$replicate
            if (identical(replicate_index, 3L)) {
                return(stage_failure(
                    "controlled K=1 decomposition failure"
                ))
            }
            result <- landscapeR:::.decompose_impl(
                new("SvdDecomposer", params = strategy@params),
                data
            )
            result
        }
    )
    register_strategy(
        "Decomposer",
        "_k1_outcomes_for_test",
        function(params) {
            new("K1OutcomeDecomposerForTest", params = params)
        }
    )
    fixture$config@strategies$Decomposer <- "_k1_outcomes_for_test"
    fixture$config@params$`_k1_outcomes_for_test` <- list(
        center = TRUE,
        k_components = 1L
    )

    proposal_implementation <- propose_component
    proposal_calls <- 0L
    testthat::local_mocked_bindings(
        propose_component = function(atlas, target = NULL, ...) {
            proposal_calls <<- proposal_calls + 1L
            proposal <- proposal_implementation(
                atlas,
                target = target,
                ...
            )
            if (identical(proposal_calls, 2L)) {
                return(landscapeR:::.new_component_abstention(
                    atlas = atlas,
                    target = target,
                    reason = "no-eligible-association",
                    ranking = proposal@ranking[0L, , drop = FALSE],
                    candidate_components = integer()
                ))
            }
            proposal
        },
        .package = "landscapeR"
    )

    assessed <- assess_component_identifiability(
        data = fixture$source,
        proposal = fixture$proposal,
        config = fixture$config,
        non_analytical_fields = "sample_id",
        n_resamples = 3L,
        seed = 12602L
    )
    observed <- proposal_identifiability(assessed)

    expect_identical(observed$n_requested, 3L)
    expect_identical(observed$n_completed, 1L)
    expect_identical(observed$n_failed, 2L)
    expect_identical(observed$failure_summary$n_computational_failures, 1L)
    expect_identical(observed$failure_summary$n_proposal_abstentions, 1L)
    expect_identical(observed$failure_summary$n_proposal_execution_failures, 0L)
    expect_identical(observed$failure_summary$failed_replicates, c(2L, 3L))
    expect_identical(observed$replicates[[2L]]$proposal_status, "abstention")
    expect_true(nzchar(observed$replicates[[2L]]$diagnostic))
    expect_equal(nrow(observed$replicates[[2L]]$assignment), 1L)
    expect_length(observed$replicates[[2L]]$subspace_angles$dimension, 1L)
    expect_identical(
        observed$replicates[[3L]]$diagnostic,
        "controlled K=1 decomposition failure"
    )
    expect_s3_class(plot_component_identifiability(assessed), "ggplot")
    expect_s3_class(
        plot_component_identifiability(assessed, view = "diagnostic"),
        "ggplot"
    )
    expect_match(
        gsub("\\s+", " ", scientific_caption(
            plot_component_identifiability(assessed)
        )),
        "Of 3 bootstrap replicates, 1 completed the full assessment; 2 did not",
        fixed = TRUE
    )
})

test_that("identifiability public boundaries return typed validation failures", {
    fixture <- .axis_identifiability_fixture(k_components = 1L)

    expect_error(
        assess_component_identifiability(
            data = list(),
            proposal = fixture$proposal,
            config = fixture$config,
            n_resamples = 2L
        ),
        class = "landscapeR_validation_error"
    )
    expect_error(
        assess_component_identifiability(
            data = fixture$source,
            proposal = fixture$proposal,
            config = fixture$config,
            n_resamples = 0L
        ),
        class = "landscapeR_validation_error"
    )
    expect_error(
        plot_component_identifiability(fixture$proposal),
        class = "landscapeR_validation_error"
    )
})

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
        "orientation_recurrence", "index_recurrence", "rank_one_fraction"
    ) %in% names(evidence$recurrence_summary)))
    expect_identical(
        evidence$target_recurrence$reference_component,
        fixture$proposal@recommended_component
    )
    expect_identical(
        evidence$failure_summary$failure_fraction,
        0
    )
    expect_true(all(c(
        "replicate", "dimension", "maximum_angle_degrees"
    ) %in% names(evidence$subspace_angle_summary)))
    surface <- plot_component_identifiability(assessed)
    expect_s3_class(surface, "ggplot")
    caption_text <- gsub("\\s+", " ", scientific_caption(surface))
    expect_null(surface$labels$caption)
    expect_setequal(
        unique(surface$data$surface),
        c(
            "Axis recurrence", "Matching similarity",
            "Assignment margin", "Subspace angle"
        )
    )
    expect_match(
        caption_text,
        "Red triangles denote the nominated component",
        ignore.case = TRUE
    )
    expect_match(
        caption_text,
        "from the axis-identifiability-fixture",
        fixed = TRUE
    )
    expect_match(caption_text, "using rna data", fixed = TRUE)
    expect_match(
        caption_text,
        "treatment versus control contrast",
        fixed = TRUE
    )
    expect_match(
        caption_text,
        "analysis used cross-sectional biological samples",
        fixed = TRUE
    )
    expect_match(caption_text, "(A) Axis recurrence", fixed = TRUE)
    expect_match(caption_text, "(D) The largest principal angle", fixed = TRUE)
    expect_match(
        caption_text,
        "All 7 bootstrap replicates completed the full assessment",
        fixed = TRUE
    )
    expect_match(
        caption_text,
        "stratified bootstrap of biological sampling units within target groups",
        fixed = TRUE
    )
    expect_match(
        caption_text,
        "No stability threshold was applied",
        fixed = TRUE
    )
    expect_match(
        caption_text,
        "remains exploratory and must not be interpreted as stably recovered",
        fixed = TRUE
    )
    expect_identical(surface$labels$colour, "Discovery component")
    expect_identical(surface$labels$shape, "Discovery component")
    diagnostic <- plot_component_identifiability(
        assessed,
        view = "diagnostic"
    )
    expect_s3_class(diagnostic, "ggplot")
    diagnostic_caption <- gsub(
        "\\s+",
        " ",
        scientific_caption(diagnostic)
    )
    expect_null(diagnostic$labels$caption)
    expect_setequal(
        unique(diagnostic$data$surface),
        c(
            "Spectrum", "Matching similarity", "Assignment margin",
            "Individual-axis recurrence", "Index recurrence",
            "Orientation recurrence", "Proposal rank", "Subspace angle",
            "Replicate completion"
        )
    )
    expect_match(
        diagnostic_caption,
        "(A) The singular-value spectrum",
        fixed = TRUE
    )
    diagnostic_panels <- c(
        "(B) Absolute feature-loading cosine similarity",
        "(C) Assignment margins",
        "(D) Individual-axis recurrence",
        "(E) Component-index recurrence",
        "(F) Orientation recurrence",
        "(G) Proposal rank",
        "(H) Largest principal angles",
        "(I) Replicate completion"
    )
    for (panel_description in diagnostic_panels) {
        expect_match(diagnostic_caption, panel_description, fixed = TRUE)
    }
    expect_match(
        diagnostic_caption,
        "for every discovery component, whether its axis was recovered",
        fixed = TRUE
    )
    expect_match(
        diagnostic_caption,
        paste(
            "sign-corrected biological-effect direction agrees with its",
            "discovery estimate"
        ),
        fixed = TRUE
    )
    expect_match(
        diagnostic_caption,
        "Larger red points denote the nominated component",
        fixed = TRUE
    )
    expect_identical(diagnostic$labels$colour, "Discovery component")
    expect_identical(diagnostic$labels$shape, "Evidence series")
    expect_identical(diagnostic$labels$size, "Nominated component")
    audit <- plot_component_identifiability(assessed, view = "audit")
    expect_setequal(
        unique(audit$data$surface),
        unique(diagnostic$data$surface)
    )
    expect_error(
        plot_component_identifiability(assessed, view = "radial"),
        "should be one of"
    )
    expect_false(any(grepl(
        "human",
        c(surface$labels$title, surface$labels$subtitle),
        ignore.case = TRUE
    )))
    plan <- landscapeR:::.identifiability_resampling_plan(
        fixture$discovery,
        fixture$config@analysis,
        n_resamples = 7L,
        seed = 8301L
    )
    reference <- S4Vectors::metadata(fixture$discovery)$stage1
    forward <- landscapeR:::.new_identifiability_evidence(
        fixture$proposal,
        fixture$config,
        fixture$source,
        reference,
        "feature-loading-cosine",
        plan,
        evidence$replicates
    )
    reverse <- landscapeR:::.new_identifiability_evidence(
        fixture$proposal,
        fixture$config,
        fixture$source,
        reference,
        "feature-loading-cosine",
        plan,
        rev(evidence$replicates)
    )
    expect_identical(forward, reverse)
    incomplete_replicates <- evidence$replicates
    incomplete_replicates[[1L]]$proposal_status <- "abstention"
    nominated <- fixture$proposal@recommended_component
    nominated_row <-
        incomplete_replicates[[2L]]$assignment$reference_component ==
            nominated
    incomplete_replicates[[2L]]$assignment$matched[nominated_row] <- FALSE
    incomplete <- landscapeR:::.new_identifiability_evidence(
        fixture$proposal,
        fixture$config,
        fixture$source,
        reference,
        "feature-loading-cosine",
        plan,
        incomplete_replicates
    )
    expect_equal(incomplete$failure_summary$failure_fraction, 2 / 7)
    expect_equal(
        incomplete$failure_summary$proposal_abstention_fraction,
        1 / 7
    )
    expect_equal(
        incomplete$failure_summary$nominated_unmatched_fraction,
        1 / 7
    )
    expect_identical(
        incomplete$failure_summary$n_proposal_abstentions,
        1L
    )
    expect_identical(
        incomplete$failure_summary$n_nominated_unmatched,
        1L
    )
    expect_identical(
        incomplete$failure_summary$failed_replicates,
        c(1L, 2L)
    )
    incomplete_plot <- plot_component_identifiability(
        landscapeR:::.proposal_with_identifiability(assessed, incomplete)
    )
    incomplete_caption <- gsub(
        "\\s+",
        " ",
        scientific_caption(incomplete_plot)
    )
    expect_match(
        incomplete_caption,
        "Of 7 bootstrap replicates, 5 completed",
        fixed = TRUE
    )
    expect_match(
        incomplete_caption,
        "1 resample in which no component could be nominated",
        fixed = TRUE
    )
    expect_match(
        incomplete_caption,
        "1 resample in which the nominated axis could not be matched",
        fixed = TRUE
    )
    expect_false(grepl(
        "computational failure|proposal abstention|proposal execution failure",
        incomplete_caption
    ))
    incomplete_axis <- incomplete_plot$data[
        incomplete_plot$data$surface == "Axis recurrence" &
            incomplete_plot$data$focal,
        ,
        drop = FALSE
    ]
    expect_equal(incomplete_axis$value, 6 / 7)
    incomplete_diagnostic <- plot_component_identifiability(
        landscapeR:::.proposal_with_identifiability(assessed, incomplete),
        view = "diagnostic"
    )
    completion_rows <- incomplete_diagnostic$data[
        incomplete_diagnostic$data$surface == "Replicate completion",
        ,
        drop = FALSE
    ]
    expect_identical(sum(completion_rows$value == 0), 2L)
    proposal_failure <- landscapeR:::.failed_identifiability_replicate(
        index = 1L,
        seed = 11L,
        source_primary = "sample_01",
        stage = "proposal",
        diagnostic = "synthetic proposal failure"
    )
    expect_identical(proposal_failure$decomposition_status, "success")
    expect_identical(proposal_failure$association_status, "success")
    expect_identical(proposal_failure$proposal_status, "failure")
    exploratory <- confirm_component(
        assessed,
        index = assessed@recommended_component,
        decision = "accept",
        rationale = "Record an exploratory choice before calibration."
    )
    expect_s4_class(exploratory, "AnalysisSpecification")
    expect_identical(exploratory@claim_intent, "exploratory")
    expect_match(
        surface$labels$subtitle,
        "Calibration not yet available",
        fixed = TRUE
    )
    expect_true(
        "Axis recurrence" %in%
            levels(surface$data$surface)
    )
    rendered <- ggplot2::ggplot_build(surface)
    bounded <- surface$data$surface %in% c(
        "Axis recurrence", "Matching similarity"
    )
    expect_true(all(
        surface$data$value[bounded] >= 0 &
            surface$data$value[bounded] <= 1
    ))
    calibration_digest <- paste(rep("a", 64L), collapse = "")
    outcome_labels <- c(
        `stable-axis` = "Individual axis recovered",
        `stable-subspace/no-stable-axis` =
            "Enclosing subspace recovered; individual axis unresolved",
        `no-stable-target-structure` =
            "No stable target-associated structure recovered",
        `outside-calibrated-operating-region` =
            "Design outside the calibrated operating region",
        `unique-winner-failure` =
            "No unique effect-ranked component identified",
        `non-identifiable-design` =
            "Design does not identify an individual axis"
    )
    outcome_conclusions <- c(
        `stable-axis` =
            "individual axis was recovered and is eligible for one-dimensional interpretation",
        `stable-subspace/no-stable-axis` =
            "interpretation must therefore remain at the subspace level",
        `no-stable-target-structure` =
            "no stable target-associated axis or enclosing subspace was recovered",
        `outside-calibrated-operating-region` =
            "no calibrated recovery claim can be made",
        `unique-winner-failure` =
            "no individual axis can be nominated",
        `non-identifiable-design` =
            "one-dimensional interpretation is not supported"
    )
    for (outcome in names(outcome_labels)) {
        outcome_evidence <- proposal_identifiability(assessed)
        outcome_evidence$structured_outcome <- outcome
        outcome_evidence$status <- if (identical(outcome, "stable-axis")) {
            "calibrated-axis-eligible"
        } else {
            "calibrated-ineligible"
        }
        outcome_evidence$calibration_digest <- calibration_digest
        if (identical(outcome, "stable-axis")) {
            outcome_evidence$effect_equivalent_candidates <-
                assessed@recommended_component
        }
        outcome_evidence$digest <- NULL
        outcome_evidence$digest <- digest::digest(
            outcome_evidence,
            algo = "sha256",
            serialize = TRUE
        )
        outcome_plot <- plot_component_identifiability(
            landscapeR:::.proposal_with_identifiability(
                assessed,
                outcome_evidence
            )
        )
        expect_match(
            gsub("\\s+", " ", outcome_plot$labels$subtitle),
            outcome_labels[[outcome]],
            fixed = TRUE
        )
        outcome_caption <- gsub(
            "\\s+",
            " ",
            scientific_caption(outcome_plot)
        )
        expect_match(
            outcome_caption,
            outcome_conclusions[[outcome]],
            fixed = TRUE
        )
        expect_false(grepl(
            "No stability threshold was applied",
            outcome_caption,
            fixed = TRUE
        ))
        if (identical(outcome, "stable-axis")) {
            calibrated <- landscapeR:::.proposal_with_identifiability(
                assessed,
                outcome_evidence
            )
            confirmed <- confirm_component(
                calibrated,
                index = calibrated@recommended_component,
                decision = "accept",
                rationale = "Accept the calibrated stable axis."
            )
            expect_identical(confirmed@lifecycle, "confirmed")
            expect_identical(confirmed@proposal_decision, "accepted")
            expect_identical(
                confirmed@claim_intent,
                calibrated@provenance$claim_intent
            )
        }
    }
    for (outcome in c(
        "stable-subspace/no-stable-axis",
        "no-stable-target-structure",
        "outside-calibrated-operating-region",
        "unique-winner-failure",
        "non-identifiable-design"
    )) {
        ineligible_evidence <- proposal_identifiability(assessed)
        ineligible_evidence$structured_outcome <- outcome
        ineligible_evidence$status <- "calibrated-ineligible"
        ineligible_evidence$calibration_digest <- calibration_digest
        ineligible_evidence$outcome_diagnostic <- paste0(
            "calibrated-",
            outcome
        )
        ineligible_evidence$digest <- NULL
        ineligible_evidence$digest <- digest::digest(
            ineligible_evidence,
            algo = "sha256",
            serialize = TRUE
        )
        ineligible <- landscapeR:::.proposal_with_identifiability(
            assessed,
            ineligible_evidence
        )
        expect_error(
            confirm_component(
                ineligible,
                index = ineligible@recommended_component,
                decision = "accept",
                rationale = "This must not override mathematical eligibility."
            ),
            "axis-identifiability evidence prevents confirmation"
        )
    }
    expect_true(grepl("^[[:xdigit:]]{64}$", evidence$digest))
    expect_identical(
        proposal_identifiability(unserialize(serialize(assessed, NULL))),
        evidence
    )
})

test_that("scientific captions remain separate from plot graphics", {
    plain_plot <- ggplot2::ggplot(
        data.frame(x = 1, y = 1),
        ggplot2::aes(x, y)
    ) + ggplot2::geom_point()

    expect_null(scientific_caption(plain_plot))
    expect_error(scientific_caption("not a plot"), "ggplot object")
    expect_error(
        landscapeR:::.with_scientific_caption(plain_plot, ""),
        "non-empty string"
    )

    captioned <- landscapeR:::.with_scientific_caption(
        plain_plot,
        "A separately rendered scientific caption."
    )
    expect_identical(
        scientific_caption(captioned),
        "A separately rendered scientific caption."
    )
    expect_null(captioned$labels$caption)
})

test_that("identifiability caption context respects declared target type", {
    fixture <- .axis_identifiability_fixture()
    proposal <- fixture$proposal

    continuous <- proposal
    continuous@reference_level <- character()
    continuous@comparison_level <- character()
    continuous@target_field <- "developmental_age"
    continuous@provenance$target_type <- "continuous"
    continuous@provenance$continuous_direction <- "increasing"
    continuous_context <-
        landscapeR:::.identifiability_caption_context(continuous)
    expect_match(
        continuous_context,
        "declared increasing association with developmental_age",
        fixed = TRUE
    )
    expect_false(grepl("versus", continuous_context, fixed = TRUE))

    ordered <- proposal
    ordered@reference_level <- character()
    ordered@comparison_level <- character()
    ordered@target_field <- "developmental_stage"
    ordered@provenance$target_type <- "ordered"
    ordered@provenance$ordered_levels <- c("early", "middle", "late")
    ordered_context <- landscapeR:::.identifiability_caption_context(ordered)
    expect_match(
        ordered_context,
        paste(
            "differences across developmental_stage in the declared order",
            "early < middle < late"
        ),
        fixed = TRUE
    )
    expect_false(grepl("versus", ordered_context, fixed = TRUE))
})
