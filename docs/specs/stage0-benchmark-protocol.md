# Proposed specification — Stage 0 acceptance protocol

**Status:** proposed protocol for ADR 0002

## Freeze before aggregate results

A protocol manifest declares generator/version digest, candidates and parameter
grids, seeds, calibration/holdout assignment, metrics, claim classes, acceptance
rules, environment, and artifact version. Changing any of these creates a new
protocol/artifact version and ADR amendment; it never overwrites prior evidence.

## Calibration and holdout

Use calibration simulations only to select a candidate configuration and freeze
numeric limits. Test the frozen choice on independent holdout seeds.

Positive controls pass only when every predeclared recovery criterion passes.
Negative controls fail when they emit an eligible one-dimensional transition
claim. Acceptance is per critical stratum—not a pooled average—and gives
false eligibility priority over raw positive accuracy.

## Artifact set

Store a compact, immutable artifact directory with:

- canonical manifest and seed manifest;
- one-row-per-replicate result table;
- derived summary with per-stratum confidence intervals and decision;
- environment/commit information;
- figures generated only from frozen results; and
- hashes for every artifact.

Each result row identifies protocol/configuration/generator digests, seed/split,
control condition and truth, stage outcomes, target/selection/topology metrics,
claim status, failure reason, and elapsed time. Large synthetic matrices are
regenerated from seeds and not versioned.

## Execution tiers

- **Smoke**: a tiny deterministic subset in ordinary tests; verifies manifest
  parsing, reproducible regeneration, and minimal positive/negative paths. It
  cannot tune or establish acceptance.
- **Full**: the entire frozen manifest, run deliberately outside ordinary PR
  checks. It creates a new artifact version only.

## Validation vignette

`stage0-adr0002-validation.Rmd` verifies artifact hashes/schema, displays the
protocol and claim scope, renders per-stratum holdout recovery and
false-eligibility evidence, and states whether ADR 0002 remains provisional.
It renders frozen artifacts; it never regenerates sweeps or retunes parameters.
