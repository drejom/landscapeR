# Frankhouser et al. 2024 — State-Transition Modeling of Blood Transcriptome Predicts Disease Evolution and Treatment Response in Chronic Myeloid Leukemia

**Journal**: Leukemia 2024;38:769–780  
**DOI**: 10.1038/s41375-024-02142-9  
**Authors**: David E. Frankhouser, Russell C. Rockne, Lisa Uechi, Dandan Zhao, Sergio Branciamore, Denis O'Meally, Jihyun Irizarry, Lucy Ghoda, Haris Ali, Jeffery M. Trent, Stephen Forman, Yu-Hsuan Fu, Ya-Huei Kuo, Bin Zhang, Guido Marcucci

---

## One-sentence summary

Extended the state-transition framework from AML to CML using a BCR::ABL Tet-off transgenic mouse model, constructed a **three-well leukemic potential** (vs. the two-well AML potential), identified five critical points corresponding to distinct disease states, predicted disease evolution and treatment response from the **earliest time point** alone, and showed that TKI treatment returns transcriptomes only to an intermediate state (not health), while TKI cessation leads to relapse.

---

## Biological question

Can state-transition models predict CML disease evolution, treatment response, and relapse at the individual level from only the earliest measurable transcriptome time point — and can they explain why TKI treatment fails to fully eradicate leukemia stem cells?

---

## Dataset

| Item | Detail |
|---|---|
| Model | SCLtTA/BCR::ABL inducible transgenic (B6 background); CML recapitulates human CP CML |
| Induction | Tet withdrawal (Tet-off) = BCR::ABL expression; Tet re-administration = suppression |
| Cohorts | CML: n=8; Control (Tet-on): n=6; TOTO (Tet-off→Tet-on, 12 wk): n=4; TKI (nilotinib 50 mg/kg oral, 4 wk): n=7 |
| Sampling | Weekly blood draws, weeks 0–18 (or moribund), total N≈35,000 samples × 39,927 genes |
| Readout | Bulk RNA-seq (PBMC) via NovaSeq 6000; BCR::ABL fusion quantified by Salmon (TPM) |

---

## Key conceptual advance over Rockne2020 / Frankhouser2022

- **Three-well potential** (not two-well): CML has three stable disease states (Early, Transition, Late) separated by two unstable transition states
- **Mechanistic potential derived from a network model** (three-node ODE) rather than purely from KDE of data
- **Treatment explicitly modelled** as a force term in the Langevin equation
- **Five critical points** (c₁–c₅) instead of three

---

## Algorithm: step-by-step

### 1. State-space construction (SVD/PCA)

```
SVD on X (n=39,927 genes, all time-sequential CML + control samples)
X = U Σ V*
```

- PC2 chosen as the **CML state-space axis** ("CML state-space") based on:
  1. Greatest separation between control (Tet-on) samples and CML moribund endpoint samples
  2. Best linear fit with BCR::ABL expression levels (R² = 0.48)
- 37.8° rotation of the PC1 vs PC2 plane applied to maximise the linear fit of all control samples parallel to x-axis, then PC2 re-defined as the rotated component

### 2. Five critical points

The CML state-space (PC2) was characterised by five critical points via KDE of the empirical distribution:

| Symbol | Type | Label | Biological state |
|---|---|---|---|
| c₁ | Stable minimum | Early state (Es) | Early CML — anti-CML gene expression |
| c₂ | Unstable maximum | Early-Transition state (T-Es) | Boundary between Es and Ts |
| c₃ | Stable minimum | Transition state (Ts) | Mid-disease CML — pro-CML gene expression |
| c₄ | Unstable maximum | Transition-Late state (T-Ls) | Boundary between Ts and Ls |
| c₅ | Stable minimum | Late state (Ls) | Late CML — maximum leukemic growth |
| c_h | Stable (control only) | Health state (Hs) | Normal hematopoiesis (control mice only) |

The three wells represent the most energetically favourable CML steady states.

### 3. CML potential: two approaches

#### Approach A — Empirical (KDE-derived)

```
Polynomial fitted to KDE density distribution of PC2 values
Critical points = zeros of the derivative of the density curve
```

#### Approach B — Theoretical (three-node network model)

A three-compartment mechanistic model (adapted from Dey and Barik 2021 DNFL-B circuit):

```
dA/dt = G_A(S, B) − k_A A
dB/dt = G_B(A, B) − k_B B
```

Where:
- A = PBMC cell population (observable: transcriptome variation)
- B = internal transcriptome state
- S = BCR::ABL signal (input)
- G_A, G_B = rate functions using Hill switching functions H⁻(x) and H⁺(x)

The **effective potential** V(x) is the integral of the steady-state rate:

```
V(B, S) = −∫₀^B [G_B(G_A*(S,x), x) − k_B x] dx
```

