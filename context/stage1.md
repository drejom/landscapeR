# Stage 1 — Comparative decomposition

Stage 1 takes K ≥ 1 omic layers as input and produces candidate low-dimensional state-space axes without using outcome labels during decomposition. The subsequent metadata-association atlas, component proposal, and human confirmation determine which axis supports a predeclared biological contrast and which axes capture nuisance or layer-specific variation.

**K=1 (single-layer SVD)** is the reference case: the registered `svd` `Decomposer` strategy accepts exactly one omic layer and performs plain SVD. It is not a degradation branch of `hogsvd_averaged`, and strategy selection is explicit rather than inferred from layer count. The Frankhouser/Rockne 2020 AML paper uses K=1 mRNA with PC2 as the disease axis (PC1 encodes age — a nuisance variable). This is the baseline that must be validated with Stage 0 synthetic controls before any real-data K=1 analysis.

**K=2 (GSVD)** and **K≥2 comparative decomposition** are the intended multi-layer generalisations. Following the v2 negative result and provisional ADR 0015, no production K≥2 strategy is currently accepted; the target axis may be any component and is identified only after decomposition through the proposal/confirmation workflow.

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
Higher-order GSVD of K≥2 matrices under compatible feature-space formulations. It remains a Stage 1 candidate family, not an accepted production strategy after the v2 negative result. Genuine heterogeneous-feature inputs require the layer-specific loading and shared sample-space contract in ADR 0009.
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
A structured, serializable table at **omic layer × component × metadata field × association form** grain. It is computed before component selection and answers which recorded variables each layer-specific component coordinate is *associated with*; it does not infer causation or declare a variable to be a confounder. Layer identity is never averaged or pooled away. Identifier fields (for example `mouse_id`) are excluded. Target/nuisance declarations and expected associations are marked as predeclared or discovered so the discovery/confirmation boundary remains explicit; other eligible metadata need no special role to remain visible.

The atlas always preserves **univariate associations** for transparent interpretation. Once nuisance fields are declared, it may additionally report **adjusted associations** (for example, condition after accounting for weeks). Adjusted results are labelled separately and never replace or hide their unadjusted counterparts. The component proposal must retain both rather than collapse them into an opaque composite score.

Only a discovery-cohort atlas may drive `propose_component()` and `confirm_component()`. After confirmation, the target axis and complete state-space definition are frozen. A projected-cohort atlas is validation-only: it evaluates the already selected coordinates and is structurally prohibited from reranking components or changing the `AnalysisSpecification`. For AML, the 132-observation source-paper training cohort is prepared as `primary_2018` and defines the state space; the 101-observation source-paper validation cohort 1 is prepared as `supp_2016` and supplies a hostile projection stress test. Authoritative `sample_weeks` and sequencing run are confounded in the 2016 experiment, so it is not a clean independent replication cohort.

Association assessment must honour the `SamplingDesign` declared on `StateTransitionData` (ADR 0006). **Sampling dependence**—independent biological units versus repeated observations within subjects—is separate from target progression semantics. Independent observations may have no progression variable, observed collection/development time, an ordered cross-sectional state, or a continuous severity measure. Repeated data use the declared subject identity and must account for within-subject dependence. Subject identifiers are design variables, not association targets. If repeated data lack a compatible subject-aware association method, assessment fails explicitly rather than silently treating observations as independent. The atlas records the model and sampling design used.

Observed collection time is not pseudotime. Pseudotime is a derived ordering inferred from molecular observations; it requires explicit provenance and cannot silently be treated as measured time or independent confirmation evidence. A binary disease/control cross-section without any progression variable remains a valid contrast analysis, although it cannot support an ordered-progression claim.

**component-selection proposal**:
A reproducible K=1 ranking of Stage 1 components after an analyst supplies the sole target/nuisance declaration in a draft `AnalysisSpecification`. Other eligible metadata remain visible in the atlas without another role class; identifiers and non-analytical fields are excluded. The proposal recommends, but does not silently choose, a target biological axis. It must not use the downstream Stage 2 quasi-potential as a selection criterion.

