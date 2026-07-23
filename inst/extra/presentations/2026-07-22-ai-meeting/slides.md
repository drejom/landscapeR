---
theme: default
layout: cover
title: landscapeR | Mapping biological state transitions
colorSchema: dark
fonts:
  sans: Inter
  mono: Fira Code
themeConfig:
  primary: '#45c7d8'
---

<div class="title-kicker">AN R PACKAGE IN DEVELOPMENT</div>

# landscapeR

## Mapping biological state transitions from molecular data

<div class="title-example"><em>Pogona</em> sex development as one example</div>
<div class="title-meta">Denis O'Meally<br>City of Hope<br>22 July 2026</div>

<!--
About 40 seconds. Introduce landscapeR as a general package for mapping biological state transitions from high-dimensional molecular data. Pogona is the motivating developmental example, not the sole intended application.
-->

---

# Study design sets the interpretation

<div class="design-grid">
<div class="design-item cyan">
<svg viewBox="0 0 260 118" role="img" aria-label="Independent embryos sampled across developmental stages">
  <g class="sample"><circle cx="42" cy="45" r="7"/><circle cx="42" cy="63" r="7"/><circle cx="91" cy="39" r="7"/><circle cx="91" cy="57" r="7"/><circle cx="91" cy="75" r="7"/><circle cx="145" cy="36" r="7"/><circle cx="145" cy="56" r="7"/><circle cx="145" cy="76" r="7"/></g>
  <g class="branch-a"><circle cx="201" cy="32" r="7"/><circle cx="221" cy="32" r="7"/></g><g class="branch-b"><circle cx="201" cy="72" r="7"/><circle cx="221" cy="72" r="7"/></g>
  <text x="24" y="17">independent cohorts</text><text x="182" y="21">later states</text>
  <path d="M45 106 C96 94 158 114 222 100 M216 96 L224 100 L217 106" class="time-arrow"/><text x="8" y="108">Time</text>
</svg>
<h2><em>Pogona</em></h2><strong>Developmental divergence</strong><p>Independent embryos sampled at observed stages</p><small>Group structure, not tracked embryo paths</small>
</div>
<div class="design-item blue">
<svg viewBox="0 0 260 118" role="img" aria-label="Repeated measurements within subjects">
  <path d="M45 26 C96 17 151 30 216 18 M45 54 C97 66 151 43 216 55 M45 82 C101 73 154 89 216 76" class="subject-line"/>
  <g class="sample"><circle cx="45" cy="26" r="7"/><circle cx="128" cy="24" r="7"/><circle cx="216" cy="18" r="7"/><circle cx="45" cy="54" r="7"/><circle cx="128" cy="52" r="7"/><circle cx="216" cy="55" r="7"/><circle cx="45" cy="82" r="7"/><circle cx="128" cy="80" r="7"/><circle cx="216" cy="76" r="7"/></g>
  <text x="8" y="30">1</text><text x="8" y="58">2</text><text x="8" y="86">3</text>
  <path d="M45 106 C96 94 158 114 222 100 M216 96 L224 100 L217 106" class="time-arrow"/><text x="8" y="108">Time</text>
</svg>
<h2>AML</h2><strong>Disease progression</strong><p>Repeated measurements within mice across time</p><small>Subject-aware trajectories</small>
</div>
<div class="design-item amber">
<svg viewBox="0 0 260 118" role="img" aria-label="Independent donors sampled across ordered clinical states">
  <g class="sample"><circle cx="46" cy="46" r="7"/><circle cx="46" cy="66" r="7"/><circle cx="112" cy="40" r="7"/><circle cx="112" cy="60" r="7"/><circle cx="112" cy="80" r="7"/><circle cx="190" cy="46" r="7"/><circle cx="190" cy="66" r="7"/></g>
  <text x="25" y="18">state 1</text><text x="93" y="18">state 2</text><text x="171" y="18">state 3</text>
  <path d="M45 106 C96 94 158 114 222 100 M216 96 L224 100 L217 106" class="time-arrow"/><text x="8" y="108">Time</text>
</svg>
<h2>Type 1 diabetes</h2><strong>Ordered clinical states</strong><p>Independent donors sampled across declared states</p><small>Cross-sectional progression structure</small>
</div>
</div>
<div class="bottom">The independent sampling unit, observed time and repeated structure remain explicit.</div>

<!--
About 70 seconds. Contrast three familiar designs. Pogona has destructive sampling of independent embryos across observed developmental stages. The AML work follows the same subjects through time. Type 1 diabetes samples independent donors across ordered clinical states. Emphasize that these designs support different claims and resampling schemes.
-->

---

