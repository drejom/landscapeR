---
theme: default
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

# Biological state transitions arise from different study designs

<div class="design-grid">
<div class="card cyan"><div class="glyph split">●──┬──●<br>&nbsp;&nbsp;&nbsp;&nbsp;└──●</div><h2><em>Pogona</em></h2><strong>Developmental divergence</strong><p>Independent embryos sampled across observed developmental time</p><small>Shared early state, later sex-associated states</small></div>
<div class="card blue"><div class="glyph">●&nbsp;&nbsp;●&nbsp;&nbsp;●<br>│&nbsp;&nbsp;│&nbsp;&nbsp;│<br>●&nbsp;&nbsp;●&nbsp;&nbsp;●</div><h2>AML</h2><strong>Disease progression</strong><p>Repeated measurements within mice across time</p><small>Subject-aware disease trajectories</small></div>
<div class="card amber"><div class="glyph">● ── ● ── ●</div><h2>Type 1 diabetes</h2><strong>Ordered clinical states</strong><p>Independent donors sampled across predeclared states</p><small>Cross-sectional progression structure</small></div>
</div>
<div class="bottom">The sampling unit and the meaning of time determine what the analysis can support.</div>

---

<span class="status">CONCEPTUAL, NOT FITTED DATA</span>
# Molecular measurements define a state space
<div class="figure-layout"><div class="copy"><b>1</b><p>Each sample contains thousands of molecular measurements.</p><p>The decomposition learns a small number of coordinates without using sex or stage labels to fit the axes.</p></div><div class="figure"><StateSpaceBuild :stage="1" /></div></div>

---

<span class="status">CONCEPTUAL, NOT FITTED DATA</span>
# Sample density defines a descriptive quasi-potential
<div class="figure-layout"><div class="copy"><b>2</b><div class="equation">U(x) = -log p(x)</div><p>Frequently observed states form wells.</p><p>Sparsely occupied regions form higher terrain.</p><div class="caveat">A descriptive landscape of sample occupancy, not physical energy.</div></div><div class="figure"><StateSpaceBuild :stage="2" /></div></div>
<div class="citation">Rockne et al. 2020, <em>Cancer Res.</em> &nbsp; Frankhouser et al. 2024, <em>Leukemia</em></div>

---

<span class="status">CONCEPTUAL, NOT FITTED DATA</span>
# Developmental metadata helps interpret the state space
<div class="figure-layout"><div class="copy"><b>3</b><p>Observed stage provides developmental ordering.</p><p>Phenotypic sex helps interpret later divergence.</p><p>Temperature, genotype and other variables remain separate evidence.</p><div class="caveat">Independent embryos show group-level structure, not tracked individual paths.</div></div><div class="figure"><StateSpaceBuild :stage="3" /></div></div>

---

# Coordinates connect the landscape to genes and pathways
<div class="gene-flow"><div><span class="axis-icon"></span><strong>Biological coordinate</strong><small>stable and direction oriented</small></div><b>→</b><div><span class="bar-icon">▂▅█▄▆</span><strong>Gene loadings</strong><small>ranked contribution to the coordinate</small></div><b>→</b><div><span class="network-icon">●╲●╱●<br>&nbsp;&nbsp;●</span><strong>Pathways and modules</strong><small>enrichment and stage-specific expression</small></div></div>
<div class="bands"><div><strong>Supports interpretation</strong><span>Which molecular programmes vary along the state direction?</span></div><div><strong>Generates candidates</strong><span>Which genes and pathways merit closer study?</span></div><div class="warn"><strong>Does not establish causality</strong><span>Large loadings alone do not prove that a gene drives the transition.</span></div></div>
<div class="citation">Rockne et al. 2020, <em>Cancer Res.</em> &nbsp; Frankhouser et al. 2024, <em>Leukemia</em></div>

---

# Interpretation depends on design, stability and prior declarations
<div class="analysis-flow"><div><span>01</span><strong>Decompose</strong><small>Fit axes without outcome labels</small></div><i>→</i><div><span>02</span><strong>Describe</strong><small>Show every candidate coordinate</small></div><i>→</i><div><span>03</span><strong>Associate</strong><small>Use declared targets and nuisance fields</small></div><i>→</i><div><span>04</span><strong>Resample</strong><small>Preserve biological sampling units</small></div><i>→</i><div><span>05</span><strong>Confirm</strong><small>Human decision or explicit abstention</small></div></div>
<div class="rules"><div>No axis chosen because its p-value looks best</div><div>No unstable axis made convincing by rotation</div><div>No weaker model substituted after failure</div></div>

---

# AI-assisted scientific development
<div class="governance"><div><strong>Generation</strong><span>Designs, code, tests, alternatives</span></div><b>→</b><div><strong>Evaluation</strong><span>Adversarial review, primary literature, synthetic truth</span></div><b>→</b><div><strong>Acceptance</strong><span>Recorded decision, human ownership, visible limitations</span></div></div>
<div class="artifacts"><div><small>DECISION RECORD</small><strong>ADR 0020</strong><span>Statistical strategy accepted provisionally</span></div><div><small>EXECUTABLE EVIDENCE</small><strong>565 tests passed</strong><span>0 failures, 0 warnings</span></div><div><small>REVIEW SURFACE</small><strong>PR #77</strong><span>Research, rationale and landing proof together</span></div></div>
<div class="bottom">AI output is working material. Scientific support comes from evidence and explicit decisions.</div>

---

# Current landscapeR scope
<div class="scope"><div class="output"><span class="implemented">IMPLEMENTED SYNTHETIC OUTPUT</span><img src="./assets/landscaper-k1-double-well.png" alt="Synthetic double-well quasi-potential produced by landscapeR"></div><div class="scope-list"><div><i class="done"></i><strong>Working now</strong><p>K=1 decomposition, provenance, projection, descriptive component views and synthetic controls</p></div><div><i class="next"></i><strong>Being built next</strong><p>Metadata association, reproducible component proposals, stability and human confirmation</p></div><div><i class="later"></i><strong>Later Pogona capability</strong><p>Validated two-dimensional bifurcation topology and comparison across temperature regimes</p></div></div></div>
<div class="repo">github.com/drejom/landscapeR</div>

<style>
.status {
  position: absolute;
  top: 1.4rem;
  right: 3.35rem;
  float: none;
  margin: 0;
}
</style>
