# 0020 — Component interpretation statistical strategy

**Stage:** 1 / cross-cutting
**Status:** accepted
**Date:** 2026-07-24
**Amended:** 2026-07-31

## Context

Stage 1 produces outcome-blind candidate components. Issue #55 must turn those
components into a metadata-association atlas, a component proposal, and an
explicit human confirmation without allowing plots, p-values, projected
cohorts, or unstable numerical axes to make hidden scientific decisions.

ADR 0006 requires association and uncertainty methods to respect the declared
sampling design. ADR 0017 requires unadjusted observations to remain visible
beside adjusted and interpreted results. Neither ADR chooses the statistical
estimands, component-search correction, axis-identifiability gate, abstention
rules, or visualization contract needed by #55.

The initial scope supports canonical biological samples after upstream
normalization and technical-replicate resolution. It must cover independent
cross-sectional observations, independent destructive-sampling time courses,
and repeated-subject time courses. It must not overstate exploratory AML
analysis as calibration or accepted scientific evidence.

## Options considered

| Decision | Chosen option | Rejected or deferred alternatives |
|---|---|---|
| Nuisance adjustment | Explicit adjusted rank-score estimand | Calling rank residualization a universal partial rank correlation; silently substituting an unadjusted result |
| Longitudinal effect | Standardized condition-by-time effect with design-specific fixed or mixed model | Naïve interaction testing on rank-transformed outcomes; automatic random-effects simplification |
| Modeling substrate | `stats::lm` and `lme4::lmer` behind a landscapeR `AssociationStrategy` registry | A core tidymodels/parsnip/workflows wrapper stack; engine-specific ad hoc calls exposed as public API |
| Component nomination | Predeclared biological-effect magnitude | p-value ranking; singular-value weighting; opaque effect × stability score |
| Near ties | Calibrated effect-equivalent candidate set | Numerically forcing a unique winner |
| Axis validity | Separate identifiability and stability gate | Treating a large biological effect as sufficient; forcing an axis out of a stable rotating subspace |
| Bootstrap alignment | Joint optimal one-to-one matching in strategy-declared geometry | Greedy matching; forced weak matches; Procrustes rotation |
| Multiplicity | Descriptive Holm adjustment plus proposal-level maximum-effect null | Claiming outcome-blind decomposition removes the component search |
| Human decision | Separate auditable confirmation call | Implicit confirmation inside proposal generation; human override of mathematical abstention |
| Visualization | Typed evidence with canonical ggplot2 decision surfaces | Plot-owned calculations; mandatory interactive dependency |

Nonlinear dependence measures, GEE, Bayesian hierarchical models, nonlinear
trajectories, wild-bootstrap nulls, interactive Plotly renderers, and
alternative resampling schemes remain valid future strategies. They are not
automatic fallback paths and require separate registration, diagnostics, and
calibration.

## Criteria

- The same declared scientific question produces the same estimand, ranking,
  provenance, and orientation.
- Unadjusted and adjusted evidence remain separately inspectable.
- Biological sampling units and assignment-level exchangeability are
  preserved.
- Component search, near ties, sign ambiguity, index swapping, and subspace
  rotation remain visible.
- Invalid design, model, matching, permutation, and calibration states produce
  typed abstentions rather than substituted answers.
- Human judgment is explicit and auditable but cannot erase mathematical
  ineligibility.
- Plots render public typed evidence and use a consistent visual language
  without becoming a second decision engine.
- Exploratory computation is useful before calibration but cannot acquire
  accepted-evidence language.

## Evidence

No Stage 0 or #67 calibration result yet selects numerical thresholds. The
choices here therefore define estimands, supported designs, diagnostics,
abstention semantics, and calibration targets rather than acceptance cutoffs.

The motivating AML failure mode is known: a dominant component may represent
time or age while a lower-variance component represents disease. This rules out
defaulting to PC1 and argues against weighting biological association by
singular value. Standard SVD non-identifiability also means that nearly equal
singular values can identify a subspace without identifying any unique axis.

Consultation-style AI responses were used only as an ephemeral adversarial
sanity check, not as expert review or evidence. Their recurring concerns were
tested against the package contracts during maintainer grilling. Decisions
were accepted only through that explicit alignment process.

