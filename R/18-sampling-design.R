# Issue #26 — Sampling-design declaration (ADR 0006)
#
# Adds a versioned SamplingDesign S4 object that travels with StateTransitionData
# and drives capability gating in DynamicsEstimator strategies.
#
# Public interface:
#   cross_sectional()                        — construct a cross-sectional design
#   longitudinal(subject_id, time, ...)       — construct a longitudinal design
#   declare_sampling_design(data, design)     — attach design to container
#   supported_sampling_designs(strategy)      — capability query (generic)
#
# The "unspecified" kind is migration-only; users cannot construct it directly.

# ---------------------------------------------------------------------------
# SamplingDesign class
# ---------------------------------------------------------------------------

#' Versioned sampling-design declaration
#'
#' A `SamplingDesign` object is a lightweight, versioned declaration that
#' travels with a `StateTransitionData` container.  It describes how samples
#' were collected (cross-sectional or longitudinal) and names the
#' `colData` columns that carry subject identity and ordered time when
#' applicable.
#'
#' Users construct designs with \code{\link{cross_sectional}} or
#' \code{\link{longitudinal}}.  The `"unspecified"` kind is created only by
#' the schema migration machinery (see `R/03-container.R`).
#'
#' @slot version  schema version of this object, initially `"1.0.0"`
#' @slot kind     one of `"unspecified"`, `"cross_sectional"`, or `"longitudinal"`
#' @slot subject_id_col  zero-or-one `colData` column name for subject identity
#' @slot time_col        zero-or-one `colData` column name for ordered time
#' @slot time_unit       optional scalar description of the time unit
#'
#' @export
setClass("SamplingDesign",
    representation(
        version        = "character",
        kind           = "character",
        subject_id_col = "character",
        time_col       = "character",
        time_unit      = "character"
    ),
    prototype = prototype(
        version        = "1.0.0",
        kind           = "unspecified",
        subject_id_col = character(0L),
        time_col       = character(0L),
        time_unit      = character(0L)
    )
)

setValidity("SamplingDesign", function(object) {
    errs <- character()

    allowed_kinds <- c("unspecified", "cross_sectional", "longitudinal")
    if (length(object@version) != 1L || !identical(object@version, "1.0.0"))
        errs <- c(errs, "SamplingDesign@version must be '1.0.0'")
    if (length(object@kind) != 1L || !object@kind %in% allowed_kinds)
        errs <- c(errs, paste0(
            "SamplingDesign@kind must be one of: ",
            paste(allowed_kinds, collapse = ", ")
        ))

    if (identical(object@kind, "cross_sectional")) {
        if (length(object@subject_id_col) > 0L)
            errs <- c(errs, "cross_sectional design must not specify subject_id_col")
        if (length(object@time_col) > 0L)
            errs <- c(errs, "cross_sectional design must not specify time_col")
        if (length(object@time_unit) > 0L)
            errs <- c(errs, "cross_sectional design must not specify time_unit")
    }

    if (identical(object@kind, "longitudinal")) {
        if (length(object@subject_id_col) != 1L || nchar(object@subject_id_col) == 0L)
            errs <- c(errs, "longitudinal design requires a non-empty subject_id_col")
        if (length(object@time_col) != 1L || nchar(object@time_col) == 0L)
            errs <- c(errs, "longitudinal design requires a non-empty time_col")
        if (identical(object@subject_id_col, object@time_col))
            errs <- c(errs, "subject_id_col and time_col must be distinct")
    }

    if (length(object@time_unit) > 1L ||
        (length(object@time_unit) == 1L && nchar(object@time_unit) == 0L))
        errs <- c(errs, "time_unit must be NULL or one non-empty string")

    if (length(errs)) errs else TRUE
})

# ---------------------------------------------------------------------------
# Public constructors
# ---------------------------------------------------------------------------

#' Declare a cross-sectional sampling design
#'
#' Each observation is an independent sample; no subject or time structure is
#' declared.  `kde_logdensity` and other cross-sectional estimators accept this
#' design.
#'
#' @return a validated \code{SamplingDesign} object
#' @export
cross_sectional <- function() {
    obj <- new("SamplingDesign",
        version        = "1.0.0",
        kind           = "cross_sectional",
        subject_id_col = character(0L),
        time_col       = character(0L),
        time_unit      = character(0L)
    )
    validObject(obj)
    obj
}

