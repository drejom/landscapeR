# Component-interpretation architecture

ADR 0020 defines the scientific strategy contract. The package architecture
keeps that choice separate from the evidence invariant exposed to downstream
consumers.

## Shared evidence seam

`associate_metadata()` is the public workflow boundary. Each supported sampling
design delegates its score-vector calculation to a registered
`AssociationStrategy` adapter, then crosses one package-owned evidence seam.
That seam normalizes and validates:

- association rows at metadata field, component, and evidence-variant grain;
- raw component observations for every association;
- declared exclusions;
- available-case cohort identity and counts;
- deterministic table and cohort-membership digests and provenance.

The internal `InterpretationEvidence` type owns this complete invariant before
a `MetadataAssociationAtlas` can be constructed. Cross-sectional, independent
destructive-time-course, and repeated-subject modules all cross this boundary.
Their contract lists have the same fields and normalized evidence grain, while
their registered module versions retain distinct sampling-design validation.
New designs supply design-specific validation without creating peer evidence
containers.

Strategies therefore own the estimand calculation, while package-owned modules
own the evidence that proposal, permutation, plotting, serialization, and
confirmation consumers require. Method authors continue to return the narrow
`AssociationStrategy` result and do not construct S4 evidence objects, manage
digests, or assemble provenance.

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
- Evidence validation cannot select a component, promote a runner-up, change a
  scientific estimand, or create an acceptance threshold.

Issues #91, #100, and #92 are architecture and implementation changes only.
They do not establish component identifiability or scientific recovery.
