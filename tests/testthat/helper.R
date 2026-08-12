library(landscapeR)

# Keep any implicit base-graphics device created by a test out of the source
# tree so repository-hygiene checks see no Rplots.pdf residue.
options(device = function(...) {
    grDevices::pdf(file = file.path(tempdir(), "landscapeR-tests.pdf"), ...)
})

# Test-only renderer and exception used to exercise the caption exemption path.
.plot_caption_contract_diagnostic <- function() {
    ggplot2::ggplot(data.frame(x = 0, y = 0)) +
        ggplot2::geom_blank(ggplot2::aes(
            x = .data[["x"]],
            y = .data[["y"]]
        ))
}

.scientific_caption_test_exception <- data.frame(
    renderer = ".plot_caption_contract_diagnostic",
    category = "internal-development",
    rationale = paste(
        "Test-only contract diagnostic verifies that explicitly unexported",
        "development plots may omit publication captions."
    ),
    test_reference = paste0(
        "tests/testthat/test-scientific-caption-contract.R:",
        "internal-development-exception"
    ),
    public_examples = FALSE,
    stringsAsFactors = FALSE
)

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
