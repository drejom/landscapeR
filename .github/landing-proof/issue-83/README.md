# Issue #83 visual landing proof

**Claim status:** implementation proof only. This synthetic example shows the
complete evidence workflow and public 100 mm decision surface. Its structured
outcome is `not-calibrated`; it does not establish a universal stability
threshold, axis recovery, or biological support.

![Component identifiability evidence](identifiability-surface.png)

*Figure caption.* 99 of 99 independent biological observation resamples
completed the full assessment; 0 did not. Resampling used target stratified
biological unit bootstrap. In component-indexed panels, the red triangle marks
the nominated component and black circles mark comparisons. Components are
matched jointly one-to-one by maximum total absolute feature-loading cosine.
Axis recurrence is the fraction assigned to the same discovery axis; higher
absolute loading cosine indicates a closer match; larger assignment margin
indicates less ambiguity. Subspace points are per-resample largest principal
angles for each enclosing dimension. Smaller subspace angles indicate more
recurrent enclosing subspaces. No stability threshold is applied; evidence is
descriptive and does not establish biological validity.

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
