# 0012 — Stage 1 evidence aggregation determinism

**Stage:** 0 / 1
**Status:** accepted
**Date:** 2026-07-12
**Amends:** ADR 0011 before any aggregate candidate result

## Context

ADR 0011 froze the C1/C2 candidates, synthetic generator, grid, seeds,
metrics, and decision thresholds. Implementation review before the first full
run found that the protocol did not make the aggregation mechanics fully
reproducible: it named a 10,000-resample paired bootstrap but not its resampling
unit or seed; it required per-stratum confidence intervals without fixing their
statistic; and it did not state how an expected typed failure in the
missing-feature negative control contributes to candidate eligibility.

Choosing these details in code after seeing aggregate results would turn an
evidence procedure into an implementation convenience. No aggregate
candidate-comparison result or artifact exists at this amendment.

## Decision

Supersede the executable protocol identifier `stage1-heterogeneous-v1` with
`stage1-heterogeneous-v2`; retain the v1 specification unchanged as the
historical pre-execution record. The candidates, generator, grid, seeds,
metrics, and numeric decision thresholds are unchanged.

### Contract-gate semantics

A negative-control row passes its contract gate when the required operation
fails with the declared typed condition. It is not a numerical-estimator
failure, and its metrics are inapplicable. A candidate is eligible only when
all of its positive contract rows pass and all expected-negative rows observe
the required typed failure.

### Calibration selection

For each full stratum, pair C1 and C2 by seed. The calibration paired-bootstrap
resamples the 20 calibration seeds *with replacement within every full
stratum*, retaining the paired C1/C2 rows. It runs 10,000 resamples with
L'Ecuyer-CMRG seed `11001`. The reported interval is the two-sided 95%
percentile interval for the all-strata, equal-stratum-weighted mean difference
`C1 - C2` in shared-recovery error.

C1 replaces C2 only if both candidates are eligible and all ADR 0011 numeric
conditions hold on calibration rows: the observed equal-stratum-weighted mean
shared-recovery difference is at most `-0.03`; the bootstrap interval's upper
bound is strictly below zero; C1's equal-stratum-weighted mean leakage and
exact-ID projection errors are each no more than `0.02` above C2's; and C1's
median elapsed time is at most `1.5` times C2's. Otherwise C2 is selected only
if C2 is eligible. If neither candidate is eligible, the decision is
`no_eligible_candidate` and the ADR must be reopened; v2 is never retuned.

### Holdout reporting

Selection is serialized before holdout aggregation. The holdout report accepts
only the selected candidate's 20 holdout rows per stratum. For every stratum it
reports the median and a two-sided 95% percentile bootstrap interval for each
applicable numeric metric, resampling seeds with replacement 10,000 times.
The deterministic seed is `11002 + i`, where `i` is the one-based position of
the stratum in canonical lexicographic grid order. Expected-negative rows
instead report their typed-control pass rate and are excluded from numerical
metric summaries.

Holdout acceptance is unchanged: every contract gate must pass; and in every
exact-ID stratum with shared signal 24 and noise SD 1, median shared-recovery
error must be at most 0.25 and median projection error at most 0.30. The
artifact reports every stratum even when the final decision is failure.

### Artifact integrity

A full artifact is created in a staging directory, then published atomically
under a name containing the SHA-256 digest of its complete declared payload.
The hash manifest declares every payload path and digest. Verification rejects
missing, duplicate, altered, or undeclared files; the actual recursive file set
must equal the declared payload set plus the hash manifest itself. The
environment record contains the exact 40-hex source commit, R version, package
version, and execution timestamp.

## Consequences

- The prior v1 specification remains readable but is never executed as an
  aggregate protocol.
- The v2 manifest and digest carry the selection and reporting rules, so a
  change to any of them produces a distinct evidence identity.
- Full execution, selection, and holdout reporting can be implemented without
  exposing tunable parameters.
- The resulting artifact will be synthetic only; it includes no raw biological
  data or generated matrices.

## Review trigger

Review only if the executor cannot reproduce a canonical v2 row, either
candidate lacks an eligible calibration run, or artifact verification fails.
Any methodological change after execution starts requires v3 and preserves the
v2 artifact.
