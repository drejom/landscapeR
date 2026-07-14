# AnalysisSpecification v2 (ADR 0008; issue #61)
#
# A compact, versioned declaration that carries one complete target hypothesis
# through draft, proposal, and confirmed component-selection states.

# ---------------------------------------------------------------------------
# AnalysisSpecification class
# ---------------------------------------------------------------------------

#' Versioned analysis specification for one target-axis run
#'
#' An `AnalysisSpecification` expresses complete scientific intent for one
#' reproducible run. It is attached to \code{\linkS4class{PipelineConfig}},
#' not to the data container, because the same data may support separate
#' biological questions.
#'
#' Version 2 retains a complete target declaration through three lifecycle
#' states: a draft has no proposal, a proposal records the ranked proposal's
#' digest, and a confirmed specification adds the selected component plus the
#' analyst's accept/override decision and rationale.
#'
#' @slot version schema version, always \code{"2.0.0"}
#' @slot id non-empty run identity string
#' @slot lifecycle \code{"draft"}, \code{"proposal"}, or \code{"confirmed"}
#' @slot target_field one \code{colData} target field
#' @slot target_type \code{"binary"}, \code{"ordered"}, or \code{"continuous"}
#' @slot reference_level binary target reference level
#' @slot comparison_level binary target comparison level
#' @slot ordered_levels ordered target levels in predeclared direction
#' @slot continuous_direction \code{"increasing"} or \code{"decreasing"}
#' @slot selected_component positive component index in the frozen reference
#'   basis; present only for a confirmed specification
#' @slot proposal_digest SHA-256 digest of the ranked component proposal;
#'   present for proposal and confirmed states
#' @slot proposal_decision \code{"accepted"} or \code{"overridden"}; present
#'   only for a confirmed specification
#' @slot analyst_rationale non-empty human rationale for confirmation
#' @slot nuisance_fields unique metadata fields declared as confounders
#' @slot orientation_anchor optional numeric metadata field providing an
#'   orientation convention distinct from target and nuisance roles
#' @slot claim_intent \code{"exploratory"} or \code{"primary_confirmatory"}
#' @slot migration_source_digest optional digest of the exact v1 payload from
#'   which this specification was explicitly migrated
#'
#' @seealso \code{\link{analysis_specification}},
#'   \code{\link{migrate_analysis_specification}},
#'   \code{\link{canonical_digest}}
#' @export
setClass("AnalysisSpecification",
    representation(
        version                 = "character",
        id                      = "character",
        lifecycle               = "character",
        target_field            = "character",
        target_type             = "character",
        reference_level         = "character",
        comparison_level        = "character",
        ordered_levels          = "character",
        continuous_direction    = "character",
        selected_component      = "integer",
        proposal_digest         = "character",
        proposal_decision       = "character",
        analyst_rationale       = "character",
        nuisance_fields         = "character",
        orientation_anchor      = "character",
        claim_intent            = "character",
        migration_source_digest = "character"
    ),
    prototype = prototype(
        version                 = "2.0.0",
        id                      = character(0L),
        lifecycle               = "draft",
        target_field            = character(0L),
        target_type             = character(0L),
        reference_level         = character(0L),
        comparison_level        = character(0L),
        ordered_levels          = character(0L),
        continuous_direction    = character(0L),
        selected_component      = integer(0L),
        proposal_digest         = character(0L),
        proposal_decision       = character(0L),
        analyst_rationale       = character(0L),
        nuisance_fields         = character(0L),
        orientation_anchor      = character(0L),
        claim_intent            = "exploratory",
        migration_source_digest = character(0L)
    )
)

