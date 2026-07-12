# Issue #28 — AnalysisSpecification (ADR 0008)
#
# A compact, versioned declaration that expresses scientific intent for exactly
# one target-axis run.  It is stored on PipelineConfig, not on the container,
# because the same dataset may support separate biological questions.
#
# Public interface:
#   analysis_specification(id, target_field, manual_component,
#                          nuisance_fields, orientation_anchor, claim_intent)
#   canonical_digest(spec)                  — reproducible sha256 of the spec
#
# Internal helpers:
#   .analysis_spec_provenance(spec)         — serialisable list for provenance

# ---------------------------------------------------------------------------
# AnalysisSpecification class
# ---------------------------------------------------------------------------

#' Versioned analysis specification for one target-axis run
#'
#' An `AnalysisSpecification` expresses scientific intent for exactly one
#' reproducible run.  It is attached to \code{\linkS4class{PipelineConfig}}, not to
#' the data container, because the same \code{StateTransitionData} may support
#' separate biological questions.
#'
#' The spec names one target axis (either a `colData` field proposed for
#' component selection, or an explicit manual component index already chosen
#' after review), zero or more nuisance variables, an optional orientation
#' anchor, and the claim intent of the run.
#'
#' Use \code{\link{analysis_specification}} to construct validated objects;
#' do not call \code{new("AnalysisSpecification")} directly.
#'
#' @slot version         schema version, always \code{"1.0.0"}
#' @slot id              non-empty run identity string
#' @slot target_field    zero-or-one \code{colData} field name proposed for
#'   component selection (proposal only — does not select a component)
#' @slot manual_component  zero-or-one positive integer: an explicit component
#'   index chosen after reviewing the Stage 1 component gallery
#' @slot nuisance_fields unique character vector of metadata field names to
#'   treat as confounders
#' @slot orientation_anchor  zero-or-one \code{colData} field name providing
#'   an orientation convention for the selected axis; must not duplicate a
#'   target or nuisance role
#' @slot claim_intent    \code{"exploratory"} or \code{"primary_confirmatory"}
#'
#' @seealso \code{\link{analysis_specification}}, \code{\link{canonical_digest}}
#' @export
setClass("AnalysisSpecification",
    representation(
        version            = "character",
        id                 = "character",
        target_field       = "character",
        manual_component   = "integer",
        nuisance_fields    = "character",
        orientation_anchor = "character",
        claim_intent       = "character"
    ),
    prototype = prototype(
        version            = "1.0.0",
        id                 = character(0L),
        target_field       = character(0L),
        manual_component   = integer(0L),
        nuisance_fields    = character(0L),
        orientation_anchor = character(0L),
        claim_intent       = "exploratory"
    )
)

setValidity("AnalysisSpecification", function(object) {
    errs <- character()

    # version
    if (!identical(object@version, "1.0.0"))
        errs <- c(errs, "AnalysisSpecification@version must be '1.0.0'")

    # id
    if (length(object@id) != 1L || nchar(object@id) == 0L)
        errs <- c(errs, "id must be a single non-empty character string")

    # XOR: exactly one of target_field or manual_component
    has_tf <- length(object@target_field) == 1L && nchar(object@target_field) > 0L
    has_mc <- length(object@manual_component) == 1L
    if (!has_tf && !has_mc)
        errs <- c(errs,
            "exactly one of target_field or manual_component must be supplied")
    if (has_tf && has_mc)
        errs <- c(errs,
            "target_field and manual_component are mutually exclusive; supply only one")

    # manual_component must be a positive integer
    if (has_mc && object@manual_component < 1L)
        errs <- c(errs, "manual_component must be a positive integer")

    # nuisance_fields: unique, non-empty elements
    nf <- object@nuisance_fields
    if (length(nf) > 0L) {
        if (any(nchar(nf) == 0L))
            errs <- c(errs, "nuisance_fields must not contain empty strings")
        if (anyDuplicated(nf))
            errs <- c(errs, "nuisance_fields must be unique")
    }

    # orientation_anchor: zero-or-one non-empty string
    oa <- object@orientation_anchor
    if (length(oa) > 1L)
        errs <- c(errs, "orientation_anchor must be zero or one field name")
    if (length(oa) == 1L && nchar(oa) == 0L)
        errs <- c(errs, "orientation_anchor must be a non-empty string when supplied")

    # Non-overlapping roles: target, nuisance, orientation must be distinct
    tf_name <- if (has_tf) object@target_field else character(0L)
    all_roles <- c(tf_name, nf, oa)
    if (anyDuplicated(all_roles))
        errs <- c(errs,
            "target_field, nuisance_fields, and orientation_anchor must be distinct")

    # claim_intent enum
    allowed_intents <- c("exploratory", "primary_confirmatory")
    if (length(object@claim_intent) != 1L ||
            !object@claim_intent %in% allowed_intents)
        errs <- c(errs, paste0(
            "claim_intent must be one of: ",
            paste(allowed_intents, collapse = ", ")
        ))

    if (length(errs)) errs else TRUE
})

# ---------------------------------------------------------------------------
# Public constructor
# ---------------------------------------------------------------------------

