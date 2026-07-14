## Summary

<!-- What does this PR do? Link the originating issue. -->

## Visual landing proof

<!-- Select exactly one. Every PR must make this decision explicitly. -->

- [ ] Proof required
- [ ] Exempt

### Required proof packet

<!-- Complete when "Proof required" is selected. Do not use generic N/A. -->

**Proof type:** <!-- before-after | new-capability | representative-output -->

**Before:** <!-- Old rendered behavior, or the absence/limitation before this capability. -->

**After or representative output:** <!-- Embed/link the figure, table, or workflow render. -->

**Cold-reader conclusion:** <!-- What should someone who has not read the code conclude? -->

**Reproduction:** <!-- Exact command or procedure that regenerates the proof. -->

**Claim status:** <!-- implementation proof | exploratory | calibration-only | accepted evidence, etc. -->

**Artifact:** <!-- Point to the Markdown image, table, or fenced rendered output in Visual review. -->

### Current documentation

<!-- Select exactly one when proof is required. -->

- [ ] Updated
- [ ] Unaffected

**Documentation reference or rationale:** <!-- Link/anchor, or explain substantively why current docs are unaffected. -->

### Exemption

<!-- Complete only when "Exempt" is selected. -->

**Exemption category:** <!-- internal-only | research/decision-only -->

**Exemption rationale:** <!-- Explain why there is no public, scientific, data, plotting, or developer-workflow surface. -->

## Visual review

<!-- For required proof, record one sentence per figure/table/render after inspecting the rendered output. -->

<!-- Add one bullet per reviewed figure, table, or workflow render. -->

## Checklist

- [ ] `devtools::test()` passes locally
- [ ] `R CMD check --no-manual` produces no new warnings
- [ ] PR-policy checker tests pass
- [ ] `pkgdown::build_site()` passes when current documentation changed
- [ ] Every acceptance-threshold figure has a labelled threshold line
- [ ] Figure axes and labels are human-readable
- [ ] Scientific captions state what is plotted, what any threshold means, and what the reader should conclude
- [ ] ADR filed or amended for any non-trivial algorithm, dependency, or cross-cutting decision