setValidity("AnalysisSpecification", function(object) {
    errs <- character()
    scalar_non_empty <- function(x) {
        length(x) == 1L && !is.na(x) && nzchar(trimws(x))
    }
    empty_or_scalar <- function(x) {
        length(x) == 0L || scalar_non_empty(x)
    }

    if (!identical(object@version, "2.0.0"))
        errs <- c(errs, "AnalysisSpecification@version must be '2.0.0'")
    if (!scalar_non_empty(object@id))
        errs <- c(errs, "id must be a single non-empty character string")
    allowed_lifecycles <- c("draft", "proposal", "confirmed")
    if (!scalar_non_empty(object@lifecycle) ||
            !object@lifecycle %in% allowed_lifecycles)
        errs <- c(errs, paste0(
            "lifecycle must be one of: ",
            paste(allowed_lifecycles, collapse = ", ")
        ))
    if (!scalar_non_empty(object@target_field))
        errs <- c(errs, "target_field must be a single non-empty field name")

    allowed_target_types <- c("binary", "ordered", "continuous")
    if (!scalar_non_empty(object@target_type) ||
            !object@target_type %in% allowed_target_types)
        errs <- c(errs, paste0(
            "target_type must be one of: ",
            paste(allowed_target_types, collapse = ", ")
        ))

    if (identical(object@target_type, "binary")) {
        if (!scalar_non_empty(object@reference_level))
            errs <- c(errs, "binary target requires reference_level")
        if (!scalar_non_empty(object@comparison_level))
            errs <- c(errs, "binary target requires comparison_level")
        if (scalar_non_empty(object@reference_level) &&
                identical(object@reference_level, object@comparison_level))
            errs <- c(errs, "reference_level and comparison_level must differ")
        if (length(object@ordered_levels) || length(object@continuous_direction))
            errs <- c(errs,
                "binary target must not declare ordered_levels or continuous_direction")
    }
    if (identical(object@target_type, "ordered")) {
        if (length(object@ordered_levels) < 2L ||
                anyNA(object@ordered_levels) ||
                any(!nzchar(trimws(object@ordered_levels))) ||
                anyDuplicated(object@ordered_levels))
            errs <- c(errs,
                "ordered target requires at least two unique non-empty ordered_levels")
        if (length(object@reference_level) || length(object@comparison_level) ||
                length(object@continuous_direction))
            errs <- c(errs,
                "ordered target must declare only ordered_levels")
    }
    if (identical(object@target_type, "continuous")) {
        if (!scalar_non_empty(object@continuous_direction) ||
                !object@continuous_direction %in% c("increasing", "decreasing"))
            errs <- c(errs,
                "continuous target requires continuous_direction 'increasing' or 'decreasing'")
        if (length(object@reference_level) || length(object@comparison_level) ||
                length(object@ordered_levels))
            errs <- c(errs,
                "continuous target must not declare discrete target levels")
    }

    has_component <- length(object@selected_component) == 1L
    has_proposal <- scalar_non_empty(object@proposal_digest)
    has_decision <- scalar_non_empty(object@proposal_decision)
    has_rationale <- scalar_non_empty(object@analyst_rationale)
    valid_digest <- function(value) {
        scalar_non_empty(value) && grepl("^[[:xdigit:]]{64}$", value)
    }

    if (length(object@selected_component) > 1L ||
            (has_component && (is.na(object@selected_component) ||
                object@selected_component < 1L)))
        errs <- c(errs, "selected_component must be zero or one positive integer")
    if (length(object@proposal_digest) > 1L ||
            (length(object@proposal_digest) && !valid_digest(object@proposal_digest)))
        errs <- c(errs, "proposal_digest must be a 64-character hexadecimal digest")
    if (length(object@proposal_decision) > 1L ||
            (length(object@proposal_decision) && !has_decision) ||
            (has_decision &&
                !object@proposal_decision %in% c("accepted", "overridden")))
        errs <- c(errs,
            "proposal_decision must be 'accepted' or 'overridden' when supplied")
    if (length(object@analyst_rationale) > 1L ||
            (length(object@analyst_rationale) && !has_rationale))
        errs <- c(errs,
            "analyst_rationale must be zero or one non-empty string")

    if (identical(object@lifecycle, "draft") &&
            (has_component || has_proposal || has_decision || has_rationale))
        errs <- c(errs,
            "draft lifecycle must not contain proposal or confirmation fields")
    if (identical(object@lifecycle, "proposal")) {
        if (!has_proposal)
            errs <- c(errs, "proposal lifecycle requires proposal_digest")
        if (has_component || has_decision || has_rationale)
            errs <- c(errs,
                "proposal lifecycle must not contain confirmation fields")
    }
    if (identical(object@lifecycle, "confirmed")) {
        if (!has_proposal)
            errs <- c(errs, "confirmed lifecycle requires proposal_digest")
        if (!has_component)
            errs <- c(errs, "confirmed lifecycle requires selected_component")
        if (!has_decision)
            errs <- c(errs, "confirmed lifecycle requires proposal_decision")
        if (!has_rationale)
            errs <- c(errs, "confirmed lifecycle requires non-empty analyst_rationale")
    }

    nf <- object@nuisance_fields
    if (length(nf) > 0L) {
        if (anyNA(nf) || any(!nzchar(trimws(nf))))
            errs <- c(errs, "nuisance_fields must not contain empty strings")
        if (anyDuplicated(nf))
            errs <- c(errs, "nuisance_fields must be unique")
    }

    oa <- object@orientation_anchor
    if (!empty_or_scalar(oa))
        errs <- c(errs, "orientation_anchor must be zero or one non-empty field name")
    if (anyDuplicated(c(object@target_field, nf, oa)))
        errs <- c(errs,
            "target_field, nuisance_fields, and orientation_anchor must be distinct")

    allowed_intents <- c("exploratory", "primary_confirmatory")
    if (!scalar_non_empty(object@claim_intent) ||
            !object@claim_intent %in% allowed_intents)
        errs <- c(errs, paste0(
            "claim_intent must be one of: ",
            paste(allowed_intents, collapse = ", ")
        ))
    if (length(object@migration_source_digest) > 1L ||
            (length(object@migration_source_digest) &&
                !valid_digest(object@migration_source_digest)))
        errs <- c(errs, paste0(
            "migration_source_digest must be zero or one 64-character ",
            "hexadecimal digest"
        ))

    if (length(errs)) errs else TRUE
})