BCR::ABL off → single-well potential at Hs (c_h)  
BCR::ABL max → three-well potential with minima at c₁, c₃, c₅

Both approaches gave qualitatively identical potential landscapes that mapped directly onto each other (Fig. 2B,C).

### 4. Stochastic equation of motion

Same Langevin framework but now in the CML potential V_CML:

```
dX_t = (−∇U_p + F̃) dt + √(2R̃) dB_t
```

Where for **untreated CML**:  
- F̃ = 0, R̃ = β⁻¹ (diffusion estimated from MSD)

For **TOTO treatment** (BCR::ABL suppression):

```
F̃_TOTO = γ_TOTO · H(t − t_Tet-on) ∇U_p-TOTO
R̃_TOTO = β⁻¹ + (β^{-1}_{Tet-on} − β⁻¹) H(t − t_Tet-on)
```

γ_TOTO = treatment strength parameter (empirically estimated: γ_TOTO = 1.1)

This transformed the tri-stable CML potential to a single-well potential at c₂.

For **TKI treatment** (nilotinib):

```
F̃_TKI = γ_TKI · exp(−λ(t − t_{TKI-off})) H(t − t_{TKI-on}) ∇U_p-TKI
λ = nilotinib half-life parameter
```

γ_TKI = 1.4 (empirically estimated)

TKI reduced BCR::ABL signal, transforming the potential to a bi-stable with wells at c₁ and c₃ (not reaching Hs). When BCR::ABL approached zero, Hs could only be reached if BCR::ABL → 0.

### 5. Fokker-Planck for treatment prediction

For CML untreated:

```
∂/∂t p = ∂/∂x (−∇U_p p) + β^{-1}_{CML} ∂²/∂x² p
```

For TOTO:

```
∂/∂t p = ∂/∂x (−∇U_p-TOTO + F̃_TOTO) p + R̃_TOTO ∂²/∂x² p
```

For TKI:

```
∂/∂t p = ∂/∂x (−∇U_p-TKI-CML + F̃_TKI) p + β^{-1}_{TKI} ∂²/∂x² p
```

**Time to disease**: P[c₅|t] = 1 − ∫∫ p(x,τ) dx dτ evaluated from c₅ outward.

Predicted vs. observed time to disease: log-rank P = 0.8; concordance index = 0.75.

### 6. Mean squared displacement (MSD)

Used to estimate the diffusion coefficient β:

```
MSD(t) = ⟨|x(t) − x_m|²⟩
```

x_m = CML state-space trajectory from simulation using treatment model. MSD fitted by linear regression for 0.1 ≤ γ ≤ 2.0 and 0.001 ≤ β ≤ 0.1. Best combination selected at minimum MSD coefficient of variation.

### 7. DEG analysis at critical points

Samples grouped by their CML state-space location (PC2 coordinate), assigned to nearest stable critical point (c₁, c₃, c₅) using the **empirical potential** to define boundaries:

- Unstable critical points c₂ and c₄ (dashed lines) define state boundaries
- DEGs identified using DESeq2 comparing each disease state vs. healthy control Hs (c_h)
- Also pairwise between disease states (Es vs. Ts, Ts vs. Ls, Es vs. Ls)

Results (vs. Hs): Es: 78 DEGs; Ts: 366 DEGs; Ls: 1,860 DEGs

#### Eigengene contribution to CML

CML eigengene = PC loading value from V* column 2 (the CML state-space loading) for each gene:

- **Pro-CML eigengene**: positive loading, down-regulated expression OR negative loading, up-regulated expression → moves sample toward Ls
- **Anti-CML eigengene**: positive loading, up-regulated OR negative loading, down-regulated → moves sample toward Hs

Visualised as a 2D "eigengene space" plot (V₁* vs V₁_CML contribution).

### 8. Gene expression dynamics — "gene modules"

Correlation-based clustering of DEG expression along the CML state-space coordinate:

- Each DEG expression plotted as function of CML state-space (PC2) coordinate (not time)
- Hierarchical clustering on correlation matrices; clusters cut at median correlation > 0.25
- **Early DEGs**: 0 modules (no coordinated dynamics pattern)
- **Transition DEGs**: 1 module (increasing expression toward Ls)
- **Late DEGs**: 2 modules (one increasing, one decreasing, both with inflection points at T-Ls c₄)

Inflection points of gene modules occur at the **unstable critical points** (T-Es c₂ and T-Ls c₄), supporting the hypothesis that coordinated expression changes at transitions drive disease evolution.

### 9. Transition driver genes

For each unstable critical point (T-Es c₂ and T-Ls c₄):
1. Select all DEGs from disease state comparisons
2. Define transition point region: samples within CML state-space coordinates [c₁, c₃] for T-Es, or [c₃, c₅] for T-Ls
3. Correlate each DEG's expression with the shape of the CML potential around the transition point
4. Driver genes = those with correlation coefficient > 0.5 and linear regression significance P < 0.05
5. Extended to high-confidence STRINGdb protein-protein interaction (PPI) partners (interaction score > 900)
6. EnrichR GSEA on resulting PPI network

