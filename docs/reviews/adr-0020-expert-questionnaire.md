# Scientific consultation — identifying biological state coordinates

<!-- Generated from adr-0020-expert-questionnaire.json. -->

**Questionnaire:** `landscaper-scientific-consultation-v2`
**Schema version:** `2.0.0`
**Estimated time:** About 10 minutes

## What landscapeR is trying to do

landscapeR is an R package under development for studying biological state transitions from high-dimensional molecular measurements. It uses SVD- and GSVD-family decompositions to learn a low-dimensional coordinate system from one or more omic layers without using phenotype labels to fit the axes. Along a selected coordinate, it can estimate the descriptive quasi-potential U(x) = −log p(x), where frequently occupied states appear as wells separated by barriers.

## The scientific problem we would like you to assess

Outcome-blind decomposition is deliberate, but it leaves a separate interpretation problem: among several learned coordinates, which one represents a biological contrast or trajectory declared in advance? We need to answer that without cherry-picking a visually attractive or statistically significant axis, ignoring nuisance variables, treating repeated measurements as independent, or concealing instability across resamples.

We would value your criticism of six proposed statistical choices for solving that problem. Everything needed for this consultation is summarized here; no code or repository review is expected. We are especially interested in assumptions, failure modes, diagnostics, or alternatives that we may have missed. A favourable response is not an endorsement of the package or of any future biological result.

## A concrete orientation example

The synthetic example below shows the type of landscape the broader method is intended to produce. It contains two frequently occupied states separated by a barrier. The questions in this consultation concern the earlier step: how to identify and validate the biologically relevant coordinate before interpreting a landscape like this.