# ---------------------------------------------------------------------------
# Public constructor
# ---------------------------------------------------------------------------

#' Construct a validated analysis specification
#'
#' One specification carries the same complete target declaration through a
#' draft, ranked proposal, and human-confirmed component decision. Target
#' direction is explicit: binary targets use neutral reference/comparison
#' levels, ordered targets use \code{ordered_levels}, and continuous targets
#' use an increasing/decreasing direction.
#'
#' A draft has no proposal or confirmation fields. A proposal adds only
#' \code{proposal_digest}. A confirmed specification requires
#' \code{selected_component}, the proposal digest, an accepted/overridden
#' decision, and non-empty analyst rationale. Real-data confirmation remains a
#' human action; this constructor validates the record but does not recommend a
#' component.
#'
#' @param id non-empty run identity
#' @param target_field one \code{colData} target field
#' @param target_type \code{"binary"}, \code{"ordered"}, or
#'   \code{"continuous"}
#' @param reference_level,comparison_level binary target direction
#' @param ordered_levels ordered target levels in predeclared direction
#' @param continuous_direction \code{"increasing"} or \code{"decreasing"}
#' @param lifecycle \code{"draft"}, \code{"proposal"}, or
#'   \code{"confirmed"}
#' @param selected_component positive component index in the frozen reference
#'   basis; confirmed lifecycle only
#' @param proposal_digest SHA-256 digest of the ranked proposal; proposal and
#'   confirmed lifecycles only
#' @param proposal_decision \code{"accepted"} or \code{"overridden"};
#'   confirmed lifecycle only
#' @param analyst_rationale non-empty human rationale; confirmed lifecycle only
#' @param nuisance_fields unique \code{colData} fields declared as confounders
#' @param orientation_anchor optional numeric non-degenerate \code{colData}
#'   field distinct from target and nuisance roles
#' @param claim_intent \code{"exploratory"} (default) or
#'   \code{"primary_confirmatory"}; intent does not establish eligibility
#' @return a validated \code{AnalysisSpecification} v2 object
#' @examples
#' draft <- analysis_specification(
#'     id = "aml-time",
#'     target_field = "weeks",
#'     target_type = "continuous",
#'     continuous_direction = "increasing"
#' )
#'
#' confirmed <- analysis_specification(
#'     id = "aml-time",
#'     target_field = "weeks",
#'     target_type = "continuous",
#'     continuous_direction = "increasing",
#'     lifecycle = "confirmed",
#'     selected_component = 2L,
#'     proposal_digest = strrep("a", 64L),
#'     proposal_decision = "accepted",
#'     analyst_rationale = "Accepted the predeclared top-ranked component."
#' )
#' @export
analysis_specification <- function(
    id,
    target_field,
    target_type,
    reference_level         = NULL,
    comparison_level        = NULL,
    ordered_levels          = character(0L),
    continuous_direction    = NULL,
    lifecycle               = "draft",
    selected_component      = NULL,
    proposal_digest         = NULL,
    proposal_decision       = NULL,
    analyst_rationale    = NULL,
    nuisance_fields      = character(0L),
    orientation_anchor   = NULL,
    claim_intent         = c("exploratory", "primary_confirmatory")
) {
    scalar_or_empty <- function(value, argument) {
        if (is.null(value)) return(character(0L))
        if (!is.character(value) || length(value) != 1L ||
                is.na(value) || !nzchar(trimws(value)))
            stop(sprintf(
                "analysis_specification(): %s must be a single non-empty string",
                argument
            ))
        value
    }

    if (!is.character(id) || length(id) != 1L ||
            is.na(id) || !nzchar(trimws(id)))
        stop("analysis_specification(): id must be a single non-empty character string")
    if (!is.character(target_field) || length(target_field) != 1L ||
            is.na(target_field) || !nzchar(trimws(target_field)))
        stop("analysis_specification(): target_field must be a single non-empty string")
    if (!is.character(target_type) || length(target_type) != 1L ||
            is.na(target_type) || !nzchar(trimws(target_type)))
        stop("analysis_specification(): target_type must be a single non-empty string")

    claim_intent <- match.arg(claim_intent)
    component <- if (is.null(selected_component)) {
        integer(0L)
    } else {
        if (!is.numeric(selected_component) || length(selected_component) != 1L ||
                is.na(selected_component) ||
                selected_component != as.integer(selected_component))
            stop(paste0(
                "analysis_specification(): selected_component must be a ",
                "single integer"
            ))
        as.integer(selected_component)
    }

    obj <- new("AnalysisSpecification",
        version                 = "2.0.0",
        id                      = id,
        lifecycle               = as.character(lifecycle),
        target_field            = target_field,
        target_type             = target_type,
        reference_level         = scalar_or_empty(reference_level, "reference_level"),
        comparison_level        = scalar_or_empty(comparison_level, "comparison_level"),
        ordered_levels          = as.character(ordered_levels),
        continuous_direction    = scalar_or_empty(
            continuous_direction, "continuous_direction"
        ),
        selected_component      = component,
        proposal_digest         = scalar_or_empty(proposal_digest, "proposal_digest"),
        proposal_decision       = scalar_or_empty(
            proposal_decision, "proposal_decision"
        ),
        analyst_rationale       = scalar_or_empty(
            analyst_rationale, "analyst_rationale"
        ),
        nuisance_fields         = as.character(nuisance_fields),
        orientation_anchor      = scalar_or_empty(
            orientation_anchor, "orientation_anchor"
        ),
        claim_intent            = claim_intent,
        migration_source_digest = character(0L)
    )
    validObject(obj)
    obj
}

