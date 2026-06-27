library(landscapeR)

# Minimal empty container for tests that don't need real data
empty_std <- function() {
    mae <- MultiAssayExperiment::MultiAssayExperiment()
    as(mae, "StateTransitionData")
}
