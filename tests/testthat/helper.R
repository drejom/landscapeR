library(landscapeR)

confirmed_planted_analysis <- function(id = "test-run", component = 1L) {
    analysis_specification(
        id = id,
        target_field = "planted_group",
        target_type = "binary",
        reference_level = "low",
        comparison_level = "high",
        lifecycle = "confirmed",
        selected_component = component,
        proposal_digest = digest::digest(
            list(control = "synthetic_control", target = "planted_group"),
            algo = "sha256"
        ),
        proposal_decision = "accepted",
        analyst_rationale = paste(
            "Synthetic ground truth fixes the target-axis component for",
            "this package contract test."
        )
    )
}

confirmed_potential_analysis <- function(id = "test-double-well", component = 1L) {
    analysis_specification(
        id = id,
        target_field = "x_coord",
        target_type = "continuous",
        continuous_direction = "increasing",
        lifecycle = "confirmed",
        selected_component = component,
        proposal_digest = digest::digest(
            list(control = "synthetic_potential_control", target = "x_coord"),
            algo = "sha256"
        ),
        proposal_decision = "accepted",
        analyst_rationale = paste(
            "Synthetic ground truth fixes the target-axis component for",
            "this package contract test."
        )
    )
}

# Minimal empty container for tests that don't need real data
empty_std <- function() {
    mae <- MultiAssayExperiment::MultiAssayExperiment()
    as(mae, "StateTransitionData")
}

potential_with_stage1 <- function(n = 100L, seed = 1L) {
    std <- synthetic_potential_control(n = n, seed = seed)
    x <- colData(std)$x_coord
    md <- metadata(std)
    md$stage1 <- DecompositionResult(
        V_star   = 1,
        sigma    = 1,
        coords   = list(x),
        warnings = character(),
        V_k      = matrix(1, nrow = 1L, ncol = 1L),
        sigma_k  = matrix(1, nrow = 1L, ncol = 1L),
        coords_k = list(matrix(x, ncol = 1L)),
        k        = 1L
    )
    metadata(std) <- md
    std
}
