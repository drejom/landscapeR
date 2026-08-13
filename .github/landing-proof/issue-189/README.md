# Issue #189 visual landing proof

`destructive-time-course-operating-map.png` is the public
`plot_k1_independent_time_course_calibration()` surface for six declared
independent destructive-sampling templates. The upper panel reports recovery of
the planted feature-space target. The lower panel reports whether the declared
condition-by-time estimand was supported after recovery. Crosses are typed
abstentions, not zero recovery.

The proof deliberately includes one animal per condition-time cell, a sparse
but complete three-animal design, one failed sequencing library, and one absent
internal condition-time cell. The failed library remains a removal from an
intended three-animal design; it is not relabelled as a balanced design.

The exact displayed evidence is in
`destructive-time-course-operating-map.csv`. The publication caption is
separate in `destructive-time-course-operating-map-caption.txt`. This is
disclosed synthetic calibration evidence, not an acceptance result or a
universal sample-size recommendation. Reproduce it with
`scripts/render-issue-189-proof.R`.
