# Frankhouser et al. 2026 — Longitudinal Single-Cell RNA-Sequencing Reveals Evolution of Micro- and Macro-states in Chronic Myeloid Leukemia

**Journal**: Cancer Research 2026 (epublished ahead of print)  
**DOI**: 10.1158/0008-5472.CAN-25-4371  
**Authors**: David E. Frankhouser, Russell C. Rockne, et al.  
**Code**: `cohmathonc/CML.BC.scRNA-manuscript` (GitHub)  
**Data**: GEO GSE296507 (mouse CP and BC CML scRNA-seq); dbGaP phs004729.v1.p1 (human CD34+)

---

## One-sentence summary

Applied time-series scRNA-seq to a BCR::ABL mouse model of CML, showed that the disease state-transition is invisible at single-cell resolution but recoverable by pseudobulk aggregation — the transcriptome encodes a macro-state disease signal that is a collective property of cell populations, not of individual cells — and demonstrated that each of the four PBMC cell types independently undergoes a CML state-transition, with cell-type-specific contributions to the overall disease potential.

---

## The central paradox: micro-states vs. macro-states

This is the conceptual core of the paper:

- **SC-level transcriptomes (micro-states)**: SVD on single-cell data places cells in a high-dimensional space dominated by cell type identity. Disease state (health vs. leukemia) accounts for R² ≤ 0.1 of variation in any of the first 6 PCs. The cells exist in a continuous "superposition of cell states" that always overlaps between healthy and leukemic time points. CML is invisible.

- **Pseudobulk transcriptomes (macro-states)**: Sum counts from all cells per mouse per time point → CPM → SVD. PC1 now captures a clear trajectory from T₀ (healthy) to T_f (leukemic); BCR::ABL expression accounts for R² = 0.80 of variation in PC1. The five-critical-point three-well CML potential from Frankhouser2024 is recovered.

**Interpretation**: Individual cells encode disease information, but it is distributed across thousands of cells and only emerges statistically when averaged. The disease phenotype is a macro-state property of the tissue/population system, not a micro-state property of individual cells.

---

## Dataset

| Item | Detail |
|---|---|
| Model (CP CML) | BCR::ABL inducible (Tet-off) transgenic mouse, CP CML (same as Frankhouser2024) |
| Model (BC CML) | Blast crisis CML mouse; different genotype from CP CML |
| Sampling | Weekly PBMC draws; week 0 (T₀, pre-induction) through week 10 or moribund (T_f); 11 points/mouse, 29 total samples |
| scRNA-seq platform | 10x Chromium, NovaSeq 6000; Cellranger v6.0.0, GRCh38-2020-A; aggregated with Cellranger aggr v6.0.0 |
| Seurat processing | v4 object; QC: ≥200 genes, ≤8000 genes, ≤10% mitochondrial transcripts; genes expressed in ≥3 cells |
| Cell type annotation | SingleR v2.6.0; Human Primary Cell Atlas (celldex v0.1.16.0) |
| Human data | Pediatric CML CD34+ bone marrow (n=4 patients); healthy pediatric CD34+ BM (n=3, STEMCELL Technologies + Lonza); Stanford COG tissue banking |

---

## Algorithm: step-by-step

### 1. SC-level state-space attempt (negative result)

```
X_SC (cells × genes, all time points) → SVD → U Σ V*
```

- PC1, PC2: grouped cells by **cell type**, not disease state
- Tested PCA, UMAP, diffusion map, Decipher, Mellon: none separated health from leukemia
- SVD on each of four cell types independently (B, T/NK, Myeloid, Stem): no PC recovered a disease state-space
- DEGs found at T₀ vs T_f within each cell type: individual genes do change, but the **system-level transition is not detectable at SC resolution**

Quantitative measure: marginal R² (PC ~ time or BCR::ABL alone) and partial R² (variance explained after accounting for mouse identity and cell type). SC data: R² ≤ 0.1 for both time and BCR::ABL across all PCs.

### 2. Pseudobulk (PsB) construction and state-space

```
For each (mouse, timepoint):
  X_PsB[sample] = sum(counts per gene across all cells in that sample)
  → CPM normalise
  → log-transform
→ SVD on X_PsB
→ PC1 = PsB CML state-space
```

