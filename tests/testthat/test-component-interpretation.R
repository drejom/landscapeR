component_interpretation_fixture <- function() {
    n <- 8L
    primary <- sprintf("sample_%02d", seq_len(n))
    assay_ids <- sprintf("rna_%02d", seq_len(n))
    condition <- factor(
        rep(c("control", "treatment"), each = n / 2L),
        levels = c("control", "treatment")
    )
    se <- SummarizedExperiment::SummarizedExperiment(
        assays = list(logcounts = matrix(
            seq_len(4L * n),
            nrow = 4L,
            dimnames = list(sprintf("gene_%02d", 1:4), assay_ids)
        ))
    )
    std <- StateTransitionData(
        experiments = list(rna = se),
        colData = S4Vectors::DataFrame(
            condition = condition,
            mouse_id = sprintf("mouse_%02d", seq_len(n)),
            row.names = primary
        ),
        sampleMap = S4Vectors::DataFrame(
            assay = factor(rep("rna", n), levels = "rna"),
            primary = primary,
            colname = assay_ids
        )
    )
    std <- declare_sampling_design(std, cross_sectional())
    coords <- cbind(
        PC1 = seq_len(n),
        PC2 = rep(c(-1, 1), times = n / 2L)
    )
    md <- metadata(std)
    md$stage1 <- DecompositionResult(
        V_star = c(1, 0, 0, 0),
        sigma = 1,
        coords = list(coords[, 1L]),
        V_k = diag(4)[, 1:2, drop = FALSE],
        sigma_k = matrix(c(2, 1), nrow = 1L),
        coords_k = list(coords),
        k = 2L
    )
    metadata(std) <- md
    std
}

continuous_component_interpretation_fixture <- function() {
    std <- component_interpretation_fixture()
    colData(std)$severity <- c(1, 2, 2, 4, 5, 6, 7, 8)
    std
}

ordered_component_interpretation_fixture <- function() {
    std <- component_interpretation_fixture()
    colData(std)$state <- ordered(
        c("early", "early", "middle", "middle", "late", "late", "late", "end"),
        levels = c("early", "middle", "late", "end")
    )
    std
}

unordered_component_interpretation_fixture <- function() {
    std <- component_interpretation_fixture()
    colData(std)$subtype <- factor(
        rep(c("alpha", "beta", "gamma", "delta"), each = 2L)
    )
    std
}

nonmonotone_component_interpretation_fixture <- function() {
    std <- continuous_component_interpretation_fixture()
    md <- metadata(std)
    md$stage1@coords_k[[1L]] <- cbind(
        PC1 = c(4, 3, 2, 1, 1, 2, 3, 4),
        PC2 = seq_len(8L)
    )
    metadata(std) <- md
    std
}

test_that("cross-sectional binary metadata produces a typed association atlas", {
    atlas <- associate_metadata(
        component_interpretation_fixture(),
        non_analytical_fields = "mouse_id",
        dataset_id = "synthetic-control"
    )

    expect_s4_class(atlas, "MetadataAssociationAtlas")
    expect_identical(atlas@version, "1.0.0")
    expect_identical(atlas@compute_tier, "analytic-unadjusted")
    expect_identical(
        atlas_provenance(atlas)$association_strategy,
        "cross-sectional-binary-signed-rank-biserial-v1"
    )
    expect_identical(
        atlas_provenance(atlas)$sampling_design,
        "cross_sectional"
    )
    expect_identical(atlas_provenance(atlas)$dataset_id, "synthetic-control")

    associations <- atlas_associations(atlas)
    expect_s3_class(associations, "data.frame")
    expect_identical(as.data.frame(atlas), associations)
    observations <- atlas_observations(atlas)
    expect_s3_class(observations, "data.frame")
    expect_identical(nrow(observations), 16L)

    condition <- associations[
        associations$metadata_field == "condition",
        ,
        drop = FALSE
    ]
    expect_identical(condition$component, c(1L, 2L))
    expect_identical(
        condition$estimand,
        rep("signed-rank-biserial", 2L)
    )
    expect_identical(condition$reference_level, rep("control", 2L))
    expect_identical(condition$comparison_level, rep("treatment", 2L))
    expect_equal(condition$estimate[[1L]], 1)
    expect_identical(condition$n_available, rep(8L, 2L))
    expect_identical(condition$n_missing, rep(0L, 2L))

    exclusions <- atlas_exclusions(atlas)
    expect_identical(exclusions$metadata_field, "mouse_id")
    expect_identical(exclusions$reason, "declared-non-analytical")
})

test_that("continuous metadata uses Spearman association with visible ties", {
    atlas <- associate_metadata(
        continuous_component_interpretation_fixture(),
        non_analytical_fields = "mouse_id",
        dataset_id = "continuous-control"
    )

    severity <- atlas_associations(atlas)
    severity <- severity[
        severity$metadata_field == "severity",
        ,
        drop = FALSE
    ]

    expect_identical(severity$component, c(1L, 2L))
    expect_identical(severity$estimand, rep("spearman", 2L))
    expect_equal(severity$estimate[[1L]], 0.994029797388005)
    expect_identical(severity$n_available, rep(8L, 2L))
    expect_identical(severity$n_missing, rep(0L, 2L))
    expect_identical(severity$n_target_ties, rep(2L, 2L))
    expect_true(all(is.na(severity$reference_level)))
    expect_true(all(is.na(severity$comparison_level)))
    expect_true(
        "cross-sectional-continuous-spearman-v1" %in%
            atlas_provenance(atlas)$association_strategy
    )
})