Primary-source package research compared native R engines, tidymodels,
mixed-model wrappers, resampling packages, diagnostic adapters, dependency
cost, and Bioconductor compatibility. The complete comparison is retained in
[`docs/archive/adr-0020-r-modeling-frameworks.md`](../docs/archive/adr-0020-r-modeling-frameworks.md).
It found that parsnip standardizes engine specification and prediction but does
not standardize the inferential estimand, sampling-design eligibility,
exchangeability, singularity semantics, or scientific abstention required here.

## Decision

**Chosen:** #55 will implement a sampling-design-aware, effect-first component
interpretation workflow with separate axis-identifiability validation,
design-preserving uncertainty, structured abstention, explicit human
confirmation, and canonical visual decision surfaces.

### 1. Association atlas and estimands

The atlas retains every eligible component × metadata association, its
available-case count, tied-value diagnostics, model, uncertainty, sampling
design, and provenance. Identifier and declared non-analytical fields are
excluded with reasons. Unadjusted associations always remain visible.

The v1 association family is:

- binary target: signed rank-biserial association, oriented from the declared
  reference level to comparison level, registered as
  `AssociationStrategy:cross_sectional_binary`;
- continuous target: Spearman association using average midranks, registered
  as `AssociationStrategy:cross_sectional_continuous`;
- ordered categorical target: Kendall's tau-b using declared level order,
  registered as `AssociationStrategy:cross_sectional_ordered`;
- unordered multilevel field: descriptive omnibus rank evidence only, ineligible
  to drive v1 component selection;
- ordered states with meaningful unequal numerical spacing: explicitly scored
  and declared as a continuous target, never inferred from labels.

Adjusted evidence uses the name **adjusted rank-score association** or
**adjusted rank-score contrast**. Component score and declared continuous
variables are expressed on rank scales before the declared nuisance design is
accounted for. The result is an operational estimand, not a universal
conditional or partial rank correlation. If the nuisance design is collinear,
rank-deficient, or otherwise non-identifiable, adjustment abstains while the
unadjusted result remains visible.

Inference uses design-preserving resampling rather than asymptotic normal
approximations. A raw-score plot, monotone fit, and flexible descriptive
smoother expose possible non-monotone model mismatch for continuous and ordered
targets. `possible-nonmonotone-association` is diagnostic only; it cannot
rerank a component. A scientifically inadequate monotone declaration causes
abstention until a separately validated nonlinear strategy is selected.

All bootstrap and permutation implementations use one package-owned resampling
policy contract. A policy plan records its lifecycle, method, biological unit,
requested count, deterministic seed, design strata or allocation structure,
materialized draws, optional replicate seeds, status, and content digest.
Execution accounting records completed and failed draws against that immutable
requested denominator, including normalized failure codes and a digest-bound
status of `complete`, `partial`, `not-identifiable`, or
`insufficient-support`. Failed eligible refits are never replaced by newly
generated draws merely to reach a success count.

The policy owns deterministic RNG isolation, identity, validation, accounting,
and serialization. Small design adapters continue to own the scientific
exchangeability rule: independent biological observations, independent
condition-by-time cells, or complete subject trajectories. Repeated draws of
one source subject receive fresh deterministic replicate-subject identifiers.
Condition-by-time cells with no observed complete biological units remain
visible with count zero but contribute no fabricated draw; estimability of the
declared interaction is assessed separately from the set of observed
exchangeability strata.
Invalid assignment structures produce typed unavailable policy records and
the existing public abstentions; they never fall back to another sampling
unit. New strategy authors therefore provide a design adapter and refit
function rather than implementing bespoke seeds, digests, denominators, or
failure semantics. This is an internal authoring contract and does not add
steps to the ordinary user-facing workflow.

### 2. Independent and repeated time courses

Components are deterministically oriented and their scores standardized to SD
units. Observed study time is scaled to a recorded study-level 0–1 interval.
The trajectory-divergence estimand is the standardized condition-by-time
coefficient.

- Independent destructive-sampling time courses use an ordinary linear
  fixed-effects
  model containing condition, scaled time, and their interaction.
- Repeated-subject time courses use the same fixed effects plus subject-specific
  random intercepts and time slopes.

The concrete v1 engines are:

- independent strategy: `stats::lm()` with explicit treatment contrasts and
  `na.action = na.fail` on
  `score_std ~ target * time_scaled + nuisance_terms`, registered as
  `AssociationStrategy:independent_time_course_linear`;
