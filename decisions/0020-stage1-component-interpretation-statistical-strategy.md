# 0020 — Stage 1 component-interpretation statistical strategy

**Stage:** 1 / cross-cutting
**Status:** provisional-accepted; external human review remains open
**Date:** 2026-07-15
**Amended:** 2026-07-22

## Context

Stage 1 decomposition is intentionally outcome-blind. A separate interpretation
workflow must show how each fitted component relates to recorded metadata,
propose one target biological axis, quantify uncertainty without
pseudoreplication, and retain a human confirmation decision for real data.

The immediate callers span three concrete sampling structures:

- independent observations without structural time (ordinary cross-sectional
  controls and diabetes donors);
- independent observations collected across time (Chen endothelial PS/OS
  cultures and *Pogona* embryos);
- repeated observations within subjects across time (AML mice).

The workflow must preserve observation before interpretation, use
`AnalysisSpecification` v2 as the sole owner of target intent, respect
`SamplingDesign`, and abstain rather than silently weaken a declared analysis.
It must not invent a K≥2 cross-layer pooling rule while no K≥2 production
strategy is accepted.

## Options considered

| Option | Source / reference | Key property | Disqualifier or concern |
|---|---|---|---|
| One generic Pearson/linear-model screen | Conventional metadata correlation | Small implementation | Erases target-type semantics, is outlier-sensitive, and encourages p-value ranking |
| Target-specific unadjusted rank effects plus separately labelled adjusted models | Spearman; Wilcoxon/rank-biserial; residualized marginal-rank correlation | Transparent estimands and robust descriptive layer | Adjustment removes only effects represented by the declared nuisance basis on the marginal-rank scale |
| Treat every time series as repeated-subject longitudinal data | Common loose use of “longitudinal” | One time-aware implementation | Pseudostructure for destructive independent time courses such as GSE103672 |
| Global-rank time-course regression or rank mixed model | Ordinary rank transform followed by a conventional interaction model | Appears robust and preserves one model shape | Global ranking does not generally preserve the no-interaction hypothesis |
| Standardized score-scale linear model plus repeated-subject linear mixed model | Linear trajectory contrast on the fitted component-score scale | Preserves exact irregular observed-time spacing and defines one comparable slope estimand | Model-based linear-time capability must be explicit; unsupported designs must abstain |
| Random-intercept-only repeated model | Simpler mixed model | Easier convergence | Assumes common subject slopes and can overstate condition × time certainty |
| Random intercept and time slope | Pinheiro and Bates mixed-model framework | Represents between-subject baseline and slope variation | Can be singular in thin designs; requires honest abstention and synthetic range validation |
| Rank components by p-value | Conventional screening | Easy ordering | Confounds effect and precision; multiplicity becomes hidden selection |
| Rank by predeclared effect, then promote a stable runner-up | Stability-aware heuristic | Produces more recommendations | Violates abstention-over-fallback and changes the target criterion |
| Globally align bootstrap axes by loading cosine and report subspace rotation separately | Bootstrap PCA literature | Preserves sign/permutation while retaining rotational instability | Requires assignment dependency and separate stability metrics |
| Procrustes-rotate bootstrap axes to the reference | Common PCA presentation technique | Visually stable axes | Corrects away the instability the evidence tier must detect |

## Criteria

The strategy is acceptable only if:

- one object owns target direction, nuisance fields, and claim intent;
- every atlas value retains omic-layer identity and observation counts;
- unadjusted evidence remains visible beside adjustment;
- repeated observations are never treated as independent;
- independent time courses are not misclassified as repeated subjects;
- p-values and multiplicity do not determine component rank;
- a declared adjustment or model cannot fall back to a weaker analysis;
- structural identifiability is distinct from an empirically supported range;
- uncertainty resamples biological units while preserving collection design;
- evidence-tier component alignment does not erase axis/subspace instability;
- K≥2 input cannot trigger an unvalidated layer-pooling rule;
- real-data confirmation remains human and retains complete target intent;
- objects are serializable, digestible, provenance-complete, and directly
  renderable without plotting code recomputing science.

## Evidence

No current Stage 0 artifact validates the complete strategy. This decision
therefore authorizes a **provisional implementation** whose scientific support
must be established by the later synthetic ladder.

The following evidence constrains the implementation:

- Lai et al. (2021), doi:10.3389/fcell.2021.635307, analysed GSE103672 with ten
  PS/OS timepoints and two biological replicates per condition/timepoint. Its
  destructive culture time course is a concrete independent-time caller; PC1
  tracked time and PC3 showed divergent PS/OS trajectories for protein-coding
  genes.