test_that("inappropriate declared target type returns a typed abstention", {
    specification <- analysis_specification(
        id = "invalid-continuous-target",
        target_field = "condition",
        target_type = "continuous",
        continuous_direction = "increasing"
    )

    abstention <- associate_metadata(
        component_interpretation_fixture(),
        specification = specification,
        non_analytical_fields = "mouse_id"
    )

    expect_s4_class(abstention, "AssociationAbstention")
    expect_identical(abstention@reason, "inappropriate-target-type")
    expect_match(
        association_abstention_diagnostic(abstention),
        "continuous target must be finite numeric"
    )
    abstention_plot <- plot(abstention)
    abstention_view <- visual_evidence(abstention)
    expect_s3_class(abstention_plot, "ggplot")
    expect_identical(
        visual_evidence_state(abstention_view),
        "abstention"
    )
    expect_null(abstention_plot$labels$caption)
    expect_match(
        scientific_caption(abstention_plot),
        "No[[:space:]]+target type or association is substituted"
    )
    expect_match(
        scientific_caption(abstention_plot),
        "design is cross_sectional"
    )
    expect_match(
        scientific_caption(abstention_plot),
        "no association[[:space:]]+estimand is available"
    )
    expect_identical(
        abstention_plot$labels$subtitle,
        "Declared target type does not match the observed metadata"
    )
    abstention_path <- tempfile(fileext = ".png")
    save_landscapeR_plot(
        abstention_plot,
        abstention_path,
        width_mm = 100,
        height_mm = 100,
        dpi = 72
    )
    expect_gt(file.info(abstention_path)$size, 0)
    restored <- unserialize(serialize(abstention, NULL))
    expect_identical(restored@digest, abstention@digest)
})

test_that("association abstention validity rejects empty reasons cleanly", {
    expect_error(
        validObject(new("AssociationAbstention")),
        "reason must be"
    )
})

test_that("ordered metadata uses Kendall tau-b with declared level order", {
    atlas <- associate_metadata(
        ordered_component_interpretation_fixture(),
        non_analytical_fields = "mouse_id",
        dataset_id = "ordered-control"
    )

    state <- atlas_associations(atlas)
    state <- state[
        state$metadata_field == "state",
        ,
        drop = FALSE
    ]

    expect_identical(state$component, c(1L, 2L))
    expect_identical(state$estimand, rep("kendall-tau-b", 2L))
    expect_equal(state$estimate[[1L]], 0.9063269671749657)
    expect_identical(state$n_target_ties, rep(7L, 2L))
    expect_true(all(is.na(state$reference_level)))
    expect_true(all(is.na(state$comparison_level)))
    expect_true(
        "cross-sectional-ordered-kendall-tau-b-v1" %in%
            atlas_provenance(atlas)$association_strategy
    )
})

test_that("declared ordered semantics override the metadata storage class", {
    std <- ordered_component_interpretation_fixture()
    colData(std)$state <- as.character(colData(std)$state)
    specification <- analysis_specification(
        id = "character-ordered-target",
        target_field = "state",
        target_type = "ordered",
        ordered_levels = c("early", "middle", "late", "end")
    )

    atlas <- associate_metadata(
        std,
        specification = specification,
        non_analytical_fields = "mouse_id"
    )
    state <- atlas_associations(atlas)
    state <- state[
        state$metadata_field == "state",
        ,
        drop = FALSE
    ]

    expect_identical(state$estimand, rep("kendall-tau-b", 2L))
    expect_true(
        "cross-sectional-ordered-kendall-tau-b-v1" %in%
            atlas_provenance(atlas)$association_strategy
    )
})

test_that("unordered multilevel metadata remains descriptive only", {
    atlas <- associate_metadata(
        unordered_component_interpretation_fixture(),
        non_analytical_fields = "mouse_id",
        dataset_id = "unordered-control"
    )
    subtype <- atlas_associations(atlas)
    subtype <- subtype[
        subtype$metadata_field == "subtype",
        ,
        drop = FALSE
    ]

    expect_identical(subtype$component, c(1L, 2L))
    expect_identical(
        subtype$estimand,
        rep("kruskal-wallis-epsilon-squared", 2L)
    )
    expect_true(all(is.finite(subtype$estimate)))
    expect_true(all(subtype$effect_magnitude >= 0))
    expect_true(all(!subtype$proposal_eligible))
    expect_false(
        "subtype" %in% atlas_exclusions(atlas)$metadata_field
    )

    abstention <- propose_component(atlas, target = "subtype")
    expect_s4_class(abstention, "ComponentAbstention")
    expect_identical(abstention@reason, "no-eligible-association")
})

test_that("association uncertainty resamples independent biological units", {
    specification <- analysis_specification(
        id = "bootstrap-with-batch",
        target_field = "condition",
        target_type = "binary",
        reference_level = "control",
        comparison_level = "treatment",
        nuisance_fields = "batch"
    )
    std <- component_interpretation_fixture()
    colData(std)$batch <- rep(c("batch_1", "batch_2"), times = 4L)

    atlas <- associate_metadata(
        std,
        specification = specification,
        non_analytical_fields = "mouse_id",
        n_resamples = 19L,
        seed = 7001L
    )
    evidence <- atlas_associations(atlas)
    condition <- evidence[
        evidence$metadata_field == "condition",
        ,
        drop = FALSE
    ]

    expect_identical(atlas@compute_tier, "standard-resampled")
    expect_identical(condition$n_resamples, rep(19L, 4L))
    expect_identical(condition$resample_failures, rep(0L, 4L))
    expect_identical(
        condition$resampling_method,
        rep("stratified-biological-unit-bootstrap", 4L)
    )
    expect_true(all(is.finite(condition$effect_conf_low)))
    expect_true(all(is.finite(condition$effect_conf_high)))
    expect_true(all(
        condition$effect_conf_low <= condition$effect_conf_high
    ))
    expect_true(all(grepl(
        "^[[:xdigit:]]{64}$",
        condition$resampling_plan_digest
    )))

    repeated <- associate_metadata(
        std,
        specification = specification,
        non_analytical_fields = "mouse_id",
        n_resamples = 19L,
        seed = 7001L
    )
    expect_identical(
        atlas_associations(repeated),
        atlas_associations(atlas)
    )
})

