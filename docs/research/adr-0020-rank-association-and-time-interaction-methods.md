# Rank association and time-interaction methods for ADR 0020

**Research date:** 2026-07-22
**Scope:** statistical interpretation of the proposed `partial_rank`,
`independent_time_course_rank`, and `longitudinal_rank_mixed` strategies
**Source rule:** primary methodological papers and first-party software
documentation only

## Executive finding

The cross-sectional statistic in ADR 0020 is defensible as a descriptive,
linear-projection-adjusted correlation of marginal rank scores. It is not, in
general, a conditional Spearman correlation, a conditional-independence
measure, or a causal estimand. The name `partial_rank` is therefore broader
than the method warrants unless the object records the exact projection
estimand. A more precise label is `residualized_rank_correlation` (or
`linear_projection_adjusted_spearman` when both variables are continuous).

The two proposed time-course procedures need revision before they can carry
inferential claims. Ranking the response once and then testing a conventional
condition-by-time coefficient in a linear or mixed model is the ordinary rank
transform (RT) pattern. RT interaction tests can have arbitrarily bad null
behaviour, and repeated-measures RT interaction tests are not generally valid.
ART is a different, effect-specific alignment procedure and is not a drop-in
justification for the proposed models. Its published validation addresses
factorial effects; it does not establish a continuous linear-time slope
estimand with nuisance covariates and a subject-specific random time slope.

## 1. What residualized midrank correlation estimates

Let \(X\) be a component coordinate, \(Y\) the target, and \(Z\) the declared
nuisance design (including its intercept, rank-scored continuous/ordered
columns, and indicator columns). Define the mid-distribution transform

\[
F_X^{mid}(x)=P(X<x)+\tfrac12P(X=x),
\]

and analogously for \(Y\). This is the population counterpart of scaled
midranks and handles ties explicitly. Let \(\Pi_Z U\) be the population
least-squares projection of \(U\) onto the declared finite-dimensional design
basis \(Z\). The natural population estimand of the ADR algorithm is

\[
\rho_{rank\cdot Z}^{proj}=
Corr\{F_X^{mid}(X)-\Pi_ZF_X^{mid}(X),
      F_Y^{mid}(Y)-\Pi_ZF_Y^{mid}(Y)\}.
\]

The sample Pearson correlation of the two OLS-residualized midrank vectors is
the plug-in analogue of this quantity (with the empirical distribution and
sample projection). With no nuisance variables it reduces to ordinary
Spearman correlation, including the usual midrank handling of ties. With
nuisance variables it removes only associations representable by the declared
linear projection basis on the *marginal rank-score scale*.

