# Frozen specification — Stage 1 candidate comparison

**Protocol ID:** `stage1-heterogeneous-v2`

**Status:** accepted — v2 supersedes the unexecuted v1 before aggregate results

**Provenance:** ADR 0012 records the deterministic aggregation, reporting, and
expected-negative-control semantics absent from v1. Candidate definitions,
generator, grid, seeds, metrics, and numeric decision thresholds are unchanged.
The unmodified v1 specification is retained in
`docs/specs/stage1-candidate-protocol-v1.md`.
**Governs:** ADR 0001 amendment, ADR 0009, Issue #24

## Purpose and boundary

This is a **Stage 0 algorithm-selection protocol**, not an implementation
specification for Issue #24. It compares two discovery-only estimators of a
shared sample subspace for complete paired multi-omic observations with
heterogeneous feature spaces. The result selects a Stage 1 baseline; it does
not establish a biological claim or permit Stage 2 inference.

No grid, seed, metric, threshold, candidate definition, aggregation rule, or
reporting rule may change after the first aggregate result. A change creates a
new protocol version, retains earlier artifacts, and amends the ADR.

## Common data convention

For each layer `i`, the discovery matrix is `X_i` with dimensions samples ×
features. Layers have the same **canonical biological sample IDs** but may have
different feature IDs and feature counts. Fitting uses only the intersection of
samples observed in every layer. The generator must represent this through
`MultiAssayExperiment` `sampleMap`, rather than shared assay-column position.

Each candidate must:

1. validate one-to-one sample-map alignment and form the complete paired cohort;
2. mean-centre each discovery feature and retain those fitted means;
3. scale the whole centred feature block to unit Frobenius norm, giving layers
   equal post-preprocessing influence;
4. retain canonical sample IDs, per-layer feature IDs, fitted means, block
   scales, exclusions, and fitted layer response matrices; and
5. reject absent blocks and non-bijective/missing projection feature IDs.

A projected cohort uses the discovery means and block scales. It never fits its
own centring/scaling reference. All candidates use `rank = 2`, convergence
tolerance `1e-8`, and at most `100` consensus iterations.

## Candidates

### C1 — symmetric sample-score consensus

For each block-scaled layer, calculate a thin SVD and retain its first two left
singular vectors. Starting with their QR-normalised mean, iteratively align each
layer score matrix to the current consensus using orthogonal Procrustes, then
QR-normalise the aligned mean. Stop at projector change below `1e-8` or after
100 iterations. Estimate each layer's response matrix by least squares against
the final consensus. No layer is a reference or receives a data-dependent
weight.

### C2 — block-scaled SVD baseline

Horizontally concatenate the same block-scaled layers in canonical sample
order, take its rank-two thin SVD, and use the first two left singular vectors
as the shared subspace. Estimate each layer's response matrix by the same least
squares convention as C1.

C2 is the required regression comparator regardless of selection outcome.
Neither raw feature count, read depth, nor a singular value is a layer weight.
Reliability weighting, alternate ranks, missing-block factorisations, automatic
component selection, and outcome/label supervision are excluded from v1.

## Generator: `heterogeneous_shared_subspace_v1`

For `n` samples, rank `r = 2`, and feature counts `p_i`, generate layer `i` as

```
X_i = U_shared B_i + U_exclusive,i C_i + U_confounder D_i + E_i.
```

`U_shared`, every `U_exclusive,i`, and `U_confounder` have orthonormal columns;
exclusive and confounder sample spaces are orthogonal to the planted shared
space. `B_i`, `C_i`, and `D_i` have orthonormal feature columns scaled by the
listed signal strengths. `E_i` is iid Gaussian noise. Feature IDs are unique
within an assay and intentionally disjoint across assays. New holdout samples
reuse `B_i`, `C_i`, and `D_i` but receive independently drawn score spaces and
noise.

The generator records planted sample projectors, layer response matrices,
feature IDs, sample map, missing-block mechanism, and seed as ground truth.
Ground truth is never made available to candidates.

## Frozen full grid and seeds

The full tier is the Cartesian product below, with 40 paired seeds (`1001`–
`1040`) per stratum. Seeds `1001`–`1020` are calibration; `1021`–`1040` are
holdout. Candidate selection uses calibration only; the frozen candidate is
reported on holdout only.

| Factor | Values |
|---|---|
| complete paired samples `n` | 20, 60 |
| layers `K` | 2, 3 |
| heterogeneous feature-count vector `p_i` | (80, 400), (80, 400, 1200) |
| shared singular value | 12, 24 |
| exclusive singular value | 0, 12 |
| confounder singular value | 0, 12 |
| noise SD | 1, 2 |
| discovery missing-block rate | 0, 0.20 |
| sample order | canonical, independently permuted per assay |
| feature order | canonical, independently permuted per assay |
| projection case | exact IDs, one required ID missing |