PsB state-space: five critical points c₁–c₅ (same three-well potential structure as Frankhouser2024 bulk):

| Symbol | Type | Label |
|---|---|---|
| c₁ | Stable | Early state (Es) |
| c₂ | Unstable | Early-Transition (T-Es) |
| c₃ | Stable | Transition state (Ts) |
| c₄ | Unstable | Transition-Late (T-Ls) |
| c₅ | Stable | Late state (Ls) |

PsB PC1 aligned with bulk CML state-space; dynamics match Frankhouser2024. PsB PC1 R² with BCR::ABL = 0.80; PsB PC1 R² with time strongly significant.

### 3. Cell-type pseudobulk (ctPsB) — separate decompositions

Four cell types: B cells (A₁), T/NK cells (A₂), Myeloid (A₃), Stem cells (A₄).

```
For each cell type i:
  X_ctPsB_i = sum(counts per gene, cells of type i only, per sample)
  → CPM → log-transform
  → SVD on X_ctPsB_i: U_i Σ_i V_i*
  → PC1 or PC2 (whichever correlates best with BCR::ABL + disease time) = ctPsB_i state-space
```

Results:
- B, T, Myeloid ctPsB: **tristable potentials** (three-well, same as full PsB)
- Stem cell ctPsB: **bistable** (noisier due to fewer cells)
- All four cell types independently contain a disease state-space — SC microstates are not individually leukemic, but the aggregated pseudobulk is

### 4. ctPsB projection into the total PsB state-space

To compare cell-type contributions within a common reference frame:

```
U_ctPsB_i = X_ctPsB_i · V_PsB · Σ_PsB⁻¹
```

Using the **total PsB** loading matrix V_PsB and singular values Σ_PsB (not refit on ctPsB data).

- Each cell type's trajectory started and ended at **different coordinates** within the PsB state-space
- The **span** of each ctPsB trajectory (min to max PC1 coordinate) occupied only a subset of the full PsB range
- Span visualisation: each cell type has a characteristic "window" of the state-space it contributes to

### 5. Fixed cell-type simulation for information content

To quantify how much each cell type contributes to CML dynamics:

```
For cell type i:
  Construct a modified PsB:
    - Replace all cells of type i at every time point with their T₀ (week 0) expression
    - Keep all other cell types unchanged
  Compute SVD of modified PsB → simulated trajectory in PC1
  KL divergence = D_KL(P_observed || P_simulated) over the PC1 distribution
```

Higher KL divergence = removing that cell type's dynamics causes more information loss = that cell type contributes more to the macro-state disease signal.

For **human paired samples**: each CML patient (n=4) paired with each healthy sample (n=3); all 4 possible pairings run; mean KL divergence reported across pairings.

### 6. Variance-weighted R² for multi-PC characterisation

```
Vr(X) = Σ_k var_k · R²_k(X)
```

where var_k = fraction of variance explained by PC_k, R²_k(X) = R² of PC_k regressed on variable X (time or BCR::ABL). Summarises how much of overall variance in the dataset is explained by X, accounting for PC importance.

### 7. PsB and ctPsB mechanistic model (ODE system)

Extends the three-node Frankhouser2024 model to five coupled variables: four cell-type populations A₁–A₄ plus the pseudobulk transcriptome state U.

**Full PsB transcriptome dynamics (weights w_i):**

```
dU/dt = Σᵢ [k_{CAᵢU} / (1 + (Aᵢ/Aᵢ₀)^n_{AᵢU})] · wᵢ
      + k_{SUU} · (U/U₀)^n_{UU} / (1 + (U/U₀)^n_{UU})
      − γ_U · U
```

- Full PsB: all wᵢ = 1
- ctPsB_i (cell type i only): wᵢ = 1, all other w_j = 0

**Individual cell-type dynamics (general form):**

```
dAᵢ/dt = k_{CAᵢ} · (C/Cᵢ₀)^n_{CAᵢ} / (1 + (C/Cᵢ₀)^n_{CAᵢ})
        + k_{UAᵢ} / (1 + (U/UAᵢ₀)^n_{UAᵢ})
        − γ_{Aᵢ} · Aᵢ
```

