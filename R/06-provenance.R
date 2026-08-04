#' Provenance step recorded by each stage
#'
#' @slot stage stage name, e.g. \code{"decompose"}
#' @slot contract contract class name, e.g. \code{"Decomposer"}
#' @slot implementation registered implementation name
#' @slot pkg_version package version at time of run
#' @slot params parameter list used
#' @slot input_hashes named character vector of \code{digest::digest} hashes
#' @slot rng_seed deprecated compatibility slot; new records store no ambient
#'   RNG state because an incidental \code{.Random.seed} is not a replay
#'   contract. Declared seed/stream identity belongs in \code{params$rng}.
#' @slot timestamp POSIXct legacy compatibility field; always \code{NA} in deterministic provenance
#' @slot status \code{"success"} or \code{"failure"}
#'
#' @export
setClass("ProvenanceStep",
    representation(
        stage          = "character",
        contract       = "character",
        implementation = "character",
        pkg_version    = "character",
        params         = "list",
        input_hashes   = "character",
        rng_seed       = "integer",
        timestamp      = "POSIXct",
        status         = "character"
    )
)

setValidity("ProvenanceStep", function(object) {
    errs <- character()
    if (!length(object@input_hashes) || is.null(names(object@input_hashes)) ||
            anyNA(names(object@input_hashes)) ||
            any(!nzchar(names(object@input_hashes))) ||
            anyNA(object@input_hashes) || any(!nzchar(object@input_hashes))) {
        errs <- c(errs, paste0(
            "input_hashes must be a non-empty named character vector of ",
            "scientifically scoped pre-stage hashes"
        ))
    }
    if (length(errs)) errs else TRUE
})

#' Append a provenance step to a StateTransitionData object
#'
#' @param data StateTransitionData
#' @param stage character stage name
#' @param contract character contract class name
#' @param implementation character implementation name
#' @param params list of parameters used
#' @param input_hashes required named character vector of scientifically scoped
#'   pre-stage input hashes. Callers, rather than this recorder, define which
#'   inputs constitute the scientific operation.
#' @param rng optional declared RNG identity list. For repeated work this
#'   should contain the run seed, RNG kind, seed-derivation scheme, and stable
#'   task or stream identity needed to reproduce the draw. Ambient RNG state is
#'   deliberately not captured.
#' @param status character \code{"success"} or \code{"failure"}
#' @return StateTransitionData with provenance appended
#' @export
record_provenance <- function(data, stage, contract, implementation,
                               params = list(),
                               input_hashes,
                               rng = NULL,
                               status = "success") {
    if (missing(input_hashes))
        .stop_landscapeR_validation(paste0(
            "record_provenance(): input_hashes must be supplied explicitly by ",
            "the scientific caller"
        ))
    if (!is.character(input_hashes))
        .stop_landscapeR_validation(
            "record_provenance(): input_hashes must be character"
        )
    if (!is.null(rng)) {
        if (!is.list(rng) || !length(rng) || is.null(names(rng)) ||
                any(!nzchar(names(rng)))) {
            .stop_landscapeR_validation(paste0(
                "record_provenance(): rng must be NULL or a non-empty named ",
                "list describing the declared seed or stream identity"
            ))
        }
        params$rng <- rng
    }
    if (is(data, "StateTransitionData"))
        params$sampling_design <- .sampling_design_provenance(data@sampling_design)

    step <- new("ProvenanceStep",
        stage          = stage,
        contract       = contract,
        implementation = implementation,
        pkg_version    = as.character(utils::packageVersion("landscapeR")),
        params         = params,
        input_hashes   = input_hashes,
        rng_seed       = integer(0L),
        timestamp      = as.POSIXct(NA),
        status         = status
    )
    validObject(step)
    data@provenance <- c(data@provenance, list(step))
    data
}