- repeated-subject strategy: `lme4::lmer()` on
  `score_std ~ target * time_scaled + nuisance_terms +
  (1 + time_scaled | subject)`, registered as
  `AssociationStrategy:repeated_time_course_lmer`.

The independent model is ordinary least squares, not an undefined robust
estimator. The repeated model uses the correlated random-intercept/random-slope
form; changing to an uncorrelated `||` form after a difficult fit is an
unregistered fallback. The analysis cohort is constructed and recorded before
fitting, and engines receive `na.action = na.fail`. Optimizer, controls,
contrasts, engine version, formula digest, and model-matrix rank are frozen and
recorded.

A singular or non-convergent random-slope model returns a structured
abstention with diagnostics. It is never silently simplified to
random-intercept-only or observation-independent inference. GEE, Bayesian
mixed models, and nonlinear trajectories require separately declared
strategies.

Both engines sit behind a package-owned virtual `AssociationStrategy` contract
and the existing strategy registry. The contract owns supported sampling
designs and targets, cohort construction, estimand mapping, diagnostics,
abstention, refitting, and normalized output. Native fit objects remain private
diagnostic payloads rather than authoritative serialized scientific results.
The executable contract declares `sampling_designs`, `target_types`,
`estimand`, `cohort_policy`, `diagnostic_prefix`, `abstention_statuses`,
`refit_policy`, and `evidence_version`. landscapeR validates that declaration
before invoking a registered adapter. Method authors return narrow preparation
and fit results; one package-owned normalized-evidence constructor creates and
validates storage tables, digests, and provenance. Default available-case
preparation and index refitting keep simple adapters small, while strategies
whose biological unit is a time cell or complete subject trajectory override
only those two hooks.
Routing by the declared `SamplingDesign` is structural contract dispatch, not
algorithm selection. It may branch on the finite set of supported design kinds;
the statistical implementation selected within that branch must remain a
registered `AssociationStrategy`.

No core dependency is added on `tidymodels`, `parsnip`, `workflows`,
`multilevelmod`, `rsample`, `broom`, `broom.mixed`, `lmerTest`,
`performance`, or `insight`. A future parsnip adapter may implement
`AssociationStrategy`, but it receives no authority to weaken the scientific
contract. `nlme::lme()` is reserved for a separately registered strategy when a
caller explicitly requires residual correlation or heterogeneous variance;
it is not a fallback from `lme4`.

### 3. Canonical samples and technical structure

Each matrix column is one canonical biological sample after upstream
technical-replicate resolution. landscapeR neither combines technical
replicates nor treats them as independent observations.

Technical plate, run, extraction, operator, laboratory, and similar fields
remain separate eligible metadata and may be declared together as additive
nuisance fields. They do not define a fourth biological sampling design or
replace the biological resampling unit. A composite `technical_batch_id` is
allowed only when concatenated labels identify a genuine nested or joint
processing unit. Its construction and constituent fields remain visible.
Blind concatenation of crossed factors is prohibited. Perfect target–batch or
time–batch confounding causes adjusted-association abstention.

### 4. Nomination, near ties, and multiplicity

Component nomination uses only the predeclared, sign-invariant biological
effect. Rank associations are scale-invariant, and longitudinal effects use
standardized scores. Effects are not weighted by singular value or variance
explained, and no fixed variance-explained cutoff excludes candidate
components.

The complete component ranking is repeated in every resample so effect
uncertainty, rank distributions, and winner's bias remain visible. A
calibrated near-tie margin may define an **effect-equivalent candidate set**.
Stability does not enter an opaque composite score and cannot privately rerank
components.

The descriptive atlas reports unchanged raw p-values and Holm-adjusted q-values
across the declared component family for each metadata field and evidence
variant. This family definition and correction method apply consistently to
cross-sectional, independent-time-course, and repeated-time-course designs. A
proposal for one predeclared target additionally reports the null distribution
of the maximum absolute target effect across all eligible components.

Permutation is permitted only under defensible exchangeability:

- unadjusted cross-sectional labels are permuted within declared strata;
- adjusted fixed-effects rank-score models use nuisance-only residual
  permutation within valid blocks, reconstruct the null outcome, and repeat the
  complete component search;
- repeated-subject conditions assigned between subjects are permuted only at
  subject level;
- fixed observed times are never permuted.

