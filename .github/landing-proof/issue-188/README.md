# Issue #188 visual landing proof

`typed-calibration-outcomes.png` renders the public
`plot_k1_calibration_outcomes()` surface. Each point is one requested synthetic
replicate. Shape separates recovery of the planted axis from availability of
downstream interpretation, so a model abstention cannot be mistaken for a
decomposition failure. The black-and-white display remains legible without
colour and the scientific caption is stored separately in
`typed-calibration-outcomes-caption.txt`.

The proof fixture deliberately includes all four typed outcomes. Its exact
plot data are in `typed-calibration-outcomes.csv`. Reproduce the proof by
loading the development package, sourcing
`tests/testthat/test-k1-calibration-outcomes.R`, creating
`calibration_outcome_fixture()`, and passing its assessment to
`plot_k1_calibration_outcomes()`.

Cold-reader conclusion: the four outcomes remain visibly distinct. In
particular, an open circle means the planted axis was recovered but a required
downstream model or stability result was unavailable; an x means the planted
axis itself was not recovered.