This distinction matters. Liu et al. define covariate-adjusted population
Spearman parameters through concordance/discordance probabilities and
probability-scale residuals (PSRs), where each variable's distribution is
modelled conditional on covariates. Their unadjusted PSRs reduce to linear
functions of ranks, but covariate-adjusted PSRs are conditional-distribution
residuals, not OLS residuals from marginal ranks. Thus, the proposed statistic
does not inherit the conditional interpretation of their parameter merely
because both procedures use rank-like scores [Liu et al. 2018,
doi:10.1111/biom.12812](https://doi.org/10.1111/biom.12812).

### Inferential properties and limits

- The coefficient is invariant to strictly increasing transformations of
  \(X\) and \(Y\), apart from the unavoidable treatment of ties. It is *not*
  invariant to changing the nuisance basis, coding, interactions, or nonlinear
  terms: those are part of the estimand.
- Zero coefficient means zero Pearson correlation between two projection
  residuals. It does not imply \(X\perp Y\mid Z\), and nonlinear residual
  dependence may remain.
- The familiar parametric partial-correlation \(t\) test is not automatically
  justified for empirical ranks with arbitrary mixed nuisance variables,
  heteroskedasticity, or data-dependent ties. In particular, “distribution
  free” does not follow from replacing values with ranks.
- A biological-unit bootstrap can estimate uncertainty for the statistic under
  independent, identically sampled units and regularity conditions, but it
  changes the claim from a closed-form partial-correlation test to bootstrap
  inference for the explicitly defined plug-in functional. The resampling unit
  must match the sampling design. Small or sparse strata still require
  simulation-based calibration and may require abstention.

### Defensible choices for ADR 0020

1. **Minimal change:** retain the computation, rename it, store the nuisance
   basis/coding as part of the estimand, describe it as associational, and use
   design-preserving bootstrap intervals rather than a nominal parametric
   partial-correlation test. This is appropriate when its role is transparent
   component ranking rather than a conditional-independence claim.
2. **If a conditional rank estimand is required:** use the PSR construction of
   Liu et al. Conditional distribution models are fit for both variables;
   their residual correlation estimates a stated covariate-adjusted Spearman
   parameter and naturally accommodates continuous, ordinal, and binary
   variables [Liu et al. 2018](https://doi.org/10.1111/biom.12812). This is
   more principled but materially increases modelling and diagnostic burden.
3. **If the scientific target is probabilistic ordering:** use a probabilistic
   index model (PIM), whose regression parameters act on probabilities such as
   \(P(Y_i<Y_j)\), rather than presenting a residual correlation as conditional
   association. De Neve and Thas give the regression framework and estimating
   theory [De Neve & Thas 2015,
   doi:10.1080/01621459.2015.1016226](https://doi.org/10.1080/01621459.2015.1016226).

The minimal-change option best matches ADR 0020's stated non-causal,
effect-ranking purpose, provided the more limited estimand is made explicit.

## 2. Why naive rank-transform interaction inference fails

Globally replacing a response by its ranks and then applying the usual
factorial linear-model test does not preserve the original no-interaction
hypothesis. Ranking is nonlinear and is performed across cells; main effects
can therefore induce an apparent interaction on the pooled-rank scale.

The failure is theoretical, not merely a conservative caveat. For balanced
two-way layouts other than the special 2-by-2 case, Thompson showed that there
are additive-model main effects for which, under no interaction, the expected
RT interaction statistic diverges as sample size grows [Thompson 1991,
doi:10.1093/biomet/78.3.697](https://doi.org/10.1093/biomet/78.3.697).
Simulation work likewise found seriously distorted size for factorial RT
procedures [Sawilowsky, Blair & Higgins 1989,
doi:10.3102/10769986014003255](https://doi.org/10.3102/10769986014003255).

Dependence does not cure the problem. Akritas's repeated-measures analysis
shows that ordinary RT procedures are not generally valid for interaction (or
main-effect) testing in generalized repeated-measures designs [Akritas 1993,
doi:10.1016/0167-7152(93)90009-8](https://doi.org/10.1016/0167-7152(93)90009-8);
the companion paper establishes only narrow valid cases and notes parameter-
dependent efficacy [Akritas 1991,
doi:10.1080/01621459.1991.10475066](https://doi.org/10.1080/01621459.1991.10475066).
Adding random intercepts or slopes after the global rank transform accounts for
some covariance structure but does not restore the interaction null destroyed
by the transformation.

Consequently, a coefficient from either proposed model can be retained as a
descriptive slope contrast on *sample-dependent pooled ranks*, but ordinary
linear/mixed-model standard errors, p-values, and confidence intervals should
not be described as validated rank-based inference for trajectory divergence.
It also lacks a stable population effect unless the limiting score
distribution and reference population are specified.

## 3. ART applicability

ART first removes (aligns away) all effects except the one being tested, ranks
that effect-specific aligned response, and then applies the corresponding
ANOVA test. A separate aligned-and-ranked response is required for each effect.
That is precisely why ART is not equivalent to fitting one model to globally
ranked outcomes. Wobbrock et al. present the N-factor algorithm, support both
between- and within-subject factorial designs, and require diagnostics that
irrelevant effects sum approximately to zero and have negligible ANOVA effects
[Wobbrock et al. 2011,
doi:10.1145/1978942.1978963](https://doi.org/10.1145/1978942.1978963).

ART is plausible only if time is treated as a finite categorical factor and the
question is the factorial condition-by-time effect covered by the alignment.
That is a different capability from ADR 0020's continuous, scaled-time linear
slope contrast. The 2011 paper's construction uses factorial cell means; it
does not validate arbitrary continuous covariates or a random time-slope
estimand. Repeated measures can be represented in the post-alignment analysis,
but the paper does not validate the specific `(1 + time | subject)` mixed model
under thin longitudinal sampling.

ART also cannot be used for arbitrary follow-up contrasts on the ordinary ART
ranks. Elkin et al. show inflated Type I error for such contrasts and introduce
the distinct ART-C alignment; their validation explicitly did not cover mixed
factorial designs or random slopes [Elkin et al. 2021,
doi:10.1145/3472749.3474784](https://doi.org/10.1145/3472749.3474784).

Therefore ART is an optional, categorical-time factorial test—not a literature
justification for either currently named ADR strategy.

## 4. Alternatives by sampling design

### Independent destructive time courses

Two scientifically different targets should not be conflated:

- **Prespecified linear trajectory contrast:** fit the condition, continuous
  time, and condition-by-time model on the original component scale. Use
  heteroskedasticity-robust/sandwich covariance or a design-cell bootstrap, and
  make the linear functional and supported time range explicit. Ranking is not
  needed merely because normality is doubtful; inference concerns the stated
  mean-slope model and its sampling assumptions.
- **Distributional factorial condition-by-time effect:** treat observed times
  as categorical and use a procedure whose hypotheses are defined on cell
  distributions or relative effects. Akritas, Arnold and Brunner derive rank
  statistics for no interaction in independent, unbalanced factorial designs,
  including ties [Akritas, Arnold & Brunner 1997,
  doi:10.1080/01621459.1997.10473623](https://doi.org/10.1080/01621459.1997.10473623).
  Brunner et al. instead define sample-size-invariant relative treatment effects
  against an unweighted reference distribution and give inference for their
  contrasts [Brunner et al. 2017,
  doi:10.1111/rssb.12206](https://doi.org/10.1111/rssb.12206). These effects are
  interpretable but do not estimate a continuous time slope.

A PIM is another option when a covariate-adjusted probabilistic ordering is the
desired estimand, but its exact condition-by-time parameter and variance scheme
would need to be specified and validated for these small design cells.

### Repeated subjects over time

For categorical time, use a longitudinal rank procedure that defines marginal
distribution/relative-effect contrasts and estimates the full within-subject
covariance, rather than globally ranking and fitting an LMM. Brunner, Munzel and
Puri provide rank-score tests for general repeated-measures and longitudinal
designs, allowing ties, missing observations, unequal response-vector lengths,
and singular covariance matrices [Brunner, Munzel & Puri 1999,
doi:10.1006/jmva.1999.1821](https://doi.org/10.1006/jmva.1999.1821). Akritas and
Arnold give fully nonparametric no-main-effect and no-interaction hypotheses for
multivariate repeated measures [Akritas & Arnold 1994,
doi:10.1080/01621459.1994.10476475](https://doi.org/10.1080/01621459.1994.10476475).

If a continuous subject-specific linear slope is scientifically essential,
the honest alternative is an explicitly model-based longitudinal analysis on
the original component-score scale, with time standardized as planned (random
intercept and slope where estimable), with
subject-cluster bootstrap or suitable robust covariance and simulation
calibration. It is not nonparametric simply because its response is ranked.
Subject-level resampling preserves dependence but cannot repair a misspecified
estimand or an unidentified random-slope distribution.

## Recommendation for the decision record

1. Keep the cross-sectional statistic only as
   `residualized_rank_correlation`, define its projection estimand in the data
   contract, and attach design-preserving bootstrap uncertainty. Reserve
   “partial Spearman” for a method with a stated conditional-rank population
   parameter (for example, PSRs).
2. Do not claim inferential validity for global-rank condition-by-time linear
   or mixed models. A bootstrap around the same statistic can quantify its
   sampling variability, but does not turn it into a generally valid test of
   no interaction.
3. Split time support by estimand: original component-score-scale model-based
   inference, with standardized time, for a prespecified continuous linear
   slope; ART or fully nonparametric factorial methods for categorical-time
   interaction/relative effects. For irregular continuous observation times,
   the former preserves the actual spacing whereas converting time to a factor
   deliberately discards that linear-spacing claim.
4. For repeated data, use subject-aware longitudinal rank methods for
   categorical-time distributional effects, or an explicitly parametric/
   semiparametric mixed model for continuous slope effects. Preserve ADR 0020's
   abstention rule when the chosen estimand is unsupported by the design.

## Access note

The full texts of several older methodological articles were publisher-
restricted during this review. Their exact citations and DOIs are supplied
above; claims about those papers are limited to their publisher-hosted
abstracts. No secondary source was substituted for inaccessible primary text.
