# Stage contracts — VIRTUAL S4 classes plus their generics.
# An implementation is a concrete subclass + setMethod() for the generic.
# The pipeline only ever touches the contract; algorithms are plug-ins.

# ---------------------------------------------------------------------------
# Stage 0 — Synthetic data generation
# ---------------------------------------------------------------------------

#' Virtual class for Stage 0 synthetic data generators
#' @export
setClass("Generator", representation("VIRTUAL"))

#' Generate synthetic StateTransitionData with embedded ground truth
#'
#' @param strategy a \code{Generator} implementation
#' @param spec list of dataset shape parameters (n_layers, n_features,
#'   n_samples, SNR, seed, …)
#' @param ... forwarded to the implementation
#' @return \code{StateTransitionData} with \code{ground_truth} populated
#' @export
setGeneric("generate",
    function(strategy, spec, ...) standardGeneric("generate"))

# ---------------------------------------------------------------------------
# Stage 0.5a — Signature extraction
# ---------------------------------------------------------------------------

#' Virtual class for Stage 0.5a signature extractors
setClass("SignatureExtractor", representation("VIRTUAL"))

#' Extract a descriptor vector from a StateTransitionData object
#'
#' Captures GSV spectrum shape, angular-distance profile across components,
#' and state-space path geometry — the inputs to archetype matching.
#'
#' @param strategy a \code{SignatureExtractor} implementation
#' @param data \code{StateTransitionData}
#' @param ... forwarded to the implementation
#' @return numeric descriptor vector (or named list of descriptors)
setGeneric("extract_signature",
    function(strategy, data, ...) standardGeneric("extract_signature"))

# ---------------------------------------------------------------------------
# Stage 0.5b — Archetype classification
# ---------------------------------------------------------------------------

#' Virtual class for Stage 0.5b archetype classifiers
setClass("ArchetypeClassifier", representation("VIRTUAL"))

#' Classify data into a trajectory archetype
#'
#' Returns a posterior over archetypes — NOT a hard label. Validate via
#' simulation-based calibration (SBC) before trusting assignment probabilities.
#'
#' @param strategy an \code{ArchetypeClassifier} implementation
#' @param signature numeric descriptor vector from \code{\link{extract_signature}}
#' @param ... forwarded to the implementation
#' @return named numeric vector of archetype posterior probabilities
setGeneric("classify_archetype",
    function(strategy, signature, ...) standardGeneric("classify_archetype"))

# ---------------------------------------------------------------------------
# Stage 0.5c — Per-domain interpretation map
# ---------------------------------------------------------------------------

#' Virtual class for Stage 0.5c per-domain interpretation maps
setClass("InterpretationMap", representation("VIRTUAL"))

#' Map an archetype to named component roles for a specific domain
#'
#' The geometry classification (\code{\link{classify_archetype}}) is universal
#' and data-driven. This mapping is a domain-specific stated claim — kept in a
#' per-domain config, not hard-coded logic, so it stays falsifiable.
#'
#' @param strategy an \code{InterpretationMap} implementation
#' @param archetype character archetype name
#' @param ... forwarded to the implementation
#' @return named list of component role assignments
setGeneric("interpret",
    function(strategy, archetype, ...) standardGeneric("interpret"))

# ---------------------------------------------------------------------------
# Stage 0.75 — Distributional fit assessment
# ---------------------------------------------------------------------------

#' Virtual class for Stage 0.75 distributional fit assessors
setClass("FitAssessor", representation("VIRTUAL"))

#' Assess where real data sits in each archetype's null distribution
#'
#' Returns a position profile across archetypes — NOT a pass/fail gate.
#' See concept note Stage 0.75 for the double-dipping caveat and the
#' bootstrap vs. SBC split.
#'
#' Return value (in \code{StageResult@value}):
#' \describe{
#'   \item{null_position}{named numeric: percentile in each archetype's null}
#'   \item{assignment_probs}{named numeric: calibrated posterior probabilities}
#'   \item{uncertainty}{numeric: spread of assignment probabilities}
#' }
#'
#' @param strategy a \code{FitAssessor} implementation
#' @param data \code{StateTransitionData}
#' @param archetype character archetype name to assess against
#' @param ... forwarded to the implementation
#' @return \code{StageResult}
setGeneric("assess_fit",
    function(strategy, data, archetype, ...) standardGeneric("assess_fit"))

# ---------------------------------------------------------------------------
# Stage 1 — Comparative decomposition
# ---------------------------------------------------------------------------

#' Virtual class for Stage 1 comparative decomposition strategies
#' @export
setClass("Decomposer", representation("VIRTUAL"))

#' Extract the primary shared gene axis from a Stage 1 result
#'
#' Returns the j-th column of the gene loading matrix from a
#' \code{DecompositionResult}. Defaults to the first (primary shared) axis.
#' This is the contract-level semantic accessor — callers should prefer this
#' over reaching into \code{dr_V_k()} directly.
#'
#' @param x a \code{DecompositionResult}
#' @param j integer column index (default 1L — the primary shared axis)
#' @return numeric vector of length p (one gene loading per feature)
#' @export
setGeneric("shared_axis",
    function(x, j = 1L) standardGeneric("shared_axis"))

