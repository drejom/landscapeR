# Component-interpretation architecture

ADR 0020 defines the scientific strategy contract. The package architecture
keeps that choice separate from the evidence invariant exposed to downstream
consumers.

## Cross-sectional seam

`associate_metadata()` is the public workflow boundary. For a cross-sectional
sampling design it delegates individual score-vector calculations to registered
`AssociationStrategy` adapters, then crosses one package-owned evidence seam.
That seam normalizes and validates:

- association rows at metadata field, component, and evidence-variant grain;
- raw component observations for every association;
- declared exclusions;
- available-case cohort identity and counts;
- deterministic table digests and provenance.

The internal `CrossSectionalInterpretationEvidence` type owns this complete
invariant before a `MetadataAssociationAtlas` can be constructed. Strategies
therefore own the estimand calculation, while the interpretation module owns
the evidence that proposal, permutation, plotting, serialization, and
confirmation consumers require.

`atlas_evidence_contract()` exposes a stable summary of the normalized row
counts, cohorts, and digests. `MetadataAssociationAtlas` validity checks the
summary against its stored evidence. Atlases serialized before this contract
remain readable, and time-course modules remain unchanged until their
separately scoped migrations.

## Boundaries retained from ADR 0020

- Unadjusted and adjusted evidence remain separate.
- Missing observations remain visible through available-case counts.
- Collapsed metadata are retained as exclusions.
- Non-identifiable adjustment remains typed evidence and produces a typed
  abstention rather than a fallback.
- Strategies remain registry adapters.
- Evidence validation cannot select a component, promote a runner-up, change a
  scientific estimand, or create an acceptance threshold.

Issue #91 is an architecture and implementation change only. It does not
establish component identifiability or scientific recovery.
