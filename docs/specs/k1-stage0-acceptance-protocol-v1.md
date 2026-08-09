# K=1 Stage 0 acceptance protocol v1

## Problem Statement

The K=1 implementation has disclosed calibration results, but real AML analysis
must remain blocked until an independent known-truth protocol is frozen before
its acceptance replicates are knowable or executed. The protocol must uniquely
define its grids, metrics, thresholds, false-positive limits, pass rules, and
seed derivation without treating its own outputs as calibration.

## Solution

Expose one digest-bound `K1AcceptanceProtocol`. Its public constructor and
validator are the sole phase-A seam. The protocol defines the Cartesian control
grids and per-cell replicate counts. Acceptance seeds are derived only after
merge from the protocol digest, the phase-A merge commit, canonical grid-cell
identity, and replicate index. Thus the seed set is hidden while the protocol
is reviewed, deterministic after merge, and requires no private secret store.

## User Stories

1. As a method developer, I want thresholds frozen before acceptance, so that holdout results cannot tune their own gates.
2. As a reviewer, I want every grid cell and replicate count explicit, so that the acceptance workload has one interpretation.
3. As a reviewer, I want seeds unknowable before merge and reproducible afterward, so that calibration and acceptance remain separate.
4. As a biological analyst, I want supported sample size derived across omics-scale feature counts, so that a passing easy cell cannot define applicability.
5. As a method developer, I want execution failures retained in denominators, so that numerical fragility cannot improve a pass rate.
6. As a reader, I want topology, target-selection, geometric, and barrier metrics distinguished, so that one success cannot mask another failure.
7. As a contributor, I want a public validator, so that modified or forged protocols fail before computation.

## Implementation Decisions

- The generic positive grid varies over the Cartesian product of `n = 24, 48, 96, 132, 192` and `p = 100, 1000, 10000, 20000`; `beta = 2` and expression noise SD `0.05` are fixed parameters applied intact to every cell.
- Pure-noise and single-well negative grids vary over `n = 48, 96, 132, 192` and the same four `p` values. Pure noise is an i.i.d. standard-normal expression matrix. The single-well coordinate is i.i.d. standard normal, embedded along a seeded random unit loading with expression noise SD `0.05`. Both use cross-sectional sampling and a balanced binary target independently permuted from expression, with no nuisance field.
- The synchronized AML grid varies over 4, 7, or 12 subjects per condition and `p = 100, 1000, 10000`. Noise, signals, and the complete 11-value AML-informed time schedule are fixed vector-valued parameters, not grid axes.
- Execution uses normalized parameters rather than package defaults. Every control uses centered SVD with six requested components. Generic and negative Stage 2 fits use 512 grid points, polynomial degree 6, layer 1, pooled layers, component 1, and `ks::hpi()` bandwidth selection with no explicit bandwidth value. The generic analysis fixes the planted continuous `x_coord` target and accepted component 1. Negative analyses fix the balanced `reference` versus `comparison` binary `target`, with no nuisance or non-analytical fields. AML fixes the binary CTL-versus-CM `condition` contrast, `batch` as nuisance, `mouse_id` and `batch` as non-analytical fields, no dropout subjects, and zero association-level atlas resamples because the separate identifiability assessment owns decomposition refits.
- The acceptance runner contract is `k1-stage0-acceptance-runner-v1`. Evidence must record that contract, the protocol digest, package version, and source revision. A change to any named generator, strategy, or normalized execution value requires a new reviewed protocol version; it cannot inherit this protocol's acceptance claim.
- Every generic and AML cell receives 100 independent replicates; every negative-control family and cell receives 200.
- Generic success requires SVD subspace angle at most 15 degrees, mean well-location error at most 0.15 coordinate units, barrier-location error at most 0.20 coordinate units, barrier-height error at most 0.50 dimensionless quasi-potential units, and exactly two wells plus one barrier. Barrier-height error is absolute error against `beta` times the physical barrier, hence truth 2 when `beta = 2`.
- A false double well is at least two recovered wells with an intervening barrier. A false target selection is a proposal-eligible coordinate with search-aware maximum-effect permutation p-value at most 0.05 and recurrence at least 0.80 when metadata are independent of expression. Each rate is calculated separately for each negative-control family and grid cell and may not exceed 0.05.
- AML success requires target loading cosine at least 0.90, enclosing target-subspace angle at most 15 degrees, target component 2 ranked first over nuisance component 1, typed `index_recurrence` at least 0.80, mean matched-loading cosine at least 0.85, resample completion at least 0.90, and typed longitudinal Stage 2 ineligibility in every replicate. Orientation recurrence, rank-one fraction, and matched fraction remain separately reported and are not silently substituted for index recurrence.
- Each cell must have pass rate at least 0.90 and Wilson 95% lower bound at least 0.80. Failures remain in the requested denominator. The supported minimum `n` is evaluated only over the shared positive/negative candidate set `48, 96, 132, 192`; it is the smallest candidate passing every declared `p` cell for the generic positive and both negative controls. The `n = 24` positive cell remains a thinness stress test and cannot establish a supported minimum because no matching negative cells exist.
- Negative controls use 99 search-aware permutations and 99 identifiability resamples per replicate; AML uses 99 of each while preserving complete mouse trajectories.
- Seed derivation is `sha256-merge-commit-cell-v1`. Canonical input is `protocol_id|protocol_digest|merge_commit|canonical_cell|replicate_index`; map the first 13 hexadecimal digits to `1 + value mod 2147483644`. This produces `1..2147483644`, respecting the strictest downstream generator's seed-plus-three limit. Any collision is a protocol failure. Canonical varying-field order is `(n,p)` for generic and both negative controls and `(subjects_per_condition,p)` for AML. Cells are `control=<name>` followed by those base-10 integer `field=value` pairs joined with semicolons. Fixed parameters are excluded because the protocol digest already binds them.
- Phase A carries protocol-definition provenance and the accurate claim status `predeclared_acceptance_protocol_only`.

## Testing Decisions

- Test the public constructor and validator rather than private list-building details.
- Assert deterministic digest identity, RDS round-trip identity and validation, immutable execution settings and thresholds, per-cell replicate plans, hidden delayed seed derivation, embedded provenance, and rejection of mutation or forged digests.
- The later runner must test exact cell expansion, seed derivation against fixed examples after the merge value exists, future-backed execution, complete failure accounting, and immutable publication.

## Out of Scope

- Executing or deriving any acceptance seed in phase A.
- Selecting thresholds from acceptance output.
- Publishing pass rates, supported sample ranges, or independent acceptance claims.
- The asynchronous-onset robustness control in #168.

## Further Notes

The phase-A PR landing packet is transition proof, not immutable scientific
evidence. Independent results and the revealed seed manifest are published only
in later content-addressed acceptance artifacts.