#' Decompose multi-layer data into shared and layer-exclusive subspaces
#'
#' Replaces plain SVD/PCA with GSVD (two layers) or HO-GSVD (N layers).
#' Generalized singular value ratios partition the space automatically;
#' confounders land in their own components rather than smearing the disease
#' axis.
#'
#' Boundary validation (\code{\link{validate_boundary}}) is enforced
#' structurally: the method below, dispatched on the VIRTUAL
#' \code{Decomposer} class itself, runs for every concrete strategy before
#' any strategy-specific code executes. Concrete strategies never implement
#' \code{decompose()} directly — they implement the internal
#' \code{.decompose_impl} generic instead, which only ever receives an
#' already-validated \code{data}. A new strategy cannot skip validation by
#' omission because validation is not part of the code path it writes.
#'
#' @param strategy a \code{Decomposer} implementation
#' @param data \code{StateTransitionData}
#' @param ... forwarded to the implementation
#' @return \code{StageResult} whose value is \code{data} annotated with
#'   shared + exclusive subspaces in \code{metadata()}
#' @export
setGeneric("decompose",
    function(strategy, data, ...) standardGeneric("decompose"))

# Structural boundary-validation gate — dispatches on the VIRTUAL
# "Decomposer" class, so it runs for ANY concrete subclass before the
# strategy-specific ".decompose_impl" hook is reached. There is no way for a
# concrete strategy to bypass this: it is not their method to skip.
#' @rdname decompose
setMethod("decompose", signature("Decomposer", "StateTransitionData"),
    function(strategy, data, ...) {
        bv <- validate_boundary(data, stage = "decompose")
        if (is(bv, "StageResult")) return(bv)
        .decompose_impl(strategy, bv, ...)
    }
)

#' Strategy-specific decomposition hook (internal)
#'
#' Concrete \code{Decomposer} implementations implement this generic, not
#' \code{decompose()} itself. By the time \code{.decompose_impl} runs,
#' \code{data} has already passed \code{\link{validate_boundary}} via the
#' \code{Decomposer}-level \code{decompose()} method in this file — boundary
#' validation is structural, not something each strategy must remember.
#'
#' @param strategy a \code{Decomposer} implementation
#' @param data \code{StateTransitionData}, already boundary-validated
#' @param ... forwarded from \code{decompose()}
#' @return \code{StageResult}
#' @keywords internal
setGeneric(".decompose_impl",
    function(strategy, data, ...) standardGeneric(".decompose_impl"))

# ---------------------------------------------------------------------------
# Stage 2 — Dynamics estimation
# ---------------------------------------------------------------------------

#' Virtual class for Stage 2 dynamics estimation strategies
#' @export
setClass("DynamicsEstimator", representation("VIRTUAL"))

#' Estimate quasi-potential dynamics on decomposition coordinates
#'
#' Fits \eqn{dX/dt = -\nabla U(X;\,\text{layer}) + \text{noise}}.
#' Critical points = commitment / irreversibility; barrier height = transition
#' difficulty. Cross-sectional (destructive) sampling is the native data type,
#' not a workaround.
#'
#' Boundary validation (\code{\link{validate_boundary}}) is enforced
#' structurally, the same way as for \code{\link{decompose}}: the method
#' below, dispatched on the VIRTUAL \code{DynamicsEstimator} class itself,
#' runs before any strategy-specific code. Concrete strategies implement the
#' internal \code{.estimate_dynamics_impl} generic instead of
#' \code{estimate_dynamics()} directly, so validation cannot be skipped by
#' omission.
#'
#' @param strategy a \code{DynamicsEstimator} implementation
#' @param data \code{StateTransitionData} with decomposition in \code{metadata()}
#' @param ... forwarded to the implementation
#' @return \code{StageResult} whose value is \code{data} annotated with
#'   quasi-potential, critical points, and barrier heights in \code{metadata()}
#' @export
setGeneric("estimate_dynamics",
    function(strategy, data, ...) standardGeneric("estimate_dynamics"))

# Structural boundary-validation gate — dispatches on the VIRTUAL
# "DynamicsEstimator" class, so it runs for ANY concrete subclass before the
# strategy-specific ".estimate_dynamics_impl" hook is reached.
#' @rdname estimate_dynamics
setMethod("estimate_dynamics", signature("DynamicsEstimator", "StateTransitionData"),
    function(strategy, data, ...) {
        bv <- validate_boundary(data, stage = "estimate_dynamics")
        if (is(bv, "StageResult")) return(bv)
        .estimate_dynamics_impl(strategy, bv, ...)
    }
)

#' Strategy-specific dynamics-estimation hook (internal)
#'
#' Concrete \code{DynamicsEstimator} implementations implement this generic,
#' not \code{estimate_dynamics()} itself. By the time
#' \code{.estimate_dynamics_impl} runs, \code{data} has already passed
#' \code{\link{validate_boundary}} via the \code{DynamicsEstimator}-level
#' \code{estimate_dynamics()} method in this file.
#'
#' @param strategy a \code{DynamicsEstimator} implementation
#' @param data \code{StateTransitionData}, already boundary-validated
#' @param ... forwarded from \code{estimate_dynamics()}
#' @return \code{StageResult}
#' @keywords internal
setGeneric(".estimate_dynamics_impl",
    function(strategy, data, ...) standardGeneric(".estimate_dynamics_impl"))