test_that("non-monotone warning remains visual and cannot rerank", {
    specification <- analysis_specification(
        id = "nonmonotone-severity",
        target_field = "severity",
        target_type = "continuous",
        continuous_direction = "increasing"
    )
    atlas <- associate_metadata(
        nonmonotone_component_interpretation_fixture(),
        specification = specification,
        non_analytical_fields = "mouse_id"
    )
    severity <- atlas_associations(atlas)
    severity <- severity[
        severity$metadata_field == "severity",
        ,
        drop = FALSE
    ]

    expect_identical(
        severity$diagnostic,
        c("possible-nonmonotone-association", "")
    )
    proposal <- propose_component(atlas)
    expect_s4_class(proposal, "ComponentProposal")
    expect_identical(proposal@recommended_component, 2L)

    atlas_plot <- plot(atlas)
    atlas_view <- visual_evidence(atlas)
    diagnostics <- unlist(lapply(
        atlas_plot$layers,
        function(layer) layer$data$diagnostic
    ))
    expect_true("possible-nonmonotone-association" %in% diagnostics)
    expect_true(
        "possible-nonmonotone-association" %in%
            visual_evidence_diagnostics(atlas_view)$diagnostic
    )
})

test_that("continuous and ordered specifications can nominate components", {
    continuous_specification <- analysis_specification(
        id = "continuous-proposal",
        target_field = "severity",
        target_type = "continuous",
        continuous_direction = "increasing"
    )
    continuous_atlas <- associate_metadata(
        continuous_component_interpretation_fixture(),
        specification = continuous_specification,
        non_analytical_fields = "mouse_id"
    )
    continuous_proposal <- propose_component(continuous_atlas)
    expect_s4_class(continuous_proposal, "ComponentProposal")
    continuous_confirmed <- confirm_component(
        continuous_proposal,
        index = continuous_proposal@recommended_component,
        decision = "accept",
        rationale = "Confirm the synthetic continuous lifecycle."
    )
    expect_identical(continuous_confirmed@target_type, "continuous")
    expect_identical(
        continuous_confirmed@continuous_direction,
        "increasing"
    )

    ordered_specification <- analysis_specification(
        id = "ordered-proposal",
        target_field = "state",
        target_type = "ordered",
        ordered_levels = c("early", "middle", "late", "end")
    )
    ordered_atlas <- associate_metadata(
        ordered_component_interpretation_fixture(),
        specification = ordered_specification,
        non_analytical_fields = "mouse_id"
    )
    ordered_proposal <- propose_component(ordered_atlas)
    expect_s4_class(ordered_proposal, "ComponentProposal")
    ordered_confirmed <- confirm_component(
        ordered_proposal,
        index = ordered_proposal@recommended_component,
        decision = "accept",
        rationale = "Confirm the synthetic ordered lifecycle."
    )
    expect_identical(ordered_confirmed@target_type, "ordered")
    expect_identical(
        ordered_confirmed@ordered_levels,
        c("early", "middle", "late", "end")
    )
})

test_that("draft analysis specification is the sole proposal intent", {
    specification <- analysis_specification(
        id = "binary-with-batch",
        target_field = "condition",
        target_type = "binary",
        reference_level = "control",
        comparison_level = "treatment",
        nuisance_fields = "batch"
    )
    std <- component_interpretation_fixture()
    colData(std)$batch <- rep(c("batch_1", "batch_2"), times = 4L)

    atlas <- associate_metadata(
        std,
        specification = specification,
        non_analytical_fields = "mouse_id"
    )
    condition <- atlas_associations(atlas)
    condition <- condition[
        condition$metadata_field == "condition",
        ,
        drop = FALSE
    ]
    unadjusted <- condition[
        condition$evidence_variant == "unadjusted",
        ,
        drop = FALSE
    ]
    adjusted <- condition[
        condition$evidence_variant == "adjusted",
        ,
        drop = FALSE
    ]

    expect_identical(unadjusted$component, c(1L, 2L))
    expect_identical(adjusted$component, c(1L, 2L))
    expect_identical(
        adjusted$estimand,
        rep("adjusted-rank-score-contrast", 2L)
    )
    expect_identical(
        adjusted$nuisance_fields,
        rep("batch", 2L)
    )
    expect_equal(adjusted$estimate[[1L]], 0.894427190999916)
    expect_true(all(grepl("^[[:xdigit:]]{64}$", adjusted$design_digest)))
    expect_true(all(grepl("^[[:xdigit:]]{64}$", adjusted$cohort_digest)))
    expect_identical(
        length(unique(adjusted$cohort_digest)),
        1L
    )
    expect_true(all(unadjusted$proposal_eligible))

    proposal <- propose_component(atlas)

    expect_identical(proposal@target_field, "condition")
    expect_identical(
        atlas_provenance(atlas)$analysis_specification_digest,
        canonical_digest(specification)
    )
    expect_identical(
        proposal_provenance(proposal)$analysis_specification_digest,
        canonical_digest(specification)
    )
    expect_identical(
        atlas_provenance(atlas)$nuisance_fields,
        "batch"
    )

    confirmed <- confirm_component(
        proposal,
        index = proposal@recommended_component,
        decision = "accept",
        rationale = "Accepted the predeclared target under its nuisance design."
    )
    expect_identical(confirmed@id, "binary-with-batch")
    expect_identical(confirmed@nuisance_fields, "batch")
    expect_identical(confirmed@claim_intent, "exploratory")
})