If no valid permutation exists, the proposal reports
`permutation-not-identifiable` rather than a global search-aware p-value.
Search-aware evidence may weaken support or cause abstention but cannot promote
another component. Multiple biological targets require separate named runs;
one may be predeclared primary and others remain exploratory unless governed by
another multiplicity plan.

Outside a predeclared effect-equivalent set, failure of the unique nominated
component yields no confirmed axis. A runner-up is not promoted after observing
that failure.

### 5. Alignment, identifiability, and stability

All data-dependent preprocessing and decomposition are repeated inside every
resample. The complete component set is matched jointly to the frozen
discovery reference using an optimal one-to-one assignment that maximizes
total absolute similarity.

Ordinary SVD uses feature-loading cosine similarity. Every other decomposition
strategy must declare the geometry appropriate to its loading space. Sign is
corrected only after assignment through the matched loading inner product. The
complete similarity matrix, assignment margins, competing matches, and failed
matches are retained. Weak or ambiguous matches remain unmatched under
calibrated thresholds. Procrustes rotation is prohibited.

The identifiability surface separately reports adjacent singular-value gaps,
matching similarity and ambiguity, individual-axis recurrence, component-index
recurrence, orientation recurrence, proposal-rank recurrence, and enclosing
subspace principal angles. Spectral gaps are diagnostics, not universal
standalone thresholds.

The structured outcomes include:

- `stable-axis`: one identifiable target direction recurs;
- `stable-subspace/no-stable-axis`: target association and enclosing subspace
  recur but no unique 1D direction is identifiable;
- `no-stable-target-structure`: neither an axis nor its enclosing target
  subspace recurs adequately.

Only a calibrated `stable-axis` is eligible for accepted 1D Stage 2 evidence.
A stable subspace remains scientifically reportable but cannot be converted
into a 1D component by human judgment.

### 6. Design-preserving resampling

- Cross-sectional observations are resampled as canonical biological units
  within predeclared target strata.
- Independent destructive time courses are resampled within
  condition-by-observed-time cells, retaining the design grid and cell counts.
- Repeated-subject studies resample complete subject trajectories within
  between-subject condition strata.
- Permutation follows the level at which the target was assigned.
- Technical labels travel with biological samples but do not replace them as
  resampling units.

Empty, collapsed, singular, unmatched, and failed resamples contribute to the
reported failure fraction. They are not silently regenerated until a requested
number of successful fits is reached.

A small package-owned resampling planner materializes the sampled biological
unit indices and deterministic replicate seeds. Duplicate repeated-subject
trajectories receive fresh deterministic subject identifiers before a fresh
`lmer()` fit. A generic resampling framework may be used internally later, but
cannot replace these design-specific rules.

### 7. Minimum data, abstention, and calibration

Hard structural gates require:

- every declared level to be represented;
- a full-rank complete-case design matrix;
- more biological sampling units than fitted model degrees of freedom;
- independent biological replication for every contrast;
- both conditions at two or more overlapping observed times, with relevant
  cell replication, for independent condition-by-time analysis;
- enough subjects with at least three usable time observations to identify
  random slopes;
- enough distinct biological-unit rearrangements for the requested resampling
  or permutation resolution.

Required target, nuisance, subject, and time values are excluded transparently
when missing and are never imputed by #55.

Failures distinguish `non-identifiable-design`,
`insufficient-resampling-support`, `permutation-not-identifiable`,
`outside-calibrated-operating-region`, and
`estimable-exploratory-only`. Universal sample-size rules and numerical
stability thresholds are not inferred from rules of thumb.

#55 may compute all descriptive, ranking, resampling, permutation, matching, and
subspace evidence before calibration, but the result remains
`estimable-exploratory-only`. Human confirmation may record an exploratory
choice but cannot label it stable, validated, accepted, or scientifically
supported.

#67 known-truth simulations and independent acceptance freeze near-tie,
matching, ambiguity, stability, acceptable-failure, and search-aware error
thresholds across declared operating regimes. Real AML analysis supplies no
calibration evidence.

### 8. Explicit human confirmation

`propose_component()` returns a proposal and cannot return a confirmed
`AnalysisSpecification`. For real data, confirmation requires a separate
`confirm_component()` call containing:

- the proposal;
- an explicit component index;
- an explicit `accept` or `override` decision;
- a non-empty rationale.

The transition records the proposal digest, recommendation, selected
component, decision, rationale, evidence status, and resulting specification
digest. A human may choose within a predeclared effect-equivalent set, reject
the proposal, or record an exploratory choice before calibration.

