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
    if (nchar(object@dataset) == 0)
        errs <- c(errs, "dataset must be a non-empty string")
    spec_valid <- tryCatch(validObject(object@analysis, test = TRUE),
                           error = function(e) conditionMessage(e))
    if (!isTRUE(spec_valid))
        errs <- c(errs, paste0("invalid analysis specification: ", spec_valid))
    if (length(errs)) errs else TRUE
})