test_that("target-confounded adjustment abstains without replacing raw evidence", {
    std <- component_interpretation_fixture()
    colData(std)$batch <- colData(std)$condition
    specification <- analysis_specification(
        id = "confounded-binary",
        target_field = "condition",
        target_type = "binary",
        reference_level = "control",
        comparison_level = "treatment",
        nuisance_fields = "batch"
    )

    atlas <- associate_metadata(
        std,
        specification = specification,
        non_analytical_fields = "mouse_id"
    )
    condition <- atlas_associations(atlas)
    condition <- condition[
        condition$metadata_field == "condition",
        ,
        drop = FALSE
    ]
    raw <- condition[condition$evidence_variant == "unadjusted", , drop = FALSE]
    adjusted <- condition[
        condition$evidence_variant == "adjusted",
        ,
        drop = FALSE
    ]

    expect_identical(raw$component, c(1L, 2L))
    expect_true(all(is.finite(raw$estimate)))
    expect_identical(adjusted$component, c(1L, 2L))
    expect_true(all(is.na(adjusted$estimate)))
    expect_identical(
        adjusted$diagnostic,
        rep("non-identifiable-design", 2L)
    )

    abstention <- propose_component(atlas)
    expect_s4_class(abstention, "ComponentAbstention")
    expect_identical(abstention@reason, "non-identifiable-design")
    abstention_plot <- plot(abstention)
    abstention_view <- visual_evidence(abstention)
    expect_s3_class(abstention_plot, "ggplot")
    expect_identical(
        visual_evidence_state(abstention_view),
        "abstention"
    )
    expect_null(abstention_plot$labels$caption)
    expect_match(
        scientific_caption(abstention_plot),
        "no runner-up is promoted"
    )
})

test_that("component proposal ranks only by sign-invariant biological effect", {
    atlas <- associate_metadata(
        component_interpretation_fixture(),
        non_analytical_fields = "mouse_id",
        dataset_id = "synthetic-control"
    )
    proposal <- propose_component(atlas, target = "condition")

    expect_s4_class(proposal, "ComponentProposal")
    expect_identical(proposal@version, "1.0.0")
    expect_identical(proposal@target_field, "condition")
    expect_identical(proposal@recommended_component, 1L)
    expect_identical(proposal@evidence_status, "estimable-exploratory-only")
    expect_identical(
        proposal_provenance(proposal)$association_strategy,
        "cross-sectional-binary-signed-rank-biserial-v1"
    )

    ranking <- proposal_ranking(proposal)
    expect_identical(ranking$component, c(1L, 2L))
    expect_equal(ranking$effect_magnitude, c(1, 0))
    expect_identical(ranking$proposal_rank, c(1L, 2L))
    expect_identical(nchar(proposal_digest(proposal)), 64L)

    altered <- atlas
    altered@associations$p_value <- c(0.9, 1e-12)
    altered@associations$q_value <- c(0.9, 2e-12)
    still_effect_first <- propose_component(altered, target = "condition")
    expect_identical(still_effect_first@recommended_component, 1L)
})

test_that("unadjusted permutation repeats the complete component search", {
    specification <- analysis_specification(
        id = "binary-permutation",
        target_field = "condition",
        target_type = "binary",
        reference_level = "control",
        comparison_level = "treatment"
    )
    atlas <- associate_metadata(
        component_interpretation_fixture(),
        specification = specification,
        non_analytical_fields = "mouse_id"
    )

    proposal <- propose_component(
        atlas,
        n_permutations = 19L,
        seed = 8001L
    )
    evidence <- proposal_permutation_evidence(proposal)

    expect_s4_class(evidence, "PermutationEvidence")
    expect_identical(evidence@method, "label-permutation")
    expect_identical(evidence@n_requested, 19L)
    expect_identical(evidence@n_completed, 19L)
    expect_length(evidence@null_max_effect, 19L)
    expect_true(all(is.finite(evidence@null_max_effect)))
    expect_equal(evidence@observed_max_effect, 1)
    expect_equal(
        evidence@search_aware_p_value,
        (1 + sum(evidence@null_max_effect >= 1)) / 20
    )
    expect_identical(proposal@recommended_component, 1L)
    expect_s3_class(plot(evidence), "ggplot")

    repeated <- propose_component(
        atlas,
        n_permutations = 19L,
        seed = 8001L
    )
    expect_identical(
        proposal_permutation_evidence(repeated),
        evidence
    )
})

test_that("cross-sectional permutation excludes finite ineligible components", {
    specification <- analysis_specification(
        id = "binary-mixed-eligibility",
        target_field = "condition",
        target_type = "binary",
        reference_level = "control",
        comparison_level = "treatment"
    )
    atlas <- associate_metadata(
        component_interpretation_fixture(),
        specification = specification,
        non_analytical_fields = "mouse_id"
    )
    ineligible <- atlas@associations$metadata_field == "condition" &
        atlas@associations$component == 2L
    atlas@associations$proposal_eligible[ineligible] <- FALSE
    altered <- atlas
    altered_rows <- altered@observations$metadata_field == "condition" &
        altered@observations$component == 2L
    altered@observations$score[altered_rows] <-
        c(8, 1, 7, 2, 6, 3, 5, 4)

    first <- propose_component(atlas, n_permutations = 19L, seed = 8009L)
    second <- propose_component(altered, n_permutations = 19L, seed = 8009L)

    expect_identical(proposal_ranking(first)$component, 1L)
    expect_identical(proposal_ranking(second)$component, 1L)
    expect_identical(
        proposal_permutation_evidence(first)@null_max_effect,
        proposal_permutation_evidence(second)@null_max_effect
    )
})

