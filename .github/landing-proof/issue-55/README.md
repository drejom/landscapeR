# Issue #55 decision-gate landing proof — expert consultation

## Proof classification

Required: this change introduces a reviewer-facing scientific consultation and changes how proposed statistical decisions are presented to external experts.

## Before

[`before-internal-review.png`](before-internal-review.png) shows the first draft. It begins with project-internal language and assumes prior knowledge of the component-interpretation workflow. The respondent is asked to assess decisions before being told what `landscapeR` does or why coordinate interpretation is scientifically difficult.

## After

[`after-scientific-consultation.png`](after-scientific-consultation.png) shows the published revision at <https://tally.so/r/NpQ2g0>. It now:

- introduces `landscapeR` and the outcome-blind decomposition problem;
- states that no code or repository review is expected;
- uses a synthetic two-state quasi-potential as a concrete orientation example;
- frames all six prompts as scientific choices rather than package decisions;
- asks directly for assumptions, failure modes, diagnostics, and alternatives;
- removes ADR, issue, lifecycle, and package-internal terminology from the reviewer surface; and
- states that responses are private, will not be published or quoted, and that disagreement is preserved internally.

## Cold-reader conclusion

A mathematically expert reviewer encountering the project for the first time can understand the intended method, the coordinate-selection problem, the limited scope of the consultation, and the kind of criticism requested without reading the repository or knowing the project's prior discussions.
