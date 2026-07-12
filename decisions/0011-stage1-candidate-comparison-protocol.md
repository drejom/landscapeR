# 0011 — Stage 1 heterogeneous-feature candidate comparison protocol

**Stage:** 0 / 1
**Status:** accepted
**Date:** 2026-07-12

## Context

ADR 0009 requires shared structure to live in matched sample space, with
heterogeneous feature spaces, complete paired fitting, and discovery-anchored
projection. ADR 0001's equal-feature loading strategy cannot meet that
contract. Selecting its replacement by availability, a single simulated data
set, or pooled averages would make Stage 1—and every downstream dynamic
claim—unfalsifiable.

The immediate decision is not which candidate wins. It is whether a frozen,
paired synthetic protocol is sufficient to select between a symmetric
sample-score consensus estimator and a block-scaled concatenated-SVD baseline.

## Options considered

| Option | Source / reference | Key property | Disqualifier or concern |
|---|---|---|---|
| Select consensus now | ADR 0001 amendment | Symmetric across layers | No heterogeneous-feature evidence yet |
| Retain current V-averaging | Existing implementation | Fast equal-feature special case | Cannot represent layer-specific feature spaces |
| Freeze paired C1/C2 comparison | `docs/specs/stage1-candidate-protocol.md` | Tests the required contract before selection | Requires deliberate Stage 0 execution |

## Criteria

Defined before aggregate results:

- Candidates must pass sample-map, heterogeneous-feature, complete-case,
  feature-ID, preprocessing-reference, and no-imputation contract gates.
- Comparison must be paired by generator seed and report every stratum rather
  than a pooled average.
- Shared-subspace recovery must be sign/rotation invariant and be accompanied
  by response, exclusive-leakage, projection, runtime, and memory evidence.
- Selection must use calibration only and be validated on independent holdout
  seeds.
- A failure must preserve immutable evidence and reopen the algorithm decision,
  not retune the same protocol after results are known.

## Evidence

No candidate-comparison results exist. The prior evidence in ADR 0001 validates
only equal-feature synthetic controls and is explicitly insufficient under ADR
0009.

## Decision

**Chosen:** subject the two candidates to the proposed frozen protocol
`stage1-heterogeneous-v1` in `docs/specs/stage1-candidate-protocol.md` before
implementing either as the production heterogeneous-feature Stage 1 strategy.

The protocol fixes preprocessing, rank, candidate mechanics, synthetic truth,
parameter grid, 40 paired calibration/holdout seeds, gates, metrics, selection
thresholds, and immutable artifacts. C2 remains the mandatory regression
comparator even if C1 wins. ADR 0012 superseded the unexecuted v1 executable
protocol with v2 before aggregate results, solely to freeze deterministic
aggregation, reporting, and expected-negative semantics. Candidate prototype
code may now implement its smoke tier, but no production candidate or Issue #24
contract rewrite follows from this ADR alone.

## Consequences

- Stage 1 work begins with a small, testable prototype harness rather than a
  contract rewrite.
- The current equal-feature strategies remain legacy special cases and cannot
  make multi-omic confirmatory claims.
- Protocol amendments require a new version and preserve earlier artifacts.
- Issue #24 remains blocked until candidate evidence selects a strategy.

## Review trigger

Review this protocol if it proves unable to generate a valid complete paired
cohort at the `n = 20` stratum, if C1/C2 both fail a required contract gate, or
if a scientific requirement demands rank other than two or a declared
feature-harmonisation policy beyond one-to-one IDs.
