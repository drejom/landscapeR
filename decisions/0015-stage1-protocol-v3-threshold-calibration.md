# 0015 — Stage 1 protocol v3: dimension-aware acceptance thresholds

**Status:** provisional  
**Date:** 2026-07-12  
**Supersedes:** ADR 0011 (v2 absolute thresholds)  
**Depends on:** ADR 0011, ADR 0012

---

## Context

The v2 Stage 1 evidence run (40,960 tasks, 0 failures, artifact
`stage1-heterogeneous-v2-*`) produced a decisive negative result: C2 (and C1)
failed 88/128 SRE strata and 32/128 projection strata against the frozen v2
thresholds (SRE ≤ 0.25, projection ≤ 0.30).

Post-hoc falsifiable diagnostics revealed the root cause:

```
n=20, p=400, rank=2, signal=24, noise=1
  Oracle SRE (noiseless):          0.000   <- metric + generator correct
  Optimal per-layer SVD (median):  0.224   <- finite-sample floor
  Optimal per-layer SVD (q90):     0.260   <- already above 0.25 threshold
  Block-scaled concat SVD (median):0.297   <- C2 is worse than per-layer
```

The oracle recovers perfectly (metric and generator are correct). A provably
optimal method — SVD applied directly to the signal-plus-noise matrix — already
sits at median 0.224 with a q90 of 0.260 at these dimensions. The v2 threshold
of 0.25 is tighter than the **finite-sample floor of any correct algorithm**.

This is a **protocol calibration failure**, not an algorithm failure. The v2
absolute thresholds were not anchored to what is achievable at the actual
(n, p, rank) conditions in the protocol grid. The BBP detectability criterion
tells us the signal is above the phase transition; it says nothing about how
quickly eigenvector estimates converge in finite samples, which depends on the
aspect ratio p/n.

The v2 holdout is consumed and cannot be revisited.

---

## Decision

### 1. Thresholds must be dimension-aware

Every acceptance threshold in protocol v3 must be expressed as a margin above
the **oracle floor** — the median (or chosen quantile) SRE/projection error
achieved by an optimal single-layer SVD at the same (n, p_layer, rank)
conditions over a large number of replicates (≥ 500), not as an absolute value.

Formally:

```
threshold_sre(n, p, rank) = floor_q90(n, p, rank) + margin_sre
threshold_proj(n, p, rank) = floor_q90_proj(n, p, rank) + margin_proj
```

where `floor_q90` is the 90th-percentile SRE of the oracle estimator (plain
SVD on single-layer data) over the replicate distribution, and `margin_*` are
positive constants declared in this ADR before any v3 run.

**Rationale:** a candidate only deserves acceptance if it beats or matches the
theoretically optimal single-layer baseline. Requiring improvement over that
floor is the correct scientific bar.

### 2. Candidates must be compared against the per-layer oracle, not each other

The v2 protocol compared C1 against C2 as if one of them would be accepted.
The correct reference is the **per-layer SVD oracle** — a method that ignores
the multi-layer structure entirely. Any multi-layer candidate that does not beat
this floor provides no justification for the additional complexity.

### 3. The protocol grid must span n and p explicitly

The v2 grid varied K, shared_signal, noise_sd, exclusive_signal, and
missing_block_rate but held n=20 and p fixed per layer. The oracle floor
depends strongly on both n and p (roughly as (p/n)^½ in the bulk). Protocol v3
must include n and p as grid axes so that per-condition floor estimates are
available for every stratum.

Proposed additions to the v3 grid:

| Axis      | v2 values      | v3 additions          |
|-----------|----------------|-----------------------|
| n         | 20 (fixed)     | 20, 40                |
| p (small) | 80 (fixed)     | 80, 200               |
| p (large) | 400 (fixed)    | 400, 1000             |

### 4. Floor estimation is a mandatory pre-run step

Before any candidate run, a **floor estimation pass** must:

1. Enumerate all (n, p_layer, rank) combinations in the v3 grid
2. Run ≥ 500 replicates of per-layer SVD under the null signal model
   (signal = 0, pure noise) and under the planted-signal model
3. Record median and q90 of SRE and projection error per condition
4. Write the floor table into the protocol manifest and include it in the
   content-addressed artifact directory

Floor estimates are frozen alongside the protocol. Any change to n, p, or rank
requires a new floor estimation pass and a new protocol version.

### 5. Margins are declared here before any v3 run

Until the concurrent benchmark completes (see Implementation below):

- `margin_sre  = 0.05`  (a candidate must achieve SRE ≤ floor_q90 + 0.05)
- `margin_proj = 0.05`

These values are provisional and will be updated in this ADR once the benchmark
result is available. **Do not begin a v3 candidate run until this ADR is
updated with final margin values.**

### 6. C2 (block-scaled concatenated SVD) requires re-evaluation

The diagnostic showed C2's median SRE (0.297) is *above* the per-layer oracle
floor (0.224) at the default conditions — meaning concatenation is actively
harmful relative to processing layers separately. The v3 candidate list should:

- Retain the per-layer pool as the **reference baseline** (not C2)
- Evaluate whether C2's deficit is due to the block-scaling denominator
  (Frobenius norm grows with p, so larger layers dominate after normalisation)
