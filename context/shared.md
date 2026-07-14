# Shared infrastructure

The plumbing every stage depends on: the container that flows through the pipeline, the registry that dispatches to strategies, the provenance system that records how artifacts were made, and the boundary validation that enforces contracts at every stage entry.

## Language

**StateTransitionData**:
The single S4 container (a `MultiAssayExperiment` subclass) that flows between all stages. Every stage receives one and returns one. The only versioned data structure in the pipeline.
_Avoid_: data object, result container, MAE wrapper

**schema version**:
The `SCHEMA_VERSION` constant declaring the current `StateTransitionData` serialisation format. Every schema change requires a bumped version and a registered migration for every prior version.
_Avoid_: data version, format version

**migration**:
A registered function that transforms a `StateTransitionData` at an old schema version into one at the current version. Required for every schema version increment.
_Avoid_: upgrade, conversion

**contract**:
An S4 `VIRTUAL` class defining the interface (input type, output type, generics) that every concrete strategy for a stage must implement. The contract is the only stable API surface — implementations are hidden behind it.
_Avoid_: interface (acceptable synonym in explanation, but prefer contract in code names), abstract class

**strategy**:
A concrete implementation of a stage contract, registered under a named key and selected via `PipelineConfig`. Never referenced directly by orchestration code.
_Avoid_: algorithm, method, backend, implementation

**registry**:
The in-memory store (`.registry`) mapping strategy names to strategy objects. The only place dispatch decisions are made at runtime. Populated by `register_strategy()`, queried by `get_strategy()`.
_Avoid_: dispatcher, factory, switch statement

**PipelineConfig**:
The configuration object that selects which strategy to use for each stage. Algorithm choices are expressed here and nowhere else.
_Avoid_: settings, options, parameters (too generic)

**StageResult**:
A typed wrapper around a stage's return value, carrying success/failure status, the output value, and a provenance step. Never a raw list or a thrown exception.
_Avoid_: result, output, return value

**descriptive evidence layer**:
The minimally interpreted analysis output needed to assess a claim: component coordinates and distributions, eligible metadata associations, empirical densities, individual benchmark metrics, and exclusions. It does not mean unrestricted publication of raw source or subject-level data; privacy and data-use constraints still apply.
_Avoid_: raw data layer (confuses analysis outputs with source data)

**hypothesis-conditioned interpretation layer**:
The declarations, models, selections, fitted structures, biological labels, and aggregate judgements imposed after descriptive evidence is available. It always references and remains visible beside its descriptive precursor. Predeclared and discovered declarations are distinguished.
_Avoid_: results layer, final answer

**observation before interpretation**:
The cross-cutting rule that every interpretive artifact retains a route to its descriptive evidence and never overwrites or hides it (ADR 0017). Raw and adjusted associations, empirical and fitted distributions, and individual metrics and aggregate judgements remain separately inspectable.

**provenance**:
The deterministic machine-readable recipe for how an artifact was produced — strategy, parameters, pre-stage input digest, schema version, and RNG seed. Stored in `StateTransitionData@provenance` as `ProvenanceStep` objects. First-class: every stage records it, and equal input/configuration/seed yields equal provenance.
_Avoid_: audit trail, lineage, history

**ProvenanceStep**:
A single deterministic entry in the provenance record, created by `record_provenance()`, persisted on `StateTransitionData`, and emitted by `StageResult`. Contains stage name, strategy key, parameter snapshot, and pre-stage input digest; it does not contain volatile execution time.
_Avoid_: log entry, record

**execution telemetry**:
Volatile observations about a particular execution, such as elapsed wall-clock time, host, or start time. Useful for profiling and benchmark artifacts, but never stored in the deterministic returned `StateTransitionData` provenance chain.

**boundary validation**:
The check run at every stage entry via `validate_boundary()` that verifies the incoming `StateTransitionData` satisfies the stage's typed preconditions. Returns a typed failure — never throws a raw exception.
_Avoid_: input validation, guard, precondition check

**RNG seed**:
The reproducibility anchor set by `setup_rng()` using L'Ecuyer-CMRG (compatible with parallel execution). Every stage function that uses randomness must accept a seed and call `setup_rng()`.
_Avoid_: random seed, set.seed (the base R function — prefer the landscapeR wrapper)