For `K = 2`, use `(80, 400)`; for `K = 3`, use `(80, 400, 1200)`. Missing-block
replicates fit on complete paired observations only; the 20% rate applies before
intersection and must leave at least 12 complete observations. The exact-ID
projection uses 60 independent holdout samples. The missing-ID projection is a
negative control and must fail typed validation before numerical projection.

The smoke tier runs the following fixed subset once with seed `1001`:
`n = 20`, `K = 2`, `p_i = (80, 400)`, shared/exclusive/confounder signals
`24/12/12`, noise `1`, no missing block, permuted sample and feature orders,
and both projection cases. It proves reproducibility and contract paths; it
cannot select a candidate.

## Metrics and contract gates

All positive metrics are sign/rotation invariant and evaluated against planted
projectors or reconstructed response matrices.

| Type | Definition | Required result |
|---|---|---|
| Gate | sample-map ambiguity, duplicate mapping, or insufficient complete paired samples | typed failure before fit |
| Gate | heterogeneous feature count and independent assay column order | successful fit equals canonical-order projector within `1e-8` |
| Gate | missing block | excluded from fit; exclusion provenance recorded; never zero-filled/imputed |
| Gate | missing/nonunique projection feature ID | typed failure before projection |
| Gate | discovery preprocessing retained | projection uses discovery means/scales exactly |
| Shared recovery | `||P_hat - P_shared||_F / sqrt(2r)` | lower is better |
| Response recovery | mean layerwise `||U_hat B_hat,i - U_shared B_i||_F / ||U_shared B_i||_F` | lower is better |
| Exclusive leakage | mean layerwise `||P_hat U_exclusive,i||_F / sqrt(r)` | lower is better |
| Held-out projection | shared-projector error on exact-ID holdout | lower is better |
| Operations | elapsed wall time, peak allocated memory, typed-failure rate | reported per stratum |

## Calibration selection and holdout acceptance

A candidate is eligible only if it passes every contract gate in every
calibration replicate. A missing-ID negative-control row passes when it emits
the required typed validation failure; its numerical metrics are inapplicable,
not evidence of a failed estimator.

For each full stratum, C1 and C2 are paired by seed. The calibration bootstrap
resamples the 20 calibration seeds with replacement **within every stratum**,
retaining paired C1/C2 rows. It uses 10,000 resamples, L'Ecuyer-CMRG seed
`11001`, and a two-sided 95% percentile interval for the equal-stratum-weighted
mean `C1 - C2` shared-recovery error.

C1 replaces C2 only when both candidates are eligible and all of these
calibration conditions hold:

1. its equal-stratum-weighted mean shared-recovery error is at least `0.03`
   lower (difference at most `-0.03`);
2. the paired-bootstrap interval lies strictly below zero;
3. its equal-stratum-weighted mean exclusive-leakage and exact-ID held-out
   projection errors are each no more than `0.02` worse; and
4. operational measurements such as elapsed time and peak memory are reported
   per stratum but do not affect selection; execution backends must not change
   the scientific decision.

Otherwise C2 remains the selected baseline if it is eligible. If neither
candidate is eligible, the decision is `no_eligible_candidate`. The selection
is serialized before examining holdout aggregate metrics.

The holdout report accepts only the selected candidate's holdout rows. For each
stratum it reports the median and a two-sided 95% percentile bootstrap interval
for every applicable numerical metric, resampling the 20 holdout seeds 10,000
times. Its deterministic seed is `11002 + i`, where `i` is the one-based
position in canonical lexicographic grid order. Missing-ID negative strata
instead report their typed-control pass rate. Holdout succeeds only if the
selected candidate passes all contract gates and, in every **exact-ID**
full-grid stratum with shared signal 24/noise 1, has median shared-recovery
error at most `0.25` and median projection error at most `0.30`. Failure does
not tune v2; it reopens ADR 0001 with the immutable v2 artifacts.

## Artifacts

Store a content-addressed `stage1-heterogeneous-v2-<payload-sha256>/`
artifact outside ordinary test fixtures with:

- canonical protocol and generator digests, including selection/reporting rules;
- seed manifest and package/commit environment (with an exact source commit);
- one row per candidate/replicate containing stratum, seed, split, gate status,
  expected-negative semantics, metrics, elapsed time, memory, exclusions, and
  failure reason;
- a serialized calibration decision, holdout summary with per-stratum bootstrap
  CIs, and figures rendered from the frozen table only; and
- a hash manifest declaring every payload file.

Verification must reject missing, duplicate, altered, or undeclared payloads;
the recursive file set must equal the declared payloads plus the hash manifest.
Large matrices are regenerated from generator version and seed; they are not
committed. Any artifact inspection must report the protocol ID and both
protocol/generator digests.
