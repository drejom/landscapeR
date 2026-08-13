# Issue #188 visual landing proof

`typed-calibration-outcomes.png` renders the public
`plot_k1_calibration_outcomes()` surface as a two-panel component-plane
comparison. Red arrows mark the planted biological direction and black arrows
reconstruct angular disagreement from absolute loading cosine. Their upward
orientation is illustrative; the plane is a schematic rather than observed
sample coordinates. Panel A shows successful geometric recovery with downstream
interpretation not estimable; panel B shows cosine agreement below the recovery
threshold. This keeps landscapeR's component-space visual language and does not
invent symbols for internal evidence states. The scientific caption is stored separately in
`typed-calibration-outcomes-caption.txt`.

The complete five-state evidence remains in the typed assessment and table;
execution failures and non-evaluable recovery do not have meaningful geometry
and are therefore not drawn as arrows. Exact arrow endpoints are in
`typed-calibration-outcomes.csv`. Reproduce the proof by loading the development
package, sourcing
`tests/testthat/test-k1-calibration-outcomes.R`, creating
`calibration_outcome_fixture()`, and passing its assessment to
`plot_k1_calibration_outcomes()` with the disclosed task IDs `outcome-1` and
`outcome-3`.

Cold-reader conclusion: recovering the planted direction and obtaining an
estimable downstream interpretation are separate decisions. Panel A recovers
the axis even though interpretation is not estimable; panel B does not meet the
axis-recovery threshold, so downstream interpretation is not attempted.
