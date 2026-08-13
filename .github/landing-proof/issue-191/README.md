# Issue #191 visual landing proof

`high-dimensional-operating-map.png` is the public
`plot_k1_high_dimensional_calibration()` surface for five governed signal and
noise regimes. Panel A reports recovery of the planted feature-loading
direction. Panel B reports its recurrence when independent biological
observations are resampled within target group.

The horizontal coordinate is effective planted signal divided by the disclosed
covariance-adjusted noise reference. The pale vertical line marks a ratio of one.
Black line types distinguish total feature counts; outlined points are exact cell
summaries. Rows deliberately distinguish increasing noise dimensionality from
growing coherent biological information. The former can leave a fixed spike
submerged as the number of noise features increases, whereas the latter can
cross the noise reference because added features carry aligned information.

The exact displayed evidence is in `high-dimensional-operating-map.csv`.
`high-dimensional-cell-summary.csv` additionally retains component nomination
and downstream estimability. The publication caption is separate in
`high-dimensional-operating-map-caption.txt`. This is disclosed synthetic
calibration evidence, not an acceptance result or a universal sample-size
recommendation. Reproduce it with `scripts/render-issue-191-proof.R`.
