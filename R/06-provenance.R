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

.validate_run_seed <- function(run_seed) {
    if (!is.numeric(run_seed) || length(run_seed) != 1L || is.na(run_seed) ||
        !is.finite(run_seed) || run_seed < 0 ||
        run_seed > .Machine$integer.max || run_seed != floor(run_seed)) {
        .stop_landscapeR_validation(
            "run seed must be one finite non-negative integer"
        )
    }
    as.integer(run_seed)
}

.validate_rng_identity <- function(rng) {
    required <- c("run_seed", "rng_kind", "seed_derivation", "task_id")
    if (!is.list(rng) || is.null(names(rng)) ||
            anyNA(names(rng)) || any(!nzchar(names(rng))) ||
            anyDuplicated(names(rng)) || !all(required %in% names(rng))) {
        .stop_landscapeR_validation(paste0(
            "record_provenance(): rng must be a uniquely named list containing ",
            paste(required, collapse = ", ")
        ))
    }
    .validate_run_seed(rng$run_seed)
    for (field in required[-1L]) {
        value <- rng[[field]]
        if (!is.character(value) || length(value) != 1L ||
                is.na(value) || !nzchar(trimws(value))) {
            .stop_landscapeR_validation(sprintf(
                "record_provenance(): rng$%s must be one non-empty string",
                field
            ))
        }
    }
    if (!is.null(rng$streams)) {
        streams <- rng$streams
        if (!is.numeric(streams) || !length(streams) || anyNA(streams) ||
                any(!is.finite(streams)) || any(streams < 0) ||
                any(streams > .Machine$integer.max) ||
                any(streams != as.integer(streams)) ||
                is.null(names(streams)) || anyNA(names(streams)) ||
                any(!nzchar(names(streams))) || anyDuplicated(names(streams))) {
            .stop_landscapeR_validation(paste0(
                "record_provenance(): rng$streams must be a non-empty, ",
                "uniquely named vector of non-negative integer seeds"
            ))
        }
    }
    rng
}

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
#' @param rng optional declared RNG identity list. Stochastic callers must
#'   provide code{run_seed}, code{rng_kind}, code{seed_derivation}, and
#'   code{task_id}; multi-stream operations also provide a uniquely named
#'   integer code{streams} vector. Ambient RNG state is deliberately not
#'   captured.
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
        params$rng <- .validate_rng_identity(rng)
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
