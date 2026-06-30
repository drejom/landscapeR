#' Typed result returned by every stage function
#'
#' Stages return this instead of throwing on failure so a struggling stage
#' cannot silently emit valid-looking output.
#'
#' @slot status \code{"success"} or \code{"failure"}
#' @slot value annotated \code{StateTransitionData} on success; \code{NULL} on failure
#' @slot reason diagnostic string on failure; \code{""} on success
#' @slot provenance provenance metadata recorded by this stage
#'
#' @export
setClass("StageResult",
    representation(
        status     = "character",
        value      = "ANY",
        reason     = "character",
        provenance = "list"
    ),
    prototype = prototype(
        status     = "success",
        value      = NULL,
        reason     = "",
        provenance = list()
    )
)

setValidity("StageResult", function(object) {
    if (!object@status %in% c("success", "failure"))
        "status must be 'success' or 'failure'"
    else
        TRUE
})

#' Construct a successful StageResult
#' @param value Annotated \code{StateTransitionData} returned by the stage.
#' @param provenance List of provenance records.
#' @return A \code{StageResult} with \code{status = "success"}.
#' @export
stage_success <- function(value, provenance = list()) {
    new("StageResult", status = "success", value = value,
        reason = "", provenance = provenance)
}

#' Construct a failed StageResult
#' @param reason Diagnostic string explaining the failure.
#' @param provenance List of provenance records.
#' @return A \code{StageResult} with \code{status = "failure"}.
#' @export
stage_failure <- function(reason, provenance = list()) {
    new("StageResult", status = "failure", value = NULL,
        reason = as.character(reason), provenance = provenance)
}
