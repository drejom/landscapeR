# Decision Map: HO-GSVD Algorithm Choice (ADR 0001)

**Goal**: Choose the Stage 1 HO-GSVD implementation — `multiblock::hogsvd` vs Kempf rank-deficient variant.

**Context**: All omic matrices in this pipeline are rank-deficient by construction (p >> n: ~20,000 genes, ~30–100 samples). The diabetes instantiation uses scRNA-seq pseudobulk + ATAC-seq pseudobulk from HPAP. The algorithm must handle rank deficiency as the normal case.

**Status**: In progress — tickets #1 and #2 can be resolved this session.

---

## #1: Does `multiblock::hogsvd` handle rank-deficient matrices?

Blocked by: —
Type: Research (install package, inspect source, run small test)

### Question

Can `multiblock::hogsvd` accept matrices where p >> n without crashing or silently producing incorrect results? What does the implementation do when input matrices are rank-deficient?

### Answer

**No — it crashes on every real omic matrix.** The implementation calls `solve(crossprod(X))` on each layer. With p >> n (e.g. 20,000 genes, 30 samples), `X'X` is p×p with rank at most n — singular. `solve()` throws: `"system is computationally singular: reciprocal condition number = 2.86e-21"`. Confirmed empirically (n=20, p=200). `multiblock::hogsvd` is unusable for omics data as-is.

---

## #2: What is the Kempf HO-GSVD — is there an R implementation?

Blocked by: —
Type: Research (gh CLI / CRAN / literature search)

### Question

What exactly is the Kempf rank-deficiency-aware HO-GSVD? Is there an R package, a standalone implementation, or is this a paper-only result that would require porting? What is the reference?

### Answer

The "Kempf" reference in ADR 0001 appears to point to the **hogsvdR** package (`barkasn/hogsvdR`, CRAN-mirrored). It uses `MASS::ginv` (Moore-Penrose pseudoinverse) instead of `solve()` everywhere, making it rank-deficiency-safe by construction.

**Confirmed correct:** K=3, n=15, p=300 (rank-deficient): 45 non-zero eigenvalues (≈ K×n, as expected), perfect reconstruction error = 0.

**Build issue:** hogsvdR uses RcppArmadillo and fails to compile on macOS arm64 / R 4.5 due to a C++14 flag + gfortran linker issue. The R-only `rsimple` backend (identical algorithm, no Rcpp) works fine and is sufficient for correctness testing.

**Open scaling question:** `ginv` on a p×p matrix requires O(p³) computation. At p=5,000 this is the bottleneck — timing not yet complete. Standard solution is to pre-reduce with truncated SVD to rank-n before applying HO-GSVD (see ticket #3a).

---

## #3a: Is pre-reduction (truncated SVD → HO-GSVD) needed for performance?

Blocked by: #2
Type: Prototype

### Question

At realistic omics scale (n=40, p=20,000, K=2–3), is the naive `ginv`-based HO-GSVD fast enough? If not, does pre-reducing each layer to its rank-n subspace (via truncated SVD) before HO-GSVD give correct results and acceptable speed?

### Answer

**Pre-reduction is essential.** Naive ginv at p=5,000 did not complete within several minutes (O(p³) = O(5000³) SVD of a 5000×5000 matrix). Pre-reduction approach:

1. Thin SVD each layer to rank-(n-1): `X = U Σ V*` → work with `U Σ` (n × rank, full rank)
2. Run HO-GSVD on the small (n × rank) reduced matrices — `solve()` is fine, they're full rank
3. Map the shared subspace back to gene space: `V_gene = V_layer * V_reduced`

**Benchmarks (confirmed working):**

| n | p | K | Time |
|---|---|---|------|
| 40 | 5,000 | 2 | 0.04s |
| 30 | 20,000 | 2 | 0.06s |
| 40 | 5,000 | 3 | 0.03s |

Non-zero eigenvalues = n-1 (as expected from theory). The approach is correct and fast.

**Confirmed timing comparison:**

| Approach | n=40, p=5,000, K=2 |
|---|---|
| Naive ginv (hogsvdR) | **290s** |
| Pre-reduction (truncated SVD first) | **0.04s** |

7,000× speedup. Pre-reduction is the only viable approach at omics scale.

**Implication:** landscapeR's Stage 1 strategy should implement pre-reduction as the standard path. The `multiblock::hogsvd` and raw `hogsvdR` APIs are both wrong for omics use — neither does pre-reduction. We need to implement this ourselves.

---

## #3: Synthetic rank-deficient benchmark

Blocked by: #1, #2, #3a
Type: Prototype

### Question

On a small synthetic dataset (n=20 samples, p=500 genes, K=2 layers, known ground-truth shared subspace), do both implementations recover the correct shared subspace? How do they differ in speed, numerical stability, and output structure?

### Answer

*Unresolved*

---

## #4: Register one or both as strategies?

Blocked by: #3
Type: Grilling

### Question

Should landscapeR register both implementations as selectable strategies (user picks via `PipelineConfig`), or should Stage 0 benchmarks pick a single default and the other be dropped? What are the conditions under which a user would want to switch?

### Answer

*Unresolved*

---

## #5: Update ADR 0001

Blocked by: #4
Type: Grilling

### Question

With evidence from #1–#4, what is the final decision recorded in ADR 0001? What are the acceptance criteria, the chosen default strategy, and any caveats?

### Answer

*Unresolved*