# ---------------------------------------------------------------------------
# Explicit v1 -> v2 migration
# ---------------------------------------------------------------------------

.analysis_spec_v1_payload <- function(spec) {
    scalar_or_na <- function(value, missing) {
        if (length(value)) value else missing
    }
    list(
        version            = methods::slot(spec, "version"),
        id                 = methods::slot(spec, "id"),
        target_field       = scalar_or_na(
            methods::slot(spec, "target_field"), NA_character_
        ),
        manual_component   = scalar_or_na(
            methods::slot(spec, "manual_component"), NA_integer_
        ),
        nuisance_fields    = methods::slot(spec, "nuisance_fields"),
        orientation_anchor = scalar_or_na(
            methods::slot(spec, "orientation_anchor"), NA_character_
        ),
        claim_intent       = methods::slot(spec, "claim_intent")
    )
}

#' Migrate an AnalysisSpecification v1 object to v2
#'
#' Migration is deliberately explicit. A v1 target-only object lacks target
#' direction, and a v1 manual-component object lacks both target intent and
#' proposal-decision provenance. Callers must supply those missing declarations;
#' this function never fabricates them or silently drops the legacy component.
#'
#' @param spec serialized or in-memory \code{AnalysisSpecification} v1 object
#' @param target target schema version; currently only \code{"2.0.0"}
#' @param target_field explicit target field when absent from the v1 object
#' @param target_type \code{"binary"}, \code{"ordered"}, or
#'   \code{"continuous"}
#' @param reference_level,comparison_level binary target direction
#' @param ordered_levels ordered target direction
#' @param continuous_direction continuous target direction
#' @param proposal_digest digest of the ranked proposal that informed a legacy
#'   manual component
#' @param proposal_decision \code{"accepted"} or \code{"overridden"}
#' @param analyst_rationale non-empty human rationale for a legacy component
#' @return a validated v2 \code{AnalysisSpecification}
#' @export
migrate_analysis_specification <- function(
    spec,
    target = "2.0.0",
    target_field = NULL,
    target_type = NULL,
    reference_level = NULL,
    comparison_level = NULL,
    ordered_levels = character(0L),
    continuous_direction = NULL,
    proposal_digest = NULL,
    proposal_decision = NULL,
    analyst_rationale = NULL
) {
    if (!is(spec, "AnalysisSpecification"))
        stop(paste0(
            "migrate_analysis_specification(): spec must be an ",
            "AnalysisSpecification object"
        ))
    if (!identical(target, "2.0.0"))
        stop("migrate_analysis_specification(): target must be '2.0.0'")

    source_version <- methods::slot(spec, "version")
    if (identical(source_version, "2.0.0")) {
        validObject(spec)
        return(spec)
    }
    if (!identical(source_version, "1.0.0"))
        stop(sprintf(
            "migrate_analysis_specification(): no migration from version %s",
            source_version
        ))

    legacy_target <- methods::slot(spec, "target_field")
    legacy_component <- methods::slot(spec, "manual_component")
    if (length(legacy_target)) {
        if (!is.null(target_field) && !identical(target_field, legacy_target))
            stop(paste0(
                "migrate_analysis_specification(): explicit target_field must ",
                "match the v1 target_field"
            ))
        target_field <- legacy_target
    } else if (is.null(target_field)) {
        stop(paste0(
            "migrate_analysis_specification(): v1 manual-component object ",
            "requires explicit target_field"
        ))
    }
    if (is.null(target_type))
        stop(paste0(
            "migrate_analysis_specification(): v1 object requires explicit ",
            "target_type and direction"
        ))

    lifecycle <- if (length(legacy_component)) {
        "confirmed"
    } else if (!is.null(proposal_digest)) {
        "proposal"
    } else {
        "draft"
    }
    if (length(legacy_component)) {
        if (is.null(proposal_digest))
            stop(paste0(
                "migrate_analysis_specification(): v1 manual-component object ",
                "requires explicit proposal_digest"
            ))
        if (is.null(proposal_decision))
            stop(paste0(
                "migrate_analysis_specification(): v1 manual-component object ",
                "requires explicit proposal_decision"
            ))
        if (is.null(analyst_rationale))
            stop(paste0(
                "migrate_analysis_specification(): v1 manual-component object ",
                "requires explicit analyst_rationale"
            ))
    }

    source_digest <- digest::digest(
        .analysis_spec_v1_payload(spec),
        algo = "sha256"
    )
    migrated <- analysis_specification(
        id = methods::slot(spec, "id"),
        target_field = target_field,
        target_type = target_type,
        reference_level = reference_level,
        comparison_level = comparison_level,
        ordered_levels = ordered_levels,
        continuous_direction = continuous_direction,
        lifecycle = lifecycle,
        selected_component = if (length(legacy_component))
            legacy_component else NULL,
        proposal_digest = proposal_digest,
        proposal_decision = proposal_decision,
        analyst_rationale = analyst_rationale,
        nuisance_fields = methods::slot(spec, "nuisance_fields"),
        orientation_anchor = if (length(methods::slot(spec, "orientation_anchor")))
            methods::slot(spec, "orientation_anchor") else NULL,
        claim_intent = methods::slot(spec, "claim_intent")
    )
    migrated@migration_source_digest <- source_digest
    validObject(migrated)
    migrated
}