T-Es (c₂) drivers: complement, coagulation, IL-2/Stat5 signalling  
T-Ls (c₄) drivers: reactive oxygen species, coagulation, allograft rejection, complement, inflammatory response, EMT, adipogenesis, apoptosis, TNFα-NFκB, IL-6/Jak/Stat3, angiogenesis, apical surface

### 10. Treatment effect analysis

Treatment cohorts (TOTO, TKI) projected into CML state-space using training V*:

```
PC_treatment = X_treatment · V*_training · Σ^{-1}_training
```

DEGs comparing treatment groups to controls (Hs) or disease states identified using DESeq2, with sex as a covariate. Age-related DEGs subtracted by comparing early vs. late control samples.

---

## Key findings

- CML transcriptome follows a three-well leukemic potential with five critical points (two stable transition boundaries)
- State-transition model predicts CML trajectories from the **earliest detectable time point** (week 0, before BCR::ABL is measureable by flow)
- TOTO (complete BCR::ABL suppression): rapidly returned transcriptomes near c₂ (a new near-healthy stable state); 38 residual pro-CML DEGs remained even after complete BCR::ABL suppression
- TKI: returned transcriptomes only to Ts (c₃), not to health; mice relapsed rapidly after treatment ended — mirrors clinical TKI failure patterns
- TKI treatment strength parameter γ_TKI = 1.4 (vs γ_TOTO = 1.1), suggesting complete BCR::ABL suppression has greater transcriptomic impact
- Disease states at Es (c₁) characterised by **anti-CML** gene expression (system resisting leukemia)
- Transition and late states characterised by **pro-CML** gene expression (driving disease)
- Inflammation and angiogenesis enriched at both Ts and Ls; metabolic processes enriched at Ls

---

## Relationship to landscapeR

This paper shows the general framework applies to CML (chronic phase → blast crisis progression) as well as AML and establishes several critical extensions:

| Frankhouser2024 extension | landscapeR relevance |
|---|---|
| Three-well potential from three-node ODE | Stage 2 must support N-well potentials (not hardcoded double-well) |
| Mechanistic (network) + empirical (KDE) potentials compared | Both approaches should be registerable strategies (ADR 0002) |
| Treatment as a force term F̃ in Langevin | Future Stage 2 extension: treatment perturbation modelling |
| Five critical points (not three) | Critical-point finder must be automated (no hardcoded count) |
| c₂ boundary defined by unstable critical point (not K-means) | Confirm automated method handles both 2-well and 3-well landscapes |
| Gene modules via correlation with state-space coordinate | Stage 2 output: expression dynamics along quasi-potential axis |

The MATLAB reference code implementing the core of Frankhouser2024 is at `cohmathonc/CML_mRNA_state-transition`.

---

## Methods summary: exact equations

### CML potential (theoretical)

```
V_CML(x) = a(x − c₁)(x − c₂)(x − c₃)(x − c₄)(x − c₅)
```

### Normal potential (theoretical, from zeros)

```
V_normal(x) ≈ a(x − c₁)(x − c₂)(x − c₃)
```

### TOTO potential

Treatment transforms the potential by removing the two late wells:

```
∇U_p-TOTO-CML = a(x − c₁)(x − c₂)(x − c₅)  ≈ V_TOTO(x)
∇U_p-TOTO-normal = a(x − c₂)  ≈ V(x)
Δ(∇U_TOTO) = a(x − c₂)(x² + c₁(c₅ − x) − c₅ x − 1)
```

### TKI potential

```
∇U_p-TKI-CML = a(x − c₁)(x − c₂)(x − c₃)  ≈ V_TKI(x)
∇U_p-TKI-normal = a(x − c₁)(x − c₂)(x − c₃)  ≈ V(x)
Δ(∇U_TKI) = a(c₃ − c₅)(x − c₁)(x − c₂)
```

### FP equations for each treatment

**CML:**
```
∂/∂t p = ∂/∂x(−∇U_p p) + β^{-1}_{CML} ∂²/∂x² p
```

**TOTO:**
```
∂/∂t p = ∂/∂x[(−∇U_p-TOTO + F̃_TOTO) p] + R̃_TOTO ∂²/∂x² p
```

**TKI:**
```
∂/∂t p = ∂/∂x[(−∇U_p-TKI-CML + F̃_TKI) p] + β^{-1}_{TKI} ∂²/∂x² p
```

### Time-to-disease integration

```
P[c₅|t] = 1 − ∫_{c₅}^{∞} ∫₀^t p(x,τ) dτ dx
```

Continuous curve evaluated at 1-week intervals; observed time to disease = first crossing of the c₅ critical point in the CML state-space.
