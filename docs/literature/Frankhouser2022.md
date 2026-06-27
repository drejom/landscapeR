# Frankhouser et al. 2022 — Dynamic Patterns of MicroRNA Expression During Acute Myeloid Leukemia State-Transition

**Journal**: Science Advances 2022;8(16):eabj1664  
**DOI**: 10.1126/sciadv.abj1664  
**Authors**: David E. Frankhouser, Denis O'Meally, Sergio Branciamore, Lisa Uechi, Lianjun Zhang, Ying-Chieh Chen, Man Li, Hanjun Qin, Xiwei Wu, Nadia Carlesso, Guido Marcucci, Russell C. Rockne, Ya-Huei Kuo

---

## One-sentence summary

Replicated the Rockne2020 state-transition framework on the **miRNA transcriptome** from the same CM AML mouse model, showing miRNA also undergoes a system-wide state-transition with the same double-well quasi-potential geometry, predicting time to AML in an independent validation cohort comparably to mRNA.

---

## Biological question

Do miRNA expression dynamics encode AML state-transition information independently of mRNA, and can the same mathematical framework (SVD → state-space → Fokker-Planck) be applied to the miRNA transcriptome to model and predict AML development?

---

## Dataset

| Item | Detail |
|---|---|
| Model | Same *Cbfb-MYH11* CM knock-in (*Cbfb^{56M+}/Mx1Cre*; C57BL/6) as Rockne2020 |
| Training cohort | CM: n=7, Control: n=7; monthly PBMC sampling t=1–10 months or moribund |
| Validation cohort | CM: n=9, Control: n=7; up to 6 months |
| Readout | Small RNA-seq (PBMC) + flow cytometry (cKit+ blast %) |
| Library prep | AllPrep DNA/RNA Kit (Qiagen); alignment with Bowtie2; counts from miRTop/Cutadapt/SAMtools |

---

## Algorithm: step-by-step

### 1. Data matrix construction

- Data matrix X: all time-sequential samples (CM + control) as rows, miRNAs as columns
- Values: log-normalised miRNA count matrix
- Mean-centred: X̄ = X − mean(X, cols)

### 2. SVD → state-space

```
X = U Σ V*
```

- **U**: left singular vectors = state-space coordinates (sample positions over time)
- **V\***: right singular vectors = miRNA loadings (PC loadings; the "feature space")
- **PC1**: most strongly correlated with Kit mRNA expression (R² = 0.68, P < 0.001) and gave greatest CM/control separation → chosen as the **miRNA AML state-space axis**
- PC2 used as second axis for 2D visualisation only

### 3. Critical points

Three critical points on PC1 corresponding to local minima/maxima of the double-well quasi-potential:

| Symbol | Name | Definition |
|---|---|---|
| c₁ | Perturbed hematopoiesis | K-means cluster centroid K1 (CM early time points) |
| c₂ | Unstable transition | Boundary between K1 and K3; estimated as argmax of Boltzmann ratio between c₁ and c₃ |
| c₃ | AML | K-means cluster centroid K3 (CM late/moribund time points) |

K-means with K=3 on PC1 coordinates of CM samples; K=2 cluster boundary gives c₂ estimate. Simulation studies confirmed K1 and K3 centroids are best estimators of c₁ and c₃.

### 4. Double-well quasi-potential

The miRNA quasi-potential is a double-well polynomial:

```
U_p(x) = α ∫ (x − c₁)(x − c₂)(x − c₃) dx
```

α is a scaling parameter. The potential wells at c₁ and c₃ are the stable states; the peak at c₂ is the unstable transition.

### 5. Langevin / Fokker-Planck

Same framework as Rockne2020:

**Langevin equation of motion:**

```
dX_t = −∇U_p(X_t) dt + √(2β⁻¹) dB_t
```

**Fokker-Planck (FP) equation:**

```
∂/∂t P(x,t) = −∂/∂x [∇U_p(x) P(x,t)] + ∂²/∂x² [β P(x,t)]    (Eq. 1)
```

β = diffusion coefficient; estimated as the average slope of mean-squared displacement (MSD) of each mouse's state-space trajectory over time (see Supplementary Fig. S11).

**Time to AML prediction**: integrate FP solution from c₂ to −∞ over time, using Gaussian kernel initial condition centred on PC1 position of each mouse at first post-induction time point (validation cohort T1).

Predicted vs. observed survival curves: log-rank P = 0.79; HR = 0.86 (0.26 to 2.8) — no significant difference.

### 6. Differential expression at critical points

