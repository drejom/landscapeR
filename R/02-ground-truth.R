# Ground-truth classes — present on synthetic data, NULL on real data.
# Validated by the harness in Stage 0; the presence of ground_truth is what
# makes a "recovery test" possible at all.

setClass("GroundTruth", representation("VIRTUAL"))

#' @export
setClass("SubspaceGroundTruth",        # Stage-0/1 decomposition controls
    contains = "GroundTruth",
    representation(
        shared    = "matrix",
        exclusive = "list",
        angles    = "numeric"
    )
)

#' @export
setClass("TopologyGroundTruth",        # Stage-0.5 archetype dictionary
    contains = "GroundTruth",
    representation(
        topology   = "character",
        pseudotime = "numeric"
    )
)

#' @export
setClass("PotentialGroundTruth",       # Stage-2 dynamics controls
    contains = "GroundTruth",
    representation(
        potential = "function",
        wells     = "matrix",
        barrier   = "numeric"
    )
)

setClassUnion("GroundTruthOrNULL", c("GroundTruth", "NULL"))
