# Speaker notes

Target duration: 10 to 12 minutes, leaving time for questions.

## 1. landscapeR

About 40 seconds. Introduce landscapeR as a general package for mapping biological state transitions from high-dimensional molecular data. Pogona is the motivating developmental example, not the sole intended application.

## 2. Study design

About 70 seconds. Contrast three familiar designs. Pogona has destructive sampling of independent embryos across observed developmental stages. The AML work follows the same subjects through time. Type 1 diabetes samples independent donors across ordered clinical states. Emphasize that these designs support different claims and resampling schemes.

## 3. Coordinate system

About 65 seconds. This is an executable landscapeR synthetic control, not a drawing. The generator creates independent samples at five stages, embeds a two-dimensional branching structure in 240 expression features, and the registered SVD recovers a low-dimensional coordinate system. Labels were withheld while fitting the axes.

## 4. Descriptive landscape

About 65 seconds. Explain the equation in plain language. Density becomes height after applying minus log. Frequently occupied states are low; sparse regions are high. State the caveat clearly: destructive cross-sectional samples do not demonstrate that an embryo moved along a plotted route.

## 5. Metadata

About 60 seconds. Add observed stage and terminal state after decomposition. Stage orders the cohorts. Terminal state interprets the late split. Temperature and genotype would remain explicit variables. The lines are summaries of group means, not tracked trajectories.

## 6. Genes and pathways

About 70 seconds. These bars are the actual feature loadings from the same recovered divergence coordinate. In real data, ranked genes can be examined directly and used for GSEA, modules, or comparison with stage-specific differential expression. This is how the landscape becomes biologically interpretable. Loadings nominate contributors but do not prove causal drivers.

## 7. Current package path

About 55 seconds. Distinguish implemented capability from the two-dimensional example. The one-dimensional double well runs end to end today through public functions: known-truth generation, SVD, density estimation, quasi-potential plotting and provenance. The figure was regenerated for this talk.

## 8. Declared analysis

About 65 seconds. Explain that decomposition is outcome-blind but interpretation is not casual browsing. The biological target, nuisance variables, association and sampling design are declared. Resampling preserves the biological unit. A person records the final decision or abstains.

## 9. Evidence

About 65 seconds. Known-truth controls answer whether the method recovers what was planted. Domain-grounded simulation adds realistic confounding, noise and sampling. Biological examples show feasibility and interpretation but cannot reveal latent truth. A valid result can be no identifiable coordinate.

## 10. LLM alignment before implementation

About 80 seconds. This is the part that differs most from casual vibe coding. We spend a long time establishing shared vocabulary, assumptions, failure conditions and scope before implementation. Matt Pocock's grilling skills influenced the structure, particularly `/grill-me` and `/grill-with-docs`. The project then adds scientific contracts, adversarial consultation, known-truth simulations, explicit abstention, ADRs and provenance. The goal is not simply to generate code faster. It is to leave an inspectable scientific argument that persists after the AI session.

## 11. Close

About 45 seconds. Summarize the current boundary. The general architecture exists and the one-dimensional path works. Metadata association and stability are being formalized. Pogona demands a validated two-dimensional branching model and comparison across temperature regimes. Close by inviting the audience to recognize other biological state-transition problems that fit the framework.

## 12. Pogona experiments

About 45 seconds, optional. These are the real expression matrices received today, not synthetic data and not an analysis result. One experiment samples days 7 through 17 at 28 °C in ZZ and ZW animals. The second spans stages 1, 2, 4, 6, 12, and 15. Whole embryos are consumed at the early stages because organs are not yet discernible; gonads are dissected later. The 28 °C ZZ and ZW cohorts span all stages, while the 36 °C ZZ cohort covers stages 6, 12, and 15. Counts and TPM matrices are consolidated locally. Two time-course labels and ten additional gonad samples still need metadata clarification, so no decomposition is shown tonight.