# ---------------------------------------------------------------------------
# Canonical payload, digest, and provenance
# ---------------------------------------------------------------------------

.analysis_spec_payload <- function(spec) {
    scalar_or_na <- function(value) {
        if (length(value)) value else NA_character_
    }
    list(
        version                 = spec@version,
        id                      = spec@id,
        lifecycle               = spec@lifecycle,
        target_field            = spec@target_field,
        target_type             = spec@target_type,
        reference_level         = scalar_or_na(spec@reference_level),
        comparison_level        = scalar_or_na(spec@comparison_level),
        ordered_levels          = spec@ordered_levels,
        continuous_direction    = scalar_or_na(spec@continuous_direction),
        selected_component      = if (length(spec@selected_component))
                                      spec@selected_component else NA_integer_,
        proposal_digest         = scalar_or_na(spec@proposal_digest),
        proposal_decision       = scalar_or_na(spec@proposal_decision),
        analyst_rationale       = scalar_or_na(spec@analyst_rationale),
        nuisance_fields         = spec@nuisance_fields,
        orientation_anchor      = scalar_or_na(spec@orientation_anchor),
        claim_intent            = spec@claim_intent,
        migration_source_digest = scalar_or_na(spec@migration_source_digest)
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
        return(sprintf(
            "declared metadata field(s) not found in colData: %s",
            paste(missing, collapse = ", ")
        ))

    target <- cd[[spec@target_field]]
    if (anyNA(target))
        return("target_field must not contain missing values in the analysis cohort")
    if (identical(spec@target_type, "binary")) {
        observed <- unique(as.character(target))
        declared <- c(spec@reference_level, spec@comparison_level)
        if (!setequal(observed, declared))
            return(sprintf(
                "observed target values must equal declared binary levels: %s",
                paste(declared, collapse = " -> ")
            ))
    }
    if (identical(spec@target_type, "ordered")) {
        observed <- unique(as.character(target))
        if (!setequal(observed, spec@ordered_levels))
            return(sprintf(
                "observed target values must equal declared ordered_levels: %s",
                paste(spec@ordered_levels, collapse = " -> ")
            ))
    }
    if (identical(spec@target_type, "continuous")) {
        if (!is.numeric(target) || any(!is.finite(target)) ||
                length(target) < 2L || stats::var(target) == 0)
            return(paste0(
                "continuous target must be finite numeric metadata with ",
                "non-zero variance"
            ))
    }

    if (length(spec@orientation_anchor)) {
        anchor <- cd[[spec@orientation_anchor]]
        if (!is.numeric(anchor) || any(!is.finite(anchor)) ||
                length(anchor) < 2L || stats::var(anchor) == 0)
            return(paste0(
                "orientation_anchor must be finite numeric metadata with ",
                "non-zero variance"
            ))
    }

    if (isTRUE(require_component)) {
        if (!identical(spec@lifecycle, "confirmed") ||
                !length(spec@selected_component))
            return(paste0(
                "Stage 2 requires a confirmed AnalysisSpecification with ",
                "selected_component"
            ))
        s1 <- metadata(data)$stage1
        if (is.null(s1) || spec@selected_component > dr_k(s1))
            return(sprintf(
                "selected_component %s is not available from Stage 1",
                spec@selected_component
            ))
    }
    TRUE
}
