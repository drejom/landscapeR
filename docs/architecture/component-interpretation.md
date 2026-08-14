# Component-interpretation architecture

ADR 0020 defines the scientific strategy contract. The package architecture
keeps that choice separate from the evidence invariant exposed to downstream
consumers.

## Shared evidence seam

`associate_metadata()` is the public workflow boundary. Cross-sectional and
independent-time-course designs now cross the normalized association execution
kernel described in
[`association-execution-kernel.md`](association-execution-kernel.md). The kernel
validates strategy resolution, traverses components, normalizes resampling
accounting, applies multiplicity, propagates typed abstention, and assembles the
final atlas. Design adapters still own cohort preparation, estimand mapping,
diagnostics, exchangeability, scientific fitting, and refitting.
That seam normalizes and validates:

- association rows at metadata field, component, and evidence-variant grain;
- raw component observations for every association;
- declared exclusions;
- available-case cohort identity and counts;
- deterministic table and cohort-membership digests and provenance.

One `.new_interpretation_evidence()` constructor and the internal
`InterpretationEvidence` type own this complete invariant before
a `MetadataAssociationAtlas` can be constructed. Cross-sectional, independent
destructive-time-course, and repeated-subject modules all cross this boundary.
Their contract lists have the same fields and normalized evidence grain, while
their registered module versions retain distinct sampling-design validation.
New designs supply design-specific validation without creating peer evidence
containers.

Strategies therefore own the scientific interpretation calculation, while
package-owned modules own the evidence that proposal, permutation, plotting,
serialization, and confirmation consumers require. Independent and repeated
time-course strategies use the explicit shared primitives in
`R/13b-time-course-common.R`; neither design module depends on helpers hidden in
the other. Method authors return narrow preparation and fit results and do not
construct S4 evidence objects, manage digests, or assemble provenance. The
practical authoring contract is documented in
[`docs/agents/association-strategy-authoring.md`](../agents/association-strategy-authoring.md).

`atlas_evidence_contract()` exposes a stable summary of the normalized row
counts, cohorts, and digests as an inspection-friendly list. This summary is
not the internal authoritative object. `MetadataAssociationAtlas` validity
checks it against stored evidence. The contract does not collapse destructive
time cells into subjects or repeated subject trajectories into independent
observations. Atlases serialized before this contract remain readable.

## Boundaries retained from ADR 0020

- Unadjusted and adjusted evidence remain separate.
- Missing observations remain visible through available-case counts.
- Collapsed metadata are retained as exclusions.
- Non-identifiable adjustment remains typed evidence and produces a typed
  abstention rather than a fallback.
- Strategies remain registry adapters.
- Strategy keys are write-once by default. Re-registering a
  fingerprint-equivalent constructor with the same code and behavior-relevant
  captured state is an idempotent no-op; a different constructor raises a typed
  collision error without mutating the registry. Method authors who genuinely
  need to replace an implementation must state that intent with
  `replace = TRUE` and supply a non-empty rationale. The accepted registration
  and replacement fingerprints and rationale remain inspectable through
  `strategy_registration_history()`. Constructors must be R closures;
  primitive functions cannot provide the inspectable implementation state this
  fingerprint contract requires.
- Evidence validation cannot select a component, promote a runner-up, change a
  scientific estimand, or create an acceptance threshold.

Issues #91, #100, and #92 are architecture and implementation changes only.
They do not establish component identifiability or scientific recovery.
