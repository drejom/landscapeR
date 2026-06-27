# Rockne et al. 2020 — State-Transition Analysis of Time-Sequential Gene Expression Identifies Critical Points That Predict Development of Acute Myeloid Leukemia

**Journal**: Cancer Research 2020;80(15):3157–69  
**DOI**: 10.1158/0008-5472.CAN-20-0354  
**Authors**: Russell C. Rockne, Sergio Branciamore, Jing Qi, David E. Frankhouser, Denis O'Meally, Wei-Kai Hua, Guerry Cook, Emily Carnahan, Lianjun Zhang, Ayelet Marom, Herman Wu, Davide Maestrini, Xiwei Wu, Yate-Ching Yuan, Zheng Liu, Leo D. Wang, Stephen Forman, Nadia Carlesso, Ya-Huei Kuo, Guido Marcucci

---

## One-sentence summary

Applied state-transition theory to time-sequential bulk RNA-seq from a *Cbfb-MYH11* (CM) mouse model of AML: built a 2D PCA state-space, estimated a double-well quasi-potential, and used the Fokker-Planck equation to accurately predict which mice would develop leukemia and when—before any circulating blasts were detectable.

---

## Biological question

Can the temporal dynamics of the whole-blood transcriptome be modelled as a particle moving in a quasi-potential, and do the geometry of that potential and its critical points predict disease initiation, progression, and time to leukemia at the individual level?

---

## Dataset

| Item | Detail |
|---|---|
| Model | *Cbfb^{+/56M}/Mx1Cre* conditional knock-in; AML driven by inv(16) CBFB-MYH11 fusion |
| Induction | Poly(I:C) i.v. × 7 doses every other day |
| Training cohort | CM: n=7, Control: n=7; monthly PBMC sampling T0–T10 (up to 10 months or moribund); N=132 samples total |
| Validation cohort 1 | CM: n=9, Control: n=7; same monthly protocol, 6 months |
| Validation cohort 2 | CM: n=3, Control: n=2; sparse sampling during progression |
| Readout | Bulk RNA-seq (PBMC) + flow cytometry (cKit+ blast %) |

---

## Algorithm: step-by-step

### 1. Data matrix construction

- Rows = samples, columns = genes
- Values = log₂-transformed counts per million (cpm) reads
- Column-mean centred: X̄ = X − mean(X)

### 2. Singular value decomposition (SVD) → state-space

```
X̄ = U Σ V*
```

- **U** (unitary): temporal dynamics of each sample
- **Σ** (diagonal): singular values, ordered largest→smallest
- **V\*** (right singular vectors): gene loadings ("eigengenes")

Each column of V* is a principal component axis. The first four PCs captured 66% of variance.

- **PC1** (47% variance): correlated with time for all samples — captures ageing
- **PC2** (11% variance): strongly correlated with Kit expression (surrogate leukemic blast marker); separates CM from control
- State-space constructed from (PC1, PC2) = (x₁, x₂), oriented so control reference state sits at PC2 = 0 and increases toward leukemia moving south (negative PC2)

### 3. Critical points

Four critical points identified geometrically on the PC2 axis:

| Symbol | Name | Biological state |
|---|---|---|
| c₁* | Reference state | Normal hematopoiesis (control) |
| c₁ | Perturbed hematopoiesis | CM-induced, no blasts yet |
| c₂ | Unstable transition | Inflection / point of no return |
| c₃ | Leukemia | Overt AML, high cKit+ blasts |

c₁* and c₁ are local minima (stable); c₂ is a local maximum (unstable); c₃ is a stable minimum.

### 4. Double-well quasi-potential

The quasi-potential U_p(x₂) along the leukemic axis is a polynomial:

```
U_p(x) = α ∫ (x − c₁)(x − c₂)(x − c₃) dx
```

where α is a scaling parameter. This gives a double-well ("W"-shaped) energy landscape with wells at c₁ and c₃ separated by the barrier at c₂.

U_p was estimated by **kernel density estimation (KDE)** of the empirical distribution of PC2 values, then fitting a polynomial whose derivative has zeros at the three critical points.

### 5. Stochastic equation of motion (Langevin)

The transcriptome particle moves according to:

```
dX_t = −∇U_p dt + √(2β⁻¹) dB_t
```

- X_t: position in state-space (PC2 value) at time t
- β⁻¹: diffusion coefficient (noise / stochastic fluctuations)
- B_t: Brownian motion with ⟨B_t, B_s⟩ = δ_{t,s}

β⁻¹ was estimated from the **mean-squared displacement (MSD)** of transcriptome trajectories in the state-space.

### 6. Fokker-Planck (FP) probability density equation

The spatial-temporal evolution of probability density P(x₂, t) is governed by:

