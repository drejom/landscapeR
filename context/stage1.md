# Stage 1 — Comparative decomposition

Stage 1 takes K ≥ 1 omic layers as input and produces a shared state-space whose axes explicitly contrast biological conditions (disease vs control, temperature, genotype). It separates shared signal from layer-specific variation and from confounders.

**K=1 (single-layer SVD)** is the reference case: plain SVD on one mRNA matrix. The Frankhouser/Rockne 2020 AML paper uses K=1 mRNA with PC2 as the disease axis (PC1 encodes age — a nuisance variable). This is the baseline that must be validated with Stage 0 synthetic controls before any real-data K=1 analysis.

**K=2 (GSVD)** and **K≥2 (HO-GSVD)** are the multi-layer generalisations. The target biological axis may be any component, not necessarily PC1 — the component-selection proposal ranks candidates against predeclared biological metadata.

## Language

**omic layer**:
A single type of molecular measurement contributing one data matrix to Stage 1 — e.g. mRNA, miRNA, methylation, proteomics, genotype. Each layer is one matrix: rows = samples (shared across layers), columns = features (layer-specific).
_Avoid_: modality, assay, data type (too generic in this context)

**feature-space heterogeneity**:
The invariant that each omic layer may have its own feature set and feature count (e.g. genes, pathology measurements, or variants). Stage 1 must represent shared structure in the matched sample space and retain layer-specific feature loadings; it must not require equal feature dimensions across layers.

**complete paired cohort**:
The intersection of biological observations with valid measurements in every omic layer required for Stage 1 fitting. Missing omic blocks are neither interpolated nor zero-filled. Excluded observations and their missingness patterns are recorded; technical-replicate resolution occurs in assay-specific preprocessing, outside landscapeR. After dedicated missingness validation, an incomplete observation may be a visibly projection-only descriptive point, but never enters target selection, bootstrap resampling, density fitting, or Stage 2 inference.

**analysis-ready omic matrix**:
An assay-specific, quality-controlled matrix supplied to landscapeR after normalization, transformation, technical-replicate resolution, and encoding appropriate to that omic layer. Those upstream decisions remain outside landscapeR but their provenance is retained; Stage 1 applies only its declared generic centering/scaling policy.

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
The subspace spanned by the columns of V* — the axes that are common across all K omic layers. It contains candidate target biological axes and other shared sources of variation.
_Avoid_: common space, joint embedding

**state-space definition**:
The immutable, machine-generated record of the discovery observations, feature identities, preprocessing reference, and fitted component basis that jointly define one state space. Everything present at the Stage 1 input boundary is eligible: row/sample filtering is upstream analyst preparation and should use provenance-recording helpers where available. The analyst does not manually copy feature or sample IDs into `AnalysisSpecification`; Stage 1 records the exact ordered IDs, exclusions, input digest, preprocessing parameters, and fitted loadings it actually used.

Stage 1 accepts one discovery `StateTransitionData` object. Projection is a separate, optional operation on zero or more secondary objects. A secondary cohort can only be projected after matching its features to the frozen state-space definition; it never contributes observations, features, centring/scaling parameters, component selection, or analysis identity back into that definition. A study without an external projection cohort remains valid. For the planned diabetes application, non-diabetic, autoantibody-positive, and type 1 diabetes donors define the ordered cross-sectional discovery state space; type 2 diabetes donors may be projected as an optional external biological comparison and must not alter that definition.

**target biological axis**:
The selected column of V* (and corresponding row of each UᵢΣᵢ) whose coordinate is associated with a predeclared biological variable or contrast. It is selected from a reproducible, predeclared proposal ranking or manually fixed by the analyst; the final choice and rationale are recorded in provenance.
_Avoid_: PC1/PC2 (too generic — the target biological axis may not be the dominant component)

**disease axis**:
A disease-specific target biological axis whose coordinate separates healthy from disease state variables or correlates with disease burden markers.

