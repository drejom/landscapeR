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

.require_decomposition_result <- function(x, caller) {
    if (!is(x, "DecompositionResult")) {
        .stop_landscapeR_validation(sprintf(
            "%s requires a DecompositionResult; got class '%s'",
            caller,
            class(x)[[1L]]
        ))
    }
    x
}

#' @rdname DecompositionResult
#' @export
dr_V_star   <- function(x) {
    .require_decomposition_result(x, "dr_V_star()")@V_star
}
#' @rdname DecompositionResult
#' @export
dr_sigma    <- function(x) {
    .require_decomposition_result(x, "dr_sigma()")@sigma
}
#' @rdname DecompositionResult
#' @export
dr_coords   <- function(x) {
    .require_decomposition_result(x, "dr_coords()")@coords
}
#' @rdname DecompositionResult
#' @export
dr_warnings <- function(x) {
    .require_decomposition_result(x, "dr_warnings()")@warnings
}
#' @rdname DecompositionResult
#' @export
dr_V_k      <- function(x) {
    .require_decomposition_result(x, "dr_V_k()")@V_k
}
#' @rdname DecompositionResult
#' @export
dr_sigma_k  <- function(x) {
    .require_decomposition_result(x, "dr_sigma_k()")@sigma_k
}
#' @rdname DecompositionResult
#' @export
dr_coords_k <- function(x) {
    .require_decomposition_result(x, "dr_coords_k()")@coords_k
}
#' @rdname DecompositionResult
#' @export
dr_k        <- function(x) {
    .require_decomposition_result(x, "dr_k()")@k
}

#' Access a typed pipeline-stage result
#'
#' Stage artifacts are physically stored in container metadata for schema
#' compatibility. These helpers are the supported semantic boundary: callers
#' do not need to know the storage key, and Stage 1 values are type checked.
#'
#' @param data a \code{StateTransitionData}
#' @param stage one of \code{"stage1"} or \code{"stage2"}
#' @param required whether absence is an error; when \code{FALSE}, absent
#'   stages return \code{NULL}
#' @return the stored stage value, or \code{NULL} when absent and optional
#' @export
stage_result <- function(data, stage = c("stage1", "stage2"), required = TRUE) {
    if (!is(data, "StateTransitionData")) {
        .stop_landscapeR_validation(sprintf(
            "stage_result() requires StateTransitionData; got class '%s'",
            class(data)[[1L]]
        ))
    }
    stage <- .with_landscapeR_validation(match.arg(stage))
    if (!is.logical(required) || length(required) != 1L || is.na(required))
        .stop_landscapeR_validation("required must be TRUE or FALSE")
    value <- S4Vectors::metadata(data)[[stage]]
    if (is.null(value)) {
        if (required) {
            .stop_landscapeR_validation(sprintf(
                "%s result is not available", stage
            ))
        }
        return(NULL)
    }
    if (identical(stage, "stage1"))
        .require_decomposition_result(value, "stage_result(stage = 'stage1')")
    value
}

#' @rdname stage_result
#' @return \code{TRUE} when the requested stage value is present
#' @export
has_stage_result <- function(data, stage = c("stage1", "stage2")) {
    !is.null(stage_result(data, stage = stage, required = FALSE))
}

#' @rdname shared_axis
#' @export
setMethod("shared_axis", "DecompositionResult", function(x, j = 1L) {
    dr_V_k(x)[, j, drop = TRUE]
})
