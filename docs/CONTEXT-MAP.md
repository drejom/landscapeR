# Context Map

## Contexts

- [Shared
  infrastructure](https://lab.omeally.com/landscapeR/context/shared.md)
  — container, registry, provenance, boundary validation, RNG; the
  plumbing every stage depends on
- [Stage 0](https://lab.omeally.com/landscapeR/context/stage0.md) —
  synthetic control ladder; generates known-potential ground truth for
  validating Stages 1 and 2
- [Stage 1](https://lab.omeally.com/landscapeR/context/stage1.md) —
  comparative decomposition via GSVD/HO-GSVD; builds the state-space
- [Stage 2](https://lab.omeally.com/landscapeR/context/stage2.md) —
  quasi-potential dynamics; fits the energy landscape and reads out
  critical points and barrier heights

## Relationships

- **Shared → all stages**: Every stage entry and exit passes through the
  shared `StateTransitionData` container and calls
  [`validate_boundary()`](https://lab.omeally.com/landscapeR/reference/validate_boundary.md).
  All provenance is recorded via shared infrastructure.
- **Stage 0 → Stage 1**: Stage 0 generates synthetic multi-omic matrices
  that Stage 1 decomposes; the recovery benchmark measures how
  faithfully Stage 1 recovers the ground-truth structure.
- **Stage 0 → Stage 2**: Stage 0 generates known-potential trajectories
  that Stage 2 must recover; the `[tbd]` acceptance thresholds in ADR
  0002 are filled from Stage 0 results.
- **Stage 1 → Stage 2**: Stage 1 produces state-space coordinates (the
  disease axis) that Stage 2 uses as input for quasi-potential
  estimation.

## Shared decisions

ADRs that span multiple contexts live in `decisions/`. Context-specific
decisions may be noted within a context file but formal ADRs always go
in `decisions/`.