- The corrected AML `primary_2018` cohort contains repeated observations from
  14 mice and is a concrete repeated-subject caller, but has no latent-axis
  ground truth.
- Fisher et al. (2016), doi:10.1080/01621459.2015.1062383, show that bootstrap
  PCA has arbitrary reflections and informative rotational variability. Dot
  products resolve sign, while subspace variability should be measured rather
  than hidden by rotating axes toward the reference.
- Holm (1979), doi:10.2307/4615733, provides strong family-wise error control
  without requiring independent component tests; R's `stats::p.adjust()`
  documents Holm as valid under arbitrary assumptions.
- Linear mixed-model references support subject-specific random effects, but
  thin-subject reliability is design-dependent. No literature rule-of-thumb is
  promoted into a package support limit; synthetic sweeps must establish the
  supported range.
- ADR 0018 already separates inspect, fixed-decomposition standard uncertainty,
  and full-pipeline evidence-tier stability.
- Liu et al. (2018), doi:10.1111/biom.12812, distinguish a population partial
  Spearman parameter based on conditional-distribution probability-scale
  residuals from simpler residualization of marginal ranks. The latter remains
  usable here only as its own explicitly defined projection estimand.
- Thompson (1991), doi:10.1093/biomet/78.3.697, and Akritas (1991),
  doi:10.1080/01621459.1991.10475066, show that ordinary rank-transform
  interaction procedures are not generally valid in factorial and repeated-
  measures designs. ART and longitudinal rank procedures answer categorical-
  time factorial/distributional questions rather than this ADR's continuous
  observed-time linear slope question.
- The primary-source assessment and alternatives are recorded in
  `docs/research/adr-0020-rank-association-and-time-interaction-methods.md`.

Capability evidence follows the three-rung ladder: generic synthetic controls,
domain-grounded synthetic controls, then biological exemplars. Biological
plausibility cannot replace known synthetic truth.

External review uses the versioned six-decision instrument
`docs/reviews/adr-0020-expert-questionnaire.json`, rendered for humans beside it
and hosted at <https://tally.so/r/NpQ2g0>. The hosted-form manifest records the
questionnaire/block digest. Responses remain private to the project team and
outside public Git history; they are not published, quoted, or attributed without
separate permission. Two invitations have been sent and the human review remains
open; no response has yet been received, and non-response is not evidence of
agreement. An ephemeral AI-assisted adversarial sanity check was used to surface
questions, not as expert review or validation; raw generated responses and model
lineage are not project evidence. Its two substantive questions were resolved
against primary methodological sources above. Later human feedback can reopen
this provisional decision before or during implementation.

## Decision

**Chosen:** implement a structured `MetadataAssociationAtlas` →
`ComponentProposal` → confirmed `AnalysisSpecification` workflow using three
registered, capability-bounded association strategies.

### Target intent and role exclusivity

A draft `AnalysisSpecification` is the sole target-intent object. It supplies
target type/direction, nuisance fields, orientation anchor, claim intent, and
run identity to `associate_metadata()`. `propose_component()` consumes the atlas
and accepts no second target object or string-based target/confounder arguments.

Target, nuisance, and orientation-anchor roles are mutually exclusive. Subject
and time sampling fields are distinct. Intrinsic sampling structure and
run-specific intent remain separate concerns: observed design time may be the
explicit target of a time-focused run, but cannot simultaneously be nuisance.
Subject identity is never an association target.

### SamplingDesign prerequisite

SamplingDesign v2 (ADR 0006) separates `dependence = independent | repeated`
from optional observed time. The narrow supported forms are:

1. independent, no structural time;
2. independent with structural observed time;
3. repeated within one subject level with structural observed time.

Pseudotime is a derived analysis artifact, not observed time. Nonlinear,
crossover, nested, informative-dropout, and repeated-without-time designs remain
unsupported and abstain until a concrete caller justifies another strategy.

ADR 0009 remains the input boundary: assay-specific normalization, quality
control, and technical-replicate resolution occur upstream. Each Stage 1 column
maps to one canonical biological observation. A declared batch field may remain
visible as nuisance metadata, but technical replicates do not create another
SamplingDesign dependence level inside landscapeR.

### Atlas grain and eligibility

The atlas grain is:

`omic_layer × component × metadata_field × association_form × adjustment_set`.

Layer identity is never pooled. Every estimable row records effect, interval,
raw p-value, Holm-adjusted p-value, available observations, biological units,
model/strategy, sampling design, adjustment fields, compute tier, specification
digest, state-space/input digest, declaration timing, and provenance.

The atlas includes all supported non-degenerate atomic metadata. Sampling
subject identifiers, per-observation identifiers, unsupported types, constants,
and underidentified categorical fields are excluded with machine-readable
reasons. Other fields use available cases without imputation. Required
 target/nuisance fields define a recorded complete-case analysis cohort; missing