test_that("adjusted permutation uses nuisance-only score residuals", {
    specification <- analysis_specification(
        id = "adjusted-permutation",
        target_field = "condition",
        target_type = "binary",
        reference_level = "control",
        comparison_level = "treatment",
        nuisance_fields = "batch"
    )
    std <- component_interpretation_fixture()
    colData(std)$batch <- rep(c("batch_1", "batch_2"), times = 4L)
    atlas <- associate_metadata(
        std,
        specification = specification,
        non_analytical_fields = "mouse_id"
    )

    proposal <- propose_component(
        atlas,
        n_permutations = 19L,
        seed = 8002L
    )
    evidence <- proposal_permutation_evidence(proposal)

    expect_s4_class(evidence, "PermutationEvidence")
    expect_identical(
        evidence@method,
        "nuisance-only-residual-permutation"
    )
    expect_identical(evidence@n_completed, 19L)
    expect_true(all(is.finite(evidence@null_max_effect)))
    expect_true(grepl("^[[:xdigit:]]{64}$", evidence@design_digest))
    expect_true(grepl("^[[:xdigit:]]{64}$", evidence@cohort_digest))
})

test_that("permutation without declared exchangeability intent abstains", {
    atlas <- associate_metadata(
        component_interpretation_fixture(),
        non_analytical_fields = "mouse_id"
    )

    abstention <- propose_component(
        atlas,
        target = "condition",
        n_permutations = 19L,
        seed = 8003L
    )

    expect_s4_class(abstention, "ComponentAbstention")
    expect_identical(abstention@reason, "permutation-not-identifiable")
    expect_identical(
        abstention_permutation_evidence(abstention)@diagnostic,
        "missing-declared-target-intent"
    )
    expect_identical(
        abstention_ranking(abstention)$component,
        c(1L, 2L)
    )
    expect_s3_class(plot(abstention), "ggplot")
})

test_that("declared invalid exchangeability returns a typed abstention", {
    specification <- analysis_specification(
        id = "invalid-exchangeability",
        target_field = "condition",
        target_type = "binary",
        reference_level = "control",
        comparison_level = "treatment"
    )
    atlas <- associate_metadata(
        component_interpretation_fixture(),
        specification = specification,
        non_analytical_fields = "mouse_id",
        exchangeability = "not_identifiable"
    )

    abstention <- propose_component(
        atlas,
        n_permutations = 19L,
        seed = 8005L
    )

    expect_s4_class(abstention, "ComponentAbstention")
    expect_identical(abstention@reason, "permutation-not-identifiable")
    expect_identical(
        abstention_permutation_evidence(abstention)@diagnostic,
        "exchangeability-not-identifiable"
    )
})

test_that("component proposal abstains when the largest effects are tied", {
    atlas <- associate_metadata(
        component_interpretation_fixture(),
        non_analytical_fields = "mouse_id"
    )
    atlas@associations$effect_magnitude <- c(0.75, 0.75)
    atlas@associations$estimate <- c(0.75, -0.75)

    abstention <- propose_component(atlas, target = "condition")

    expect_s4_class(abstention, "ComponentAbstention")
    expect_identical(abstention@version, "1.0.0")
    expect_identical(abstention@target_field, "condition")
    expect_identical(abstention@reason, "effect-magnitude-tie")
    expect_identical(abstention@candidate_components, c(1L, 2L))
    expect_identical(
        abstention@evidence_status,
        "estimable-exploratory-only"
    )
    expect_identical(
        abstention_ranking(abstention)$component,
        c(1L, 2L)
    )
    expect_identical(nchar(abstention_digest(abstention)), 64L)
    expect_identical(
        abstention_provenance(abstention)$association_strategy,
        "cross-sectional-binary-signed-rank-biserial-v1"
    )
})

test_that("human confirmation produces a confirmed analysis specification", {
    atlas <- associate_metadata(
        component_interpretation_fixture(),
        non_analytical_fields = "mouse_id",
        dataset_id = "synthetic-control"
    )
    proposal <- propose_component(atlas, target = "condition")

    accepted <- confirm_component(
        proposal,
        index = 1L,
        decision = "accept",
        rationale = "PC1 carries the unique predeclared binary contrast."
    )
    expect_s4_class(accepted, "AnalysisSpecification")
    expect_identical(
        accepted@id,
        "synthetic-control_condition_PC1"
    )
    expect_identical(accepted@lifecycle, "confirmed")
    expect_identical(accepted@target_field, "condition")
    expect_identical(accepted@target_type, "binary")
    expect_identical(accepted@reference_level, "control")
    expect_identical(accepted@comparison_level, "treatment")
    expect_identical(accepted@selected_component, 1L)
    expect_identical(accepted@proposal_digest, proposal_digest(proposal))
    expect_identical(accepted@proposal_decision, "accepted")
    expect_identical(
        accepted@analyst_rationale,
        "PC1 carries the unique predeclared binary contrast."
    )

    expect_error(
        confirm_component(
            proposal,
            index = 1L,
            rationale = "A decision must be supplied explicitly."
        ),
        "decision must be 'accept' or 'override'",
        class = "landscapeR_validation_error"
    )

    overridden <- confirm_component(
        proposal,
        index = 2L,
        decision = "override",
        rationale = "Exploratory override retained for a documented comparison."
    )
    expect_identical(overridden@selected_component, 2L)
    expect_identical(overridden@proposal_decision, "overridden")

    expect_error(
        confirm_component(
            proposal,
            index = 2L,
            decision = "accept",
            rationale = "Wrong decision for a non-recommended component."
        ),
        "accept.*recommended"
    )
    expect_error(
        confirm_component(
            proposal,
            index = 1L,
            decision = "accept",
            rationale = ""
        ),
        "rationale"
    )
})

