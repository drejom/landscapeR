# Issue 117 strategy-author proof

## Author workflow

```mermaid
flowchart LR
    A[Register adapter] --> B[Validate declared contract]
    B --> C[Prepare biological cohort]
    C --> D[Fit one component]
    D --> E[Refit through shared future execution]
    E --> F[Normalize evidence once]
    F --> G[Atlas, proposal, or typed abstention]
```

A method author supplies the first four scientific decisions. landscapeR owns
execution, accounting, normalized storage, provenance and public result
construction. The conformance fixture adds a novel target adapter without
editing `associate_metadata()` or a design dispatcher.

## Compatibility surface

| Sampling design | Strategy resolution | Cohort/refit unit | Public result retained | Verification |
|---|---|---|---|---|
| Cross-sectional | registry plus validated contract | available biological observations | `MetadataAssociationAtlas`, proposal and typed abstention | component interpretation and author-conformance suites |
| Independent destructive time course | registry plus validated contract | condition-by-time observations | `MetadataAssociationAtlas`, proposal and typed abstention | independent time-course and boundary suites |
| Repeated-subject time course | registry plus validated contract | complete subject trajectories | `MetadataAssociationAtlas`, proposal and typed abstention | repeated time-course suite |

The existing estimands, multiplicity, exchangeability, orientation, rankings,
permutation formulas and public result classes are unchanged. Strategy contract
facts are added to provenance, and all three designs now cross the same
normalized evidence constructor. This is architecture and compatibility proof;
it does not accept a new estimator or scientific threshold.

## Reproduction

```r
devtools::test(filter = paste(
  "association-strategy-authoring|component-interpretation|",
  "independent-time-course|repeated-time-course",
  sep = ""
))
```
