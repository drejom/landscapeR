# Issue #79 publication visual grammar

**Claim status:** implementation proof only. These deterministic synthetic
figures demonstrate the visual API that precedes #79; they do not rank,
confirm, or validate a biological axis.

## Declared binary contrast

![A control and treatment time course using black and focal red](binary-contrast.png)

The caller explicitly declares the reference and focal levels. Factor order
does not decide which group receives the restrained red highlight.

## Repeated biological units

![Nine synthetic mouse trajectories using the categorical palette](categorical-units.png)

The categorical scale remains legible beyond eight levels and does not reuse
the focal red as a claim about biological importance.

## Continuous metadata

![A synthetic component trajectory using the continuous palette](continuous-metadata.png)

Continuous metadata use a perceptually ordered, colour-vision-deficiency-aware
scale. All three figures share the same 100 mm square, minimal publication
grammar with visible axes and ticks.

## Observable contract

| Role | Visual contract |
|---|---|
| Structural marks | Black, white, and grey |
| Declared focal binary level | Restrained red |
| Categorical metadata | Unbounded discrete Viridis scale |
| Continuous metadata | Sequential Viridis scale |
| Missing metadata | Dashed black rug plus explicit caption |
| Default export | 100 mm square at 450 dpi |

## Reproduction

```sh
Rscript scripts/render-issue-79-theme-proof.R
Rscript -e 'devtools::test(filter = "plot-theme")'
```
