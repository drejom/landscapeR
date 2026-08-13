# K=1 Stage 0 revised acceptance protocol v3

## Purpose

Version 3 freezes the independent assessment that follows the disclosed
design-aware calibrations in #189, #190, and #191. It preserves the verified
version 2 negative artifact from #67 unchanged. No version 3 acceptance seed
is derived or executed until this definition has been reviewed and merged.

## Scientific question

The protocol asks where plain SVD recovers a planted biological loading under
declared sampling and signal regimes, and whether the required downstream model
is estimable after recovery. Those are separate questions. Neither a recovered
but non-estimable model nor an execution failure is counted as failed SVD
recovery.

## Canonical recovery and typed outcomes

Target-axis recovery is the absolute cosine between the recovered and planted
feature loadings. A value of at least 0.90 is recovered. The equivalent
one-dimensional principal angle may be reported but cannot gate the same
property a second time.

Every requested replicate retains exactly one outcome:

1. recovered and downstream estimable;
2. recovered but downstream non-estimable;
3. recovery below threshold;
4. recovery not evaluable; or
5. execution failure.

Downstream estimability is conditional on recovery and has its own denominator.
Strict random-slope abstention remains strict. No observation-independent or
random-intercept-only fallback is selected after seeing a result.

## Frozen grids

Each declared cell receives 100 independent replicates.

- Destructive time course: all six governed templates from #189, crossed with
  100, 1,000, and 10,000 features. Generator values remain `noise_sd = 0.15`,
  `time_signal = 8`, and `condition_time_signal = 3`.
- Repeated subject: all four governed templates from #190, crossed with 100,
  1,000, and 10,000 features. Generator values remain `noise_sd = 0.03`,
  `time_signal = 8`, and `condition_time_signal = 3`. Each replicate requests
  19 complete-subject axis refits.
- High-dimensional positive controls: fixed total spike, fixed sparse signal,
  growing coherent signal, and correlated modules at 100, 1,000, and 10,000
  features and covariance-adjusted signal ratios 0.75, 1.00, and 1.25.
- High-dimensional negative controls: null and near-null signal at the same
  feature counts and ratios 0 and 0.75.

The high-dimensional controls use 24 biological observations, 10 informative
features where applicable, unit Gaussian noise, and block correlation 0.6.
Here `signal_ratio` is a coefficient against the regime-specific noise
reference evaluated at `n = 24` and the frozen reference `p = 100`; it is not
the effective ratio at every feature count. The executed effective ratio is
`signal_strength * planted_loading_norm / recovery_boundary_at_p`. This exactly
preserves the calibrated generator semantics, including the growing coherent
regime's increasing loading norm.
Each replicate requests 19 stratified biological-observation axis refits.
The complete workload contains 7,200 requested replicates.

## Cell decisions and claim boundary

A positive cell is supported only when its recovery probability is at least
0.90 and its Wilson 95% lower confidence bound is at least 0.80. A null cell
passes only when its recovery probability is no greater than 0.05 and its
Wilson 95% upper confidence bound is no greater than 0.10. Execution failures
remain in immutable requested/completed accounting and never become scientific
observations.

Recovery probability and its Wilson interval divide recovered replicates by
all 100 requested replicates in the cell. Execution failures and
recovery-not-evaluable outcomes remain in that denominator as not recovered.
A cell is eligible for support only when all 100 tasks complete and all 100
recovery outcomes are evaluable. Downstream estimability has a separate
denominator containing only recovered replicates and cannot rescue or defeat
the recovery decision.

Results identify supported, unsupported, indeterminate, and out-of-domain
regions. They apply only to the declared sampling template, feature count,
signal regime, covariance regime, and missingness pattern. They are not a
universal minimum sample-size rule. A complete negative result is valid and
does not authorize a threshold or generator change on the consumed seeds.

Exploratory real-data K=1 work advances only if the real experiment is
design-compatible with at least one supported cell, all null controls pass,
and the complete artifact verifies. Longitudinal Stage 2 remains outside the
current estimator regardless of Stage 1 recovery.

## Seed and execution contract

The reviewed version 3 protocol merge SHA-1 reveals one deterministic indexed
seed block. Canonical task order is control, governed template or regime,
feature count, signal ratio where applicable, then replicate index. Each task
receives a disjoint eight-integer block. All disclosed #189–#191 calibration
streams, resource-pilot streams, and historical version 1 and version 2
acceptance streams are reserved. The protocol records digest-bound task-stream
manifests for the exact #189–#191 calibration proof runs, including their child
seeds, plus the verified historical version 2 stream range and manifest digest.
Any root, task-stream, or child-seed collision is a protocol failure.

Post-merge execution uses a revision-stamped package and the backend-independent
targets graph with future, crew, hprcc, and Slurm. Outer targets own parallelism;
each replicate is sequential internally. Requested, completed, failed, and
collector states remain immutable.

## Required publication

The content-addressed artifact contains the frozen protocol and manifest,
replicate evidence, typed cell summaries, operating-map data, publication
figures, separate scientific captions, environment identity, worker and
collector provenance, and a complete hash manifest. Verification must reproduce
the summaries and address from those contents.

## Provenance

- Source issue: #193
- Calibration inputs: #189, #190, #191
- Historical negative evidence preserved: #67
- Acceptance results inspected while defining version 3: no
- Claim before post-merge execution: predeclared acceptance protocol only
