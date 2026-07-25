# R modeling frameworks for ADR 0020 longitudinal associations

**Research date:** 2026-07-24
**Decision scope:** implementation substrate and registered extension seam for
independent and repeated-subject component-association models
**Sources:** R manuals, CRAN/package manuals, official package sites and source
repositories, Bioconductor guidance, and primary package papers only

## Recommendation

Use `stats::lm()` for independent time courses and `lme4::lmer()` for the
supported repeated-subject model. Keep a package-owned, typed
`AssociationStrategy` registry as the scientific abstraction. Do not make
`parsnip`, `workflows`, `multilevelmod`, or the full tidymodels stack part of
the execution core.

The repeated model should be an explicitly fixed contract, conceptually:

```r
score ~ target * time_scaled + nuisance +
    (1 + time_scaled | subject)
```

with a separately registered independent strategy using the same fixed-effect
contract without random effects. Extract coefficients and diagnostics through
native generics/accessors into package-owned records. Treat convergence,
rank deficiency, zero residual degrees of freedom, and singular random-effects
fits as typed abstentions; never use diagnostics or p-values to choose a weaker
model.

`nlme::lme()` is the best alternative if a future caller requires a declared
within-subject residual correlation or heteroscedastic variance function. Those
features are not in the current narrow capability, while `lme4` has a clearer
singularity diagnostic and purpose-built `refit()`/`bootMer()` infrastructure.
Do not silently switch engines: an `nlme` correlation/variance model would be a
new registered strategy with a new estimand and validation range.

Use a small package-owned bootstrap planner/refitter because ADR 0020 requires
special resampling (condition-by-time cells for independent data and whole
trajectories with fresh duplicate subject IDs for repeated data). `rsample` may
be used internally later, but its generic group bootstrap does not itself
enforce those rules. Persist extracted results, declarations, diagnostics,
replicate identifiers, seeds, and engine/package versions; do not make a raw
fitted model object the authoritative serialized scientific result.

## Why the strategy registry should sit above the model engine

The repository already has `register_strategy(contract, name, constructor)`.
That seam is closer to the scientific decision than parsnip's engine registry:
it can bind one name to all of the following without pretending that engines
have uniform semantics:

- supported `SamplingDesign`, target type, time form, and nuisance encodings;
- complete-case cohort and structural-identifiability checks;
- exact formula and contrast construction;
- estimator and fixed control settings;
- coefficient-to-estimand mapping;
- diagnostic-to-abstention mapping;
- design-preserving resampling and duplicate-ID policy;
- normalized result schema, provenance, and serialization.

A minimal internal contract should expose operations equivalent to
`supports()`, `fit()`, `extract_effect()`, `diagnose()`, and `refit()`. The
constructor should return a typed strategy instance rather than a free-form
engine specification. Engine-specific objects remain private implementation
details. This allows another strategy to use `nlme`, a robust covariance
estimator, or a future nonlinear method without changing the atlas/proposal
contract.