**metadata-association atlas**:
A structured, serializable table of associations between every Stage 1 component and every eligible `colData` field. It is computed before component selection and answers which recorded variables each component is *associated with*; it does not infer causation or declare a variable to be a confounder. Identifier fields (for example `mouse_id`) are excluded. Fields and their eventual scientific roles are marked as predeclared or discovered so the discovery/confirmation boundary remains explicit.

The atlas always preserves **univariate associations** for transparent interpretation. Once nuisance fields are declared, it may additionally report **adjusted associations** (for example, condition after accounting for weeks). Adjusted results are labelled separately and never replace or hide their unadjusted counterparts. The component proposal must retain both rather than collapse them into an opaque composite score.

Only a discovery-cohort atlas may drive `propose_component()` and `confirm_component()`. After confirmation, the target axis and complete state-space definition are frozen. A projected-cohort atlas is validation-only: it evaluates the already selected coordinates and is structurally prohibited from reranking components or changing the `AnalysisSpecification`. For AML, `primary_2018` defines the state space and `supp_2016` is a hostile projection stress test; timepoint and sequencing run are confounded in the 2016 experiment, so it is not a clean independent replication cohort.

Association assessment must honour the `SamplingDesign` declared on `StateTransitionData` (ADR 0006). Cross-sectional data use independent-observation methods. Longitudinal data use the declared subject-ID and ordered-time columns; adjusted estimates and uncertainty must account for within-subject repeated measures. Subject identifiers are design variables, not association targets. If longitudinal data lack a compatible subject-aware association method, assessment fails explicitly rather than silently treating observations as independent. The atlas records the model and sampling design used.

**component-selection proposal**:
A reproducible ranking of Stage 1 components after an analyst assigns metadata fields the roles target, confounder/nuisance, descriptive-only, or excluded. It recommends, but does not silently choose, a target biological axis. It must not use the downstream Stage 2 quasi-potential as a selection criterion. The assigned roles and whether they were predeclared or discovered become part of the `AnalysisSpecification` and provenance.

The ranking criterion is declared per-analysis and supports multiple association forms:
- **continuous association**: Spearman correlation of component scores against a numeric metadata column (e.g. weeks post-infection, developmental day). Use to identify or deprioritise time/age-driven components.
- **binary group separation**: rank-biserial or point-biserial correlation of component scores against a binary metadata column (e.g. condition CM vs CTL, sex). Use to identify disease or contrast axes.
- **longitudinal trajectory divergence**: a subject-aware condition-by-time interaction for repeated observations. For AML, report both average CM-versus-CTL separation and divergent trajectories; the interaction is the stronger disease-progression criterion.
- **cross-sectional ordered-state trend**: association with a predeclared ordering of independent biological states. For diabetes, the discovery ordering is non-diabetic → autoantibody-positive → type 1 diabetes. This is evidence of ordered cross-sectional states, not direct observation of within-person temporal progression.

Multiple forms may be declared together; a component may rank high on one and low on another (as in AML: PC1 ranks high on weeks, while the disease axis is expected to capture condition separation and trajectory divergence). Orthogonal biological measures such as cKit expression or blast counts can provide convergent diagnostic support but do not silently select the axis.

The proposal is a **formal scored object** (not just a plot): it carries a ranked list of components with their association scores. `plot_components()` visualises this object; tests can assert against it directly.

**Two downstream paths from the proposal object:**
- *Synthetic controls*: ground truth is known (planted component index is recorded in `SubspaceGroundTruth`). CI asserts `proposal$rank[1] == ground_truth_component` automatically — no human needed.
- *Real data*: ground truth is unknown. Human reviews the gallery, then calls `confirm_component(proposal, index = k)` to promote component k to a `manual_component` in the `AnalysisSpecification`. Human is mandatory; this step cannot be automated away.