<span class="status implemented">LANDSCAPER SYNTHETIC CONTROL</span>
# Molecular data define the coordinate system

<div class="science-split">
<div class="matrix-side">
  <div class="matrix-glyph"><span>genes</span><div class="heat-grid">● ● ● ● ● ●<br>● ● ● ● ● ●<br>● ● ● ● ● ●<br>● ● ● ● ● ●<br>● ● ● ● ● ●</div><i>samples</i></div>
  <div class="plain-arrow">→</div>
  <div class="step-copy"><b>Outcome-blind decomposition</b><p>Sex, stage and temperature are not used to fit the axes.</p><small>Known-truth branching control, about four independent animals per visible cluster and 240 features</small></div>
</div>
<div class="plot-frame"><img src="./assets/branching-state-space-unlabelled.png" alt="Recovered two-dimensional coordinate system from landscapeR synthetic branching data"></div>
</div>

<!--
About 65 seconds. This is an executable landscapeR synthetic control, not a drawing. The generator creates independent samples at five stages, embeds a two-dimensional branching structure in 240 expression features, and the registered SVD recovers a low-dimensional coordinate system. Labels were withheld while fitting the axes.
-->

---

<span class="status implemented">SAME SYNTHETIC CONTROL</span>
# Sample density defines a descriptive landscape

<div class="science-split potential-slide">
<div class="equation-side">
  <div class="equation">U(x) = -log p(x)</div>
  <p>Dense regions correspond to frequently observed states.</p>
  <p>Sparse regions correspond to higher terrain between them.</p>
  <div class="caveat">This describes sample occupancy. It is not physical energy and it does not establish a developmental path.</div>
</div>
<div class="plot-frame"><img src="./assets/branching-density.png" alt="Density contours estimated from recovered landscapeR synthetic coordinates"></div>
</div>
<div class="citation">Rockne et al. 2020, <em>Cancer Res.</em> &nbsp; Frankhouser et al. 2024, <em>Leukemia</em></div>

<!--
About 65 seconds. Explain the equation in plain language. Density becomes height after applying minus log. Frequently occupied states are low; sparse regions are high. State the caveat clearly: destructive cross-sectional samples do not demonstrate that an embryo moved along a plotted route.
-->

---

<span class="status implemented">SAME SYNTHETIC CONTROL</span>
# Metadata gives the geometry biological meaning

<div class="science-split">
<div class="metadata-side">
  <div><span class="meta-dot stage"></span><strong>Observed stage</strong><p>Orders independent cohorts in developmental time.</p></div>
  <div><span class="meta-dot sex"></span><strong>Terminal state</strong><p>Interprets the later divergence after the axes are fitted.</p></div>
  <div><span class="meta-dot temp"></span><strong>Temperature and genotype</strong><p>Remain separate variables for later comparison.</p></div>
  <div class="caveat">The lines summarize group means. They are not embryo trajectories.</div>
</div>
<div class="plot-frame"><img src="./assets/branching-state-space.png" alt="Recovered developmental branching coordinates coloured by stage and terminal state"></div>
</div>

<!--
About 60 seconds. Add observed stage and terminal state after decomposition. Stage orders the cohorts. Terminal state interprets the late split. Temperature and genotype remain explicit variables. The lines are summaries of group means, not tracked trajectories.
-->

---

<span class="status implemented">LOADINGS FROM THE SAME SVD</span>
# Loadings connect coordinates to genes and pathways

<div class="loadings-layout">
<div class="plot-frame"><img src="./assets/branching-loadings.png" alt="Ranked feature loadings on the recovered divergence coordinate"></div>
<div class="interpret-side">
  <div class="interpret-chain">
    <div><svg class="concept-icon landscape-icon" viewBox="0 0 56 44" aria-hidden="true"><path d="M3 34 C12 23 19 42 28 28 C37 14 45 32 53 17 M3 25 C12 14 19 33 28 19 C37 5 45 23 53 8 M8 38 L8 22 M18 39 L18 18 M28 34 L28 14 M38 30 L38 10 M48 25 L48 6"/></svg><b>coordinate landscape</b></div><i>↓</i>
    <div><svg class="concept-icon helix-icon" viewBox="0 0 56 44" aria-hidden="true"><path d="M12 3 C45 13 45 31 12 41 M44 3 C11 13 11 31 44 41 M18 8 L38 8 M13 16 L43 16 M13 28 L43 28 M18 36 L38 36"/></svg><b>ranked genes</b></div><i>↓</i>
    <div><svg class="concept-icon network-icon" viewBox="0 0 56 44" aria-hidden="true"><path d="M10 11 L27 7 L45 15 L38 35 L17 37 Z M10 11 L38 35 M27 7 L17 37 M45 15 L17 37"/><circle cx="10" cy="11" r="3"/><circle cx="27" cy="7" r="3"/><circle cx="45" cy="15" r="3"/><circle cx="38" cy="35" r="3"/><circle cx="17" cy="37" r="3"/></svg><b>pathways and modules</b></div>
  </div>
  <p>Loadings identify genes that contribute strongly to a coordinate.</p>
  <p>Ranked gene lists can support enrichment, module analysis and comparison with stage-specific expression.</p>
  <div class="caveat amber-caveat">A large loading supports interpretation and candidate generation. It does not establish causality.</div>
