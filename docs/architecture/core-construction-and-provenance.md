# Core construction and provenance

## Supported construction boundaries

Use `StateTransitionData()` for the inter-stage data container and
`PipelineConfig()` for one declared analysis run. Direct `new()` calls remain
an S4 implementation detail and are not the contributor-facing interface.

`StateTransitionData()` and coercion from `MultiAssayExperiment` obtain schema
version, provenance, ground-truth and sampling-design defaults from one
internal authority. The default sampling design remains `unspecified`; a user
must declare the biological sampling unit before a design-sensitive stage can
run.

## Stage results

Stage values remain stored in `S4Vectors::metadata()` for schema compatibility,
but package code reads them through `stage_result()` and
`has_stage_result()`. These functions distinguish an absent stage from an
invalid stored value and enforce the `DecompositionResult` type at the Stage 1
boundary. New modules must not index `metadata(data)$stage1` or
`metadata(data)$stage2` directly.

## Provenance hashes

`record_provenance()` requires every scientific caller to supply a named
`input_hashes` vector. The recorder cannot infer the scientific input boundary:
hashing the whole container would also hash its growing audit history and make
equivalent scientific inputs appear different. Names should identify the
scientific object being hashed, such as `expression_matrix`, `stage1_result`,
or `simulation_specification`.

## Random-number identity

Ambient `.Random.seed` state is not a usable replay contract and is no longer
recorded. The legacy `ProvenanceStep@rng_seed` slot is retained empty for
schema compatibility. A stochastic caller supplies `rng` as a named identity
containing the declared run seed and, where applicable, RNG kind,
seed-derivation scheme, and stable task or stream identity. Repeated work uses
the future-backed deterministic stream machinery documented in
[`execution-reproducibility.md`](../agents/execution-reproducibility.md).

This records how to reproduce a draw without treating unrelated session state
as scientific provenance.

## Contributor checklist

1. Construct configs and containers through their exported constructors.
2. Read stored stages through the typed stage helpers.
3. Define and name the scientific inputs before hashing them.
4. Record a declared seed or stream identity for stochastic work.
5. Test every new S4 validity branch directly, in addition to exercising it
   through a workflow.