required values never trigger imputation or a different model.

### Canonical unadjusted effects

- Binary: signed rank-biserial correlation, comparison versus reference.
- Continuous: Spearman correlation, oriented by declared direction when target.
- Ordered: descriptive omnibus rank effect plus separately reported Spearman
  trend against the declared level order; the trend is the target effect.
- Unordered categorical metadata: descriptive omnibus rank effect only.

### Cross-sectional adjustment

The canonical adjusted no-time effect is
`residualized_rank_correlation`. Component coordinates and the direction-
encoded binary, continuous, or ordered target are converted to empirical
midranks. Continuous/ordered nuisance fields use midranks and unordered
nuisance fields use explicit indicator columns. Let `Z` denote that complete
declared nuisance basis. The estimand is the correlation between the residuals
from the separate least-squares projections of the component and target
midranks onto `Z`.

This is a linear-projection-adjusted correlation on the **marginal-rank
scale**. It is not named partial Spearman, does not claim conditional
independence, removes only nuisance structure represented by `Z`, and is not
causal. The atlas stores the exact nuisance basis and coding. Design-preserving
bootstrap intervals quantify its sampling uncertainty; a nominal parametric
partial-correlation test is not used. Collinearity, zero residual variance,
incomplete required fields, or non-positive residual degrees of freedom causes
abstention rather than unadjusted fallback. Nonlinear residual dependence and
non-monotone target structure remain visible diagnostic limitations, never an
automatic alternative ranking rule.

### Independent time-course strategy

`independent_time_course_linear` fits a fixed model on the original fitted
component-score scale after standardizing each candidate component within the
recorded complete-case analysis cohort. Observed time is transformed once as
`(time - min(time)) / (max(time) - min(time))`; the atlas retains the original
range and transform. The model contains binary target, scaled observed time,
target × time, and additional declared nuisance fields. The interaction is the
primary effect: the difference in fitted linear change across the observed time
range, expressed in analysis-cohort component standard deviations. Pooled
binary separation remains descriptive. No subject random effect is introduced.

This is an explicitly model-based linear trajectory estimand, not a rank-based
interaction test or a claim of general trajectory divergence. Full-rank design,
overlapping target/time support, residual diagnostics, and design-cell
resampling are required. Nonlinear structure, influential-cell failure, or
unsupported dependence causes abstention.

### Repeated-subject strategy

`longitudinal_linear_mixed` uses the same standardized component-score and
fixed-effect time transform with subject-specific random intercepts and time
slopes. The target × time coefficient is the primary longitudinal effect;
subject-balanced average target separation remains separately visible. The
implementation uses `nlme` rather than a package-owned mixed-model solver and
records fixed/random design rank, convergence, estimated random-effects
covariance, boundary/singularity diagnostics, and failed-resample frequency.

Random-slope singularity, non-convergence, non-identifiability, or unsupported
dependence causes abstention. A random-intercept-only or row-independent model
is never substituted.

### Uncertainty and multiplicity

Design-preserving resampling follows ADR 0018:

- independent no-time observations are resampled as whole biological units,
  preserving discrete target-level counts for target uncertainty;
- independent time courses resample within target × observed-time design cells;
- repeated data resample whole subject trajectories within subject-invariant
  target levels and assign duplicate draws new subject IDs.

`inspect` reports deterministic point/descriptive output; `standard` resamples
association models while holding decomposition fixed; `evidence` reruns the
applicable fitted pipeline. Resample counts and stopping rules are protocol
parameters established by accuracy/runtime benchmarks.

Every multiplicity family comprises component tests for one fixed layer, field,
association form, and adjustment set. Holm-adjusted values remain supporting
evidence. Neither raw nor adjusted p-values determine rank or eligibility.

### Proposal ranking and abstention

Automatic proposals are K=1 only. K≥2 atlases are valid descriptive objects,
but proposal generation returns `no_aggregation_strategy` until a validated
layer-response/concordance strategy exists.

Point ranking uses the magnitude of the predeclared primary target effect:
unadjusted when no nuisance is declared and adjusted when nuisance is declared.
For independent/repeated time courses with binary targets, target × time is the
primary effect. Other forms and descriptive geometry, including BC when
requested, remain visible but do not enter an opaque composite.

Component sign never changes rank. The proposal records the orientation
multiplier needed to follow target direction. Point ranking is identical across
compute tiers. Stability validates the top-ranked proposal or causes abstention;
it never reranks or promotes a weaker component. The proposal also records the
top-versus-runner-up effect gap and a deterministic component-index tie break.
These expose numerical or practical ambiguity but do not create a top tier,
composite score, or runner-up promotion rule.