where C = BCR::ABL expression level (bifurcation parameter).

**Abstract general form (Eqs. 1–5):**

```
dAᵢ/dt = g(C,U) − γ_{Aᵢ} · Aᵢ                        (1)
dU/dt  = h(Aᵢ,U) − γ_U · U                             (2)

Steady-state Aᵢ: Aᵢ = g(C,U)/γ_{Aᵢ} ≡ g'(C,U)        (3)

Substituting: dU/dt = h(g'(C,U), U) − γ_U U            (4)

Effective potential:
V(C,U) = −∫₀ᵁ [h(g'(C,x), x) − γ_U x] dx             (5)
```

Equation 5 gives the potential landscape as a function of BCR::ABL level C and transcriptome state U. Used to generate bifurcation diagrams showing how ctPsB potentials can be monostable, bistable, or tristable while the combined PsB remains tristable.

### 8. Antagonistic teams of genes

```
1. Select top 90th percentile of eigengene magnitudes from CP CML PsB state-space
   → 2951 genes
2. Compute gene × gene correlation matrix using leukemic sample expression
3. Hierarchical clustering → two mutually anticorrelated groups
4. Label each gene pro- or anti-CML based on sign of eigengene in PsB state-space
5. Repeat at SC level for each cell type:
   - Use same 2951 eigengenes
   - Build gene × gene correlation per cell type
   - Cut dendrogram into 3 branches; remove largest (weakly correlated)
   - Visualise two remaining branches as antagonistic teams per cell type
```

### 9. Blast crisis (BC) CML application

- BC CML mice processed identically to CP CML
- BC CML PsB state-space: **PC1** (vs PC1 also in CP CML — consistent)
- BC CML potential: **bistable** (two stable + one unstable critical point), not tristable
- ctPsB projections for BC CML: different locations and contributions to PsB state-space vs. CP CML
- Fixed cell-type simulation applied to BC CML

---

## Key findings

1. **CML state-transition is invisible at single-cell resolution**: cell type dominates all leading PCs; disease accounts for R² ≤ 0.1. SC-level analysis methods (PCA, UMAP, diffusion map, Decipher, Mellon) all fail.

2. **Pseudobulk aggregation recovers the disease macro-state**: PsB PC1 shows clear T₀ → T_f trajectory with R² = 0.80 for BCR::ABL. Five-critical-point three-well potential matches bulk results from Frankhouser2024.

3. **Each cell type independently encodes a disease state-transition**: B, T, Myeloid ctPsB each have tristable potentials. Stem cells (fewer cells) appear bistable. Cell-type disease signals are individually coherent but distinct.

4. **Cell types contribute differently to the PsB state-space**: each ctPsB trajectory spans only a subset of the total PsB coordinate range; they start and end at different state-space locations — the total PsB is not a simple sum of identical per-cell-type signals.

5. **Model unification**: the five-node ODE system shows mathematically how tristable PsB dynamics can emerge from cell types that are themselves bistable or tristable — the system-level potential is not the average of its parts.

6. **BC CML**: bistable potential (vs. tristable CP CML), consistent with a simpler two-state disease progression in blast crisis.

7. **Human CD34+ BM**: fixed cell-type simulation (with all pairings) applied to 4 pediatric CML patients — shows which cell types are informative in human CML bone marrow.

---

## Relationship to landscapeR

### The user's GSVD framing

> "With the GSVD we now have cell type as a common element between the two things. This paper shows how pseudobulk recovers macro-states, but what about this GSVD approach for single cell data?"

This paper uses **separate SVD per cell type** followed by **projection into a shared state-space**. The workflow is:

1. Compute total PsB state-space by SVD on all-cell aggregate
2. Compute ctPsB state-spaces by SVD on each cell-type aggregate independently
3. Project ctPsB into total PsB using training loadings: `U_ctPsB = X_ctPsB · V_PsB · Σ_PsB⁻¹`

This is sequential and approximate — the ctPsB SVDs are fit independently, so there is no guarantee the resulting components are orthogonal in any shared sense; alignment to the common frame is post-hoc via projection.

