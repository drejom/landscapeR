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
    expect_s3_class(atlas_plot, "ggplot")
    expect_s3_class(proposal_plot, "ggplot")
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
})

test_that("atlas and proposal survive serialization without refitting", {
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
