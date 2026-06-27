# 0004 — Package identity: eigentime extension vs companion package

**Stage:** cross-cutting
**Status:** proposed
**Date:** 2026-06-27

## Context

Design spec §0 flags this as the open decision to resolve before first commit
(now past — scaffolding exists in landscapeR). The question: does landscapeR
*own* the decomposition + dynamics engine, or does it depend on a separate
`eigentime` package for that?

## Current state

`eigentime` does not exist as a public package. The Rockne-Frankhouser code
(ADR 0003) is analysis scripts, not a package. There is no published implementation
to depend on.

## Options

| Option | What it means | Risk |
|---|---|---|
| landscapeR owns everything | Stages 0–2 all live here; no eigentime dependency | More scope; no waiting on another package |
| companion: landscapeR depends on eigentime | eigentime must be built first and stabilised; landscapeR wraps it | Blocks landscapeR Stage 1-2 implementation until eigentime exists |
| Ship eigentime as a sub-package / internal | Stages 1-2 code lives in a subdirectory with intent to spin out later | Cleanest long-term but most up-front cost |

## Decision

**Provisional: landscapeR owns everything until eigentime exists.**

The `Decomposer` and `DynamicsEstimator` contracts are already defined. If eigentime
is built later, a thin adapter implementing those contracts can wrap it — the registry
handles the swap with zero change to the pipeline. The contract *is* the interface;
the package boundary is an organisational question, not an architectural one.

**Status: accepted** — this unblocks implementation without prejudicing the future.

## Review trigger

Revisit if eigentime is published as a stable package with a maintained API.
At that point, wrapping it behind the existing contracts is low-risk and may
reduce duplication.
