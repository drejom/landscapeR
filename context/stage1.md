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

**technical batch field**:
A recorded plate, run, extraction day, operator, laboratory, or other technical
factor shared by canonical biological samples. Technical batch fields remain
separate metadata columns and may be declared together as additive nuisance
fields. They are not technical replicates, biological sampling units, or a
fourth `SamplingDesign`. A composite `technical_batch_id` is appropriate only
when the concatenated labels identify a genuine nested or joint processing
unit, such as plate identifiers that restart within sequencing run. Its
construction is recorded, and the atlas retains the constituent fields so the
source of association remains visible. Blind concatenation of crossed
technical factors is avoided because it creates sparse levels, hides factor
effects, and can destroy identifiability. Perfect target–batch or time–batch
confounding yields adjusted-association abstention.

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
A structured, serializable table of associations between every Stage 1 component and every eligible `colData` field. It is computed before component selection and answers which recorded variables each component is *associated with*; it does not infer causation or declare a variable to be a confounder. Identifier fields (for example `mouse_id`) are excluded. Target/nuisance declarations and expected associations are marked as predeclared or discovered so the discovery/confirmation boundary remains explicit; other eligible metadata need no special role to remain visible.

The atlas always preserves **univariate associations** for transparent interpretation. Once nuisance fields are declared, it may additionally report **adjusted associations** (for example, condition after accounting for weeks). Adjusted results are labelled separately and never replace or hide their unadjusted counterparts. The component proposal must retain both rather than collapse them into an opaque composite score.

**adjusted rank-score association**:
An operational association estimand obtained after expressing the component
score and declared continuous variables on their rank scales and accounting for
the declared nuisance design. For a contrast, the reported quantity is an
adjusted rank-score contrast; for a continuous target, it is an adjusted
rank-score association. The name states what was calculated and must not be
shortened to *partial rank correlation*, which would imply a more general
conditional estimand. Uncertainty comes from design-preserving resampling. If
the nuisance design is collinear, rank-deficient, or otherwise
non-identifiable, the adjusted result is a structured abstention; the
unadjusted association remains visible but is never substituted for it.

Only a discovery-cohort atlas may drive `propose_component()` and `confirm_component()`. After confirmation, the target axis and complete state-space definition are frozen. A projected-cohort atlas is validation-only: it evaluates the already selected coordinates and is structurally prohibited from reranking components or changing the `AnalysisSpecification`. For AML, the 132-observation source-paper training cohort is prepared as `primary_2018` and defines the state space; the 101-observation source-paper validation cohort 1 is prepared as `supp_2016` and supplies a hostile projection stress test. Authoritative `sample_weeks` and sequencing run are confounded in the 2016 experiment, so it is not a clean independent replication cohort.

Association assessment must honour the `SamplingDesign` declared on `StateTransitionData` (ADR 0006). Cross-sectional data use independent-observation methods. Longitudinal data use the declared subject-ID and ordered-time columns; adjusted estimates and uncertainty must account for within-subject repeated measures. Subject identifiers are design variables, not association targets. If longitudinal data lack a compatible subject-aware association method, assessment fails explicitly rather than silently treating observations as independent. The atlas records the model and sampling design used.

**component-selection proposal**:
A reproducible ranking of Stage 1 components after an analyst declares one target field and any nuisance fields. Other eligible metadata remain visible in the atlas without another role class; identifiers and non-analytical fields are excluded. The proposal recommends, but does not silently choose, a target biological axis. It must not use the downstream Stage 2 quasi-potential as a selection criterion. Target/nuisance declarations and whether expectations were predeclared or discovered become part of the `AnalysisSpecification` and provenance.