Critical points used as **pseudo-time reference** to align mice at equivalent disease states:

- **Early events**: DE miRNAs unique to c₁ (vs control)
- **Transition events**: DE miRNAs unique to c₂ (vs control)
- **Late events**: DE miRNAs unique to c₃ (vs control)
- **Persistent events**: DE miRNAs at all three critical points c₁, c₂, c₃

Critical point–based comparisons used the Boltzmann ratio (c₂ boundary) to partition samples; DE analysis performed with DESeq2.

### 7. Eigengene vectors for miRNA

Each miRNA is a 2D vector:

```
v⃗ = (V₁*, V₂*)
```

- V₁*: PC loading magnitude (how strongly the miRNA contributes to defining the AML state-space)
- Sign and magnitude of V₁* determine whether the miRNA has positive or negative contribution to AML state-transition

A miRNA contributes positively to AML if:
- Negative V₁* loading **and** increased expression, OR
- Positive V₁* loading **and** decreased expression

Example: miR-409-5p had the largest negative loading value and was up-regulated → strongest positive contribution to AML.

Mean contribution vectors for each event group (early/transition/late/persistent) visualised as:

```
v⃗ = (mean(V₁*_up), mean(V₁*_down))
```

### 8. Expression dynamics and clustering

Hierarchical clustering on the correlation matrix of all CM mouse time points, for each event group's DE miRNAs. Four distinct patterns identified:

| Group | Pattern | Peak/trough near c₂? | Biology |
|---|---|---|---|
| 1 | Nonmonotonic — local **maximum** near c₂ | Yes | Cytokines, inflammation, Wnt, IL-6, TNFα-NFκB, TGFβ |
| 2 | Monotonic — continuously **decreasing** | No | Metabolism, p53 signalling, adhesion |
| 3 | Nonmonotonic — local **minimum** near c₂ | Yes | Immune response, antigen processing, TLR signalling |
| 4 | Monotonic — continuously **increasing** | No | Cell differentiation, apoptosis, PI3K-Akt |

Groups 1 and 3 (nonmonotonic, near c₂) suggest these miRNAs facilitate or resist the irreversible transition at c₂.

### 9. Cross-modal comparison: miRNA vs mRNA state-spaces

To compare miRNA and mRNA state-spaces, the angle between their PC vectors was computed using the **vector dot product**:

```
cos(θ) = (PC_miRNA · PC_mRNA) / (|PC_miRNA| × |PC_mRNA|)
```

The two state-space PCs that were most similar (smallest angle): miRNA PC1 and mRNA PC2 (defined in Rockne2020). Only 5/129 total samples classified differently between the two state-spaces. Both encode disease progression information, but are not identical.

### 10. Validation projection

```
YV = U_y Σ_y   where   YV = X_validation · V*_training
```

Validation state-space taken as the first component of this projection, consistent with training data. Critical points same as training.

---

## Key findings

- miRNA transcriptome undergoes the same double-well state-transition as mRNA during AML development
- Critical points c₁, c₂, c₃ defined on PC1 (miRNA state-space) match biological disease stages
- State-transition model correctly predicts which mice did not develop AML (those that never crossed c₂)
- miRNA and mRNA state-spaces are nearly equivalent (5/129 samples differently classified)
- Top persistent DE miRNA: miR-126a-5p (positive contribution), miR-181c-5p (negative contribution)
- miR-126a — hallmark of inv(16) AML; crucial for CM-induced AML development
- Nonmonotonic miRNAs near c₂ may represent biomarkers of irreversibility

---

## Relationship to landscapeR

This paper demonstrates the method is **omic-agnostic**: the same SVD → state-space → FP pipeline works on miRNA as well as mRNA. Key implication for landscapeR:

- The Stage 1 GSVD/HO-GSVD generalisation must handle arbitrary omic layers (mRNA, miRNA, proteomics, methylation) without assuming any single layer is "the" state-space axis
- The cross-modal alignment (vector dot product to compare PC angles) is an analytic technique that landscapeR may want to implement for validating multi-layer decomposition
- The K-means c₂ estimation method is more systematic than visual inspection and could seed the Stage 2 automated critical-point finder

---

## Methods reference: Fokker-Planck (exact form used)

```
∂/∂t P(x,t) = −∂/∂x (∇U_p(x) P(x,t)) + ∂²/∂x² (β P(x,t))
```

Initial condition: Gaussian kernel with width estimated from validation cohort data (Table S4).

Time to AML calculated by integrating P(c₅|t) = 1 − ∫∫ p(x,τ) dx dτ over time, evaluated at experimental observation points.
