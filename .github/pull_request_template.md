## Summary

<!-- What does this PR do? -->

## Figures (required when vignettes/ is modified)

> Skip this section if no vignette or pkgdown article was changed.

- [ ] Screenshotted every rendered figure in `_site/` after `pkgdown::build_article()` and examined it visually
- [ ] Every figure that compares a metric to an acceptance criterion has a labelled threshold line
- [ ] Axis labels are human-readable (no raw code names, no underscores)
- [ ] Each figure has a scientific caption that states: what is plotted, what the threshold means, and what the reader should conclude
- [ ] A cold reader who has not seen the code can interpret the figure

**Figure review** _(paste a one-sentence interpretation of each figure here before merge)_

<!-- Example:
- fig-shared-recovery: median SRE across all exact-ID holdout strata; red cluster straddles the 0.25 threshold showing C2 passes only in high-signal, low-noise, K=2 conditions.
- fig-projection: same strata for projection error; nearly all red strata pass the 0.30 threshold but all other signal/noise regimes fail by a wide margin.
-->

## Checklist

- [ ] `devtools::test()` passes locally
- [ ] `R CMD check --no-manual` produces no new warnings
- [ ] `pkgdown::build_site()` + `check-pkgdown-images.py` pass locally (if vignette changed)
- [ ] ADR filed for any non-trivial algorithm or dependency choice
