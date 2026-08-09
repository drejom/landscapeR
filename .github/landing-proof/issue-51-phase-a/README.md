# Issue #51 phase-A landing proof

This packet demonstrates that the independent K=1 Stage 0 acceptance protocol
is frozen and inspectable before any acceptance replicate is executed.

The protocol contains the complete generic double-well thinness grid,
pure-noise and single-well negative controls, synchronized AML control,
control-specific thresholds, aggregate pass rules, biological-unit resampling
requirements, and a deterministic delayed seed-derivation rule. Its public
object validates only
when every field and its SHA-256 digest match the frozen definition.

The companion files are:

- `protocol-summary.tsv`, a cold-reader summary of the frozen gates;
- the public `k1_acceptance_protocol()` object, which contains the complete
  frozen definition and embedded provenance.

Run `Rscript scripts/render-issue-51-phase-a-proof.R` to reproduce them.

## Claim boundary

This is protocol-definition proof only. Phase A exposes no acceptance executor,
reveals or consumes no acceptance seed, reports no pass rate, and establishes no supported
sample range. Independent execution and immutable content-addressed evidence
belong to the later #51/#67 phases.