Human judgment cannot override `non-identifiable-design`,
`stable-subspace/no-stable-axis`, `no-stable-target-structure`, an
outside-operating-region restriction, or unique-winner failure. It cannot
change the target, nuisance fields, orientation, or ranking rule within the same
run. Such changes require a separately declared analysis.

Synthetic known-truth controls use a separate assertion path and do not
simulate human confirmation.

### 9. Visual decision surfaces

Every consequential proposal, diagnostic, or abstention has a canonical visual
decision surface where visual rendering materially improves interpretation.
Plots render public typed evidence; they do not calculate hidden scores or
mutate decisions. The visual grammar uses progressive disclosure and never
relies on colour alone.

The v1 plotting surface is ggplot2. `plot(atlas)`, `plot(proposal)`, and
subordinate diagnostic plots return ordinary `ggplot` objects assembled from
modular evidence panels. Typed objects expose stable public accessors so future
Plotly or other compatible adapters can consume the same evidence without
changing scientific computation. Interactive inspection cannot confirm or
alter a proposal. Static plots remain the canonical reproducible artifacts for
tests, documentation, and pull-request review.

Public figures, captions, and user-facing workflow documentation use restrained,
publication-quality scientific language suitable for a primary research
article. They state the estimand, design, uncertainty, and inferential boundary
directly. Internal governance phrases such as *human confirmation*, software
enforcement language, agent/development terminology, and implementation
instructions remain in provenance, API reference, ADRs, or developer
documentation and do not appear in scientific plot titles, subtitles, axes, or
captions. Visual review is performed at the canonical 100 mm output size and
must reject clipping, crowding, ambiguous encodings, or decorative elements
that do not carry scientific information.

Every newly implemented or migrated user-facing plotting function returns its
scientific caption as metadata attached to the ordinary `ggplot` object.
`scientific_caption()` provides the stable public accessor for that text.
Captions are not drawn inside the plotting area or plot layout by package
plotting functions. Quarto, R Markdown, manuscript, and other publication
systems can therefore render the returned text as a true figure caption,
separate from the graphic. The caption is generated deterministically from the
same typed evidence rendered by the plot; a renderer cannot require the user
to consult developer documentation to discover what colours, shapes, lines,
panels, observations, summaries, missing values, failures, thresholds, or
structured outcomes mean. Where applicable, the caption states:

- the declared dataset or experiment label, molecular layer, target field,
  oriented contrast labels, time field and unit, subject field, and nuisance
  fields needed to identify the scientific analysis;
- what is plotted and the biological sampling or analysis unit;
- the meaning of every non-obvious visual encoding, including focal versus
  comparison marks;
- the estimand, sampling design, and uncertainty or resampling basis;
- the meaning and calibration status of any threshold or reference line;
- the inferential and claim boundary, including exploratory or abstention
  status.

Caption templates substitute exact declared scientific labels from typed
analysis metadata. They do not silently prettify machine identifiers, infer
species or biological meaning from field names, or invent missing context.
Callers therefore own meaningful dataset, target, level, time, subject, layer,
and nuisance labels at the declaration boundary.

Multi-panel public figures carry visible letter labels in reading order.
Publication captions begin with a concise declarative title, integrate relevant
experimental context into narrative scientific prose, and refer to each panel
by its visible letter. Captions do not present metadata as a sequence of
`field: value` labels or describe package implementation. Figure numbering
remains the responsibility of the manuscript, Quarto document, or other
publication system.

Titles, axis labels, legends, and direct annotations may make a simple plot
self-explanatory, but omission of a caption from a user-facing function is a
documented exception rather than the default. An exception is valid only when
tests demonstrate that all applicable scientific semantics above are already
present in the returned plot. Internal-only diagnostic renders may omit this
contract only when they are unexported, identified as development diagnostics,
and not used in user documentation or public workflow examples.

The package-wide transition is tracked by issues #106 through #108. Plot
families that predate this amendment may retain their existing embedded
captions only until the corresponding migration lands. New plotting work must
not extend that legacy convention.

Caption tests inspect `scientific_caption(plot)`, verify that package plotting
functions do not populate `plot$labels$caption`, and verify dynamic content for
materially different designs, evidence states, encodings, and calibrated
versus uncalibrated boundaries. Captions describe stored evidence and never
become a second place where scientific results are calculated.

