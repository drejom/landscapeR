# Implementation plan — Stage 1 frozen evidence execution

**Status:** active — Issue #40
**Date:** 2026-07-12

## Objective

Turn the accepted `stage1-heterogeneous-v2` protocol into auditable evidence
without changing its grid, seeds, candidates, or decision rule. Keep the
living development log distinct from this acceptance evidence.

## Deliverables

1. A deliberate full-tier executor which enumerates the canonical manifest,
   emits observable progress, can resume a matching local temporary workspace,
   and writes an immutable, content-addressed artifact directory. It must not
   be invoked by ordinary package tests.
2. Pure aggregation functions which apply ADR 0011's calibration-only candidate
   decision rule and produce an independent holdout report with per-stratum
   confidence intervals and acceptance decisions.
3. A render-only Stage 1 validation vignette which verifies artifact integrity
   and reports the frozen evidence. It never generates simulations or tunes
   parameters.
4. A deterministic, explicitly non-evidentiary development tier that exercises
   the executor's major contract branches quickly without candidate selection,
   holdout assessment, or artifact publication.
5. A corrected `development-log.Rmd` which treats its historical AML examples
   as non-reproducible exploratory context, reports the actual proof status,
   and points to the GitHub Pages site.

## Invariants

- No protocol values, candidate definitions, seeds, metrics, or acceptance
  rules may change after execution begins; any such change requires v2 and an
  ADR amendment.
- Full evidence is separate from test fixtures. Tiny fixtures and the
  development tier test executor/aggregation interfaces only and make no
  selection or acceptance claim.
- Local checkpoints are compact per-task synthetic results under `tempdir()`;
  they are operational state, not evidence, and are removed after successful
  final artifact verification unless retained for diagnosis. Interrupted runs
  are explicitly marked and may resume only with matching identity.
- Artifact verification includes every stored file, and figures are made only
  from stored frozen result rows.
- Holdout values must remain inaccessible to the selection function.
- No real data, raw matrices, or confirmatory biological claims are added.

## Completion evidence

- Artifact verifier and vignette checks pass on the committed full artifact.
- The artifact manifest agrees with `stage1_benchmark_manifest()` and reports
  a committed source revision/environment.
- The selected candidate and the holdout decision are derived solely through
  the protocol's frozen rules.
- Full package tests, tarball check, lint, ADR coverage, registry compliance,
  and CI are green.
