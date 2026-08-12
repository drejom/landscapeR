# Issue #188 visual landing proof

`typed-calibration-outcomes.png` renders the public
`plot_k1_calibration_outcomes()` surface at the package's canonical 100 mm
figure size. Each point is one requested synthetic
replicate. Shape separates recovery of the planted axis from availability of
downstream interpretation, so a model abstention cannot be mistaken for a
decomposition failure. The black-and-white display remains legible without
colour and the scientific caption is stored separately in
`typed-calibration-outcomes-caption.txt`.

The proof fixture deliberately includes the four required outcomes plus a
completed replicate whose recovery evidence is not evaluable. Its exact
plot data are in `typed-calibration-outcomes.csv`. Reproduce the proof by
loading the development package, sourcing
`tests/testthat/test-k1-calibration-outcomes.R`, creating
`calibration_outcome_fixture()`, and passing its assessment to
`plot_k1_calibration_outcomes()`.

Cold-reader conclusion: all five outcomes remain visibly distinct. A filled
circle means recovered and estimable; an open circle means recovered but a
required downstream result was unavailable; an x means the planted axis was
evaluated but not recovered; an open square means recovery itself could not be
evaluated; and a plus means execution failed.