For K≥2, the atlas remains valid and fully descriptive at explicit omic-layer grain, but automatic proposal generation currently returns a structured `no_aggregation_strategy` abstention. There is no accepted rule for pooling layer-specific coordinates or effects, and no K≥2 production decomposition strategy is accepted. A future validated layer-response/concordance strategy may authorize K≥2 ranking without changing the atlas grain.

The ranking criterion is declared per-analysis and supports multiple association forms:
- **continuous association**: Spearman correlation of component scores against a numeric metadata column (e.g. weeks post-infection, developmental day), oriented by the target's declared increasing/decreasing direction when it is the target. Use to identify or deprioritise time/age-driven components.
- **binary group separation**: signed rank-biserial correlation of component scores for the declared comparison versus reference level (e.g. condition CM vs CTL, sex). Use to identify disease or contrast axes.
- **independent time-course divergence**: for independent observations collected across declared times, standardize each fitted component within the recorded complete-case analysis cohort and fit a score-scale target × observed-time interaction with no subject random effect. Time is mapped from the retained original range to `[0, 1]`, so the interaction is the difference in fitted linear change across that range in component-standard-deviation units. Pooled target separation remains descriptive and cannot substitute for the interaction. Chen PS/OS cultures and Pogona developmental samples are concrete callers; nonlinear trajectories remain unsupported until separately justified.
- **longitudinal trajectory divergence**: the supported repeated-subject strategy fits the same standardized score-scale target × observed-time fixed effects with subject-specific random intercepts and time slopes. Declared design time enters automatically and is not repeated in `nuisance_fields`; nuisance fields are additional fixed covariates. For AML, report both subject-balanced average CM-versus-CTL separation and divergent trajectories; the interaction is the stronger disease-progression criterion. It is explicitly a linear slope contrast, not a rank interaction or general trajectory claim. The initial strategy supports one subject level and linear time only. Random-slope singularity, non-convergence, nonlinear/crossover structure, additional nesting, or informative-dropout requirements cause abstention rather than a random-intercept or row-independent fallback.
- **cross-sectional ordered-state assessment**: retain an omnibus rank-based group effect as descriptive evidence and separately report Spearman trend against the predeclared ordering. For diabetes, the discovery ordering is non-diabetic → autoantibody-positive → type 1 diabetes. The directional trend is the hypothesis-conditioned target effect; the omnibus result never substitutes for it. This is evidence of ordered cross-sectional states, not direct observation of within-person temporal progression.
- **unordered categorical association**: retain an omnibus rank-based effect in the atlas. It is descriptive metadata evidence and cannot silently become a target score because `AnalysisSpecification` target types are binary, ordered, or continuous.

Multiple forms may be declared together; a component may rank high on one and low on another (as in AML: PC1 ranks high on weeks, while the disease axis is expected to capture condition separation and trajectory divergence). Associations with other eligible biological measures such as cKit expression or blast counts remain visible in the same atlas but do not silently enter the selection score.

Every estimable atlas row retains its effect size, uncertainty interval, raw p-value, and Holm-adjusted p-value. A multiplicity family is all component tests for one fixed omic layer, metadata field, association form, and adjustment set. Proposal ranking uses the predeclared direction-aware target effect and, at evidence tier, its stability; neither raw nor adjusted p-values determine component order or become acceptance thresholds.

**Abstention rather than fallback is the general rule.** With no nuisance fields, a proposal may rank on the unadjusted directional target effect. Once nuisance adjustment is declared, an estimable adjusted target effect is mandatory for ranking; unadjusted evidence remains visible but cannot substitute. Non-identifiability, rank deficiency, insufficient biological units, unsupported sampling design, missing aggregation strategy, or failed stability requirements produce a structured abstention with a machine-readable reason and retained descriptive evidence.

For cross-sectional proposals, the canonical adjusted effect is **residualized rank correlation**. Component coordinates and the direction-encoded target are converted to midranks; continuous/ordered nuisance fields use midranks and unordered nuisance fields use explicit indicators. The component and target midranks are each projected onto the complete declared nuisance basis, then their residual correlation is reported with design-preserving bootstrap uncertainty. This is a linear-projection-adjusted association on the marginal-rank scale: it is not partial Spearman, conditional independence, or a causal effect, and it removes only nuisance structure represented by that basis. Collinearity, zero residual variance, insufficient residual degrees of freedom, or incomplete required fields cause abstention.