- Evaluate HOGSVD consensus (C1's iterative aligner) as a candidate only if it
  beats the per-layer pool floor
- Consider JIVE/MOFA-class methods only if both simpler candidates fail

---

## Consequences

- **v2 result stands**: the negative finding is scientifically valid — both v2
  candidates failed the v2 thresholds. The interpretation now is that the v2
  thresholds were unachievable, not that the methods are without merit.
- **#24 remains blocked**: no v3 candidate may proceed to a real-data
  discovery/confirmation run until this ADR is fully accepted (margins
  finalised, floor table frozen, protocol v3 document written).
- **New issue needed**: track (a) floor estimation pass, (b) protocol v3
  document, (c) v3 candidate run.
- **ADR 0011 amended**: append a cross-reference to this ADR noting that v2
  thresholds are superseded for all future protocol versions.

---

## Implementation

### Concurrent benchmark (in progress, 2026-07-12)

A 200-replicate benchmark across the following conditions is running now:

- n ∈ {20, 40}
- p ∈ {80+400, 200+1000} (heterogeneous layers)
- K ∈ {2, 3}
- signal ∈ {24, 48, 96}
- noise_sd ∈ {1, 2}

Three estimators: per-layer pool, block-scaled concat (C2), iterative consensus (C1).

Results will be used to:
1. Confirm whether C1 (consensus) beats the per-layer floor at any condition
2. Set the final `margin_sre` and `margin_proj` values in section 5 above
3. Determine whether C2 is recoverable or should be replaced

**Benchmark completed 2026-07-12. Results and margin updates follow.**

### Benchmark results (200 replicates × 48 conditions)

Conditions: n ∈ {20,40}, p ∈ {80+400, 200+1000}, K ∈ {2,3},
signal ∈ {24,48,96}, noise_sd ∈ {1,2}.

**Three estimators compared:**
- `per_layer`: SVD each layer, pool via sum-of-projectors (oracle reference)
- `concat` (C2): block-scale, concatenate, single SVD
- `consensus` (C1): iterative Procrustes consensus on per-layer SVD scores

```
Conditions where consensus (C1) beats per-layer pool:  0 / 48
Median C1 gain over per-layer:  +0.143  (positive = C1 is WORSE)
```

Selected illustrative rows (sorted by per-layer floor):

```
 n   p_spec K signal noise  pl_median  co_median  cs_median
20   80+400 3     96     1     0.026      0.194      0.194   <- K=3 best case
40   80+400 3     96     1     0.037      0.133      0.133
20   80+400 2     96     1     0.032      0.190      0.309   <- K=2: C1 diverges
40   80+400 2     48     2     0.214      0.264      0.718   <- K=2 high noise: catastrophic
40  200+1000 2    24     1     0.260      0.281      0.709   <- v2 exact conditions
```

**Interpretation:**

1. **C1 (consensus) is genuinely suboptimal**, not just threshold-miscalibrated. It is worse than a
   simple per-layer pool at every one of 48 conditions. The K=2 failure is severe (SRE up to 0.72
   vs oracle floor 0.03–0.26): the iterative alignment has too little evidence to converge with
   only two layers.

2. **C2 (block-scaled concat) is also worse than the per-layer pool** at all 48 conditions,
   confirming the diagnostic: concatenating heterogeneous-p layers after Frobenius normalisation
   dilutes the signal unequally.

3. **The per-layer pool IS a sensible candidate** — sum of per-layer projectors, leading
   eigenvectors of the pooled projector matrix. It is not currently registered as a production
   strategy and was not in the v2 candidate set.

4. **Both problems are real and separable:**
   - Threshold calibration failure: the v2 threshold (0.25) is at or below the per-layer floor
     q90 for 10/48 conditions (including the v2 exact grid).
   - Algorithm failure: C1 and C2 are genuinely worse than the per-layer pool at all conditions.

### Revised decisions from benchmark

**Section 2 update — correct reference baseline:** the per-layer pool (sum-of-projectors) is
added as the mandatory reference baseline for v3. Any candidate must beat the per-layer pool
median, not just beat the v2 absolute threshold.

**Section 5 update — final margin values:**

Given that the per-layer pool is now the reference, margins are set relative to its median:

- `margin_sre  = 0.05`  (candidate median SRE ≤ per-layer pool median − 0.05, i.e. must
  beat the pool by at least 0.05 to be accepted)
- `margin_proj = 0.05`  (same logic for projection error)

These are the final v3 margin values. The per-layer pool floor is computed empirically per
condition in the mandatory floor estimation pass (Section 4).

**Section 6 update — v3 candidate list:**

| Candidate | Status | Rationale |
|---|---|---|
| Per-layer pool | **Reference baseline** (new) | Theoretically well-motivated; best performer in benchmark |
| C1 (consensus) | **Dropped** | 0/48 wins over per-layer; catastrophic K=2 failure |
| C2 (concat) | **Dropped** | 0/48 wins over per-layer; block-scaling bias confirmed |
| JIVE-class | To evaluate in new ADR | Explicit rank separation may improve on pool |
| MOFA-class | To evaluate in new ADR | Factor model may handle heterogeneous p better |

Any new candidate must be specified in a new ADR before a v3 run.

---

## References

- Diagnostic script: `/tmp/diagnose-sre.R`, `/tmp/diagnose-floor.R`
- Benchmark script: `/tmp/benchmark-consensus-vs-floor.R`
- v2 artifact: `inst/benchmarks/stage1-heterogeneous-v2-*/`
- ADR 0011: `decisions/0011-stage1-candidate-comparison-protocol.md`