test_that("an abstention cannot cross the human confirmation boundary", {
    atlas <- associate_metadata(
        component_interpretation_fixture(),
        non_analytical_fields = "mouse_id"
    )
    atlas@associations$effect_magnitude <- c(0.5, 0.5)
    abstention <- propose_component(atlas, target = "condition")

    expect_error(
        confirm_component(
            abstention,
            index = 1L,
            decision = "override",
            rationale = "Attempt to bypass abstention."
        ),
        "cannot confirm.*abstention"
    )
})

test_that("interpretation evidence has tidy accessors and ggplot views", {
    atlas <- associate_metadata(
        component_interpretation_fixture(),
        non_analytical_fields = "mouse_id"
    )
    proposal <- propose_component(atlas, target = "condition")

    expect_identical(as.data.frame(proposal), proposal_ranking(proposal))
    expect_identical(nchar(atlas_digest(atlas)), 64L)
    expect_identical(
        atlas_digest(atlas),
        atlas_digest(associate_metadata(
            component_interpretation_fixture(),
            non_analytical_fields = "mouse_id"
        ))
    )
    expect_identical(
        proposal_digest(proposal),
        proposal_digest(propose_component(atlas, target = "condition"))
    )

    atlas_plot <- plot(atlas)
    proposal_plot <- plot(proposal)
    atlas_view <- visual_evidence(atlas)
    proposal_view <- visual_evidence(proposal)
    permutation_view <- visual_evidence(
        proposal_permutation_evidence(proposal)
    )
    expect_s3_class(atlas_plot, "ggplot")
    expect_s3_class(proposal_plot, "ggplot")
    expect_s4_class(atlas_view, "VisualEvidenceView")
    expect_s4_class(proposal_view, "VisualEvidenceView")
    expect_s4_class(permutation_view, "VisualEvidenceView")
    expect_identical(visual_evidence_surface(atlas_view), "atlas")
    expect_identical(visual_evidence_surface(proposal_view), "proposal")
    expect_identical(
        visual_evidence_surface(permutation_view),
        "permutation"
    )
    expect_identical(
        atlas_plot$data,
        atlas_observations(atlas)
    )
    expect_identical(
        proposal_plot$data,
        proposal_observations(proposal)
    )
    proposal_layers <- ggplot2::ggplot_build(proposal_plot)$data
    expect_true(any(vapply(
        proposal_layers,
        function(layer) "shape" %in% names(layer) &&
            any(layer$shape == 23),
        logical(1L)
    )))
    canonical_paths <- vapply(
        list(
            atlas_plot,
            proposal_plot,
            plot(proposal_permutation_evidence(proposal))
        ),
        function(figure) {
            path <- tempfile(fileext = ".png")
            save_landscapeR_plot(
                figure,
                path,
                width_mm = 100,
                height_mm = 100,
                dpi = 72
            )
            path
        },
        character(1L)
    )
    expect_true(all(file.info(canonical_paths)$size > 0))
})

test_that("continuous atlas plot exposes monotone and flexible fits", {
    atlas <- associate_metadata(
        continuous_component_interpretation_fixture(),
        non_analytical_fields = "mouse_id"
    )
    atlas_plot <- plot(atlas)
    severity <- atlas_observations(atlas)
    severity <- severity[
        severity$metadata_field == "severity",
        ,
        drop = FALSE
    ]

    expect_equal(
        severity$metadata_numeric[severity$component == 1L],
        c(1, 2, 2, 4, 5, 6, 7, 8)
    )
    flexible_layers <- vapply(
        atlas_plot$layers,
        function(layer) {
            inherits(layer$geom, "GeomLine") &&
                "flexible_fitted" %in% names(layer$data)
        },
        logical(1L)
    )
    monotone_layers <- vapply(
        atlas_plot$layers,
        function(layer) {
            inherits(layer$geom, "GeomLine") &&
                "monotone_fitted" %in% names(layer$data)
        },
        logical(1L)
    )
    expect_identical(sum(flexible_layers), 1L)
    expect_identical(sum(monotone_layers), 1L)
    view <- visual_evidence(atlas)
    stored_visual_evidence <- atlas_provenance(atlas)$visual_evidence
    expect_identical(
        visual_evidence_display(view, "monotone_fit"),
        stored_visual_evidence$monotone_fit
    )
    expect_identical(
        atlas_plot$layers[[which(flexible_layers)]]$data,
        visual_evidence_display(view, "flexible_fit")
    )
    expect_identical(
        visual_evidence_display(view, "flexible_fit"),
        stored_visual_evidence$flexible_fit
    )
    testthat::local_mocked_bindings(
        .monotone_fit_data = function(...) {
            stop("adapter recomputed monotone fit")
        },
        .flexible_fit_data = function(...) {
            stop("adapter recomputed flexible fit")
        },
        .package = "landscapeR"
    )
    expect_s4_class(visual_evidence(atlas), "VisualEvidenceView")
    invalid_visual <- atlas
    invalid_visual@provenance$visual_evidence$flexible_fit <-
        data.frame()
    expect_error(
        validObject(invalid_visual),
        "stored visual evidence is invalid"
    )
    expect_null(atlas_plot$labels$caption)
    expect_match(scientific_caption(atlas_plot), "exploratory")
})

test_that("coincident continuous observations expose atom mass", {
    std <- continuous_component_interpretation_fixture()
    md <- metadata(std)
    md$stage1@coords_k[[1L]][1:2, 1L] <- 1
    colData(std)$severity[1:2] <- 1
    metadata(std) <- md

    atlas <- associate_metadata(
        std,
        non_analytical_fields = "mouse_id"
    )
    observations <- atlas_observations(atlas)
    atom <- observations[
        observations$metadata_field == "severity" &
            observations$component == 1L &
            observations$sample_index %in% 1:2,
        ,
        drop = FALSE
    ]

    expect_identical(atom$atom_count, c(2L, 2L))
    numeric_points <- Filter(
        function(layer) {
            inherits(layer$geom, "GeomPoint") &&
                !is.null(layer$mapping$size)
        },
        plot(atlas)$layers
    )
    expect_true(length(numeric_points) >= 1L)
})

