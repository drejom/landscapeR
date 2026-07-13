# 0001 — Stage 1 HO-GSVD implementation

**Stage:** 1 (comparative decomposition)
**Status:** provisional-accepted for legacy equal-feature use; reopened for a heterogeneous baseline
**Date:** 2026-06-27
**Updated:** 2026-07-13

## Context

Stage 1 requires decomposing N ≥ 2 data matrices with **different row dimensions**
(pathology features ≠ transcriptome features ≠ genotype variants) matched on a
shared column dimension (donors). This is the defining case for HO-GSVD and the
case that rules out stacked SVD or plain PCA entirely.

The diabetes instantiation has three layers: pathology + transcriptome + genotype.
The genotype layer is almost certainly rank-deficient (p >> n). The pathology and
transcriptome layers may also be rank-deficient at realistic donor counts (n ~ 20–80).

The R-primary constraint (design spec §0) means native R is strongly preferred;
a reticulate bridge is permitted only inside a single plug-in.

## Options considered

| Option | Source | Key property | Verdict |
|---|---|---|---|
| `multiblock::hogsvd` | CRAN, Liland et al., v0.8.10 (May 2026) | Active maintenance, CRAN-stable | **Rejected** — calls `solve(X'X)` on p×p; crashes on every rank-deficient matrix (all omics data) |
| `hogsvdR` (barkasn/hogsvdR) | GitHub/CRAN | Uses `MASS::ginv`; rank-deficiency safe | **Rejected** — O(p³) ginv; 290s at p=5,000 (7,000× too slow); fails to build on macOS arm64/R 4.5 |
| Kempf rank-deficient HO-GSVD | SIAM J. Matrix Anal. Appl. 2022 | Handles rank deficiency explicitly | **No R implementation** — the Kempf approach is what landscapeR's own implementation approximates via pre-reduction |
| **Pre-reduction + V-averaging** (implemented here) | Native R, this codebase | Pre-reduce each layer to rank-(n-1) via thin SVD; average per-layer disease-axis vectors | **Chosen** — exact noiseless recovery, 0.02–0.10s at full omics scale, multi-layer averaging confirmed |
| Pre-reduction without averaging | Native R | Pre-reduce but select single best component | **Registered as baseline** — equivalent to best single-layer SVD; use for debugging/comparison |

## Criteria

Defined before Stage 0 benchmarks exist. A chosen implementation must:

1. **Handle rank-deficient matrices** at the column dimensions expected in the diabetes data
   (n ~ 20–80 donors; genotype layer will be rank-deficient by construction).
2. **Correctly isolate layer-exclusive subspaces** — measured by principal subspace angles
   against planted ground truth in the Stage 0 confounder-separation control.
3. **Detection floor at realistic n** — the thinness sweep (Stage 0) must show signal
   recovery at n ≥ 20 for the expected SNR range.
4. **Swappable** — must sit behind the `Decomposer` contract so it can be replaced without
   touching downstream stages.

Availability and maintenance are *necessary* but not *sufficient* — they do not
override criteria 1–3.

## Evidence

From in-session benchmarks (`decisions/maps/hogsvd-algorithm.md`):

**Correctness:**
- Noiseless rank-1 case (K=2, n=10, p=20): exact 0° subspace recovery — algorithm is correct
- `multiblock::hogsvd` crashes immediately: `solve()` on singular `p×p` matrix (confirmed n=20, p=200)
- `hogsvdR` naive ginv: 290s at p=5,000 (confirmed via timing)
- Pre-reduction: 0.024s at p=5,000; 0.10s at p=20,000 (7,000× speedup vs naive ginv)

**Multi-layer advantage (V-averaging):**
| K | SVD best(°) | V-averaged(°) |
|---|---|---|
| 2 | 34.72 | 26.71 |
| 3 | 34.71 | 22.30 |
| 5 | 34.71 | 17.51 |