#' Construct a validated analysis specification
#'
#' One `AnalysisSpecification` = one named reproducible run.  Attach it to a
#' \code{\linkS4class{PipelineConfig}} so the analysis intent travels with the run.
#'
#' Exactly one of `target_field` or `manual_component` must be supplied:
#'
#' \itemize{
#'   \item `target_field` is a **proposal only**.  It names a `colData` column
#'     whose values will be used by a future component-selection procedure to
#'     suggest candidate components.  It does not silently select a component.
#'     A Stage 2 run requires an explicit `manual_component` chosen after
#'     reviewing the Stage 1 gallery; provenance will link the accepted choice
#'     to its proposal.
#'   \item `manual_component` is an explicit positive integer identifying the
#'     Stage 1 component to use.  It is validated against the available
#'     components at the stage boundary, not here.
#' }
#'
#' @param id              non-empty character run identity
#' @param target_field    character \code{colData} field name (proposal only);
#'   mutually exclusive with \code{manual_component}
#' @param manual_component  positive integer component index; mutually exclusive
#'   with \code{target_field}
#' @param nuisance_fields character vector of \code{colData} field names to
#'   declare as confounders; must be unique and distinct from \code{target_field}
#'   and \code{orientation_anchor}
#' @param orientation_anchor  optional single \code{colData} field name providing
#'   an orientation convention; must be numeric and non-degenerate (checked at
#'   the stage boundary); must not duplicate a target or nuisance role
#' @param claim_intent    \code{"exploratory"} (default) or
#'   \code{"primary_confirmatory"}
#' @return a validated \code{AnalysisSpecification} object
#' @export
analysis_specification <- function(
    id,
    target_field       = NULL,
    manual_component   = NULL,
    nuisance_fields    = character(0L),
    orientation_anchor = NULL,
    claim_intent       = c("exploratory", "primary_confirmatory")
) {
    if (!is.character(id) || length(id) != 1L || nchar(id) == 0L)
        stop("analysis_specification(): id must be a single non-empty character string")

    claim_intent <- match.arg(claim_intent)

    tf <- if (!is.null(target_field)) {
        if (!is.character(target_field) || length(target_field) != 1L ||
                nchar(target_field) == 0L)
            stop("analysis_specification(): target_field must be a single non-empty string")
        target_field
    } else character(0L)

    mc <- if (!is.null(manual_component)) {
        if (!is.numeric(manual_component) || length(manual_component) != 1L ||
            is.na(manual_component) || manual_component != as.integer(manual_component))
            stop("analysis_specification(): manual_component must be a single integer")
        as.integer(manual_component)
    } else integer(0L)

    nf <- as.character(nuisance_fields)

    oa <- if (!is.null(orientation_anchor)) {
        if (!is.character(orientation_anchor) || length(orientation_anchor) != 1L ||
                nchar(orientation_anchor) == 0L)
            stop("analysis_specification(): orientation_anchor must be a single non-empty string")
        orientation_anchor
    } else character(0L)

    obj <- new("AnalysisSpecification",
        version            = "1.0.0",
        id                 = id,
        target_field       = tf,
        manual_component   = mc,
        nuisance_fields    = nf,
        orientation_anchor = oa,
        claim_intent       = claim_intent
    )
    validObject(obj)
    obj
}

# ---------------------------------------------------------------------------
# Canonical payload, digest, and provenance
# ---------------------------------------------------------------------------

.analysis_spec_payload <- function(spec) {
    list(
        version            = spec@version,
        id                 = spec@id,
        target_field       = if (length(spec@target_field))
                                 spec@target_field else NA_character_,
        manual_component   = if (length(spec@manual_component))
                                 spec@manual_component else NA_integer_,
        nuisance_fields    = spec@nuisance_fields,
        orientation_anchor = if (length(spec@orientation_anchor))
                                 spec@orientation_anchor else NA_character_,
        claim_intent       = spec@claim_intent
    )
}

#' Compute a canonical deterministic digest for an AnalysisSpecification
#'
#' Produces a reproducible SHA-256-based hex string over the declared fields.
#' The digest changes whenever any declared value changes, making it suitable
#' as a run fingerprint in provenance records and file names.
#'
#' @param spec an \code{AnalysisSpecification} object
#' @return a single character hex string
#' @export
canonical_digest <- function(spec) {
    if (!is(spec, "AnalysisSpecification"))
        stop("canonical_digest(): spec must be an AnalysisSpecification object")
    digest::digest(.analysis_spec_payload(spec), algo = "sha256")
}

# ---------------------------------------------------------------------------
# Internal helper: serialisable list for provenance
# ---------------------------------------------------------------------------

#' Produce a serialisable list summary of an AnalysisSpecification for provenance
#'
#' @param spec an \code{AnalysisSpecification} object
#' @return named list suitable for inclusion in a provenance record
#' @keywords internal
.analysis_spec_provenance <- function(spec) {
    c(.analysis_spec_payload(spec), digest = canonical_digest(spec))
}

.validate_analysis_specification_data <- function(spec, data, require_component = FALSE) {
    cd <- as.data.frame(colData(data))
    fields <- c(spec@target_field, spec@nuisance_fields, spec@orientation_anchor)
    missing <- setdiff(fields, colnames(cd))
    if (length(missing))
        return(sprintf("declared metadata field(s) not found in colData: %s",
                       paste(missing, collapse = ", ")))

    if (length(spec@orientation_anchor)) {
        anchor <- cd[[spec@orientation_anchor]]
        if (!is.numeric(anchor) || any(!is.finite(anchor)) || stats::var(anchor) == 0)
            return("orientation_anchor must be finite numeric metadata with non-zero variance")
    }

    if (isTRUE(require_component)) {
        if (!length(spec@manual_component))
            return("target_field is a proposal only; Stage 2 requires manual_component")
        s1 <- metadata(data)$stage1
        if (is.null(s1) || spec@manual_component > dr_k(s1))
            return(sprintf("manual_component %s is not available from Stage 1",
                           spec@manual_component))
    }
    TRUE
}
