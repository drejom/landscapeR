# Ground-truth classes — present on synthetic data, NULL on real data.
# Validated by the harness in Stage 0; the presence of ground_truth is what
# makes a "recovery test" possible at all.

setClass("GroundTruth", representation("VIRTUAL"))

#' Ground truth for Stage 0/1 decomposition recovery tests
#' @export
setClass("SubspaceGroundTruth",
    contains = "GroundTruth",
    representation(
        shared    = "matrix",
        exclusive = "list",
        angles    = "numeric"
    )
)

#' Ground truth for Stage 0.5 archetype topology tests
#' @export
setClass("TopologyGroundTruth",
    contains = "GroundTruth",
    representation(
        topology   = "character",
        pseudotime = "numeric"
    )
)

#' Ground truth for Stage 2 quasi-potential recovery tests
#' @export
setClass("PotentialGroundTruth",
    contains = "GroundTruth",
    representation(
        potential = "function",
        wells     = "matrix",
        barrier   = "numeric"
    )
)

setClassUnion("GroundTruthOrNULL", c("GroundTruth", "NULL"))
