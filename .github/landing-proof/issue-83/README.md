# Issue #83 visual landing proof

**Claim status:** implementation proof only. This synthetic example shows the
complete evidence workflow and public 100 mm decision surface. Its structured
outcome is `not-calibrated`; it does not establish a universal stability
threshold, axis recovery, or biological support.

![Component identifiability evidence](identifiability-surface.png)

*Figure caption.* **Component-axis identifiability under design-preserving
resampling.** Axis identifiability was assessed for the treatment versus control
contrast using RNA expression data from the Synthetic control-treatment
expression study. The analysis used cross-sectional biological samples. All 99
bootstrap replicates completed the full assessment. Resampling used a
stratified bootstrap of biological sampling units within target groups.
**(A)** Axis recurrence is the proportion of resamples assigned to the
corresponding discovery axis. **(B)** Mean absolute feature-loading cosine
similarity measures agreement between matched resampled and discovery axes;
values approaching one indicate closer agreement. **(C)** Assignment margins
are shown for individual resamples; smaller values indicate greater ambiguity
between competing one-to-one assignments. **(D)** The largest principal angle
is shown for each enclosing subspace dimension; smaller angles indicate greater
subspace recurrence. Red triangles denote the nominated component and black
circles denote the remaining candidate components in panels A-C. Components
were matched jointly by maximizing total absolute feature-loading cosine
similarity. No stability threshold was applied. The nominated axis therefore
remains exploratory and must not be interpreted as stably recovered. These
results describe numerical identifiability and do not, by themselves, establish
biological validity.

The red triangles identify the uniquely nominated discovery component; black
circles retain the remaining search set. The primary surface exposes
individual-axis recurrence, mean loading-match similarity, assignment
ambiguity, and enclosing-subspace angles. Its dynamic caption defines the
encodings, biological resampling unit, joint one-to-one matching rule,
completion status, and uncalibrated claim boundary. The caption is kept
separate from the graphic. The reproduction script obtains this exact text by
calling `scientific_caption(identifiability_plot)` and saves it as
[`identifiability-surface-caption.txt`](identifiability-surface-caption.txt).
The complete nine-panel audit surface remains available through
`plot_component_identifiability(proposal, view = "diagnostic")`, where
component identity, per-resample recurrence, proposal rank, orientation,
spectrum, and completion remain visible.

The exact per-replicate assignments and rank recurrence remain available in
[`component-recurrence.tsv`](component-recurrence.tsv);
[`recurrence-summary.tsv`](recurrence-summary.tsv) provides one row per frozen
reference component. [`assessed-proposal.rds`](assessed-proposal.rds) preserves
the complete digest-bound evidence, including similarity matrices, competing
assignments, sampling draws, failures, and provenance.

## Reproduction

```sh
Rscript scripts/render-issue-83-proof.R
Rscript -e 'devtools::test(filter = "axis-identifiability")'
```