**The GSVD alternative**: treat each cell type's pseudobulk matrix as a separate data matrix fed to HO-GSVD. With K cell types, you have K matrices, each (samples × genes):

```
{X_B, X_T, X_Myeloid, X_Stem}   (each: time-points × genes)
```

HO-GSVD decomposes these simultaneously:

```
Xᵢ = Uᵢ Σᵢ V*   (shared right singular vectors V across all cell types)
```

The shared V gives **cell-type-invariant gene loadings** — the axes that are common to all cell types simultaneously. These shared axes separate variation that is **consistent across cell types** (macro-state disease signal) from **cell-type-specific** variation (micro-state).

| Approach | What "common" means | Output |
|---|---|---|
| Paper's approach | Shared projection basis from full PsB SVD | Post-hoc alignment; PsB loadings not derived from ctPsB signal |
| GSVD approach | Simultaneous decomposition; V* is literally the common structure across cell-type matrices | Principled separation: shared axes = macro-state; cell-type-specific axes = micro-state |

**Concrete prediction**: the GSVD shared axis (common V*) should recover the same disease trajectory that PsB pseudobulk finds, but it would be derived **from the cell-type-specific pseudobulk matrices directly** rather than from their sum — and it would come with a measure of how much each cell type's signal aligns with the shared axis vs. is unique to that cell type.

This could replace both the ctPsB SVD step and the projection step with a single principled factorisation, and would make the micro-state / macro-state distinction algebraically explicit rather than emergent from aggregation.

### Implications for landscapeR Stage 1

| Paper feature | landscapeR relevance |
|---|---|
| SC-level SVD fails (cell type dominates) | Confirms that plain SVD on SC data is not the right approach for disease state detection; GSVD or pseudobulk aggregation needed |
| ctPsB: separate SVD per cell type then project | Viable baseline approach; GSVD would be the principled generalisation |
| ctPsB trajectories span different subsets of PsB space | GSVD cell-type-specific singular vectors should capture this cell-type specificity naturally |
| Five-node ODE producing tristable PsB from cell-type sub-potentials | Motivates multi-dimensional Stage 2 quasi-potential; the 1D quasi-potential along a single PC is an approximation of a higher-dimensional landscape |
| Fixed cell-type simulation + KL divergence | Stage 0 ablation protocol: "knock out" a layer in HO-GSVD and measure information loss (KL divergence of recovered state-space) — exact analogue |
| BC CML: bistable (2-well) vs. CP CML: tristable (3-well) | Stage 2 must support flexible N-well potentials; the number of critical points is a model output, not an input parameter |
| Human pediatric CD34+ BM: 4 CML × 3 healthy | Stage 0 thinness sweep should test at this sample scale (very small n) |

### What this paper does NOT provide

- The paper does not implement GSVD or any multi-matrix joint decomposition
- The paper does not compare GSVD to its ctPsB-then-project approach
- The paper does not address the rank-deficiency question (the diabetes genotype layer will be rank-deficient — the GSVD must handle this; see ADR 0001)

---

## Methods glossary (terms introduced in this paper)

| Term | Definition |
|---|---|
| Pseudobulk (PsB) | scRNA-seq counts summed over all cells per sample (mouse × timepoint), then CPM-normalised; analogous to bulk RNA-seq |
| Cell-type pseudobulk (ctPsB) | As PsB but summed within one cell type only |
| Micro-state | Transcriptional state of an individual cell; continuous, no clear disease axis |
| Macro-state | Population-level aggregate transcriptional state (pseudobulk); discrete disease states emerge |
| Span (of a ctPsB trajectory) | Min to max PC1 coordinate observed for a given cell type when projected into PsB state-space |
| Fixed cell-type simulation | Replace one cell type's expression at all time points with its T₀ value; measure information lost from resulting PsB trajectories |
| Variance-weighted R² | Vr(X) = Σ_k var_k · R²_k(X) — summarises overall variance explained by variable X across all PCs |
| Antagonistic teams | Two mutually anticorrelated gene clusters (pro- and anti-CML), identified by clustering a gene × gene correlation matrix on top eigengene genes |
