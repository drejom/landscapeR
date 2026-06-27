# Stage 1 — Comparative decomposition

Stage 1 takes K omic layers as input and produces a shared state-space whose axes explicitly contrast biological conditions (disease vs control, temperature, genotype). It separates shared signal from layer-specific variation and from confounders, using GSVD (K=2) or HO-GSVD (K≥2).

## Language

**omic layer**:
A single type of molecular measurement contributing one data matrix to Stage 1 — e.g. mRNA, miRNA, methylation, proteomics, genotype. Each layer is one matrix: rows = samples (shared across layers), columns = features (layer-specific).
_Avoid_: modality, assay, data type (too generic in this context)

**comparative decomposition**:
The Stage 1 operation: decomposing K omic layers simultaneously so that shared axes reflect contrast between biological conditions, not just variance within a single layer.
_Avoid_: joint PCA, multi-omic PCA

**GSVD**:
Generalised SVD of exactly two matrices; the K=2 special case of HO-GSVD. Produces one shared right singular matrix V* and two left coordinate matrices U₁Σ₁ and U₂Σ₂.
_Avoid_: joint SVD

**HO-GSVD**:
Higher-order GSVD of K≥2 matrices. Produces one shared V* (gene loadings common across all layers) and K layer-specific left coordinate matrices UᵢΣᵢ. This is the primary Stage 1 algorithm.
_Avoid_: multi-block PCA (a different method), tensor decomposition (incorrect framing), HOSVD (a different factorisation)

**shared subspace**:
The subspace spanned by the columns of V* — the axes that are common across all K omic layers. Contains the disease axis and other shared sources of variation.
_Avoid_: common space, joint embedding

**disease axis**:
The specific column of V* (and corresponding row of each UᵢΣᵢ) whose coordinate separates healthy from disease state variables and correlates with disease burden markers. Identified by inspecting correlation with clinical covariates.
_Avoid_: leukemia axis (disease-specific), PC1/PC2 (too generic — the disease axis may not always be PC1)

**layer-specific variation**:
Variation captured in UᵢΣᵢ but not in V* — unique to one omic layer, absent from others. Represents omic-layer-specific signal (e.g. miRNA-specific regulation not reflected in mRNA).
_Avoid_: residual, noise (it may be meaningful biology)

**eigengene**:
The loading of a gene on the disease axis (a scalar value from the relevant column of V*). Quantifies that gene's directional contribution to the state-transition. Positive or negative sign indicates direction relative to disease progression.
_Avoid_: gene weight, PC loading, feature importance (prefer eigengene when the loading has biological interpretation on the disease axis)

**projection**:
Mapping new samples into an existing Stage 1 state-space using training loadings without refitting: `X_new · V*_training · Σ_training⁻¹`. Used for validation cohorts and treatment groups.
_Avoid_: embedding, transfer, out-of-sample prediction

**rank-deficient layer**:
An omic layer whose matrix has fewer linearly independent rows or columns than expected (rank < min(rows, cols)). Requires a rank-deficiency-aware HO-GSVD implementation (Kempf variant). The diabetes genotype layer is expected to be rank-deficient.
_Avoid_: singular matrix (rank-deficiency may be partial, not total singularity)

### Algorithm candidates (open — see ADR 0001)

**multiblock HOGSVD**:
The `multiblock::hogsvd` R implementation of HO-GSVD. Does not handle rank-deficient layers.

**Kempf HO-GSVD**:
A rank-deficiency-aware HO-GSVD implementation (Kempf et al.). Required when any layer is rank-deficient. Both this and multiblock HOGSVD should be registered as strategies; Stage 0 recovery benchmarks decide which is preferred.
