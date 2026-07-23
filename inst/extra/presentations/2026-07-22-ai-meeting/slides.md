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

---

# Study design sets the interpretation

<div class="design-grid">
<div class="design-item cyan">
<svg viewBox="0 0 260 96" role="img" aria-label="Independent embryos sampled across developmental stages">
  <path d="M24 67 H225" class="guide"/><path d="M219 61 L229 67 L219 73" class="guide"/>
  <g class="sample"><circle cx="42" cy="57" r="7"/><circle cx="42" cy="75" r="7"/><circle cx="91" cy="51" r="7"/><circle cx="91" cy="69" r="7"/><circle cx="91" cy="87" r="7"/><circle cx="145" cy="48" r="7"/><circle cx="145" cy="68" r="7"/><circle cx="145" cy="88" r="7"/></g>
  <g class="branch-a"><circle cx="201" cy="42" r="7"/><circle cx="221" cy="42" r="7"/></g><g class="branch-b"><circle cx="201" cy="84" r="7"/><circle cx="221" cy="84" r="7"/></g>
  <text x="24" y="17">independent cohorts</text><text x="182" y="21">later states</text>
</svg>
<h2><em>Pogona</em></h2><strong>Developmental divergence</strong><p>Independent embryos sampled at observed stages</p><small>Group structure, not tracked embryo paths</small>
</div>
<div class="design-item blue">
<svg viewBox="0 0 260 96" role="img" aria-label="Repeated measurements within subjects">
  <path d="M45 26 C96 17 151 30 216 18 M45 54 C97 66 151 43 216 55 M45 82 C101 73 154 89 216 76" class="subject-line"/>
  <g class="sample"><circle cx="45" cy="26" r="7"/><circle cx="128" cy="24" r="7"/><circle cx="216" cy="18" r="7"/><circle cx="45" cy="54" r="7"/><circle cx="128" cy="52" r="7"/><circle cx="216" cy="55" r="7"/><circle cx="45" cy="82" r="7"/><circle cx="128" cy="80" r="7"/><circle cx="216" cy="76" r="7"/></g>
  <text x="8" y="30">1</text><text x="8" y="58">2</text><text x="8" y="86">3</text>
</svg>
<h2>AML</h2><strong>Disease progression</strong><p>Repeated measurements within mice across time</p><small>Subject-aware trajectories</small>
</div>
<div class="design-item amber">
<svg viewBox="0 0 260 96" role="img" aria-label="Independent donors sampled across ordered clinical states">
  <path d="M24 67 H225" class="guide"/><path d="M219 61 L229 67 L219 73" class="guide"/>
  <g class="sample"><circle cx="46" cy="56" r="7"/><circle cx="46" cy="76" r="7"/><circle cx="112" cy="50" r="7"/><circle cx="112" cy="70" r="7"/><circle cx="112" cy="90" r="7"/><circle cx="190" cy="56" r="7"/><circle cx="190" cy="76" r="7"/></g>
  <text x="25" y="18">state 1</text><text x="93" y="18">state 2</text><text x="171" y="18">state 3</text>
</svg>
<h2>Type 1 diabetes</h2><strong>Ordered clinical states</strong><p>Independent donors sampled across declared states</p><small>Cross-sectional progression structure</small>
</div>
</div>
<div class="bottom">The independent sampling unit, observed time and repeated structure remain explicit.</div>

---

<span class="status implemented">LANDSCAPER SYNTHETIC CONTROL</span>
# Molecular data define the coordinate system

<div class="science-split">
<div class="matrix-side">
  <div class="matrix-glyph"><span>genes</span><div class="heat-grid">● ● ● ● ● ●<br>● ● ● ● ● ●<br>● ● ● ● ● ●<br>● ● ● ● ● ●<br>● ● ● ● ● ●</div><i>samples</i></div>
  <div class="plain-arrow">→</div>
  <div class="step-copy"><b>Outcome-blind decomposition</b><p>Sex, stage and temperature are not used to fit the axes.</p><small>Known-truth branching control, 160 independent samples and 240 features</small></div>
</div>
<div class="plot-frame"><img src="./assets/branching-state-space-unlabelled.png" alt="Recovered two-dimensional coordinate system from landscapeR synthetic branching data"></div>
</div>

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

