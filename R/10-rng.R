#' Set up reproducible parallel-safe RNG
#'
#' Sets L'Ecuyer-CMRG so parallel streams (via targets / future) are
#' reproducible. Call once at the start of a pipeline run. Retrofitting this
#' later is painful; it is designed in from the start.
#'
#' @param seed integer global seed
#' @return invisible NULL
#' @export
setup_rng <- function(seed) {
    RNGkind("L'Ecuyer-CMRG")
    set.seed(seed)
    invisible(NULL)
}