Component nomination uses only the predeclared, sign-invariant biological
effect. The complete ranking is repeated under design-preserving resampling so
effect uncertainty, rank distributions, and winner's bias remain visible.
Stability validates, reveals a stable subspace, or causes abstention; it is not
multiplied into the biological effect and cannot privately rerank components.
Rank-biserial and Spearman effects are scale-invariant, and longitudinal
effects use standardized component scores. Component effects are therefore not
weighted by singular value or variance explained, and no fixed
variance-explained cutoff removes candidate axes. Singular values remain
prominent identifiability diagnostics and visual evidence; they answer a
different question from biological association.
A calibrated near-tie margin may define an **effect-equivalent candidate set**
instead of forcing a numerically brittle winner. Identifiability differences
within that set remain visible, and any human confirmation records that the
effect evidence was equivalent. Outside a predeclared near-tie set, failure of
the unique top-ranked component yields no confirmed axis; a runner-up is not
promoted after observing that failure. Alternative targets or selection rules
require separately predeclared runs.

The ranking criterion is declared per-analysis and supports multiple association forms:
- **continuous association**: Spearman correlation using average midranks
  against a numeric metadata column (e.g. weeks post-infection, developmental
  day). The tied-value proportion remains visible. Use to identify or
  deprioritise time/age-driven components.
- **binary group separation**: signed rank-biserial association against a
  binary metadata column (e.g. condition CM vs CTL, sex), oriented from the
  declared reference to comparison level.
- **longitudinal trajectory divergence**: a condition-by-time interaction on
  deterministically oriented component scores standardized to SD units.
  Observed time is transformed to a fixed study-level 0–1 interval and the
  transformation is recorded. Independent destructive-sampling designs use an
  ordinary linear fixed-effects model; repeated-subject designs additionally
  require subject-specific random intercepts and time slopes. Both estimate the
  same mean standardized trajectory contrast. Uncertainty preserves the
  declared biological sampling units. A singular or non-convergent random-slope
  model yields a structured abstention with diagnostics, never silent
  simplification to a random-intercept-only or observation-independent model.
  GEE, robust, Bayesian mixed, and nonlinear trajectory models require
  separately declared strategies. For AML, report both average CM-versus-CTL
  separation and divergent trajectories; the interaction is the stronger
  disease-progression criterion.
- **cross-sectional ordered-state trend**: Kendall's tau-b against a
  predeclared ordering of independent biological states. An omnibus rank effect
  remains descriptive and cannot compete in proposal ranking. If states have
  scientifically meaningful unequal numerical spacing, those scores are
  declared explicitly and the target is continuous; spacing is never inferred
  from labels. For diabetes, the discovery ordering is non-diabetic →
  autoantibody-positive → type 1 diabetes. This is evidence of ordered
  cross-sectional states, not direct observation of within-person temporal
  progression.

Unordered multilevel fields remain visible descriptively but cannot drive v1
component selection. Heavy ties and concentrated category masses are reported
diagnostically, and uncertainty comes from design-preserving resampling rather
than asymptotic normal approximations.

Multiple forms may be declared together; a component may rank high on one and low on another (as in AML: PC1 ranks high on weeks, while the disease axis is expected to capture condition separation and trajectory divergence). Associations with other eligible biological measures such as cKit expression or blast counts remain visible in the same atlas but do not silently enter the selection score.

Monotone association strategies expose possible model mismatch rather than
silently searching for another effect. For each continuous or ordered target,
the visual decision surface shows raw component scores, the monotone fit, and a
flexible descriptive smoother while preserving biological sampling units and
observed times. Material disagreement is recorded as
`possible-nonmonotone-association`; it cannot promote or rerank a component. If
the predeclared monotone estimand is not scientifically adequate, the proposal
abstains under that target declaration. Distance correlation, HSIC, GAM, and
other nonlinear association methods require separately registered and
calibrated strategies.

Multiplicity remains explicit even though significance does not drive
selection. The descriptive atlas reports raw p-values and within-metadata-field
BH-adjusted q-values across eligible components. A proposal for one predeclared
target additionally uses design-preserving permutation to report the null
distribution of the maximum absolute target effect across all eligible
components. The complete ranking operation is repeated under resampling.
Search-aware results may weaken support or cause abstention but cannot promote
a different component. Separate biological targets require separate named
runs; one may be predeclared primary, while additional runs remain exploratory
unless governed by another multiplicity plan.