Parsnip also has a documented model registry (`set_new_model()`,
`set_model_engine()`, `set_fit()`, `set_pred()`, and dependency registration),
but its registry standardizes model specification, fitting, and prediction—not
sampling-design eligibility, inferential estimands, scientific abstention, or
bootstrap units. Its extension guide also requires package-time registration
and dependency declarations so parallel workers can load custom engines
correctly [parsnip extension API](https://parsnip.tidymodels.org/reference/set_new_model.html),
[official extension guide](https://www.tidymodels.org/learn/develop/models/).
Recreating landscapeR's scientific registry inside parsnip would add a second
dispatch layer without removing the need for the first.

## Engine comparison

| Candidate | Fixed and random slopes | Diagnostics/extraction | Weights and missingness | Bootstrap/refit and serialization | Decision |
|---|---|---|---|---|---|
| `stats::lm` | Exact fixed `target * time_scaled`; no random effects | Stable base accessors for coefficients, QR rank, residual df, residuals, model matrix, influence | Numeric weights are inverse-variance or replication-like weights; `na.action` is explicit | Ordinary R object; `update()`/fresh fit are simple | Use for independent time courses |
| `lme4::lmer` | Correlated `(1 + time | subject)` and uncorrelated `(1 + time || subject)` random slopes; nested and crossed grouping | `fixef`, `VarCorr`, `getME`, optimizer messages, `isSingular`; no denominator-df p-values by default | Numeric prior weights; native `na.action`; no `nlme`-style residual correlation/variance-function layer | `refit()` and seeded `bootMer()`; serializable native object, but authoritative output should be extracted | Preferred repeated engine |
| `lmerTest` | Same fit inherited from `lme4` | Adds Satterthwaite/Kenward–Roger p-values, ANOVA tables, `step`, `drop1`, and random-effect tests | Inherits engine behavior | Adds inference metadata rather than needed fit capability | Do not import |
| `nlme::lme` | Random intercept/time slope for nested groups; current one-subject-level design fits directly | Fixed/random effects, covariance, residuals, fitted values, `update`; optimizer controls and nonconvergence handling | `varFunc` models heteroscedastic residual variance; `corStruct` models within-group correlation; explicit `na.action` | Ordinary fitted object and `update`; no native counterpart as focused as `isSingular`/`refit`/`bootMer` | Register only when correlation/variance structure is a declared capability |
| `parsnip` + `multilevelmod` | Formula passthrough to `lmer`, `lme`, `gls`, GEE, or Stan engines | Native fit must still be extracted for engine-specific diagnostics | Support remains engine-specific; wrapper does not unify meanings | Wraps the native object; orchestration does not create reproducibility guarantees | No core benefit here |
| `glmmTMB` | Rich Gaussian/GLMM random and residual structures | Strong diagnostics and simulation ecosystem | Flexible dispersion/correlation models | Heavier compiled TMB dependency | Reserve for a concrete non-Gaussian or structured-residual caller |
| `mmrm` | Marginal repeated-measures covariance models, not subject random slopes | Purpose-built repeated-measures inference | Visit/covariance-oriented model | Strong clinical repeated-measures implementation | Different estimand; not current strategy |

### `stats::lm`

`lm()` directly represents the independent design's condition, continuous
time, condition-by-time, and nuisance terms. Its result records coefficients,
residuals, fitted values, QR rank, residual degrees of freedom, contrasts,
factor levels, model frame, and missing-data action. Its documentation is also
explicit that weight meanings matter: numeric weights represent inverse
variance or replication-like precision, and replication weights can make sigma
and residual degrees of freedom inappropriate if misused
[R `lm` manual](https://stat.ethz.ch/R-manual/R-devel/library/stats/html/lm.html).

Therefore ADR bootstrap multiplicity must be represented by actual resampled
rows, not compressed into `lm(weights=)` unless the corresponding statistical
equivalence is established. Required fields should be complete-cased upstream
and the model called with an explicit `na.action` (preferably `na.fail` after
cohort construction), so engine defaults cannot silently change the cohort.
R's model-frame machinery records the applied missingness action
[R `na.action` manual](https://stat.ethz.ch/R-manual/R-devel/library/stats/html/na.action.html).

### `lme4::lmer`

`lmer()` supports the exact random intercept and time slope required here. A
single `|` estimates their covariance; `||` requests uncorrelated random
effects [lmer reference](https://lme4.github.io/lme4/reference/lmer.html).
The correlated form should remain the declared model unless the decision is
changed; changing to `||` after a difficult fit would be an unregistered
fallback.

For programmatic extraction, `fixef()` gives fixed coefficients, `vcov()` their
estimated covariance, `VarCorr()` the random/residual variance structure,
`getME()` internal model matrices and convergence quantities, and
`isSingular()` detects boundary covariance fits
[lme4 `isSingular`](https://lme4.github.io/lme4/reference/isSingular.html).
The primary lme4 paper describes its penalized least-squares formulation and
modular computational design [Bates et al. 2015,
doi:10.18637/jss.v067.i01](https://doi.org/10.18637/jss.v067.i01).

This diagnostic surface fits ADR 0020's abstention rule. A singular optimum can
be mathematically well-defined, but the package warns that singularity can
indicate overfitting, numerical difficulty, and unreliable conventional
inference. Record it separately from optimizer nonconvergence, then abstain
under the proposed capability rather than simplifying the random structure.

`lmer()` accepts numeric prior weights, but their scale affects the residual
variance; they are not a generic declaration of biological-unit sampling
weights [lmer reference](https://lme4.github.io/lme4/reference/lmer.html).
Duplicate sampled trajectories must instead receive fresh subject IDs and be
present as duplicated rows, as ADR 0020 already requires.

`refit()` can reuse a fitted model structure with a new response, and
`bootMer()` supports seeded parametric and partially implemented semiparametric
model bootstraps while retaining warnings/errors from replicate fits
[lme4 `bootMer`](https://lme4.github.io/lme4/reference/bootMer.html). ADR's
nonparametric subject-trajectory bootstrap changes rows and IDs, so fresh
`lmer()` calls are clearer than forcing it through `bootMer`; nevertheless the
native APIs are useful for synthetic calibration and fixed-design response
simulation.

### Why not `lmerTest`

`lmerTest` adds Satterthwaite and Kenward–Roger denominator-degree-of-freedom
tests, type I/II/III ANOVA tables, stepwise model selection, `drop1`, and random
effect tests [CRAN package page](https://cran.r-project.org/web/packages/lmerTest/index.html).
ADR 0020 explicitly prohibits p-value-driven component/model selection and
requires a frozen random structure. It adds no needed estimator capability;
importing it would invite precisely the inference and fallback surface the
contract excludes. If a future reporting decision adopts one of those
approximations, that should be a separately justified inference layer.

### When `nlme` is stronger

`nlme::lme()` fits the current random intercept/slope model as
`random = ~ time_scaled | subject`. Unlike `lme4`, it can simultaneously declare
within-group `corStruct` residual correlations and `varFunc` residual variance
models [R `lme` manual](https://stat.ethz.ch/R-manual/R-patched/library/nlme/html/lme.html),
[nlme reference manual](https://stat.ethz.ch/CRAN/web/packages/nlme/refman/nlme.html).
Those are valuable for a caller whose residual serial correlation or
heteroscedasticity is part of the estimand.

They are not free robustness switches. `weights` in `lme()` specifies a
variance function, not a uniform case-weight abstraction; `correlation`
specifies a within-group error model. Adding either changes assumptions and
must be validated. `lmeControl(returnObject = FALSE)` ordinarily refuses to
return an object after iteration-limit nonconvergence, which is compatible with
typed abstention. `nlme` is an R "recommended" package, maintained by R Core,
with only base/recommended imports and GPL-2-or-3 licensing
[CRAN `nlme`](https://stat.ethz.ch/CRAN/web/packages/nlme/index.html).

`nlme` remains a defensible primary choice if the ADR values its residual
structures more than `lme4`'s boundary/refit tooling. For the current model,
however, those unused features do not outweigh `isSingular()` and the broader
modern mixed-model diagnostics ecosystem.

## Tidymodels and adjacent packages

### `parsnip`, `workflows`, and `multilevelmod`

Parsnip is a translation layer: `fit()` converts a model specification to an
engine call, and a `model_fit` contains the native engine object plus
specification/preprocessing metadata
[parsnip `fit`](https://parsnip.tidymodels.org/reference/fit.html),
[parsnip `model_fit`](https://parsnip.tidymodels.org/reference/model_fit.html).
Workflows bundle preprocessing, a parsnip model, and optional postprocessing;
the native model is still recovered through `extract_fit_engine()`
[workflow stages](https://workflows.tidymodels.org/articles/stages.html),
[workflow extraction](https://workflows.tidymodels.org/reference/extract-workflow.html).

`multilevelmod` registers `lmer`, `glmer`, `lme`, `gls`, GEE, and Stan engines
for parsnip. Random-effect terms still require a special formula, and the
experimental-unit column must not be destroyed by recipe encoding
[multilevelmod engines](https://multilevelmod.tidymodels.org/),
[multilevelmod vignette](https://multilevelmod.tidymodels.org/articles/multilevelmod.html).
Thus the wrapper does not normalize singularity, denominator degrees of
freedom, REML versus ML, weight meaning, missingness, or random-slope semantics.

For a user-facing predictive workflow spanning many interchangeable engines,
this uniform surface is valuable. ADR 0020 instead freezes one estimator per
sampling design and publishes scientific effects, diagnostics, abstentions,
and provenance—not a tunable predictive workflow. A workflow object would add
recipes/molds/specifications while native access and a package-owned result
schema are still necessary. The cost is several new dependency layers with no
scientific capability gained.

Case weights illustrate the mismatch. Parsnip distinguishes frequency and
importance weights, but support is engine-specific and must be queried with
`case_weights_allowed()` [parsnip case weights](https://parsnip.tidymodels.org/reference/case_weights.html).
It does not make `lm`, `lmer`, and `lme` weights equivalent. Missing-data
handling is likewise left to recipe preprocessing or the native engine. ADR's
explicit cohort construction is the stronger contract.

### `broom` and `broom.mixed`

`broom` standardizes `tidy()`, `glance()`, and `augment()` tables for many
models [broom overview](https://broom.tidymodels.org/). Mixed-model methods live
in separately maintained `broom.mixed`, which supports a broad range of
hierarchical model classes [broom.mixed](https://bbolker.github.io/broom.mixed/).
They are useful adapters, but their columns and inferential statistics remain
class/method-specific.

Do not make either an authoritative extraction dependency for two known model
classes. A few native accessors are easier to audit, prevent accidental
publication of p-values, and let the package enforce one stable schema.
`broom` can remain useful for examples; `broom.mixed` can be optional user-side
interoperability. `broom` is MIT; `broom.mixed` is GPL-3. Any direct dependency
should undergo the project's normal license-compatibility review rather than
assuming wrapper output is cost-free.

### `rsample` and `infer`

`rsample` creates resample descriptors and intentionally does not fit models or
calculate statistics [rsample overview](https://rsample.tidymodels.org/).
`group_bootstraps()` samples whole groups and explicitly identifies repeated
measures as a use case [group bootstraps](https://rsample.tidymodels.org/reference/group_bootstraps.html).
This is close to the repeated design, but it does not assign fresh identifiers
to duplicate subject draws, enforce subject-invariant target strata, or encode
the independent condition-by-time-cell bootstrap. Package-owned planning is
still required.

`infer` is a grammar for standard bootstrap/randomization null distributions
(`specify`, `hypothesize`, `generate`, `calculate`), not arbitrary mixed-model
refit orchestration [infer overview](https://infer.tidymodels.org/). It adds
little once effects and resampling are governed by the strategy contract.

Determinism should be explicit rather than attributed to either framework:

1. create stable replicate IDs and deterministic seeds before parallel work;
2. record RNG kind, seed policy, engine and package versions;
3. materialize/record sampled biological-unit indices;
4. reconstruct duplicate subject IDs deterministically;
5. fit each replicate with frozen formula, contrasts, optimizer, controls, and
   complete-case cohort rules;
6. retain every warning, error, convergence code, and abstention reason;
7. sort outputs by declared keys, never completion order.

### `probably`, `performance`, and `insight`

`probably` handles prediction postprocessing—probability thresholds,
calibration, equivocal zones, and conformal regression intervals. It does not
fit longitudinal models or extract coefficient estimands
[probably overview](https://probably.tidymodels.org/). It has no role here.

`performance` and `insight` offer convenient cross-model diagnostics and
accessors. For example, `performance::check_singularity()` supports several
mixed classes, while `check_convergence()` is specifically an alternative
check for `merMod`/`glmmTMB` objects
[singularity](https://easystats.github.io/performance/reference/check_singularity.html),
[convergence](https://easystats.github.io/performance/reference/check_convergence.html).
`insight::get_variance()` extracts random-slope/intercept components but warns
that `nlme::lme` support is not fully implemented/tested for every model
[insight variance extraction](https://easystats.github.io/insight/reference/get_variance.html).

These are good interactive diagnostic companions, not a stable scientific
contract. Direct native checks for two engines are smaller and more auditable.
They could be Suggests-only tools for vignettes or expert debugging.

## Stronger candidates for narrower future needs

- **`lmeresampler`:** supplies parametric, residual, case, wild, and
  random-effect-block bootstraps for `lme4`/`nlme` objects. It is stronger than
  a hand-written generic mixed-model bootstrap, but ADR's stratification and
  duplicate-ID semantics remain custom
  [official repository](https://github.com/aloy/lmeresampler).
- **`clubSandwich`:** supplies cluster-robust covariance estimators and
  small-sample corrections for supported regression/mixed objects. It may be a
  future inference strategy when robustness to covariance misspecification is
  the declared goal, but is not a diagnostic patch to apply after seeing a bad
  fit [official site](https://jepusto.github.io/clubSandwich/).
- **`glmmTMB`:** supports broader distributions, dispersion models, structured
  covariance, simulation, and random slopes. For a Gaussian random-slope model
  it adds TMB compilation and a much larger surface without a present need
  [Brooks et al. 2017,
  doi:10.32614/RJ-2017-066](https://doi.org/10.32614/RJ-2017-066).
- **`mmrm`:** is a high-quality marginal repeated-measures implementation with
  structured covariance and clinical-trial inference, but it estimates a
  marginal visit model rather than subject-specific random slopes
  [official documentation](https://openpharma.github.io/mmrm/). It belongs
  behind a different association strategy if that estimand becomes required.

## Case weights, missingness, and resampling rules

The initial strategies should reject user case weights unless ADR 0020 defines
their provenance and meaning. Engine arguments named `weights` are not
interchangeable:

- `lm` weights affect least-squares precision;
- `lmer` prior weights alter the conditional residual precision/scale;
- `lme` weights describe a residual variance function;
- bootstrap draw multiplicity represents repeated sampled units and should be
  expanded, with new group IDs where necessary.

Similarly, do not delegate missingness to framework defaults. Build and record
the complete-case analysis cohort once from target, time, subject, score, and
declared nuisance fields; fit with `na.action = na.fail`; and require every
bootstrap replicate to preserve the same variable contract. A replicate that
loses an estimable factor level or residual degree of freedom abstains rather
than changing its formula.

## Serialization and reproducibility

Native `lm`, `lmerMod`, `lme`, parsnip, and workflow fits are R objects and can
usually be serialized in the same supported environment. That is not the same
as a durable scientific schema: calls and formula environments can capture
data/environments, wrappers embed native objects, object layouts evolve, and
successful reload still depends on compatible packages.

The authoritative `MetadataAssociationAtlas` row should therefore store plain,
versioned values:

- estimand/formula term IDs and estimates;
- interval and supporting p-value only if the chosen inference method defines
  them;
- fixed-effect covariance elements needed downstream;
- random intercept/slope variances and covariance;
- residual scale, observations, units, ranks/df, and cohort digest;
- convergence and singularity diagnostics with thresholds;
- engine, package/version, optimizer/control, contrasts, and formula digest;
- resample plan/replicate ID, seed provenance, warnings, and abstention reason.

A raw fit may be retained as an optional diagnostic payload, but plots and
proposal ranking must use stored normalized results. Test serialization with a
fresh-session read and schema validation; never require refitting to render.

## Dependency and Bioconductor implications

All discussed packages are on CRAN and therefore eligible dependencies under
Bioconductor's rule that dependencies be publicly available on CRAN or
Bioconductor. Bioconductor distinguishes essential `Imports` from conditional
`Suggests`, discourages remote-only dependencies, and expects reuse of
well-tested packages rather than duplicated algorithms
[Bioconductor DESCRIPTION guidance](https://contributions.bioconductor.org/description.html).

Recommended dependency posture:

- keep `stats` for the independent strategy;
- add `lme4` as the one essential mixed-model import if repeated support is
  mandatory in the base installation;
- keep `nlme`, `rsample`, `broom`, `broom.mixed`, `performance`, `insight`,
  `clubSandwich`, and `lmeresampler` out of Imports until a registered strategy
  or required user workflow actually uses them;
- do not add the tidymodels metapackage, `parsnip`, `workflows`,
  `multilevelmod`, `infer`, or `probably` for this feature.

`nlme` is R-recommended and GPL-2-or-3; `lme4` is mature, widely reverse-used,
GPL-2-or-3, and has compiled dependencies. As checked on 2026-07-24, CRAN lists
`nlme` 3.1-170 and `lme4` 2.0-1; the latter links to `RcppEigen`/`Matrix` and
also imports `nlme`, so choosing `lme4` does not remove `nlme` from the
installation graph. Its advantages here are API/diagnostic behavior rather
than dependency minimalism
[CRAN `lme4`](https://stat.ethz.ch/CRAN/web/packages/lme4/index.html).
CRAN lists parsnip 1.4.1 with a substantially broader tidyverse dependency
graph
[CRAN `parsnip`](https://stat.ethz.ch/CRAN/web/packages/parsnip/index.html).
The core tidymodels packages are
actively maintained and mostly MIT, but adopting several of them increases the
release/check surface. `broom.mixed` is separately maintained under GPL-3.
License compatibility and redistribution implications should be confirmed at
package-integration time; this note does not offer legal advice.

## Decision matrix

| Requirement | Native engines + `AssociationStrategy` | tidymodels wrapper stack |
|---|---:|---:|
| Exact fixed/random slope contract | Direct | Passes through to native engine |
| Typed scientific eligibility/abstention | Natural package-owned seam | Still custom |
| Native convergence/singularity detail | Direct | Requires engine extraction |
| Uniform weights/NA/inference semantics | Explicitly avoids false uniformity | Not provided |
| Design-specific bootstrap | Small custom planner/refitter | Still custom around `rsample` |
| Prediction/tuning across many engines | Limited | Strong |
| Stable atlas schema | Explicit adapter | Explicit adapter still required |
| New dependency burden | `lme4` only | Multiple packages plus native engine |
| Fit for current ADR | **High** | **Low** |

The strongest present design is therefore not a universal modeling framework.
It is a deliberately small scientific strategy contract backed by `lm` and
`lmer`, with future engines registered only when a new caller and estimand make
their additional capability necessary.
