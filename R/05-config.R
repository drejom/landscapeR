#' Pipeline configuration
#'
#' One \code{PipelineConfig} = one reproducible run. Algorithms and parameters
#' are data, not code — changing a run means changing a config object, not
#' editing source.
#'
#' Every \code{PipelineConfig} requires an explicit
#' \code{\linkS4class{AnalysisSpecification}}.  Construct one with
#' \code{\link{analysis_specification}} and supply it via the \code{analysis}
#' argument.  There is no null/unspecified fallback.
#'
#' @slot strategies named list: contract name -> implementation name
#' @slot params named list: implementation name -> parameter list
#' @slot dataset character identifier for the input dataset
#' @slot analysis validated \code{\linkS4class{AnalysisSpecification}} for this run
#'
#' @export
setClass("PipelineConfig",
    representation(
        strategies = "list",
        params     = "list",
        dataset    = "character",
        analysis   = "AnalysisSpecification"
    ),
    prototype = prototype(
        strategies = list(),
        params     = list(),
        dataset    = ""
    )
)

setValidity("PipelineConfig", function(object) {
    errs <- character()
    if (length(object@dataset) != 1L || is.na(object@dataset) ||
            !nzchar(trimws(object@dataset)))
        errs <- c(errs, "dataset must be a non-empty string")
    for (field in c("strategies", "params")) {
        value <- methods::slot(object, field)
        if (length(value) && (is.null(names(value)) ||
                anyNA(names(value)) || any(!nzchar(names(value))) ||
                anyDuplicated(names(value)))) {
            errs <- c(errs, sprintf(
                "%s must have unique non-empty names", field
            ))
        }
    }
    if (length(object@strategies)) {
        valid_strategy <- vapply(object@strategies, function(value) {
            is.character(value) && length(value) == 1L &&
                !is.na(value) && nzchar(trimws(value))
        }, logical(1L))
        if (!all(valid_strategy))
            errs <- c(errs, "strategies values must be non-empty strings")
    }
    if (length(object@params) &&
            !all(vapply(object@params, is.list, logical(1L))))
        errs <- c(errs, "params values must be lists")
    spec_valid <- tryCatch(validObject(object@analysis, test = TRUE),
                           error = function(e) conditionMessage(e))
    if (!isTRUE(spec_valid))
        errs <- c(errs, paste0("invalid analysis specification: ", spec_valid))
    if (length(errs)) errs else TRUE
})

#' Construct a pipeline configuration
#'
#' This is the supported construction boundary for a reproducible pipeline
#' run. It avoids direct S4 slot assembly while preserving the configuration as
#' an inspectable value object.
#'
#' @param dataset one non-empty dataset identifier
#' @param analysis a validated \code{\linkS4class{AnalysisSpecification}}
#' @param strategies named list mapping contract names to registered strategy
#'   names
#' @param params named list mapping strategy names to parameter lists
#' @return a validated \code{PipelineConfig}
#' @examples
#' cfg <- PipelineConfig(
#'     dataset = "example",
#'     analysis = analysis_specification(
#'         id = "example-target",
#'         target_field = "condition",
#'         target_type = "binary",
#'         reference_level = "control",
#'         comparison_level = "treated"
#'     ),
#'     strategies = list(Decomposer = "svd"),
#'     params = list(svd = list())
#' )
#' @export
PipelineConfig <- function(dataset, analysis, strategies = list(), params = list()) {
    obj <- .with_landscapeR_validation(new(
        "PipelineConfig",
        dataset = dataset,
        analysis = analysis,
        strategies = strategies,
        params = params
    ))
    .with_landscapeR_validation(validObject(obj))
    obj
}