test_that("continuous proposal plot preserves the numeric decision surface", {
    specification <- analysis_specification(
        id = "continuous-plot",
        target_field = "severity",
        target_type = "continuous",
        continuous_direction = "increasing"
    )
    atlas <- associate_metadata(
        continuous_component_interpretation_fixture(),
        specification = specification,
        non_analytical_fields = "mouse_id"
    )
    proposal_plot <- plot(propose_component(atlas))
    flexible_layers <- vapply(
        proposal_plot$layers,
        function(layer) {
            inherits(layer$geom, "GeomLine") &&
                "flexible_fitted" %in% names(layer$data)
        },
        logical(1L)
    )

    expect_identical(sum(flexible_layers), 1L)
    expect_null(proposal_plot$labels$caption)
    expect_match(scientific_caption(proposal_plot), "red diamond")
    expect_true(any(vapply(
        proposal_plot$layers,
        function(layer) {
            identical(layer$geom_params$shape, 23) ||
                identical(layer$aes_params$shape, 23)
        },
        logical(1L)
    )))
})

test_that("atlas and proposal survive serialization without refitting", {
    specification <- analysis_specification(
        id = "serialized-permutation",
        target_field = "condition",
        target_type = "binary",
        reference_level = "control",
        comparison_level = "treatment"
    )
    atlas <- associate_metadata(
        component_interpretation_fixture(),
        specification = specification,
        non_analytical_fields = "mouse_id",
        n_resamples = 9L,
        seed = 7002L
    )
    proposal <- propose_component(
        atlas,
        n_permutations = 9L,
        seed = 8004L
    )
    tied_atlas <- atlas
    tied_atlas@associations$effect_magnitude <- c(0.5, 0.5)
    tied_atlas@associations$estimate <- c(0.5, -0.5)
    abstention <- propose_component(tied_atlas, target = "condition")
    confirmed <- confirm_component(
        proposal,
        index = proposal@recommended_component,
        decision = "accept",
        rationale = "Fresh-session serialization contract."
    )
    path <- tempfile(fileext = ".rds")
    on.exit(unlink(path), add = TRUE)

    saveRDS(
        list(
            atlas = atlas,
            proposal = proposal,
            abstention = abstention,
            confirmed = confirmed
        ),
        path
    )
    restored <- readRDS(path)

    expect_s4_class(restored$atlas, "MetadataAssociationAtlas")
    expect_s4_class(restored$proposal, "ComponentProposal")
    expect_identical(atlas_digest(restored$atlas), atlas_digest(atlas))
    expect_identical(
        proposal_digest(restored$proposal),
        proposal_digest(proposal)
    )
    expect_identical(
        proposal_permutation_evidence(restored$proposal),
        proposal_permutation_evidence(proposal)
    )
    expect_s3_class(plot(restored$atlas), "ggplot")
    expect_s3_class(plot(restored$proposal), "ggplot")
})

test_that("orientation and canonical sample alignment are deterministic", {
    std <- component_interpretation_fixture()
    cd <- colData(std)
    cd$condition <- factor(
        as.character(cd$condition),
        levels = c("treatment", "control")
    )
    colData(std) <- cd[rev(seq_len(nrow(cd))), , drop = FALSE]

    atlas <- associate_metadata(std)
    condition <- atlas_associations(atlas)

    expect_identical(condition$reference_level, rep("treatment", 2L))
    expect_identical(condition$comparison_level, rep("control", 2L))
    expect_equal(condition$estimate[[1L]], -1)
    expect_identical(
        atlas_exclusions(atlas)$reason,
        "identifier-field"
    )
})

test_that("available-case and tied-score diagnostics remain visible", {
    std <- component_interpretation_fixture()
    cd <- colData(std)
    cd$condition[[2L]] <- NA
    colData(std) <- cd

    atlas <- associate_metadata(
        std,
        non_analytical_fields = "mouse_id"
    )
    condition <- atlas_associations(atlas)

    expect_identical(condition$n_available, c(7L, 7L))
    expect_identical(condition$n_missing, c(1L, 1L))
    expect_identical(condition$n_score_ties, c(0L, 7L))
})

test_that("non-finite continuous targets are unavailable everywhere", {
    std <- continuous_component_interpretation_fixture()
    colData(std)$severity[[8L]] <- Inf

    atlas <- associate_metadata(
        std,
        non_analytical_fields = "mouse_id"
    )
    severity <- atlas_associations(atlas)
    severity <- severity[
        severity$metadata_field == "severity",
        ,
        drop = FALSE
    ]
    observations <- atlas_observations(atlas)
    observations <- observations[
        observations$metadata_field == "severity" &
            observations$sample_index == 8L,
        ,
        drop = FALSE
    ]

    expect_identical(severity$n_available, c(7L, 7L))
    expect_identical(severity$n_missing, c(1L, 1L))
    expect_false(any(observations$available))
})

test_that("component interpretation rejects malformed layer and coordinate inputs", {
    std <- component_interpretation_fixture()

    expect_error(
        landscapeR:::.aligned_component_metadata(
            std,
            layer = 2L,
            field = "condition",
            caller = "test"
        ),
        class = "landscapeR_validation_error"
    )

    md <- metadata(std)
    md$stage1@coords_k <- list(matrix(
        c(1:15, Inf),
        nrow = 8L,
        dimnames = list(NULL, c("PC1", "PC2"))
    ))
    metadata(std) <- md
    expect_error(
        associate_metadata(std),
        "finite numeric matrix",
        class = "landscapeR_validation_error"
    )
})

