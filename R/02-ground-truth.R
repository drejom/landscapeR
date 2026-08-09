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

#' Ground truth for heterogeneous Stage 1 sample-subspace recovery
#'
#' The shared, exclusive, and confounder slots contain sample-score matrices
#' (samples × rank). The response slots hold one feature-response matrix
#' (features × rank) per assay for the shared, exclusive, and confounder terms.
#' `missing_block_mechanism` records the generator's missing-block policy. It is
#' used only by Stage 0 prototype controls.
#' @export
setClass("HeterogeneousSubspaceGroundTruth",
    contains = "GroundTruth",
    representation(
        shared              = "matrix",
        exclusive              = "list",
        confounder             = "matrix",
        response               = "list",
        exclusive_response     = "list",
        confounder_response    = "list",
        missing_block_mechanism = "list"
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

#' Ground truth for the generic K=1 end-to-end double-well calibration control
#'
#' Keeps the planted feature subspace and quasi-potential answer keys together
#' so Stage 1 and Stage 2 can be assessed on the same synthetic object.
#' @export
setClass("K1DoubleWellGroundTruth",
    contains = "GroundTruth",
    representation(
        subspace = "SubspaceGroundTruth",
        potential = "PotentialGroundTruth"
    )
)

#' Ground truth for the AML-shaped K=1 longitudinal calibration control
#'
#' Keeps the planted feature subspace, sample scores, component identities, and
#' biological orientation together as one versioned answer key.
#'
#' @export
setClass("K1AmlLongitudinalGroundTruth",
    contains = "GroundTruth",
    representation(
        subspace = "SubspaceGroundTruth",
        sample_scores = "matrix",
        target_component = "integer",
        nuisance_component = "integer",
        target_orientation = "character"
    )
)

setValidity("K1AmlLongitudinalGroundTruth", function(object) {
    errors <- character()
    if (ncol(object@sample_scores) != 2L ||
            any(!is.finite(object@sample_scores))) {
        errors <- c(errors, "sample_scores must be a finite two-column matrix")
    }
    if (!identical(object@target_component, 2L))
        errors <- c(errors, "target_component must be component 2")
    if (!identical(object@nuisance_component, 1L))
        errors <- c(errors, "nuisance_component must be component 1")
    if (length(object@target_orientation) != 1L ||
            is.na(object@target_orientation) ||
            !nzchar(object@target_orientation)) {
        errors <- c(errors, "target_orientation must be one non-empty string")
    }
    if (length(errors)) errors else TRUE
})

setClassUnion("GroundTruthOrNULL", c("GroundTruth", "NULL"))
