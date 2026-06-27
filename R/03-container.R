#' Inter-stage container
#'
#' Subclasses \code{MultiAssayExperiment}. The three added slots carry
#' schema versioning, ordered provenance, and (for synthetic data) the
#' answer key. Everything else lives in the MAE slots or in
#' \code{S4Vectors::metadata()} as private scratch.
#'
#' @slot schema_version semver string, e.g. \code{"0.1.0"}
#' @slot provenance ordered list of \code{ProvenanceStep} objects
#' @slot ground_truth \code{GroundTruth} subclass or \code{NULL}
#'
#' @export
setClass(
    "StateTransitionData",
    contains = "MultiAssayExperiment",
    representation = representation(
        schema_version = "character",
        provenance     = "list",
        ground_truth   = "GroundTruthOrNULL"
    ),
    prototype = prototype(
        schema_version = "0.1.0",   # literal to avoid forward-reference to SCHEMA_VERSION
        provenance     = list(),
        ground_truth   = NULL
    )
)

setValidity("StateTransitionData", function(object) {
    errs <- character()
    if (!grepl("^[0-9]+\\.[0-9]+\\.[0-9]+$", object@schema_version))
        errs <- c(errs, "schema_version must be semver MAJOR.MINOR.PATCH")
    if (!is.list(object@provenance))
        errs <- c(errs, "provenance must be a list")
    if (length(errs)) errs else TRUE
})

# Coerce from MAE — used by the StateTransitionData() constructor below.
setAs("MultiAssayExperiment", "StateTransitionData", function(from) {
    new("StateTransitionData", from,
        schema_version = SCHEMA_VERSION,
        provenance     = list(),
        ground_truth   = NULL)
})

#' Construct a StateTransitionData object
#'
#' Thin wrapper around \code{MultiAssayExperiment()} that adds the required
#' slots. All MAE arguments are forwarded.
#'
#' @param experiments list or ExperimentList (passed to MAE)
#' @param colData DataFrame of sample-level metadata
#' @param ground_truth a \code{GroundTruth} object, or \code{NULL}
#' @param ... additional arguments forwarded to \code{MultiAssayExperiment()}
#' @return a validated \code{StateTransitionData} object
#' @export
StateTransitionData <- function(experiments = list(),
                                 colData     = S4Vectors::DataFrame(),
                                 ground_truth = NULL,
                                 ...) {
    mae <- MultiAssayExperiment(
        experiments = experiments,
        colData     = colData,
        ...
    )
    obj <- as(mae, "StateTransitionData")
    if (!is.null(ground_truth)) obj@ground_truth <- ground_truth
    validObject(obj)
    obj
}

# ---------------------------------------------------------------------------
# Migration machinery
# ---------------------------------------------------------------------------

.migrations <- new.env(parent = emptyenv())

#' Register a schema migration function
#'
#' @param from character source schema version
#' @param to character target schema version
#' @param fn function(StateTransitionData) -> StateTransitionData
#' @return invisible NULL
#' @export
register_migration <- function(from, to, fn) {
    assign(paste(from, to, sep = "->"), fn, envir = .migrations)
    invisible(NULL)
}

#' Migrate a StateTransitionData object to a target schema version
#'
#' Follows the registered chain of migration steps. Fails loudly if no path
#' exists (the UpdateSeuratObject pattern).
#'
#' @param object StateTransitionData
#' @param target character target schema version (default: \code{SCHEMA_VERSION})
#' @return StateTransitionData at target schema version
#' @export
migrate <- function(object, target = SCHEMA_VERSION) {
    current <- object@schema_version
    if (identical(current, target)) return(object)
    key <- paste(current, target, sep = "->")
    if (!exists(key, envir = .migrations, inherits = FALSE))
        stop(sprintf(
            "No migration registered from schema %s to %s. Call register_migration() first.",
            current, target
        ))
    get(key, envir = .migrations)(object)
}
