# Algorithm implementation registry.
# Algorithms self-register under their contract on package load. The pipeline
# resolves them by name — no switch statements, no central dispatcher to edit.

.registry <- new.env(parent = emptyenv())

#' Register an algorithm implementation under a stage contract
#'
#' @param contract character contract class name (e.g. \code{"Decomposer"})
#' @param name character unique implementation name
#' @param constructor function(params_list) -> contract-class instance
#' @return invisible NULL
#' @export
register_strategy <- function(contract, name, constructor) {
    assign(paste(contract, name, sep = ":"), constructor, envir = .registry)
    invisible(NULL)
}

#' Retrieve an implementation constructor from the registry
#'
#' @param contract character contract class name
#' @param name character implementation name
#' @return constructor function
#' @export
get_strategy <- function(contract, name) {
    key <- paste(contract, name, sep = ":")
    if (!exists(key, envir = .registry, inherits = FALSE))
        stop(sprintf(
            "No implementation '%s' registered for contract '%s'.",
            name, contract
        ))
    get(key, envir = .registry)
}

#' List registered implementations, optionally filtered by contract
#'
#' @param contract character contract name to filter by, or \code{NULL} for all
#' @return character vector of keys (\code{"Contract:name"})
#' @export
list_strategies <- function(contract = NULL) {
    keys <- ls(.registry)
    if (!is.null(contract))
        keys <- grep(paste0("^", contract, ":"), keys, value = TRUE)
    keys
}
