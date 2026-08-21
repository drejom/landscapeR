# Public visual palette contract

This guide is the contributor-facing application of ADR 0020's semantic
palette contract (#245). It governs public figures and their captions; it does
not change scientific estimands or stored evidence.

## Default roles

- Ink/black is ordinary structure, labels, axes, and neutral annotation.
- Neutral grey is reference, control, comparison, background, or unavailable.
- Restrained red is reserved for an explicitly declared focal result,
  nominated component, or attention-worthy comparison.
- Signed quantities use a blue–neutral–red diverging scale only when the
  quantity has an intrinsic negative-to-positive direction.

## Permitted data-role exceptions

Genuinely multi-level categorical or molecular-layer variables may use a named
qualitative palette. Ordered non-signed continuous variables may use a named
sequential palette when a gradient is scientifically necessary. In both cases
the legend and scientific caption must state the variable and direction, and a
redundant non-colour channel must remain available where colour alone would
make a consequential distinction.

Do not use red for an arbitrary category, use Viridis as an unexplained
package-wide default, or embed hex values in a renderer. Use
`landscapeR_palette()` and `scale_colour_landscapeR()`/
`scale_fill_landscapeR()` instead.

## Adding a plotting module

1. Identify the plotted variable's semantic role before choosing a scale.
2. Use the canonical package palette or record a named exception in the
   module's caption and documentation.
3. Make the legend and `scientific_caption()` describe the same colour and
   non-colour encodings.
4. Add a contract test for every mandatory mapping and inspect native and
   reduced proof renders before opening the PR.

The existing family-by-family classification is the review baseline at
`.github/landing-proof/issue-245/palette-classification.tsv`. A classification
of intentional exception is not a failure; it means the data role is explicit
and the exception remains bounded.
