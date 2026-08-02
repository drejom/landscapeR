# Common package validation conditions

.stop_landscapeR_validation <- function(message, call = sys.call(-1L)) {
    stop(structure(
        list(message = message, call = call),
        class = c("landscapeR_validation_error", "error", "condition")
    ))
}

.with_landscapeR_validation <- function(expr) {
    tryCatch(
        force(expr),
        error = function(error) {
            if (inherits(error, "landscapeR_validation_error")) stop(error)
            .stop_landscapeR_validation(
                conditionMessage(error),
                call = sys.call(-1L)
            )
        }
    )
}
