.adversarial_identifiability_fixture <- function(target_scale) {
    n <- 16L
    primary <- sprintf("sample_%02d", seq_len(n))
    assay_ids <- sprintf("rna_%02d", seq_len(n))
    condition <- factor(
        rep(c("control", "treatment"), each = n / 2L),
        levels = c("control", "treatment")
    )
    target <- target_scale * ifelse(condition == "treatment", 1, -1)
    nuisance <- 8 * rep(c(-1, 1), length.out = n)
    background <- rep(c(-0.8, -0.2, 0.3, 0.7), length.out = n)
    expression <- rbind(
        nuisance + 0.02 * target,
        0.9 * nuisance - 0.01 * target,
        target + 0.05 * background,
        0.8 * target - 0.04 * background,
        background,
        rev(background),
        rep(c(-0.4, 0.1, 0.5, -0.2), length.out = n),
        rep(c(0.3, -0.5, 0.2, 0), length.out = n)
    )
    if (identical(target_scale, 0)) {
        expression[8L, n] <- expression[8L, n] + 1e-4
    }
    rownames(expression) <- sprintf("gene_%02d", seq_len(nrow(expression)))
    colnames(expression) <- assay_ids
    data <- StateTransitionData(
        experiments = list(
            rna = SummarizedExperiment::SummarizedExperiment(
                assays = list(logcounts = expression)
            )
        ),
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
    data <- declare_sampling_design(data, cross_sectional())
    specification <- analysis_specification(
        id = paste0("adversarial-target-", target_scale),
        target_field = "condition",
        target_type = "binary",
        reference_level = "control",
        comparison_level = "treatment"
    )
    config <- new(
        "PipelineConfig",
        strategies = list(Decomposer = "svd"),
        params = list(svd = list(center = TRUE, k_components = 4L)),
        dataset = paste0("adversarial-target-", target_scale),
        analysis = specification
    )
    discovery <- decompose(
        get_strategy("Decomposer", "svd")(config@params$svd),
        data
    )
    expect_identical(discovery@status, "success")
    atlas <- associate_metadata(
        discovery@value,
        specification = specification,
        non_analytical_fields = "sample_id",
        dataset_id = config@dataset
    )
    list(
        data = data,
        config = config,
        proposal = propose_component(atlas),
        atlas = atlas
    )
}

test_that("a strong nuisance axis does not replace the nominated target axis", {
    fixture <- .adversarial_identifiability_fixture(target_scale = 1)
    expect_s4_class(fixture$proposal, "ComponentProposal")
    expect_false(identical(fixture$proposal@recommended_component, 1L))

    assessed <- assess_component_identifiability(
        fixture$data,
        fixture$proposal,
        fixture$config,
        non_analytical_fields = "sample_id",
        n_resamples = 5L,
        seed = 8331L
    )
    evidence <- proposal_identifiability(assessed)
    expect_identical(
        evidence$target_recurrence$reference_component,
        fixture$proposal@recommended_component
    )
    expect_identical(evidence$structured_outcome, "not-calibrated")
})

test_that("null target structure cannot acquire a stability claim", {
    fixture <- .adversarial_identifiability_fixture(target_scale = 0)
    if (is(fixture$proposal, "ComponentAbstention")) {
        expect_identical(fixture$proposal@reason, "effect-magnitude-tie")
        expect_error(
            confirm_component(
                fixture$proposal,
                index = 1L,
                decision = "accept",
                rationale = "A null abstention cannot be confirmed."
            ),
            "cannot confirm an abstention"
        )
    } else {
        assessed <- assess_component_identifiability(
            fixture$data,
            fixture$proposal,
            fixture$config,
            non_analytical_fields = "sample_id",
            n_resamples = 5L,
            seed = 8332L
        )
        evidence <- proposal_identifiability(assessed)
        expect_identical(evidence$structured_outcome, "not-calibrated")
        expect_identical(
            proposal_identifiability(assessed)$status,
            "estimable-exploratory-only"
        )
    }
})