```
∂/∂t P(x₂,t) = −∂/∂x₂ [U_p(x₂) P(x₂,t)] + ∂²/∂x₂² [β⁻¹ P(x₂,t)]    (Eq. A)
```

This was solved numerically forward in time, with:
- **Initial condition**: Gaussian kernel centred on the PC2 position of each mouse at the first sampling time point after CM induction (T1)
- **FP parameters**: estimated from the training cohort
- **Time to leukemia**: calculated by integrating the probability density from c₂ to c₃ over time; the expected first arrival time from c₁ to c₃

Survival curves (predicted vs. observed) compared using log-rank test (P >> 0.05 for all validation cohorts, indicating no statistical difference).

### 7. Validation projection

For validation cohorts, samples were projected into the **training-cohort state-space** using the training V* loadings:

```
PC_validation = X_validation · V*_training
```

No re-fitting; only training parameters used.

### 8. Differential expression at critical points

- Each sample assigned to the nearest critical point (smallest Euclidean distance in state-space)
- **Pairwise DEG comparisons** using edgeR, FDR 0.05, |log₂(FC)| > 1
- Event classification:
  - **Early**: c₁ vs c₁* and ~c₂ vs c₁ and ~c₃ vs c₂ (unique to c₁)
  - **Transition**: c₂ vs c₁, ~c₁ vs c₁*, ~c₃ vs c₂ (unique to c₂)
  - **Persistent**: c₁ vs c₁*, c₂ vs c₁, c₃ vs c₂ (all three critical points)

See Table 2 for counts (e.g., c₃ vs c₁* had 11,634 total DEGs).

### 9. Eigengene geometric analysis

Each gene j is a 2D vector:

```
g⃗ = (v₁*, v₂*)
```

- v₁*: loading on PC1 (time/ageing axis)
- v₂*: loading on PC2 (**leukemia eigengene**) — direction toward leukemia state

The larger the magnitude of v₂* and the more negative, the stronger the gene's relative contribution to leukemic state-transition.

Pathway vectors G⃗ = sum of constituent eigengenes:

```
G⃗ = (G₁, G₂) where G₁ = Σᵢ g⃗ᵢ₁, G₂ = Σᵢ g⃗ᵢ₂
```

Only genes that were DEGs in a pathway were included in the sum (pink dots); background genes shown for context.

---

## Key findings

- Transcriptome changes precede detectable leukemic blasts by weeks to months
- Critical point c₂ corresponds to the "point of no return": blast frequency accelerates rapidly after crossing
- State-space trajectories are concordant across all CM mice despite non-synchronous leukemia onset (temporal realignment via state-space)
- Early events at c₁ enrich cytokine signalling (possible homeostatic counter-response)
- Transition events at c₂ enrich DNA metabolic processes / cell cycle
- Persistent events enrich PI3K signalling, Kit upregulation (pro-leukemic)
- AML is interpretable as an "eigenstate" of the transcriptome — an energetically favourable stable configuration
- FP model correctly predicted time to AML in two independent validation cohorts (P >> 0.05 log-rank)
- Key leukemia eigengenes: Kit, CBFB-MYH11, Egfl7, Wt1, Prkd1

---

## Relationship to landscapeR

This paper is the **foundational reference for Stage 2**. The exact method landscapeR generalises:

| Rockne2020 (MATLAB/R ad-hoc) | landscapeR target |
|---|---|
| Plain PCA/SVD on single omic layer | HO-GSVD across multiple omic layers (Stage 1) |
| 1D quasi-potential along PC2 | Multi-dimensional quasi-potential (Stage 2) |
| Polynomial double-well, hardcoded degree | Constrained polynomial, degree chosen by cross-validation (ADR 0002) |
| KDE bandwidth not documented | KDE bandwidth selected by criteria (ADR 0002) |
| FP solved numerically (MATLAB pdepe) | FP solved via deSolve + ReacTran in R |
| Critical points found by visual inspection | Critical points found by automated zero-finding of KDE derivative |

The MATLAB code is at `cohmathonc/CML_mRNA_state-transition` (`CML_Potentials.m`, `CML_fitStationary.m`).

---

## Glossary (from Table 1)

| Term | Meaning |
|---|---|
| State variable | Minimal set describing the mathematical "state" — here, the transcriptome from RNA-seq of PBMCs |
| State-space | All possible configurations; constructed here by PCA of time-series RNA-seq data |
| State-transition | Dynamic process of a system changing from one state to another |
| Probability density | Probability of finding the system at a given state/position at a given time; sums to 1 over all states; given by the Fokker-Planck solution |
| Double-well quasipotential | Energy function with two local minima (wells = stable states) and a local maximum (= unstable transition state); not a physical potential (state-space has no physical units) |
| Eigengene | PCA loading of a gene; "leukemia eigengene" = weight of a gene in the component associated with leukemia |
