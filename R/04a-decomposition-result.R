# Typed container for Stage 1 decomposition output.
#
# Replaces the plain list previously stored at metadata()$stage1 with a class
# that is validated at construction time and accessed through named accessor
# functions (not string-indexed list fields).
#
# Accessor naming convention:  dr_<field>()
# Constructor:                 DecompositionResult()

#' Typed result of a Stage 1 decomposition
#'
#' @slot V_star   numeric -- shared gene axis for component 1 (backwards compat)
#' @slot sigma    numeric -- first singular value per layer (backwards compat)
#' @slot coords   list of numeric vectors -- component 1 coordinates per layer
#' @slot warnings character vector -- any BBP or convergence warnings
#' @slot V_k      matrix -- p x k gene loading matrix
#' @slot sigma_k  matrix -- K x k singular values per layer per component
#' @slot coords_k list of n x k matrices -- layer i component j coordinates
#' @slot k        integer -- number of components returned
#' @export
setClass("DecompositionResult",
    representation(
        V_star   = "numeric",
        sigma    = "numeric",
        coords   = "list",
        warnings = "character",
        V_k      = "matrix",
        sigma_k  = "matrix",
        coords_k = "list",
        k        = "integer"
    )
)

setValidity("DecompositionResult", function(object) {
    errs <- character()
    p <- length(object@V_star)
    if (p == 0L)
        errs <- c(errs, "V_star must be a non-empty numeric vector")
    k <- object@k
    if (length(k) != 1L || k < 1L)
        errs <- c(errs, "k must be a positive scalar integer")
    if (nrow(object@V_k) != p)
        errs <- c(errs, "V_k must have nrow == length(V_star)")
    if (ncol(object@V_k) != k)
        errs <- c(errs, "V_k must have ncol == k")
    if (ncol(object@sigma_k) != k)
        errs <- c(errs, "sigma_k must have ncol == k")
    if (length(object@sigma) != nrow(object@sigma_k))
        errs <- c(errs, "sigma length must equal nrow(sigma_k) (number of omic layers)")
    if (length(object@coords_k) != nrow(object@sigma_k))
        errs <- c(errs, "coords_k must have length == nrow(sigma_k)")
    if (length(errs)) errs else TRUE
})

#' Construct a validated DecompositionResult
#'
#' @param V_star   numeric p-vector
#' @param sigma    numeric K-vector
#' @param coords   list of K numeric n-vectors (component 1)
#' @param warnings character vector
#' @param V_k      p x k numeric matrix
#' @param sigma_k  K x k numeric matrix
#' @param coords_k list of K numeric n x k matrices
#' @param k        positive integer
#' @param x        a \code{DecompositionResult} (accessor functions only)
#' @return validated \code{DecompositionResult}
#' @export
DecompositionResult <- function(V_star, sigma, coords, warnings = character(),
                                 V_k, sigma_k, coords_k, k) {
    obj <- new("DecompositionResult",
        V_star   = as.numeric(V_star),
        sigma    = as.numeric(sigma),
        coords   = coords,
        warnings = as.character(warnings),
        V_k      = V_k,
        sigma_k  = sigma_k,
        coords_k = coords_k,
        k        = as.integer(k)
    )
    validObject(obj)
    obj
}

#' @rdname DecompositionResult
#' @export
dr_V_star   <- function(x) {
    if (!is(x, "DecompositionResult"))
        stop("dr_V_star() requires a DecompositionResult; got class '", class(x)[[1L]], "'")
    x@V_star
}
#' @rdname DecompositionResult
#' @export
dr_sigma    <- function(x) {
    if (!is(x, "DecompositionResult"))
        stop("dr_sigma() requires a DecompositionResult; got class '", class(x)[[1L]], "'")
    x@sigma
}
#' @rdname DecompositionResult
#' @export
dr_coords   <- function(x) {
    if (!is(x, "DecompositionResult"))
        stop("dr_coords() requires a DecompositionResult; got class '", class(x)[[1L]], "'")
    x@coords
}
#' @rdname DecompositionResult
#' @export
dr_warnings <- function(x) {
    if (!is(x, "DecompositionResult"))
        stop("dr_warnings() requires a DecompositionResult; got class '", class(x)[[1L]], "'")
    x@warnings
}
#' @rdname DecompositionResult
#' @export
dr_V_k      <- function(x) {
    if (!is(x, "DecompositionResult"))
        stop("dr_V_k() requires a DecompositionResult; got class '", class(x)[[1L]], "'")
    x@V_k
}
#' @rdname DecompositionResult
#' @export
dr_sigma_k  <- function(x) {
    if (!is(x, "DecompositionResult"))
        stop("dr_sigma_k() requires a DecompositionResult; got class '", class(x)[[1L]], "'")
    x@sigma_k
}
#' @rdname DecompositionResult
#' @export
dr_coords_k <- function(x) {
    if (!is(x, "DecompositionResult"))
        stop("dr_coords_k() requires a DecompositionResult; got class '", class(x)[[1L]], "'")
    x@coords_k
}
#' @rdname DecompositionResult
#' @export
dr_k        <- function(x) {
    if (!is(x, "DecompositionResult"))
        stop("dr_k() requires a DecompositionResult; got class '", class(x)[[1L]], "'")
    x@k
}

#' @rdname shared_axis
#' @export
setMethod("shared_axis", "DecompositionResult", function(x, j = 1L) {
    dr_V_k(x)[, j, drop = TRUE]
})
