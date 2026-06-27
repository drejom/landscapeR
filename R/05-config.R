#' Pipeline configuration
#'
#' One \code{PipelineConfig} = one reproducible run. Algorithms and parameters
#' are data, not code — changing a run means changing a config object, not
#' editing source.
#'
#' @slot strategies named list: contract name -> implementation name
#' @slot params named list: implementation name -> parameter list
#' @slot dataset character identifier for the input dataset
#'
#' @export
setClass("PipelineConfig",
    representation(
        strategies = "list",
        params     = "list",
        dataset    = "character"
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
    if (length(errs)) errs else TRUE
})
