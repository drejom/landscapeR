# 0003 — Reference implementation: Rockne-Frankhouser state-transition code

**Stage:** cross-cutting
**Status:** proposed
**Date:** 2026-06-27

## Context

The Rockne-Frankhouser Cancer Research 2020 paper ("State-Transition Analysis of
Time-Sequential Gene Expression Identifies Critical Points That Predict Development
of Acute Myeloid Leukemia") is the primary prior work for the Stage 2 dynamics
approach. Code exists in the City of Hope / Mathon Institute GitHub org.

This code is not a package — it is analysis scripts. It is the reference
implementation of the quasi-potential / critical-point approach on real omic data,
and the thing landscapeR is generalising and formalising.

## Purpose of this ADR

Track what we extract from the reference code and how it informs landscapeR decisions.
The reference code is a source of:
- The concrete algorithm for Stage 2 (what did they actually compute?)
- Practical decisions about coordinate systems, normalisation, and bandwidth choices
- Failure modes and workarounds discovered empirically
- What "critical point" meant operationally in their implementation

It is NOT a source of architecture — landscapeR deliberately imposes the
contract/registry/provenance structure that the reference code lacks.

## Action items

- [ ] Locate exact GitHub repo URL (City of Hope / Mathon org — user to confirm)
- [ ] Read the Stage 2 computation: how is U(x) estimated? What estimator?
- [ ] Note any hard-coded assumptions (dimensionality, normalisation, bandwidth)
- [ ] Record findings in the Evidence section of ADR 0002 before deciding on estimator

## Consequences

The reference code review is a prerequisite for closing ADR 0002.