Minimum-data handling separates **structural identifiability** from the **supported range**. Structural checks are properties of the realized design—required levels and variation, full-rank model matrix, positive residual degrees of freedom, identifiable random effects, non-singular convergence—and contain no guessed universal sample-size cutoff. Numeric limits for biological-unit count, balance, time density, and missingness are derived and frozen only from synthetic sweeps over recovery and false-selection behavior. Successful model fitting never implies scientific support.

Uncertainty uses **design-preserving resampling**. Independent observations are resampled as whole biological units, preserving discrete target counts when estimating that target. Independent time courses resample within target × observed-time design cells. Repeated designs resample whole subject trajectories within subject-invariant target levels and assign duplicate draws new subject IDs; rows from repeated subjects are never sampled independently. Under ADR 0018, `standard` tier holds the fitted decomposition fixed, while `evidence` tier reruns decomposition, alignment, and proposal assessment. Resample counts are protocol-defined and benchmarked rather than hard-coded as evidence defaults.

The proposal is a **formal scored object** (not just a plot): it carries a ranked list of components with their association scores. Point ranking is fixed by the predeclared primary target effect and is identical across compute tiers. Evidence-tier stability validates the top-ranked proposal or causes abstention; it never reranks or promotes a weaker but more stable component. Arbitrary component sign does not affect rank; the proposal records the orientation multiplier required to follow the target's declared direction. `plot_components()` remains the descriptive coordinate gallery; proposal-specific plots render the scored proposal without making the descriptive plot a second scoring engine.

**Two downstream paths from the proposal object:**
- *Synthetic controls*: ground truth is known (planted component index is recorded in `SubspaceGroundTruth`). CI asserts `proposal$rank[1] == ground_truth_component` automatically — no human needed.
- *Real data*: ground truth is unknown. Human reviews the gallery, then calls `confirm_component(proposal, index = k)` to retain the target declaration and add `selected_component = k` to the confirmed `AnalysisSpecification`. Human is mandatory; this step cannot be automated away.

**Intended API sequence:**
```r
# Step 1: run Stage 1
std2 <- decompose(dec(), std)@value

# Step 2: declare the sole target intent for this run
spec <- analysis_specification(
    id = "aml-condition",
    target_field = "condition",
    target_type = "binary",
    reference_level = "CTL",
    comparison_level = "CM"
)
# sample_weeks is already structural longitudinal time; it is not redeclared
# as a nuisance field

# Step 3: surface unadjusted evidence plus separately labelled adjustments
atlas <- associate_metadata(std2, specification = spec)
plot(atlas)

# Step 4: proposal consumes the atlas; it does not redeclare or recompute intent
proposal <- propose_component(atlas)
plot(proposal)

# Step 5: confirm and proceed (human decision for real data;
#          automated assertion in synthetic control tests)
aspec <- confirm_component(
    proposal,
    index = 2L,
    rationale = "Condition-associated axis is stable and distinct from time"
)
# retains target declaration; adds selected_component = 2L
# records accepted/overridden recommendation, proposal digest, and rationale
# id auto-generated: "{dataset}_{target_field}_PC{k}"
# e.g. "aml_2018_condition_PC2", "synthetic_condition_PC1"
# Stable: same dataset + target field + component choice -> same id
run_pipeline(std2, cfg_with(aspec))
```

**bootstrap component alignment**:
The evidence-tier K=1 operation that matches each resampled decomposition to the frozen discovery reference before assessing stability. Raw component indices are not scientific identities: signs may flip, PC order may swap when singular values are close, and near-degenerate components may rotate within a stable subspace. Components are globally assigned by maximum absolute loading cosine (using a standard linear-sum assignment implementation), then arbitrary sign is corrected by requiring a positive loading dot product with the matched reference. Greedy or same-index matching is prohibited. Individual axes are not Procrustes-rotated toward the reference because that would erase informative rotational instability; enclosing-subspace stability is measured separately with principal angles. Alignment never uses downstream Stage 2 topology.