Permutation is available only where the declared design supports
exchangeability. Unadjusted cross-sectional targets permute labels within
declared exchangeability strata. Adjusted fixed-effects rank-score models use a
nuisance-only residual-permutation procedure within valid blocks, reconstruct
the null outcome, and repeat the complete component search. Repeated-subject
conditions assigned between subjects permute only at subject level; fixed
observed times are never permuted. When no defensible permutation exists, the
proposal reports `permutation-not-identifiable` rather than manufacturing a
global search-aware p-value. Wild-bootstrap, Bayesian, and other model-based
null procedures require separately registered and calibrated strategies.

Minimum-data assessment separates mathematical estimability from a calibrated
operating region. Declared levels must be represented, the complete-case design
must be full rank, biological sampling units must exceed fitted degrees of
freedom, and every contrast must contain independent biological replication.
Independent condition-by-time designs require both conditions at two or more
overlapping observed times with relevant cell replication. Random-slope models
require enough subjects with at least three usable time observations to
identify within-subject slopes. Resampling requires enough distinct
biological-unit rearrangements for its requested resolution. Missing target,
nuisance, subject, or time values are excluded visibly and are not imputed.
Failures distinguish `non-identifiable-design`,
`insufficient-resampling-support`, `outside-calibrated-operating-region`, and
`estimable-exploratory-only`. Universal sample-size cutoffs are not inferred
from rules of thumb; accepted operating limits are frozen from disclosed
simulation calibration. Future Bayesian association or hierarchical trajectory
strategies may expand those limits, but require explicit registration, declared
priors and diagnostics, and separate calibration rather than acting as silent
fallbacks.

The proposal is a **formal scored object** (not just a plot): it carries a ranked list of components with their association scores. `plot_components()` visualises this object; tests can assert against it directly.

Before acceptance thresholds are calibrated, the workflow distinguishes
computation from support. The descriptive tier produces atlas associations,
proposal rankings, and model/design diagnostics with exploratory status. The
evidence-computation tier may run resampling, permutation, matching, and
subspace diagnostics while thresholds remain unset, but reports
`estimable-exploratory-only`. Human confirmation may record an exploratory
choice, override, and rationale; it cannot label the choice stable, validated,
accepted, or scientifically supported. Known-truth calibration and independent
acceptance freeze the near-tie, matching, ambiguity, stability, failure-rate,
and search-aware error thresholds before calibrated stable-axis or abstention
claims become available. Real AML analyses do not supply calibration evidence.

**Two downstream paths from the proposal object:**
- *Synthetic controls*: ground truth is known (planted component index is recorded in `SubspaceGroundTruth`). CI asserts `proposal$rank[1] == ground_truth_component` automatically — no human needed.
- *Real data*: ground truth is unknown. Human reviews the gallery, then makes
  a separate, explicit `confirm_component()` call with the proposal, component
  index, decision (`accept` or `override`), and a non-empty rationale. Proposal
  generation cannot return a confirmed specification or hide confirmation
  behind a flag. The transition records the proposal digest, recommendation,
  selected component, decision, rationale, evidence status, and resulting
  specification digest. Mathematically ineligible abstentions return a typed
  failure even when confirmation arguments are supplied. Rejection is another
  explicit recorded decision. Synthetic known-truth assertions use a separate
  non-human path.

