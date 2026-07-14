# Issue #68 checker before/after proof

`checker-before-after.txt` records the same public behavior change against a
one-file `R/` diff and a PR body with no landing-proof declaration:

- the base checker exits 0 because no vignette changed;
- the new checker exits 1 because every PR must classify its visual landing
  proof.

Reproduce by checking the base script out from `ad77a2a`, creating a temporary
Git repository with a `main` commit and an `R/` change on a feature branch, and
running both checker versions against a PR body containing only `## Summary`.

The CLI contract tests additionally cover artifact presence, required current
documentation, obvious qualifying surfaces, exemptions, malformed templates,
placeholder bypasses, and unavailable comparison refs.