test_that("binary association uses the registered AssociationStrategy contract", {
    expect_true(
        "AssociationStrategy:cross_sectional_binary" %in%
            list_strategies("AssociationStrategy")
    )
    strategy <- get_strategy(
        "AssociationStrategy",
        "cross_sectional_binary"
    )()
    expect_s4_class(strategy, "AssociationStrategy")

    atlas <- associate_metadata(
        component_interpretation_fixture(),
        non_analytical_fields = "mouse_id"
    )
    expect_identical(
        atlas_provenance(atlas)$association_strategy,
        "cross-sectional-binary-signed-rank-biserial-v1"
    )
})

test_that("coordinate rows must match selected-layer observations", {
    std <- component_interpretation_fixture()
    md <- metadata(std)
    md$stage1@coords_k <- list(matrix(
        seq_len(18L),
        nrow = 9L,
        dimnames = list(NULL, c("PC1", "PC2"))
    ))
    metadata(std) <- md

    expect_error(
        associate_metadata(std),
        "coordinate rows.*layer observations",
        class = "landscapeR_validation_error"
    )
})

test_that("a genuine null produces a typed no-identifiable-result abstention", {
    std <- component_interpretation_fixture()
    md <- metadata(std)
    null_coords <- cbind(
        PC1 = c(1, 4, 5, 8, 2, 3, 6, 7),
        PC2 = rep(0, 8)
    )
    md$stage1 <- DecompositionResult(
        V_star = c(1, 0, 0, 0),
        sigma = 1,
        coords = list(null_coords[, 1L]),
        V_k = diag(4)[, 1:2, drop = FALSE],
        sigma_k = matrix(c(2, 1), nrow = 1L),
        coords_k = list(null_coords),
        k = 2L
    )
    metadata(std) <- md
    atlas <- associate_metadata(
        std,
        non_analytical_fields = "mouse_id"
    )

    abstention <- propose_component(atlas, target = "condition")
    expect_s4_class(abstention, "ComponentAbstention")
    expect_identical(abstention@reason, "effect-magnitude-tie")
    expect_equal(abstention_ranking(abstention)$effect_magnitude, c(0, 0))
})

test_that("an ineligible target produces a typed abstention", {
    atlas <- associate_metadata(
        component_interpretation_fixture(),
        non_analytical_fields = c("condition", "mouse_id")
    )

    abstention <- propose_component(atlas, target = "condition")
    expect_s4_class(abstention, "ComponentAbstention")
    expect_identical(abstention@reason, "no-eligible-association")
    expect_identical(nrow(abstention_ranking(abstention)), 0L)
    expect_error(
        confirm_component(
            abstention,
            index = 1L,
            decision = "override",
            rationale = "Cannot override mathematical ineligibility."
        ),
        "cannot confirm.*abstention"
    )
})

test_that("serialized evidence reloads and renders in a fresh R session", {
    skip_if_not_installed("pkgload")

    atlas <- associate_metadata(
        component_interpretation_fixture(),
        non_analytical_fields = "mouse_id"
    )
    proposal <- propose_component(atlas, target = "condition")
    tied_atlas <- atlas
    tied_atlas@associations$effect_magnitude <- c(0.5, 0.5)
    tied_atlas@associations$estimate <- c(0.5, -0.5)
    abstention <- propose_component(tied_atlas, target = "condition")
    confirmed <- confirm_component(
        proposal,
        index = proposal@recommended_component,
        decision = "accept",
        rationale = "Fresh-session serialization contract."
    )
    path <- tempfile(fileext = ".rds")
    script <- tempfile(fileext = ".R")
    output <- tempfile(fileext = ".txt")
    on.exit(unlink(c(path, script, output)), add = TRUE)
    saveRDS(
        list(
            atlas = atlas,
            proposal = proposal,
            abstention = abstention,
            confirmed = confirmed
        ),
        path
    )

    repository <- normalizePath(
        testthat::test_path("..", ".."),
        mustWork = TRUE
    )
    writeLines(
        c(
            sprintf(
                paste0(
                    "if (file.exists(file.path(%s, 'DESCRIPTION'))) ",
                    "pkgload::load_all(%s, quiet = TRUE) ",
                    "else library(landscapeR)"
                ),
                dQuote(repository),
                dQuote(repository)
            ),
            sprintf("restored <- readRDS(%s)", dQuote(path)),
            "methods::validObject(restored$atlas)",
            "methods::validObject(restored$proposal)",
            "methods::validObject(restored$abstention)",
            "methods::validObject(restored$confirmed)",
            "stopifnot(inherits(plot(restored$atlas), 'ggplot'))",
            "stopifnot(inherits(plot(restored$proposal), 'ggplot'))",
            sprintf(
                paste0(
                    "writeLines(c(atlas_digest(restored$atlas), ",
                    "proposal_digest(restored$proposal), ",
                    "abstention_digest(restored$abstention), ",
                    "canonical_digest(restored$confirmed)), %s)"
                ),
                dQuote(output)
            )
        ),
        script
    )
    status <- system2(
        file.path(R.home("bin"), "Rscript"),
        c("--vanilla", script)
    )
    expect_identical(status, 0L)
    if (!identical(status, 0L)) {
        return(invisible())
    }
    restored_digests <- readLines(output, warn = FALSE)
    expect_identical(
        restored_digests,
        c(
            atlas_digest(atlas),
            proposal_digest(proposal),
            abstention_digest(abstention),
            canonical_digest(confirmed)
        )
    )
})
