# Proposed specification — Stage 1 candidate comparison

**Status:** proposed protocol for ADRs 0001 and 0009

## Candidates

1. **Symmetric sample-score consensus**: for each centred layer
   `X_i` (samples × layer-specific features), compute a thin SVD and align its
   sample-score subspace to an iteratively updated consensus. No omic layer is
   a privileged reference.
2. **Block-scaled SVD baseline**: feature-block-scale each layer, concatenate
   blocks, and SVD matched samples.

Both preserve per-layer feature loadings and use the same complete-paired cohort,
sample map, and feature-ID-safe projection convention.

## Alignment and weighting

Evaluation uses subspace/projector metrics and is sign/rotation invariant.
Displayed axes receive a deterministic non-biological sign convention.

Equal post-preprocessing layer influence is the default. Reliability weighting
is a separate candidate and must be estimated from discovery data only; raw
feature count, sequencing depth, and singular value must not silently weight a
layer.

## Result and projection convention

A candidate returns shared sample coordinates, named per-layer loading matrices,
per-layer reconstructed response profiles, fitted feature means/scales, canonical
sample IDs, feature IDs, weights, and exclusions. Projection matches feature IDs
one-to-one and applies discovery preprocessing; it never independently recentres
a confirmation cohort.

## Synthetic truth and metrics

Generate heterogeneous layers with planted shared sample subspace, per-layer
feature loadings, layer-exclusive signal, and layer-specific noise. Predeclare:

- shared sample-subspace recovery;
- per-layer response recovery and exclusive-signal leakage;
- per-layer loading/projection recovery;
- held-out projection recovery;
- typed-failure, elapsed-time, and memory behaviour.

The ladder varies sample size, number of layers, heterogeneous feature counts,
signal/noise, confounder strength, rank deficiency, sample/feature permutations,
and projection mismatch cases.

## Selection rule

A candidate must first satisfy all contract gates: sample-map alignment,
heterogeneous features, complete-case fitting, fixed discovery preprocessing,
feature-ID-safe projection, and no truth/label leakage. Compare candidates on
paired seeds. Promote a default only when predeclared shared-recovery and timing
criteria are met with a confidence interval excluding no advantage; otherwise
retain the block baseline and reopen ADR 0001 with frozen evidence.