**Intended API sequence:**
```r
# Step 1: run Stage 1
std2 <- decompose(dec(), std)@value

# Step 2: surface all eligible metadata associations
atlas <- associate_metadata(std2)
plot(atlas)

# Step 3: analyst assigns scientific roles and inspects proposal
proposal <- propose_component(
    atlas,
    target = "condition",
    confounders = "weeks_post_infection"
)
plot(proposal)

# Step 4: confirm and proceed (human decision for real data;
#          automated assertion in synthetic control tests)
aspec <- confirm_component(proposal, index = 2L)
# id auto-generated: "{dataset}_{target_field}_PC{k}"
# e.g. "aml_2018_condition_PC2", "synthetic_condition_PC1"
# Stable: same dataset + target field + component choice -> same id
run_pipeline(std2, cfg_with(aspec))
```

**axis orientation anchor**:
An optional predeclared biological metadata rule that gives a selected target biological axis a semantic direction (for example, increasing developmental day or toward treated samples). Technical alignment to the discovery-cohort reference is automatic; directional biological claims require this anchor and must not use downstream Stage 2 topology to set it.

**metadata roles**:
A declaration that separates one target biological variable, named nuisance variables, and diagnostic metadata. Eligible undeclared `colData` fields, including QC metrics, are screened automatically as diagnostics; identifiers are ignored by default. Strong diagnostic or nuisance association creates a visible confounding alert and calls for sensitivity analysis, never silent selection, orientation, residualisation, or correction. Missing values in required target/nuisance/orientation fields exclude that biological observation from the analysis cohort and are recorded; diagnostic screens report available-case counts without imputing metadata.

**target-axis run**:
One reproducible pipeline run with exactly one target biological axis. Distinct biological questions use distinct named runs, each with its own selection rule, orientation anchor, nuisance declaration, stability assessment, and provenance; a run must not search across targets for the most persuasive landscape. Studies with multiple runs predeclare one primary confirmatory analysis; the rest are exploratory unless a multiplicity plan says otherwise.

**layer-response profile**:
The per-omic-layer direction, magnitude, concordance, and uncertainty on a selected target biological axis. It preserves asymmetric biology—such as anti-correlated miRNA and mRNA responses—and supplies the evidence for or against pooling layers in Stage 2. If an incomplete observation is projected descriptively, its source omic layer is predeclared from this profile, never chosen automatically from availability.

**layer-specific variation**:
Variation captured in UᵢΣᵢ but not in the shared sample-space coordinate — unique to one omic layer, absent from others. Represents omic-layer-specific signal (e.g. miRNA-specific regulation not reflected in mRNA).
_Avoid_: residual, noise (it may be meaningful biology)

**eigengene**:
The loading of a gene on a selected target biological axis (a scalar value from the relevant column of V*). Quantifies that gene's directional contribution to the chosen biological contrast. Its sign is interpreted relative to the axis orientation recorded for that analysis.
_Avoid_: gene weight, PC loading, feature importance (prefer eigengene when the loading has biological interpretation)

**projection**:
Mapping new samples into an existing Stage 1 state-space using discovery-cohort loadings without refitting: `X_new · V*_training · Σ_training⁻¹`. Used for confirmation cohorts and treatment groups after the target biological axis and analysis choices have been frozen.
_Avoid_: embedding, transfer, out-of-sample prediction

**discovery/confirmation boundary**:
The separation between a primary cohort used to select a target biological axis and a secondary cohort projected into the frozen state-space to assess replication. Claims without an independent confirmation cohort are exploratory, not confirmatory.

**rank-deficient layer**:
An omic layer whose matrix has fewer linearly independent rows or columns than expected (rank < min(rows, cols)). Requires a rank-deficiency-aware HO-GSVD implementation (Kempf variant). The diabetes genotype layer is expected to be rank-deficient.
_Avoid_: singular matrix (rank-deficiency may be partial, not total singularity)

### Algorithm candidates (open — see ADR 0001)

**multiblock HOGSVD**:
The `multiblock::hogsvd` R implementation of HO-GSVD. Does not handle rank-deficient layers.

**Kempf HO-GSVD**:
A rank-deficiency-aware HO-GSVD implementation (Kempf et al.). Required when any layer is rank-deficient. Both this and multiblock HOGSVD should be registered as strategies; Stage 0 recovery benchmarks decide which is preferred.