**target-axis stability**:
The frequency with which an equivalent biological axis recurs after bootstrap component alignment. It is reported separately from component-index stability, orientation stability, subspace stability, and proposal rank stability. A target axis may be biologically stable even when its ordinal PC index changes across resamples.

**stable-subspace/no-stable-axis result**:
A valid component-proposal abstention: the target association and enclosing subspace recur across resamples, but no single one-dimensional direction is identifiable because components rotate or exchange signal. The proposal must not choose the best-looking PC. The result is ineligible for the current 1D Stage 2 estimator and remains descriptive evidence for a future separately validated 2D strategy.

**target direction**:
The neutral, predeclared orientation carried by the target itself. A binary target declares `reference_level` and `comparison_level` (for example CTL → CM); an ordered target declares `ordered_levels` (for example non-diabetic → autoantibody-positive → T1D); and a continuous target declares increasing or decreasing direction. Avoid `positive_level`: it is overloaded with coefficient sign, disease positivity, and value judgement. The convention fixes an otherwise arbitrary component sign before Stage 2 and does not assert that coordinates, effects, or biology are intrinsically positive.

**axis orientation anchor**:
An optional predeclared biological metadata rule used only when the target declaration does not provide a scientifically meaningful direction. Technical alignment to the discovery-cohort reference is automatic; directional biological claims require either target direction or this anchor and must not use downstream Stage 2 topology to set it.

**metadata declarations**:
A declaration that separates one target biological variable and any named nuisance variables. **Role exclusivity** applies within each declaration: target, nuisance, and orientation-anchor fields are mutually exclusive; sampling subject and time fields are distinct. Intrinsic `SamplingDesign` structure and run-specific `AnalysisSpecification` intent remain separate concerns, so design time may be the explicit target of a separate time-focused run but cannot simultaneously be a nuisance. All other eligible `colData` fields, including biological measures and QC metrics, remain visible automatically without receiving another role class; identifiers and declared non-analytical fields are ignored. A strong association with undeclared metadata or a nuisance field creates a visible alert and calls for sensitivity analysis, never silent selection, orientation, residualisation, or correction. Missing values in required target/nuisance/orientation fields exclude that biological observation from the analysis cohort and are recorded; other association screens report available-case counts without imputing metadata.

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
Mapping new samples into an existing Stage 1 score space without refitting: `(X_new − center_training) · V_training = U_newΣ_training` for ordinary SVD coordinates. Projection matches canonical feature identities and applies the frozen discovery preprocessing reference; it does not independently recenter the secondary cohort or divide scores by singular values. Strategy-specific multi-layer projection must preserve the same declared coordinate convention.
_Avoid_: embedding, transfer, out-of-sample prediction

**discovery/confirmation boundary**:
The separation between a primary cohort used to select a target biological axis and an eligible secondary cohort projected into the frozen state-space to assess replication. The AML `supp_2016` cohort is batch/time-confounded and therefore supplies hostile robustness/stress-test evidence, not clean independent confirmation; it cannot by itself make an AML claim confirmatory. Claims without an eligible independent confirmation cohort remain exploratory.

**rank-deficient layer**:
An omic layer whose matrix has fewer linearly independent rows or columns than expected (rank < min(rows, cols)). Requires a rank-deficiency-aware HO-GSVD implementation (Kempf variant). The diabetes genotype layer is expected to be rank-deficient.
_Avoid_: singular matrix (rank-deficiency may be partial, not total singularity)

### Algorithm candidates (open — see ADR 0001)

**multiblock HOGSVD**:
The `multiblock::hogsvd` R implementation of HO-GSVD. Does not handle rank-deficient layers.

**Kempf HO-GSVD**:
A rank-deficiency-aware HO-GSVD implementation (Kempf et al.). Required when any layer is rank-deficient. Both this and multiblock HOGSVD should be registered as strategies; Stage 0 recovery benchmarks decide which is preferred.
