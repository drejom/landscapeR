#' Provenance step recorded by each stage
#'
#' @slot stage stage name, e.g. \code{"decompose"}
#' @slot contract contract class name, e.g. \code{"Decomposer"}
#' @slot implementation registered implementation name
#' @slot pkg_version package version at time of run
#' @slot params parameter list used
#' @slot input_hashes named character vector of \code{digest::digest} hashes
#' @slot rng_seed integer RNG state captured before stage ran
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

#' Append a provenance step to a StateTransitionData object
#'
#' @param data StateTransitionData
#' @param stage character stage name
#' @param contract character contract class name
#' @param implementation character implementation name
#' @param params list of parameters used
#' @param input_hashes named character vector of pre-stage input hashes
#' @param status character \code{"success"} or \code{"failure"}
#' @return StateTransitionData with provenance appended
#' @export
record_provenance <- function(data, stage, contract, implementation,
                               params = list(),
                               input_hashes = c(data = digest::digest(data)),
                               status = "success") {
    seed <- if (exists(".Random.seed", envir = globalenv()))
        get(".Random.seed", envir = globalenv())
    else
        integer(0)

    step <- new("ProvenanceStep",
        stage          = stage,
        contract       = contract,
        implementation = implementation,
        pkg_version    = as.character(utils::packageVersion("landscapeR")),
        params         = params,
        input_hashes   = input_hashes,
        rng_seed       = as.integer(seed),
        timestamp      = as.POSIXct(NA),
        status         = status
    )
    data@provenance <- c(data@provenance, list(step))
    data
}
