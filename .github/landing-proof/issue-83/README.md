# Issue #83 visual landing proof

**Claim status:** implementation proof only. This synthetic example shows the
complete evidence workflow and public 100 mm decision surface. Its structured
outcome is `not-calibrated`; it does not establish a universal stability
threshold, axis recovery, or biological support.

![Component identifiability evidence](identifiability-surface.png)

The red traces identify the uniquely nominated discovery component. Grey traces
retain the remaining search set. The compact surface exposes the reference
spectrum, matching similarity and ambiguity, proposal-rank recurrence,
individual-axis, component-index, and biological-orientation recurrence,
subspace angles, exact failed-replicate fraction, replicate completion, and the
final structured status without using a spectral gap or stability score to
rerank the biological effect. Unmatched axes remain visible as zero
individual-axis recurrence.

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
