# Issue #226 adversarial visual review

This review was performed against the retained native 100 mm PNGs and the
reduced contact sheet. It used the governing objective of scientific accuracy
and usefulness through a coherent visual language that elevates scientific
interpretation. Tufte and Wilke are supporting criteria, not substitutes for
checking the estimand, uncertainty, evidence, or claim boundary.

## Findings

- **P1, #232:** long tile subtitles collide across contact-sheet boundaries at
  reduced reading size. The sheet is an audit surface, so the full captions
  remain separate while tile-local text is queued for repair.
- **P1, #227:** independent-time-course interaction intervals are clipped in
  the native 100 mm figure.
- **P1, #229:** identifiability comparison markers and Stage 2 critical-point
  annotations can occlude one another or the landscape evidence.
- **P1, #230:** several Stage 1/Stage 2 rugs rely on thin colour-only marks that
  weaken at reduced size and under colour-vision deficiency.
- **P2, #231:** two captions describe encodings not rendered by their figures:
  cross-sectional fits and the colour of the abstention reason. The operating-
  domain caption also needs public wording correction: a design identifier is
  not a biological analysis unit, and the current sentence is malformed.
- **P2, #233:** the abstention empty state and shared layout tokens need a
  consistency pass after the higher-severity issues are addressed.
- **P2, #228:** valid continuous component plots emit an unknown fill-scale
  warning during regeneration.
- **Pre-existing, #220:** independent-time-course facets do not yet have the
  visible A/B labels required by the publication policy.

These are recorded in `audit-findings.tsv` and are deliberately not hidden by
changing plotting code in the contact-sheet audit itself. Native figures and
their separate captions are retained so each follow-up can be reproduced.

## Review framework

- Wilke, *Fundamentals of Data Visualization*, introduction:
  https://clauswilke.com/dataviz/introduction.html
- Wilke, aesthetic mapping:
  https://clauswilke.com/dataviz/aesthetic-mapping.html
- Wilke, multi-panel figures:
  https://clauswilke.com/dataviz/multi-panel-figures.html
- Wilke, redundant coding:
  https://clauswilke.com/dataviz/redundant-coding.html
- Wilke, colour pitfalls:
  https://clauswilke.com/dataviz/color-pitfalls.html
- Tufte, *The Visual Display of Quantitative Information*:
  https://www.edwardtufte.com/book/the-visual-display-of-quantitative-information/
