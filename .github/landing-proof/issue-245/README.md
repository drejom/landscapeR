# Issue #245 semantic palette proof

This packet classifies every included public family in the immutable
issue-226 inventory against ADR 0020's semantic palette contract.
It does not recolour figures or change scientific evidence.

`compliant` means the existing renderer already uses canonical semantic
roles. `intentional-exception` means a named data-role scale is permitted
and already has the required legend, caption, and redundant encoding.
`follow-up` records a real public-family gap: the current figure is
unchanged in this contract-only PR, but its consequential distinction
still needs a non-colour encoding in a subsequent visual issue. The
follow-up text in the TSV states the missing encoding for each family.

Regenerate with `Rscript scripts/render-issue-245-proof.R`.
