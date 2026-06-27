# 0001 — Stage 1 HO-GSVD implementation

**Stage:** 1 (comparative decomposition)
**Status:** proposed
**Date:** 2026-06-27

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

| Option | Source | Key property | Concern |
|---|---|---|---|
| `multiblock::hogsvd` | CRAN, Liland et al., v0.8.10 (May 2026) | Active maintenance, CRAN-stable, no extra deps | Requires full column rank in all matrices — fails on rank-deficient layers without pre-processing |
| Kempf rank-deficient HO-GSVD | SIAM J. Matrix Anal. Appl. 2022; MATLAB `kmpape/HO-GSVD` | Explicitly handles rank deficiency; the case cited in the design spec worked example | No R implementation; requires port or reticulate bridge to sklearn-hogsvd (Python) |
| `derekbeaton/GSVD` | GitHub only, Beaton et al. arXiv 2020 | Constrained/weighted SVD; covers 2-layer case | This is a *different* GSVD (PCA/MCA generalization), not the Alter comparative GSVD; does not extend to N layers with different row dims |
| Roll our own (2-layer GSVD via `geigen`) | base R + `geigen` package | Transparent, auditable, covers 2-layer case | Only 2 layers; scaling to N requires the HO extension |

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

**Not yet available.** Stage 0 thinness sweep has not been run. This ADR is
**provisional** pending those results.

Known from published record:
- `multiblock::hogsvd` uses the standard full-rank formulation (Liland/Smilde).
  Whether pre-processing (truncated SVD projection) adequately approximates
  rank-deficient recovery for our data shapes is unknown.
- Kempf et al. (SIAM 2022) prove recovery guarantees for rank-deficient matrices
  and provide the algorithm the design spec explicitly references.
- No published head-to-head benchmark at the column dimensions relevant here.

## Decision

**Provisional: register `multiblock::hogsvd` as `"hogsvd_standard"` now; implement
or bridge Kempf as `"hogsvd_kempf"` in parallel; decide via Stage 0 thinness sweep.**

Do not hard-wire either. Both live behind the `Decomposer` contract. The thinness
sweep (varying n × SNR × rank-deficiency level) will show where each one's recovery
breaks down. Pick the one whose breakdown threshold is safely above the realistic
data regime. Update this ADR to **accepted** with that evidence.

## Consequences

- The `Decomposer` contract must expose rank tolerance as a parameter so the
  thinness sweep can sweep it.
- `multiblock` added to Imports (or Suggests if we gate it); reticulate + sklearn-hogsvd
  added to Suggests for the Kempf bridge.
- Stage 0 thinness sweep design must include rank-deficiency as an explicit axis,
  not just n × SNR.

## Review trigger

Revisit if: Stage 0 shows `hogsvd_standard` fails recovery below n = 40 on rank-deficient
layers, or if a native R implementation of Kempf becomes available on CRAN/Bioconductor.