#' Declare a longitudinal sampling design
#'
#' Identifies the `colData` columns carrying subject identity and ordered
#' measurement time.  A future longitudinal `DynamicsEstimator` will consume
#' these columns; cross-sectional estimators will reject this design at the
#' capability gate.
#'
#' Column existence and distinctness are checked here.  Subject IDs and time
#' values are validated by \code{\link{declare_sampling_design}} against the
#' actual `colData`.
#'
#' @param subject_id character name of the `colData` column containing subject IDs
#' @param time      character name of the `colData` column containing ordered time
#' @param time_unit optional character description of the time unit (e.g. `"days"`)
#' @return a validated \code{SamplingDesign} object
#' @export
longitudinal <- function(subject_id, time, time_unit = character(0L)) {
    if (!is.character(subject_id) || length(subject_id) != 1L || nchar(subject_id) == 0L)
        stop("longitudinal(): subject_id must be a single non-empty character string")
    if (!is.character(time) || length(time) != 1L || nchar(time) == 0L)
        stop("longitudinal(): time must be a single non-empty character string")
    if (identical(subject_id, time))
        stop("longitudinal(): subject_id and time must be distinct column names")

    obj <- new("SamplingDesign",
        version        = "1.0.0",
        kind           = "longitudinal",
        subject_id_col = subject_id,
        time_col       = time,
        time_unit      = if (length(time_unit) == 1L && nchar(time_unit) > 0L)
                             time_unit
                         else
                             character(0L)
    )
    validObject(obj)
    obj
}

# ---------------------------------------------------------------------------
# Data-dependent validation
# ---------------------------------------------------------------------------

.validate_sampling_design_data <- function(data) {
    design <- data@sampling_design
    if (!identical(design@kind, "longitudinal")) return(TRUE)

    cd <- as.data.frame(colData(data))
    sid_col  <- design@subject_id_col
    time_col <- design@time_col
    if (!sid_col %in% colnames(cd))
        return(sprintf("subject_id_col '%s' not found in colData", sid_col))
    if (!time_col %in% colnames(cd))
        return(sprintf("time_col '%s' not found in colData", time_col))

    sid_vals <- cd[[sid_col]]
    if (any(is.na(sid_vals))) return("subject_id_col contains NA values")
    time_vals <- cd[[time_col]]
    if (any(is.na(time_vals))) return("time_col contains NA values")
    if (!is.numeric(time_vals) &&
        !inherits(time_vals, c("Date", "POSIXct", "POSIXlt")) &&
        !is.ordered(time_vals))
        return("time_col must be numeric, Date/POSIXct, or ordered")
    if (any(duplicated(data.frame(subject = sid_vals, time = time_vals))))
        return("duplicate subject/time observations are not supported")
    has_repeats <- any(tapply(time_vals, sid_vals, function(tv)
        length(unique(tv))) > 1L)
    if (!has_repeats)
        return("longitudinal design requires at least one subject with distinct repeated time points")
    TRUE
}

# ---------------------------------------------------------------------------
# declare_sampling_design()
# ---------------------------------------------------------------------------

#' Attach a sampling design to a StateTransitionData container
#'
#' Returns a new `StateTransitionData` with the declared design stored in the
#' `sampling_design` slot.  Does not mutate the caller's object.
#'
#' For a `longitudinal` design, the referenced columns must exist in `colData`;
#' subject IDs must be non-missing and at least one subject must have distinct
#' repeated time points.
#'
#' @param data   a \code{StateTransitionData} object
#' @param design a \code{SamplingDesign} from \code{\link{cross_sectional}} or
#'   \code{\link{longitudinal}}
#' @return a new \code{StateTransitionData} with `sampling_design` set
#' @export
declare_sampling_design <- function(data, design) {
    if (!is(data, "StateTransitionData"))
        stop("declare_sampling_design(): data must be a StateTransitionData object")
    if (!is(design, "SamplingDesign"))
        stop("declare_sampling_design(): design must be a SamplingDesign object")
    if (identical(design@kind, "unspecified"))
        stop("declare_sampling_design(): 'unspecified' is a migration-only kind; ",
             "use cross_sectional() or longitudinal()")

    data@sampling_design <- design
    data_valid <- .validate_sampling_design_data(data)
    if (!isTRUE(data_valid))
        stop("declare_sampling_design(): ", data_valid)
    validObject(data)
    data
}

# ---------------------------------------------------------------------------
# supported_sampling_designs() — capability generic
# ---------------------------------------------------------------------------

#' Query the sampling designs supported by a DynamicsEstimator strategy
#'
#' Each concrete `DynamicsEstimator` implementation must provide a method for
#' this generic declaring which `SamplingDesign` kinds it can process.  The
#' structural `estimate_dynamics()` gate uses this to reject incompatible
#' designs before any strategy-specific code runs.
#'
#' @param strategy a \code{DynamicsEstimator} implementation
#' @return character vector of supported kind strings, e.g. `"cross_sectional"`
#' @export
setGeneric("supported_sampling_designs",
    function(strategy) standardGeneric("supported_sampling_designs"))

# ---------------------------------------------------------------------------
# Helper: canonical sampling-design list for provenance
# ---------------------------------------------------------------------------

#' Produce a serialisable list summary of a SamplingDesign for provenance
#'
#' @param design a \code{SamplingDesign} object
#' @return named list suitable for inclusion in a provenance record
#' @keywords internal
.sampling_design_provenance <- function(design) {
    list(
        version        = design@version,
        kind           = design@kind,
        subject_id_col = if (length(design@subject_id_col)) design@subject_id_col else NA_character_,
        time_col       = if (length(design@time_col))       design@time_col        else NA_character_,
        time_unit      = if (length(design@time_unit))      design@time_unit       else NA_character_
    )
}