</div>
</div>
<div class="citation">Rockne et al. 2020, <em>Cancer Res.</em> &nbsp; Frankhouser et al. 2024, <em>Leukemia</em></div>

<!--
About 70 seconds. These bars are the actual feature loadings from the same recovered divergence component. In real data, ranked genes can be examined directly and used for GSEA, modules, or comparison with stage-specific differential expression. This is how the landscape becomes biologically interpretable. Loadings nominate contributors but do not prove causal drivers.
-->

---

<span class="status implemented">CURRENT IMPLEMENTED OUTPUT</span>
# The one-dimensional path runs end to end

<div class="science-split current-output">
<div class="equation-side">
  <strong>Working now</strong>
  <p>Known-truth data generation</p><p>Registered SVD decomposition</p><p>Kernel density estimation</p><p>Quasi-potential plotting</p><p>Provenance at every stage</p>
  <small>Regenerated for this talk with public landscapeR functions.</small>
</div>
<div class="plot-frame"><img src="./assets/landscaper-k1-double-well.png" alt="One-dimensional double-well quasi-potential produced by landscapeR"></div>
</div>

<!--
About 55 seconds. Distinguish implemented capability from the two-dimensional example. The one-dimensional double well runs end to end today through public functions: known-truth generation, SVD, density estimation, quasi-potential plotting and provenance. The figure was regenerated for this talk.
-->

---

# Coordinate interpretation follows a declared analysis

<div class="analysis-flow"><div><span>01</span><strong>Decompose</strong><small>Fit axes without outcome labels</small></div><i>→</i><div><span>02</span><strong>Describe</strong><small>Show all candidate coordinates</small></div><i>→</i><div><span>03</span><strong>Associate</strong><small>Use declared targets and nuisance fields</small></div><i>→</i><div><span>04</span><strong>Resample</strong><small>Preserve biological sampling units</small></div><i>→</i><div><span>05</span><strong>Confirm</strong><small>Record a decision or abstain</small></div></div>
<div class="rules"><div>Effect is declared before candidate axes are ranked</div><div>Axis and subspace instability remain visible</div><div>A failed model is reported rather than silently replaced</div></div>

<!--
About 65 seconds. Explain that decomposition is outcome-blind but interpretation is not casual browsing. The biological target, nuisance variables, association and sampling design are declared. Resampling preserves the biological unit. A person records the final decision or abstains.
-->

---

# Known truth defines the operating limits

<div class="evidence-ladder">
<div><span>1</span><strong>Known-truth controls</strong><p>Can the pipeline recover the planted axis, subspace and landscape?</p><small>Including null, nuisance, weak-signal and near-degenerate cases</small></div>
<div><span>2</span><strong>Domain-grounded simulations</strong><p>Do the rules survive realistic sampling designs, noise and confounding?</p><small>Thresholds are calibrated, frozen, then tested on held-out simulations</small></div>
<div><span>3</span><strong>Biological examples</strong><p>Does the result make biological sense and reproduce across evidence sources?</p><small>Useful for interpretation and feasibility, not latent ground truth</small></div>
</div>
<div class="bottom">The package should also be able to conclude that no coordinate is identifiable.</div>

<!--
About 65 seconds. Known-truth controls answer whether the method recovers what was planted. Domain-grounded simulation adds realistic confounding, noise and sampling. Biological examples show feasibility and interpretation but cannot reveal latent truth. A valid result can be no identifiable coordinate.
-->

---

# LLM alignment comes before implementation

<div class="alignment-intro">We spend substantial time establishing shared language, assumptions, failure conditions and scientific boundaries before asking the agent to build.</div>
<div class="collaboration-flow">
  <div><span>01</span><strong>Align</strong><small>Vocabulary, intent and scope</small></div><i>→</i>
  <div><span>02</span><strong>Grill</strong><small>Resolve ambiguity and expose assumptions</small></div><i>→</i>
  <div><span>03</span><strong>Formalise</strong><small>ADRs, contracts and explicit abstention</small></div><i>→</i>
  <div><span>04</span><strong>Test</strong><small>Known truth, adversarial review and CI</small></div><i>→</i>
  <div><span>05</span><strong>Record</strong><small>Durable rationale and provenance</small></div>