---

<span class="status implemented">LOADINGS FROM THE SAME SVD</span>
# Loadings connect coordinates to genes and pathways

<div class="loadings-layout">
<div class="plot-frame"><img src="./assets/branching-loadings.png" alt="Ranked feature loadings on the recovered divergence coordinate"></div>
<div class="interpret-side">
  <div class="mini-flow"><span class="axis-mark"></span><b>coordinate</b><i>→</i><span class="gene-mark">A C G T</span><b>ranked genes</b><i>→</i><span class="pathway-mark">●─●<br>╲●╱</span><b>pathways</b></div>
  <p>Loadings identify genes that contribute strongly to a coordinate.</p>
  <p>Ranked gene lists can support enrichment, module analysis and comparison with stage-specific expression.</p>
  <div class="caveat amber-caveat">A large loading supports interpretation and candidate generation. It does not establish causality.</div>
</div>
</div>
<div class="citation">Rockne et al. 2020, <em>Cancer Res.</em> &nbsp; Frankhouser et al. 2024, <em>Leukemia</em></div>

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

---

# Coordinate interpretation follows a declared analysis

<div class="analysis-flow"><div><span>01</span><strong>Decompose</strong><small>Fit axes without outcome labels</small></div><i>→</i><div><span>02</span><strong>Describe</strong><small>Show all candidate coordinates</small></div><i>→</i><div><span>03</span><strong>Associate</strong><small>Use declared targets and nuisance fields</small></div><i>→</i><div><span>04</span><strong>Resample</strong><small>Preserve biological sampling units</small></div><i>→</i><div><span>05</span><strong>Confirm</strong><small>Record a decision or abstain</small></div></div>
<div class="rules"><div>Effect is declared before candidate axes are ranked</div><div>Axis and subspace instability remain visible</div><div>A failed model is reported rather than silently replaced</div></div>

---

# Known truth defines the operating limits

<div class="evidence-ladder">
<div><span>1</span><strong>Known-truth controls</strong><p>Can the pipeline recover the planted axis, subspace and landscape?</p><small>Including null, nuisance, weak-signal and near-degenerate cases</small></div>
<div><span>2</span><strong>Domain-grounded simulations</strong><p>Do the rules survive realistic sampling designs, noise and confounding?</p><small>Thresholds are calibrated, frozen, then tested on held-out simulations</small></div>
<div><span>3</span><strong>Biological examples</strong><p>Does the result make biological sense and reproduce across evidence sources?</p><small>Useful for interpretation and feasibility, not latent ground truth</small></div>
</div>
<div class="bottom">The package should also be able to conclude that no coordinate is identifiable.</div>

---

# AI development follows a scientific governance loop

<div class="governance">
<div><strong>Generate</strong><span>Code, tests, alternatives and candidate explanations</span></div><b>→</b>
<div><strong>Challenge</strong><span>Adversarial review, primary literature and synthetic truth</span></div><b>→</b>
<div><strong>Decide</strong><span>Recorded rationale, human ownership and visible limitations</span></div>
</div>
<div class="artifact-line"><span><small>DECISIONS</small>Architecture and statistical contracts</span><span><small>EVIDENCE</small>Executable tests and reproducible controls</span><span><small>REVIEW</small>Rationale and limitations beside the code</span></div>
<div class="bottom">AI output is working material. Claims are constrained by explicit contracts and evidence.</div>

---

# landscapeR is general; <em>Pogona</em> is a demanding next case

<div class="closing-grid">
<div><span class="done-dot"></span><strong>Implemented</strong><p>One-dimensional decomposition and quasi-potential estimation, synthetic controls, projection, provenance and descriptive component views</p></div>
<div><span class="next-dot"></span><strong>In development</strong><p>Metadata association, reproducible component proposals, design-aware stability and recorded human confirmation</p></div>
<div><span class="later-dot"></span><strong>Required for <em>Pogona</em></strong><p>Validated two-dimensional branching dynamics and a principled comparison across temperature regimes</p></div>
</div>
<div class="closing-statement">A framework for developmental, disease and other biological state transitions.</div>
<div class="repo">github.com/drejom/landscapeR</div>
