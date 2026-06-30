#' Validate a StateTransitionData object at a stage boundary
#'
#' Runs at every stage entry. Three outcomes:
#' \enumerate{
#'   \item Proceed — schema matches, invariants hold.
#'   \item Auto-migrate — a registered migration path exists.
#'   \item Typed failure — returns a \code{StageResult} with status
#'         \code{"failure"} rather than throwing.
#' }
#'
#' @param data StateTransitionData (or anything, to catch type errors early)
#' @param required_schema character required schema version
#' @param stage character stage name used in error messages
#' @return \code{StateTransitionData} (possibly migrated) on success;
#'   \code{StageResult} with \code{status = "failure"} on failure
#' @keywords internal
validate_boundary <- function(data,
                               required_schema = SCHEMA_VERSION,
                               stage = "unknown") {
    if (!is(data, "StateTransitionData"))
        return(stage_failure(sprintf(
            "[%s] expected StateTransitionData, got %s",
            stage, paste(class(data), collapse = "/")
        )))

    current <- data@schema_version

    if (identical(current, required_schema))
        return(data)

    migrated <- tryCatch(
        migrate(data, target = required_schema),
        error = function(e) e
    )

    if (inherits(migrated, "error"))
        return(stage_failure(sprintf(
            "[%s] schema mismatch: object is v%s, stage needs v%s -- %s",
            stage, current, required_schema, conditionMessage(migrated)
        )))

    migrated
}