![Synthetic one-dimensional quasi-potential with two wells separated by a central barrier; observation rugs are shown along the horizontal axis.](https://drejom.github.io/landscapeR/articles/development-log_files/figure-html/k1-double-well-2.png)

*Synthetic two-state orientation example: U(x) = −log p(x). This calibration figure illustrates the intended output; it is not evidence for the six statistical choices below.*

## About the reviewer

- **Your name** — required
- **Affiliation or relevant expertise** — optional

## Decision 1 — Represent collection design explicitly

We distinguish three initial data structures: independent observations without a structural time variable; independent observations collected at known times, such as destructive culture or developmental sampling; and repeated observations from the same subject over time. Observed collection time is kept distinct from ordered disease state, severity, and inferred pseudotime. Designs such as crossover, nested sampling, informative dropout, nonlinear trajectories, or repeated observations without usable time are treated as outside the initial scope rather than forced into one of these analyses.

**Question:** Is this distinction sufficient to prevent the main forms of dependence or temporal structure from being misrepresented?

Response options:
- Scientifically reasonable as proposed
- Reasonable only with additional conditions
- Important revision or alternative needed
- Not enough information / outside my expertise

**Optional comment:** What collection design, assumption, or failure mode should we add or describe differently?

## Decision 2 — Use robust associations matched to the biological variable

For each learned coordinate, we propose signed rank-biserial correlation for a binary biological contrast, Spearman correlation for a continuous variable, and both an omnibus rank effect and an ordered Spearman trend for ordered states. Unordered variables with more than two levels remain descriptive. Unadjusted associations always remain visible. When nuisance variables are declared, the adjusted estimate is a partial rank association obtained by rank transformation and residualization; if that adjustment is not identifiable, we report no adjusted estimate rather than substituting the unadjusted one.

**Question:** Are these association measures and the no-substitution rule appropriate for identifying a biologically relevant coordinate?

Response options:
- Scientifically reasonable as proposed
- Reasonable only with additional conditions
- Important revision or alternative needed
- Not enough information / outside my expertise

**Optional comment:** What estimand, diagnostic, nonlinearity, or adjustment problem should we consider instead?

## Decision 3 — Model independent and repeated time courses differently

For independently sampled time courses, we propose a rank-scale fixed-effects model containing biological condition, scaled observed time, their interaction, and declared nuisance variables. For repeated-subject data, we propose the same fixed effects plus subject-specific random intercepts and time slopes. For a binary condition, the condition-by-time interaction is the primary trajectory-divergence effect. If the repeated model is singular, non-identifiable, or fails to converge, we report that limitation rather than falling back to a random-intercept-only or observation-independent analysis.

**Question:** Is this model split, including the random-slope requirement and refusal to fall back to a weaker dependence model, scientifically defensible?

Response options:
- Scientifically reasonable as proposed
- Reasonable only with additional conditions
- Important revision or alternative needed
- Not enough information / outside my expertise

**Optional comment:** Which assumptions, diagnostics, or alternative trajectory models are important at this initial scope?

## Decision 4 — Choose the coordinate by a predeclared effect, not significance

For a single molecular layer, we propose ranking learned coordinates by the magnitude of the biological effect declared before looking at the decomposition: unadjusted when no nuisance variable is declared, adjusted when nuisance variables are declared, and condition-by-time interaction for the initial binary time-course analysis. Raw and multiplicity-adjusted p-values remain visible but do not determine the ranking. Resampling then validates or rejects the initially top-ranked coordinate; it cannot promote a more stable runner-up. For decompositions spanning multiple molecular layers, we would report associations descriptively but make no automatic selection until a cross-layer rule has been validated.

**Question:** Does this rule adequately limit researcher degrees of freedom while retaining scientifically useful coordinate selection?

Response options:
- Scientifically reasonable as proposed
- Reasonable only with additional conditions
- Important revision or alternative needed
- Not enough information / outside my expertise

**Optional comment:** What should replace or constrain effect-magnitude ranking, stability assessment, or the multi-layer boundary?

## Decision 5 — Preserve biological sampling units and visible axis instability

Uncertainty resampling preserves the data-collection design: independent observations are resampled within their biological groups; independent time-course observations are resampled within fixed condition-by-time cells; and repeated data resample complete subject trajectories within subject-level condition groups. When the decomposition is rerun, all resampled coordinates are matched jointly to the reference coordinates by maximum absolute cosine similarity of their loadings, and arbitrary sign is corrected by the loading dot product. We do not Procrustes-rotate resampled axes toward the reference; axis recurrence and enclosing-subspace angles are reported separately so rotational instability remains visible.

**Question:** Does this resampling and alignment strategy preserve the uncertainty that matters for coordinate interpretation?

Response options:
- Scientifically reasonable as proposed
- Reasonable only with additional conditions
- Important revision or alternative needed
- Not enough information / outside my expertise

**Optional comment:** What resampling unit, matching rule, instability measure, or failure case should we reconsider?

## Decision 6 — Establish scientific support with known-truth simulations

We do not plan to infer universal sample-size or stability thresholds from rules of thumb. Instead, simulations with known target axes, nuisance axes, sampling dependence, and potential structure will be used to define the range in which the method recovers the intended coordinate and avoids false selection. Thresholds and analysis rules will be chosen on disclosed calibration simulations, frozen, and then tested on separate simulation seeds. Biological datasets may later demonstrate feasibility and face validity, but they cannot establish latent-axis recovery truth. The final coordinate choice for real data remains an explicit, recorded human judgement.

**Question:** Is this validation sequence sufficient before exploratory biological interpretation, and what essential evidence is missing?

Response options:
- Scientifically reasonable as proposed
- Reasonable only with additional conditions
- Important revision or alternative needed
- Not enough information / outside my expertise

**Optional comment:** What simulation regimes, negative controls, error criteria, or external validation should be mandatory?

## Overall recommendation

Given the scientific scope described here, what is your overall recommendation?
- Proceed to synthetic validation as proposed
- Proceed after adding specific conditions or diagnostics
- Revise the statistical strategy before validation
- Not enough information / outside my expertise

**Optional comment:** What is the most important gap, alternative, or caution we should address?

## Response handling

Your responses are for internal methodological review by the landscapeR project team. They will not be published or quoted. If we later want to attribute or quote any feedback, we will ask you separately.

If you prefer not to use the form, you can reply to the invitation email with the decision numbers and your comments.

Thank you. We will consider every response individually and revise the statistical strategy before using it for biological interpretation. Where reviewers disagree, we will preserve the disagreement internally rather than reducing the consultation to a vote.
