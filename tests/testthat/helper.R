library(landscapeR)

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