The shared implementation seam is
`landscapeR_scientific_caption_view`, an internal typed formatting view whose
fields contain only declared context and facts already computed in scientific
evidence. `.build_scientific_caption()` validates and formats that view; it
does not inspect raw observations, refit models, calculate thresholds, or
derive biological labels. The renderer registry records whether each public
plot family already requires this contract or has a named migration issue.
The separate exception registry accepts only tested `self-explanatory` or
unexported `internal-development` cases, with a substantive rationale and test
reference. A migration entry is transitional scheduling metadata, not a
scientific-caption exemption.

Canonical interpretation renderers consume a public `VisualEvidenceView`
obtained through `visual_evidence()`. The view contains normalized
observations, stored estimand and uncertainty summaries, diagnostics,
structured completeness or abstention state, design-specific display tables,
and the validated caption facts used by the same figure. Stable accessors expose
those fields without exposing private provenance. This is the package boundary
for future compatible adapters: a renderer may shape aesthetics and layout, but
it may not refit a model, recompute a smoother, rerank a component, reinterpret
missingness, or change an abstention.

The view is not a generalized renderer abstraction. The canonical reproducible
adapter remains ggplot2 until a second concrete adapter demonstrates a need for
shared rendering machinery. Plotly and Shiny may later consume the same typed
view, but they receive no independent scientific decision authority.

Legacy Stage 1 and Stage 2 plot families use the same rule through
digest-bound `StagePlotEvidence`. The structural Stage 1 wrapper owns the
legacy raw, uncentred assay spectrum as a descriptive estimand distinct from
any centred or pre-reduced strategy spectrum. Decomposition owns
component-density curves, decomposition-coordinate tables, and synthetic
ground-truth angles; dynamics estimation owns potential curves,
critical-point coordinates, barrier-height segments, and coordinate rugs.
New results store this evidence as part of their responsible scientific stage.
`prepare_plot_evidence()` is the explicit, provenance-recorded migration
operation for legacy or manually modified objects. Missing or stale evidence
returns a typed unavailable condition; renderers never silently refit an SVD,
estimate a density, compare against ground truth, interpolate a critical point,
or calculate a barrier segment.

The axis-identifiability surface jointly exposes the spectrum, matching
similarity and ambiguity, recurrence distributions, subspace angles, and final
structured status so a stable rotating plane is visually distinguishable from
a stable 1D axis.

## Implementation landing proof

- **Proof classification:** required
- **Before/after or representative output:** representative synthetic atlas,
  proposal, identifiability, abstention, and confirmation-decision renders,
  including raw and adjusted associations and nuisance structure
- **Current documentation affected:** component-interpretation workflow
  vignette and public function reference
- **Claim status:** implementation and synthetic known-truth proof only until
  #67 calibration and independent acceptance; real-data confirmation remains
  exploratory and human-recorded

## Consequences

- #55 can implement typed atlas, proposal, confirmation, and visualization
  contracts without inventing acceptance thresholds.
- Plots, future interfaces, and interactive adapters consume package-owned
  evidence rather than reimplementing scientific logic.
- Lower-variance biological axes remain eligible, while noisy or rotating axes
  are handled through multiplicity, matching, and identifiability rather than
  variance weighting.
- Some realistic datasets will return abstention, especially under confounding,
  sparse longitudinal structure, invalid exchangeability, or random-slope
  failure.
- The workflow is more computationally expensive because preprocessing,
  decomposition, ranking, and matching repeat under resampling.
- Repeated-subject support adds `lme4` and its compiled dependency graph; this
  cost is accepted for its native random-slope, convergence, singularity,
  extraction, and refit interfaces.
- Avoiding a core tidymodels stack keeps one scientific dispatch layer and a
  smaller release/check surface, while preserving an adapter seam for future
  callers.
- Future nonlinear, Bayesian, GEE, wild-bootstrap, and interactive strategies
  have explicit extension seams but no implicit authority.

## Review trigger

Revisit when #67 calibration or independent acceptance shows that any
estimand, resampling design, matching geometry, diagnostic, or abstention rule
fails its declared operating regime; when a concrete supported caller requires
nonlinear or Bayesian inference; or when a validated interactive renderer can
preserve the same typed evidence and confirmation boundary. Revisit the engine
choice if `lme4` cannot expose a required diagnostic or if two concrete
association strategies demonstrate that the package-owned registry cannot
support engine interoperability without a common external modeling framework.