</div>
<div class="skills-reference"><div><small>WORKFLOW INFLUENCE</small><strong>Matt Pocock skills</strong><span><code>/grill-me</code> and <code>/grill-with-docs</code></span></div><div class="url-box">github.com/mattpocock/skills</div></div>
<div class="bottom">The aim is not faster code generation. It is a scientific argument that remains inspectable after the AI session ends.</div>

<!--
About 80 seconds. This is the part that differs most from casual vibe coding. We spend a long time establishing shared vocabulary, assumptions, failure conditions and scope before implementation. Matt Pocock's grilling skills influenced the structure, particularly `/grill-me` and `/grill-with-docs`. The project then adds scientific contracts, adversarial consultation, known-truth simulations, explicit abstention, ADRs and provenance. The goal is not simply to generate code faster. It is to leave an inspectable scientific argument that persists after the AI session.
-->

---

# landscapeR is general; <em>Pogona</em> is a demanding next case

<div class="closing-grid">
<div><span class="done-dot"></span><strong>Implemented</strong><p>One-dimensional decomposition and quasi-potential estimation, synthetic controls, projection, provenance and descriptive component views</p></div>
<div><span class="next-dot"></span><strong>In development</strong><p>Metadata association, reproducible component proposals, design-aware stability and recorded human confirmation</p></div>
<div><span class="later-dot"></span><strong>Required for <em>Pogona</em></strong><p>Validated two-dimensional branching dynamics and a principled comparison across temperature regimes</p></div>
</div>
<div class="closing-statement">A framework for developmental, disease and other biological state transitions.</div>
<div class="repo">github.com/drejom/landscapeR</div>

<!--
About 45 seconds. Summarize the current boundary. The general architecture exists and the one-dimensional path works. Metadata association and stability are being formalized. Pogona demands a validated two-dimensional branching model and comparison across temperature regimes. Close by inviting the audience to recognize other biological state-transition problems that fit the framework.
-->

---

<span class="status implemented">REAL MATRICES NOW IN HAND</span>
# <em>Pogona</em> sampling spans stage, genotype and temperature

<div class="pogona-two-experiments">
<div class="pogona-timecourse">
  <small>EXPERIMENT 1</small><strong>Two-day sampling through the sex-determining window</strong>
  <div class="cohort-label">28 °C ZW</div><div class="day-track"><i></i><i></i><i></i><i></i><i></i><i></i></div>
  <div class="cohort-label">28 °C ZZ</div><div class="day-track zz"><i></i><i></i><i></i><i></i><i></i><i></i></div>
  <div class="day-labels"><span>7</span><span>9</span><span>11</span><span>13</span><span>15</span><span>17</span></div>
  <b>35 libraries</b><span>Two sample labels require clarification</span>
</div>
<div class="pogona-stage-series">
  <small>EXPERIMENT 2</small><strong>Developmental series with crossed biological conditions</strong>
  <div class="material-bands"><span>whole embryo</span><span>dissected gonad</span></div>
  <div class="design-matrix">
    <b></b><b>S1</b><b>S2</b><b>S4</b><b>S6</b><b>S12</b><b>S15</b>
    <strong>28 °C ZW</strong><i class="zw"></i><i class="zw"></i><i class="zw"></i><i class="zw"></i><i class="zw"></i><i class="zw"></i>
    <strong>28 °C ZZ</strong><i class="zz"></i><i class="zz"></i><i class="zz"></i><i class="zz"></i><i class="zz"></i><i class="zz"></i>
    <strong>36 °C ZZ</strong><i class="empty"></i><i class="empty"></i><i class="empty"></i><i class="hot"></i><i class="hot"></i><i class="hot"></i>
  </div>
  <b>17 whole-embryo and 70 mapped gonad libraries</b><span>Ten additional gonads need metadata</span>
</div>
</div>
<div class="bottom">Counts and TPM matrices are consolidated and checksum-verified. No decomposition is shown yet.</div>

<!--
About 45 seconds, optional. These are the real expression matrices received today, not synthetic data and not an analysis result. One experiment samples days 7 through 17 at 28 °C in ZZ and ZW animals. The second spans stages 1, 2, 4, 6, 12, and 15. Whole embryos are consumed at the early stages because organs are not yet discernible; gonads are dissected later. The 28 °C ZZ and ZW cohorts span all stages, while the 36 °C ZZ cohort covers stages 6, 12, and 15. Counts and TPM matrices are consolidated locally. Two time-course labels and ten additional gonad samples still need metadata clarification, so no decomposition is shown tonight.
-->