**BBP signal threshold:** signal `s` must exceed `(n·p)^(1/4)` to emerge from noise bulk.
At p=5,000, n=40: threshold ≈ 21. Real omic data (disease R²~0.8 in pseudobulk) is well above.

**Open (Stage 0 must fill):**
- Weighting scheme: `σ_i²`-weighted vs equal-weight V-averaging — Stage 0 double-well recovery sweep
- Minimum n for reliable recovery at omics p — Stage 0 thinness sweep
- BBP threshold as hard gate vs soft warning — Stage 0 calibration

## Decision

**Implement two strategies behind the `Decomposer` contract:**

1. **`"hogsvd_averaged"`** (default): Pre-reduce each layer to rank-(n-1) via thin SVD,
   extract per-layer first right singular vector `v_i^(1)`, then form shared disease axis
   as `V* = Σ_i (σ_i^(1))² · v_i^(1)` normalized. Emits a warning (not error) when
   `σ_1 < (n·p)^(1/4)` (signal below noise bulk). This is the recommended production strategy.

2. **`"hogsvd_prereduced"`** (baseline): Pre-reduce as above but select a single component by
   `which.max(mean_sigma)` without cross-layer averaging. Equivalent to best single-layer SVD.
   Use for debugging and as the low-level building block.

Do NOT register `multiblock::hogsvd` or `hogsvdR` — both are unusable at omics scale.

## Consequences

- `multiblock` removed from Imports/Suggests (no longer needed)
- `MASS` needed for `ginv` in edge cases; already a dependency
- `Decomposer` contract must accept `K` input layers and a `strategy` parameter
- `PipelineConfig` default: `decomposer_strategy = "hogsvd_averaged"`
- Stage 0 thinness sweep must include: n sweep × signal strength × K layers

## Review trigger

Revisit if: Stage 0 shows `hogsvd_averaged` fails below n = 20 in the thinness sweep,
or a native R Kempf implementation appears that provides better theoretical guarantees.

## 2026-07-12 amendment — heterogeneous feature spaces

ADR 0009 establishes that genuine multi-omic layers may have different feature
spaces and that shared structure is therefore defined in matched sample space.
The current shared-gene-loading V-averaging implementation cannot satisfy that
contract; it remains a legacy equal-feature special case pending replacement.

The next algorithm decision must compare two registered candidates on a
predeclared Stage 0 ladder:

1. an aligned **symmetric** sample-score consensus that thin-SVDs each layer,
   aligns sample-space components without privileging an omic layer, and
   retains per-layer feature loadings and response profiles; and
2. a block-scaled concatenated-SVD baseline.

Equal post-preprocessing layer influence is the initial consensus baseline.
Reliability-weighted variants are predeclared Stage 0 comparison candidates;
raw feature count, sequencing depth, or singular value must not silently set a
layer's influence. A selected baseline remains registered as a regression
comparator. Future
`Decomposer` strategies require their own ADR and a predeclared comparison to
the accepted strategy on the same Stage 0 harness before admission.

## 2026-07-13 amendment — frozen heterogeneous v2 result

The complete `stage1-heterogeneous-v2` Stage 0 evidence run completed all
40,960 tasks with no task failures. Its content-addressed, hash-verified
artifact is committed at:

```
inst/benchmarks/stage1-heterogeneous-v2-a28239b9af0c5569e3be1892a5b60308c8451aefa04a165852cf521606087d4c/
```

The artifact records source commit
`6f1f0614b2c4f0d539baa69a20df1ef43705ade6`. Calibration selected
`C2_block_scaled_svd`; however, C2 failed the frozen holdout acceptance rule
(`thresholds_passed = FALSE`). Accordingly, **no heterogeneous Stage 1
baseline is accepted** and Issue #24 remains blocked.

This is a confirmation failure, not a license to select C1 or to retune C2:
C1 was not the calibration-selected candidate and the v2 holdout is consumed.
Any revised candidate or threshold must be proposed in a new ADR and evaluated
under a newly frozen protocol, while retaining this artifact unchanged.