**Intended API sequence:**
```r
# Step 1: run Stage 1
std2 <- decompose(dec(), std)@value

# Step 2: surface all eligible metadata associations
atlas <- associate_metadata(std2)
plot(atlas)

# Step 3: analyst declares the target and nuisance fields and inspects proposal
proposal <- propose_component(
    atlas,
    target = "condition",
    nuisance_fields = "sample_weeks"
)
plot(proposal)

# Step 4: confirm and proceed (human decision for real data;
#          automated assertion in synthetic control tests)
aspec <- confirm_component(
    proposal,
    index = 2L,
    decision = "accept",
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
The evidence-tier operation that matches each resampled decomposition to the
frozen discovery reference before assessing stability. All data-dependent
preprocessing and decomposition are repeated inside each resample. Raw
component indices are not scientific identities: signs may flip, PC order may
swap when singular values are close, and near-degenerate components may rotate
within a stable subspace. The complete component set is matched jointly through
an optimal one-to-one assignment that maximizes total absolute similarity. For
ordinary SVD, similarity is feature-loading cosine; every other decomposition
strategy must declare the geometry appropriate to its own loading space. Sign
is corrected only after assignment using the matched loading inner product.
The complete similarity matrix, assignment margins, and competing matches are
retained. Weak or ambiguous matches remain unmatched under thresholds frozen
by calibration rather than being forcibly paired. Individual-axis matching and
enclosing-subspace principal angles are reported separately. Procrustes
rotation is prohibited because it would conceal rotational instability.
Alignment uses coordinates/loadings and the predeclared orientation anchor
rather than downstream Stage 2 topology.

**target-axis stability**:
The frequency with which an equivalent biological axis recurs after bootstrap component alignment. It is reported separately from component-index stability, orientation stability, subspace stability, and proposal rank stability. A target axis may be biologically stable even when its ordinal PC index changes across resamples.

**design-preserving resampling**:
Resampling defined by biological exchangeability and the level at which the
target was assigned. Cross-sectional observations are sampled as canonical
biological units within predeclared target strata. Independent destructive
time courses are sampled within condition-by-observed-time cells, retaining
the design grid and cell counts and making inference conditional on that
design. Repeated-subject studies sample complete subject trajectories within
between-subject condition strata; individual observations are never sampled
independently. Permutation occurs at observation level only for independent
assignment and at subject level for between-subject longitudinal assignment;
time cells are not freely permuted. Technical labels travel with their
biological samples but never replace biological resampling units. Empty,
collapsed, singular, unmatched, and failed resamples remain in the reported
failure fraction rather than being silently regenerated. Alternative
subsampling or jackknife strategies require separate calibration.

**stable-subspace/no-stable-axis result**:
A valid component-proposal abstention: the target association and enclosing subspace recur across resamples, but no single one-dimensional direction is identifiable because components rotate or exchange signal. The proposal must not choose the best-looking PC. The result is ineligible for the current 1D Stage 2 estimator and remains descriptive evidence for a future separately validated 2D strategy.

**visual decision surface**:
A canonical visual rendering of the public evidence carried by a typed
scientific decision object. It makes a consequential proposal, diagnostic, or
abstention visually interpretable without calculating a hidden score or
privately changing the recorded result. The same visual grammar recurs across
analyses, uses progressive disclosure for detail, and never relies on colour
alone. Visual interpretation supports human confirmation but cannot override
the machine-readable decision. An axis-identifiability surface jointly exposes
the spectrum, component-matching ambiguity, axis recurrence, subspace angles,
and the resulting stable-axis, stable-subspace/no-stable-axis, or
no-stable-target-structure status.

**target direction**:
The neutral, predeclared orientation carried by the target itself. A binary target declares `reference_level` and `comparison_level` (for example CTL → CM); an ordered target declares `ordered_levels` (for example non-diabetic → autoantibody-positive → T1D); and a continuous target declares increasing or decreasing direction. Avoid `positive_level`: it is overloaded with coefficient sign, disease positivity, and value judgement. The convention fixes an otherwise arbitrary component sign before Stage 2 and does not assert that coordinates, effects, or biology are intrinsically positive.

**axis orientation anchor**:
An optional predeclared biological metadata rule used only when the target declaration does not provide a scientifically meaningful direction. Technical alignment to the discovery-cohort reference is automatic; directional biological claims require either target direction or this anchor and must not use downstream Stage 2 topology to set it.

**metadata declarations**:
A declaration that separates one target biological variable and any named nuisance variables. All other eligible `colData` fields, including biological measures and QC metrics, remain visible automatically without receiving another role class; identifiers and declared non-analytical fields are ignored. A strong association with undeclared metadata or a nuisance field creates a visible alert and calls for sensitivity analysis, never silent selection, orientation, residualisation, or correction. Missing values in required target/nuisance/orientation fields exclude that biological observation from the analysis cohort and are recorded; other association screens report available-case counts without imputing metadata.

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
