# 0017 — Observation before interpretation

**Stage:** cross-cutting
**Status:** accepted
**Date:** 2026-07-13

## Context

landscapeR turns high-dimensional observations into increasingly interpreted
artifacts: decomposition components, metadata associations, a selected target
axis, a fitted quasi-potential, critical points, biological state labels, and
an aggregate evidence judgement. Each transformation is useful, but each can
also conceal contradictory or weak support if only the final interpretation is
shown.

This risk is especially acute when:

- the dominant component is a nuisance axis rather than the target axis;
- categorical separation is strong but contradicts a predeclared biological
  ordering;
- an adjusted model obscures a different unadjusted association;
- a smooth fitted landscape appears more decisive than its empirical coordinate
  distribution;
- a projected cohort is used to revise a discovery-cohort choice;
- an unexpected exploratory observation is later presented as if predeclared.

The package therefore needs one cross-cutting rule for how descriptive evidence
and hypothesis-conditioned interpretation coexist in objects, plots,
provenance, automated evidence artifacts, and any future Shiny interface.

Here, **descriptive evidence does not mean unrestricted publication of raw
source or subject-level data**. Privacy, data-use agreements, and repository
rules still apply. It means the minimally interpreted analysis output needed
to assess a claim, such as component coordinates or distributions, metadata
association effect sizes, empirical densities, and individual acceptance
metrics.

## Options considered

| Option | Source / reference | Key property | Disqualifier or concern |
|---|---|---|---|
| Publish only the final selected/fitted interpretation | Conventional concise reporting | Simple presentation | Hides selection alternatives, nuisance structure, poor fit, and contradictory evidence |
| Expose descriptive outputs but allow interpretation to replace them in downstream artifacts | Partial transparency | Raw diagnostics exist somewhere | The evidence chain becomes difficult to audit and UI/reporting may omit them |
| Preserve linked descriptive and hypothesis-conditioned layers throughout | Reproducible research and diagnostic-model-checking principles | Observation is visible before and beside interpretation | Larger objects and more demanding reporting/API design |

## Criteria

- A reader can inspect the observations supporting every interpretive claim.
- Hypothesis-conditioned output never overwrites or hides its descriptive
  precursor.
- Predeclared expectations remain distinguishable from discoveries made after
  inspecting results.
- Discovery choices cannot be revised using confirmation/projection data.
- Raw and adjusted associations can disagree visibly.
- Null, no-transition, ineligible, and contradictory results remain reportable.
- Artifacts remain structured, serializable, testable, and usable by a future
  interface without reimplementing scientific logic.
- Subject privacy and data-use constraints are preserved.

## Evidence

No Stage 0 benchmark selects this reporting architecture. The decision follows
from the package's provenance, discovery/confirmation, and human-in-the-loop
contracts and from a concrete AML failure mode: PC1 captures age/time while PC2
is the disease axis. A gallery that displayed only the fitted/selected result,
or silently sorted on a mismatched criterion, would make the wrong component
appear persuasive.

The same issue arises in the planned cross-sectional diabetes application:
omnibus separation among non-diabetic, autoantibody-positive, and type 1
diabetes donors does not by itself establish the predeclared progression order.
Both the observed separation and order-concordance result are necessary.

## Decision

**Chosen:** every interpretive artifact retains and exposes a linked descriptive
evidence layer. Observation precedes interpretation, and interpretation never
replaces observation.

The two layers are:

1. **Descriptive evidence layer** — minimally interpreted outputs produced
   without imposing the target hypothesis: component coordinates and
   distributions, all eligible metadata associations, empirical coordinate
   density, individual benchmark metrics, and recorded exclusions.
2. **Hypothesis-conditioned interpretation layer** — declared target and
   nuisance roles, expected ordering and orientation, adjusted models,
   component proposal and confirmation, fitted quasi-potential, critical-point
   classification, biological labels, and aggregate evidence judgement.

Every hypothesis-conditioned object references the digest and provenance of its
descriptive precursor. It records which declarations were predeclared and which
were discovered after inspection.

Concrete requirements:

- Stage 1 shows component distributions and a metadata-association atlas before
  the component proposal; unadjusted associations remain beside adjusted ones.
- Omnibus group separation remains beside order-concordance or longitudinal
  trajectory tests.
- Component confirmation is a human decision for real data and cannot be
  changed by a projected cohort.
- Stage 2 exposes selected coordinates and empirical density before and beside
  the fitted quasi-potential.
- Critical points are shown with their uncertainty and supporting data;
  biological labels are distinct from geometric classifications.
- Evidence reports show every predeclared metric before aggregate pass/fail.
- No-transition, ineligible, and contradictory outcomes are retained rather
  than smoothed, filtered, or relabelled into a positive result.
- A future Shiny application renders package-owned objects and cannot bypass
  these layers.

### 2026-07-14 amendment — visual landing proof

Observation-before-interpretation also applies to the act of landing a change.
Tests and package checks can establish machine-level correctness while leaving a
reviewer unable to see what changed. A qualifying implementation is therefore
not complete until its pull request carries **visual landing proof**.

The pull request is the canonical transition record because it co-locates the
base revision, head revision, issue, diff, review, and commits. Required proof
contains:

- a rendered before/after comparison for a fix, or a representative figure,
  table, workflow render, or equivalent inspectable output for a new capability;
- a cold-reader interpretation;
- a command or procedure that reproduces the proof; and
- explicit claim status, including exploratory, calibration-only, or accepted
  evidence where relevant.

This obligation applies to scientific behavior, public APIs, user-visible
behavior, plotting, prepared data/schema, and developer-facing workflows.
Internal-only changes with no observable surface and research/decision-only
work that prohibits implementation may be exempt, but the category and
rationale must be declared explicitly before merge. A deferred exemption
expires when implementation begins. Generic `N/A` is not an exemption.

Pull-request proof, current documentation, and immutable scientific evidence
answer different questions:

1. **Pull-request landing proof:** did the implementation visibly change the
   intended behavior?
2. **Current package documentation:** how should the supported workflow be used
   now? Public workflow changes update the affected vignette or README.
3. **Immutable evidence artifact/article:** what scientific claim is supported?

A pull-request image or development-log entry cannot select thresholds, confer
acceptance, or replace a content-addressed evidence artifact. Restricted or
unpublished data use synthetic or privacy-safe proof surfaces.

The development log is a concise current-status and implementation index. It
links issues and merged pull requests rather than duplicating every historical
review packet. Qualifying work targets `main` through a reviewed pull request so
the canonical landing-proof record exists.

## Consequences

- Result objects and public plotting APIs must make both layers accessible.
- Plotting functions cannot be the sole holders of association scores or model
  results; plots render structured objects.
- Evidence artifacts and vignettes become larger but scientifically auditable.
- User interfaces must expose uncertainty and alternatives rather than only a
  recommended action.
- Confirmation/projection objects are validation-only and cannot mutate the
  discovery specification.
- Privacy-safe summaries may substitute for restricted subject-level outputs,
  but their provenance must still point to the protected descriptive artifact.
- This ADR does not choose the statistical model for metadata association or
  the Stage 2 estimator; those remain separate algorithm decisions requiring
  their own criteria and evidence.

## Review trigger

Revisit if preserving descriptive outputs creates a demonstrated privacy or
storage conflict that cannot be resolved with protected artifacts and
privacy-safe summaries, or if a validated reporting standard provides a more
specific equivalent guarantee without weakening auditability.