All non-estimable or unsupported outcomes return a structured abstention with
machine-readable reason and retained atlas. Numeric support limits are not
hard-coded from rules of thumb: structural identifiability is checked directly,
while the supported range is derived and frozen from synthetic sweeps.

### Evidence-tier alignment and stability

For K=1 bootstrap decompositions, components are globally assigned to the frozen
reference by maximum absolute loading cosine using `clue::solve_LSAP`, then
arbitrary sign is corrected by the matched loading dot product. Greedy and
same-index matching are prohibited. Individual axes are not
Procrustes-rotated.

Target-axis recurrence, ordinal-index recurrence, orientation recurrence,
proposal-rank recurrence, and enclosing-subspace principal angles are reported
separately. The full absolute-cosine assignment matrix and matched cosine are
retained; weak matches may be marked unmatched only under a threshold derived
and frozen from synthetic sweeps. `stable_subspace/no_stable_axis` thresholds
are likewise derived and frozen rather than guessed. A stable enclosing
subspace never licenses selection of an unstable individual axis.

### Provisional validation requirements

The later synthetic ladder must predeclare calibration regimes, metrics, seeds,
and independent acceptance seeds. It must include at least: a complete target
null and the null distribution of the maximum component effect; target signal
weaker than nuisance; correlated target/nuisance structure through adjustment
failure; weak and near-degenerate axes; axis truth distributed across a stable
subspace; heavy-tailed and heteroskedastic noise; unequal groups and thin or
irregular time designs; and deliberate linear-model misspecification. Assay-
specific technical-replicate processing remains upstream, but domain-grounded
controls may reproduce residual batch patterns among canonical observations.

Acceptance reports correct-axis recovery, correct-subspace recovery, nuisance-
axis false selection, null false selection, correct structured abstention,
angular error, proposal-rank recurrence, interval coverage, and failure rates.
The protocol, generator families, metrics, and thresholds are frozen before the
independent acceptance run.

### Confirmation

`confirm_component()` consumes a proposal, selected index, and non-empty human
rationale. It returns a confirmed v2 `AnalysisSpecification` retaining the
original run ID and complete target declaration, adding proposal digest,
selected component, `accepted` versus `overridden` decision, and rationale.
The stale auto-generated-ID requirement is superseded because identity already
exists throughout the v2 lifecycle.

Real-data confirmation is always a human decision. Synthetic tests may assert a
recommendation against planted truth, but do not create a second confirmation
contract.

## Implementation landing proof

- **Proof classification:** required
- **Before/after or representative output:** synthetic representative workflow
  showing atlas exclusions, unadjusted/adjusted rows, independent-time and
  repeated-subject effects, proposal rank, structured abstention, stability
  dimensions, and confirmation provenance
- **Current documentation affected:** component-interpretation workflow vignette,
  Stage 1 context, SamplingDesign and AnalysisSpecification references
- **Claim status:** provisional implementation proof; synthetic scientific
  validation remains #67/#51 and biological exemplars remain later roadmap work

## Consequences

- `SamplingDesign` v2 and migration must land before association strategies.
- New deep objects are limited to `MetadataAssociationAtlas`,
  `ComponentProposal`, and one `AssociationStrategy` contract; ordinary
  algorithms remain plain code inside strategies.
- `nlme` is required for the repeated strategy; `clue` is required for global
  component assignment. ADR 0018 governs any `future.apply` repetition.
- Atlas/proposal plots render stored results and never recompute models.
- The provisional implementation can merge after comprehensive synthetic
  contract tests, but this does not establish a supported sample range.
- Evidence-tier reruns include landscapeR's fitted centering/scaling,
  decomposition, alignment, association, and proposal. Assay-specific
  normalization, filtering, feature construction, imputation, and technical-
  replicate resolution remain frozen upstream inputs with provenance; they are
  not silently reinvented inside a bootstrap.
- #67 supplies AML-shaped synthetic validation; #71 supplies the AML biological
  exemplar. Chen and *Pogona* are independent-time exemplars only after their
  own source/preprocessing and scientific gates are satisfied.
- Unsupported designs remain visible as typed abstentions instead of expanding
  this ADR into hypothetical model families.

## Review trigger

Revisit when synthetic sweeps establish or reject a supported range; when a
concrete nonlinear, crossover, nested, informative-dropout, or repeated-without-
time caller exists; when a K≥2 production decomposition requires validated
cross-layer proposal aggregation; or when biological exemplars contradict the
assumptions without being used to retune frozen criteria; or when pending human
review supplies a substantive objection or alternative.
