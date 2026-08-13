# Issue #190 visual landing proof

`repeated-subject-operating-map.png` is the public
`plot_k1_repeated_subject_calibration()` surface for four governed longitudinal
sampling templates. Panel A reports recovery of the planted feature-space
target. Panel B reports recurrence of the nominated axis when complete mice are
resampled within condition. Panel C reports whether the declared
random-intercept-plus-slope condition-by-time model remains estimable after
target recovery.

The templates begin with four CTL and four CM mice intended at times 0, 1, 2,
and 3. They then retain all observations, remove one internal visit, remove the
last two visits from one disease mouse, or remove the last two visits from two
disease mice. The exact removals remain attached to mouse identity, condition,
and observed time. No missing visit is imputed, balanced away, or treated as an
independent animal.

Crosses are typed scientific non-estimability, not zero-valued evidence. The
strict model does not fall back to random-intercept-only or observation-level
independence when a random slope is not identifiable. One named task carries a
declared scheduler interruption in the assessment's execution provenance. It
is excluded from scientific denominators and appears as a hollow triangle at
the left margin, separately from scientific non-estimability.

The exact displayed evidence is in `repeated-subject-operating-map.csv`. The
publication caption is separate in
`repeated-subject-operating-map-caption.txt`. This is disclosed synthetic
calibration evidence, not an acceptance result or a universal sample-size
recommendation. Reproduce it with `scripts/render-issue-190-proof.R`.
