# Issue #226 public-facing visual audit

Generated from the current package source; source-file digests are recorded
in public-plot-inventory.tsv.
Tile-local labels and their bounded text budget are recorded in
public-plot-contact-sheet-labels.tsv.

The contact sheet is an audit surface, not a scientific result. Included
figures are rendered by current package plotting functions from deterministic
synthetic fixtures. Individual figures and captions are retained beside the
sheet; the inventory records source-file digests and explicit exclusions.
This is an audit gate, not a claim that every figure is publication-ready. The
adversarial findings and queued follow-up issues are recorded in audit-findings.tsv.

Review the native and reduced contact sheets. The checker enforces dimensions
and the tile-label text budget; direct visual inspection remains mandatory.
Tile-local labels are concise and isolated; full scientific captions remain in
the inventory and separate files. Record inconsistent visual grammar, clipped
labels, unreadable
legends, caption mismatch, or public-language leaks as follow-up issues
rather than silently changing them.

Regenerate with:

Rscript scripts/render-issue-226-contact-sheet.R
