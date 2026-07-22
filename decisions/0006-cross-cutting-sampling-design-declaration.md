# 0006 — Sampling-design declaration

**Stage:** cross-cutting / 2
**Status:** accepted
**Date:** 2026-07-12

## Context

The package must support both cross-sectional datasets (for example, *Pogona*
embryo transcriptomes) and longitudinal datasets (for example, repeated AML
mouse blood samples). Sampling design constrains the scientific claims an
estimator may make.

The current `kde_logdensity` strategy pools Stage 1 coordinates and does not
consume subject identity or ordered time. It is therefore a cross-sectional
quasi-potential estimator, even when its input was collected longitudinally.
Treating repeated observations as independent would introduce pseudoreplication.

Sampling design is a fact about a `StateTransitionData` input, not an algorithm
choice. It must survive projection and be recorded in provenance. The package's
container policy forbids treating undocumented `metadata()` entries as versioned
public fields.

## Options considered

| Option | Key property | Disqualifier or concern |
|---|---|---|
| Put a named list in `PipelineConfig` | Small apparent interface | Confuses scientific data design with strategy selection; does not travel with the data object. |
| Store an undocumented list in `metadata()` | No schema change | Violates the declared-container-schema rule; cannot be migrated or reliably validated. |
| Add a versioned `SamplingDesign` declaration to `StateTransitionData` | Data-attached, validated, provenance-ready | Requires a schema migration and a small public interface. |
| Introduce a full `AnalysisPlan` hierarchy | Could express future studies | Premature abstraction: there is no current caller needing recruitment, power, or protocol planning. |

## Criteria

- One short, explicit declaration for end users.
- Subject/time values remain ordinary `colData` columns; the declaration only
  names and interprets them.
- Sampling design is versioned, migratable, validated at boundaries, and
  retained in provenance.
- Each `DynamicsEstimator` declares compatible sampling designs through a
  contract-level capability, not an implementation-name switch.
- Cross-sectional and longitudinal claims cannot be confused silently.

## Evidence

No Stage 0 result selects this interface. The decision follows the package's
container, provenance, and registry invariants. Code inspection confirms that
`kde_logdensity` currently pools coordinate observations without using time or
subject identifiers, so accepting longitudinal input without a declaration
would silently overstate its evidence.

## Decision

**Chosen:** add a versioned `SamplingDesign` declaration to
`StateTransitionData`, exposed through a one-line declaration helper.

Users declare either cross-sectional data or longitudinal data and, for the
latter, supply the names of the subject-ID and ordered-time columns in
`colData`. `PipelineConfig` remains restricted to strategy and parameter
selection. Missing or malformed declarations cause typed failures at the
relevant stage boundary.

The initial `kde_logdensity` strategy supports only cross-sectional analysis.
A longitudinal strategy must be registered separately, have its own ADR, and
use the declared subject/time structure before it may report directional or
timing quantities. Legacy objects migrate to an explicit unspecified state that
Stage 2 rejects until the user declares the design.

**Amendment (2026-07-15): separate dependence from observed time.** The
initial `cross_sectional`/`longitudinal` kind conflates whether biological units
are independent with whether collection time exists. Two concrete callers show
the distinction: Chen endothelial RNA-seq (GSE103672) and *Pogona* developmental
series have independent biological observations at observed times, whereas AML
has repeated observations within mice. `SamplingDesign` v2 therefore records
`dependence = independent | repeated`, an optional observed `time_col`, and a
`subject_id_col` required only for repeated observations. Narrow constructors
represent only current callers: `cross_sectional()`,
`independent_time_course(time)`, and `longitudinal(subject_id, time)`.

Sampling dependence remains orthogonal to target progression semantics. An
independent cohort may support a binary contrast, ordered state, continuous
severity measure, or observed-time target; none is implied merely by declaring
independence. Pseudotime is a derived analysis artifact, not observed collection
time. Existing v1 cross-sectional, longitudinal, and unspecified declarations
migrate without guessing. More complex crossover, nested, dropout, or
repeated-without-time designs remain unsupported until a concrete caller and
separate decision exist.

**Withdrawn amendment (2026-07-13): optional event/censoring declaration.**
The proposal to add event-status and event-time fields was not implemented and
is withdrawn as speculative generality. The current longitudinal contract names
only subject identity and ordered observation time. A last observation is not
universally an event, and one AML study's categorical labels must not define a
general package schema. Event/censoring semantics require a concrete analysis
caller, verified source protocol, and a separate decision when that need exists.

## Consequences

- SamplingDesign v2 requires a schema-version bump and explicit migration from
  every v1 kind before the #55 association strategies are implemented.
- Synthetic constructors can declare their known design automatically; real
  data require one explicit user declaration.
- Cross-sectional Stage 2 output is labelled as distributional
  quasi-potential evidence, not direct temporal evidence.
- A future longitudinal estimator has a clean contract seam without adding a
  second data container or a bespoke dispatcher.

## Review trigger

Revisit when there are two concrete real-data workflows requiring study-level
constraints beyond sampling design, or when a longitudinal estimator is ready
for Stage 0 validation.
