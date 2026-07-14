# Ubiquitous Language — landscapeR

## Mathematical framework

| Term | Definition | Aliases to avoid |
|---|---|---|
| **state variable** | The minimal description of a biological system at a point in time — here, the whole-blood or PBMC transcriptome | snapshot, profile |
| **state-space** | The low-dimensional coordinate system (typically one or two PCA axes) in which state variables are plotted over time | feature space, embedding, PC space |
| **descriptive evidence layer** | The minimally interpreted analysis output needed to assess a claim—component coordinates and distributions, metadata associations, empirical densities, individual metrics, and exclusions. It is not synonymous with publishable raw subject-level data. | raw data layer |
| **hypothesis-conditioned interpretation layer** | The declared roles, expected ordering, models, selections, fitted structures, biological labels, and aggregate judgements applied after descriptive evidence is available; always retained beside and linked to its descriptive precursor | results layer, final answer |
| **observation before interpretation** | The rule that interpretation never overwrites or hides descriptive evidence; predeclared and discovered hypotheses remain distinguished (ADR 0017) | hypothesis-free analysis |
| **state-transition** | The dynamic process by which a biological system moves from one stable state to another across an unstable boundary | phenotype switch, disease progression (too narrow) |
| **quasi-potential** | A scalar energy function U(x) over the state-space whose local minima are stable states and local maxima are unstable transition boundaries; not a physical potential (has no physical units) | potential energy, energy landscape, attractor landscape |
| **well** | A local minimum of the quasi-potential — a stable, energetically favourable biological state the system tends to occupy | attractor basin, stable state (use only when distinguishing from unstable state) |
| **barrier** | The quasi-potential value at an unstable critical point minus the value at the adjacent well; quantifies irreversibility | activation energy, barrier height (preferred compound form for numeric comparisons) |
| **no-transition result** | A valid Stage 2 conclusion that the selected target biological axis has a single well or no supported barrier; the data do not support a state-transition topology on that axis | failed landscape |
| **Langevin equation** | The stochastic differential equation `dX_t = −∇U_p dt + √(2β⁻¹) dB_t` governing how the state variable moves in the quasi-potential with noise | equation of motion |
| **Fokker-Planck equation** | The deterministic PDE for the probability density P(x,t) of the state variable; solved numerically to predict time-to-disease | FP equation, probability transport equation |
| **diffusion coefficient** | The noise parameter β⁻¹ in the Langevin/Fokker-Planck equations, estimated from the mean squared displacement of state-space trajectories | noise strength, stochastic fluctuation parameter |
| **barrier first-passage time** | The model-derived distribution of time from an initial state-space position to the unstable critical point under longitudinal dynamics; the primary longitudinal Stage 2 timing quantity | time-to-disease (unless clinically validated), disease onset time, survival time |

## Decomposition layer

| Term | Definition | Aliases to avoid |
|---|---|---|
| **SVD** | Singular value decomposition X = UΣV*; the foundational matrix factorisation used to build a state-space from a gene expression matrix | PCA (PCA is a restatement of SVD — prefer SVD when describing the computation) |
| **GSVD** | Generalised SVD of two matrices; decomposes shared and layer-specific variation simultaneously; the two-matrix special case of HO-GSVD | joint PCA |
| **HO-GSVD** | Higher-order GSVD of K ≥ 2 matrices; a candidate Stage 1 family, not an accepted production strategy after the v2 negative result. Genuine heterogeneous-feature inputs must satisfy ADR 0009. | tensor decomposition (incorrect), multi-block PCA (different method) |
| **eigengene** | The loading of a gene on a selected target biological axis (a column of V*); quantifies that gene's directional contribution to the chosen biological contrast | gene weight, PC loading (prefer eigengene when the loading has biological interpretation) |
| **target biological axis** | The component whose coordinate is associated with a predeclared biological variable or contrast; recommended by a reproducible proposal and human-confirmed in the frozen reference basis while retaining the target declaration | PC1/PC2 (the target may not be the dominant component), manually selected component |
| **disease axis** | A disease-specific target biological axis whose coordinate separates healthy from disease state variables or correlates with disease burden markers | leukemia axis, CML state-space (use disease-specific names only in disease-specific contexts) |
| **component-selection proposal** | A reproducible ranking of Stage 1 components against predeclared biological metadata. It recommends but never silently selects the target biological axis, and never uses Stage 2 results as a criterion | component picker |
| **omic layer** | A single type of molecular measurement (mRNA, miRNA, proteomics, methylation) contributing one data matrix to the multi-layer decomposition | modality, data type, assay (too generic) |
| **projection** | Mapping new samples into a frozen state-space without refitting; for ordinary SVD scores, `(X_new − center_training) · V_training`. Uses canonical feature identity and discovery preprocessing, never independent secondary-cohort recentering or division by singular values. | embedding, transfer |

## Multi-scale biology

| Term | Definition | Aliases to avoid |
|---|---|---|
| **micro-state** | The transcriptional state of a single cell; dominated by cell-type identity; does not resolve disease status at single-cell resolution | single-cell state, SC state |
| **macro-state** | The aggregate transcriptional state of a cell population (pseudobulk); encodes discrete disease phenotypes invisible at the micro-state level | bulk state, tissue state |
| **pseudobulk (PsB)** | A synthetic bulk RNA-seq sample constructed by summing scRNA-seq counts across all cells in a (mouse, timepoint) sample, then CPM-normalising | aggregated sample, in-silico bulk |
| **cell-type pseudobulk (ctPsB)** | A pseudobulk constructed from cells of one cell type only; used to decompose each cell type's independent contribution to the macro-state disease trajectory | cell-type aggregate, per-lineage pseudobulk |
| **fixed cell-type simulation** | A counterfactual experiment in which one cell type's expression is frozen at its baseline (T₀) value to quantify how much that cell type contributes to macro-state disease dynamics, measured by KL divergence | cell-type ablation, knockout simulation |
| **superposition of cell states** | The observation that SC-level transcriptomes continuously overlap between healthy and disease conditions — disease is not a discrete microstate but a statistical property of the population | mixed states |

## Critical points

| Term | Definition | Aliases to avoid |
|---|---|---|
| **critical point** | A location x* where ∇U_p(x*) = 0; either stable (well) or unstable (barrier peak) | fixed point (reserve for ODE contexts), attractor (means stable critical point only) |
| **stable critical point** | A local minimum of the quasi-potential; a disease phenotype the system tends to occupy | attractor, stable state |
| **unstable critical point** | A local maximum of the quasi-potential; the tipping point or point of no return between two stable states | saddle point (only correct in 2D), transition state (acceptable synonym) |
| **point of no return** | Informal name for an unstable critical point at which stochastic transitions become highly likely and disease progression accelerates; equivalent to the transition-state critical point c₂ in a double-well | tipping point (acceptable in non-technical contexts) |
| **double-well potential** | A quasi-potential with exactly two stable critical points separated by one unstable critical point; characterises two-state systems (e.g. AML: healthy and leukemic) | two-well landscape |
| **three-well potential** | A quasi-potential with three stable and two unstable critical points; characterises three-state systems (e.g. CML: Early, Transition, Late) | tri-stable landscape, tristable potential |
| **bifurcation topology** | A quasi-potential with one shared early region of marginal stability that resolves into two distinct wells as a function of developmental progression or condition; produces a Y-shape in a PC1/PC2 biplot. Characterises the Pogona TSD dataset. Outside the scope of the current 1D KDE Stage 2 estimator; requires a 2D or time-aware estimator and its own ADR and Stage 0 control ladder. | branching potential, Y-shape potential |
| **confounder axis** | A Stage 1 component that captures a declared nuisance variable (e.g. age, batch) rather than the target biological contrast. In the AML Cancer Research 2020 reference result, PC1 is a confounder axis (age); PC2 is the disease axis. The component-selection proposal must rank the target biological axis above confounder axes. | nuisance component, batch component |

## Pipeline architecture

| Term | Definition | Aliases to avoid |
|---|---|---|
| **stage** | A numbered phase of the landscapeR pipeline (0, 0.5, 0.75, 1, 2), each with a defined contract and input/output type; not to be confused with a biological disease state | step, phase |
| **Stage 0** | The synthetic control ladder: generates known-potential ground truth data for validating Stages 1 and 2; load-bearing for all downstream threshold decisions | validation stage, test stage |
| **Stage 1** | Comparative decomposition via GSVD/HO-GSVD; produces a state-space whose axes contrast biological layers | decomposition stage |
| **Stage 2** | Quasi-potential dynamics estimation; fits U(x) = −log p(x) on Stage 1 coordinates and reads out critical points and barrier heights | dynamics stage, potential stage |
| **contract** | An S4 VIRTUAL class defining the interface (input type, output type, generics) that every concrete strategy for a stage must implement | interface, abstract class |
| **strategy** | A concrete implementation of a stage contract, registered under a named key; selected via `PipelineConfig`, not by code branching | algorithm, method, backend |
| **registry** | The in-memory store mapping strategy names to implementations; the only place dispatch decisions are made | dispatcher, factory |
| **StateTransitionData** | The single S4 container (MAE subclass) that flows between all stages; the contract-defined unit of exchange | data object, result container |
| **PipelineConfig** | The configuration object that selects each stage strategy and carries one `AnalysisSpecification`; the only place algorithm choices and run-specific scientific intent are joined | settings, parameters |
| **AnalysisSpecification** | The versioned declaration that retains one complete target contrast/order/direction through `draft`, `proposal`, and human-`confirmed` component-selection states. Confirmation adds `selected_component` and decision provenance; it never replaces target intent. | manual component, target/component XOR, analysis plan (too broad) |
| **StageResult** | A typed wrapper around a stage's return value carrying success/failure status and provenance; never a raw list or exception | result, output |
| **provenance** | The machine-readable record of how an artifact was produced, stored in `StateTransitionData` metadata; first-class in landscapeR | audit trail, lineage |
| **visual landing proof** | The pull-request-co-located before/after or representative figure, table, or workflow render showing that a qualifying implementation visibly changed the intended behavior; includes reproduction instructions and claim status, and never substitutes for immutable scientific evidence | screenshot (too narrow), acceptance evidence (incorrect) |
| **boundary validation** | The check run at every stage entry via `validate_boundary()` that verifies the input `StateTransitionData` satisfies the stage's preconditions | input validation, guard |
| **schema version** | The `SCHEMA_VERSION` constant declaring the current `StateTransitionData` serialisation format; bumped whenever the container schema changes, with a registered migration for every prior version | data version, format version |

## Ground truth and validation

| Term | Definition | Aliases to avoid |
|---|---|---|
| **ground truth** | Synthetic data generated by Stage 0 with a known quasi-potential, used to measure Stage 2 recovery accuracy; the evidence oracle for all `[tbd]` thresholds | test data, mock data |
| **end-to-end recovery benchmark** | A mandatory Stage 0 acceptance-gate experiment that runs synthetic multi-omic data through Stage 1 then Stage 2, measuring planted target-biological-axis and quasi-potential recovery before real-data analysis | accuracy test |
| **potential-recovery benchmark** | A Stage 0 estimator-level experiment that supplies known coordinates directly to Stage 2 and measures quasi-potential recovery; does not validate the full pipeline | accuracy test |
| **thinness sweep** | A Stage 0 experiment that varies sample count and time points to find the minimum data requirements for reliable quasi-potential estimation | sample-size sensitivity analysis |
| **rank-deficiency axis** | A dimension of the Stage 0 thinness sweep in which one omic layer is deliberately rank-deficient, testing whether Stage 1's HO-GSVD handles this correctly; critical for the diabetes genotype layer | rank collapse, degenerate case |

---

## Relationships

- A **StateTransitionData** container is produced and consumed at every **stage** boundary; it carries all **provenance** forward.
- A **Stage 1** run on K **omic layers** using **HO-GSVD** produces a shared subspace V* and K layer-specific coordinate matrices (UᵢΣᵢ); analysis selects one **target biological axis** from that subspace.
- A **Stage 2** run on **Stage 1** coordinates fits a **quasi-potential** whose **wells** correspond to **stable critical points** (disease phenotypes) and whose **barriers** quantify irreversibility.
- A **double-well potential** has exactly one **unstable critical point** (the **point of no return**); a **three-well potential** has two.
- Every **strategy** must be registered in the **registry** and selected by **PipelineConfig** — never by a conditional dispatcher in stage code.
- **Stage 0** ground truth is the only honest oracle for the `[tbd]` thresholds in **Stage 2**; no **Stage 2** implementation is complete until those thresholds are filled from **recovery benchmarks**.
- A **pseudobulk** aggregates **micro-states** into a **macro-state**; the macro-state encodes the **state-transition** that is invisible at the micro-state level.
- Each **cell-type pseudobulk** trajectory spans only a subset of the total **pseudobulk** state-space coordinate range; the union of all **ctPsB** spans recovers the full **disease axis**.

---

## Example dialogue

> **Dev:** "For Stage 1, should I run SVD on each omic layer separately and then align the state-spaces?"
>
> **Domain expert:** "No — that's the sequential approach from the Frankhouser2026 paper: separate SVD per **cell-type pseudobulk**, then **project** each into the total **pseudobulk** state-space after the fact. The landscapeR approach is HO-GSVD across all **omic layers** at once, giving a shared **disease axis** that is jointly optimised. The sequential approach aligns post-hoc; HO-GSVD gives you the alignment algebraically."
>
> **Dev:** "So the shared V* from HO-GSVD is the **disease axis** for all layers?"
>
> **Domain expert:** "It's the set of axes that are common across all layers. One of them will be the **disease axis** — the one whose coordinate separates healthy from disease **state variables** — and Stage 2 fits the **quasi-potential** along that coordinate. The others capture shared confounders you want to inspect but not model as a potential."
>
> **Dev:** "And Stage 0 is what tells us whether the **quasi-potential** Stage 2 recovers is accurate?"
>
> **Domain expert:** "Exactly. Stage 0 generates a **double-well** or **three-well** synthetic dataset with a known **quasi-potential**, runs the full Stage 1 + Stage 2 pipeline on it, and measures how well the **recovery benchmark** recovers the known **critical points** and **barrier heights**. Those results fill in the `[tbd]` thresholds in ADR 0002. Until that's done, Stage 2 has no honest calibration."
>
> **Dev:** "What's the **rank-deficiency axis** in the **thinness sweep**?"
>
> **Domain expert:** "The diabetes instantiation will have a genotype **omic layer** that is rank-deficient — the matrix doesn't have full column rank. The **thinness sweep** must include this as an explicit experimental axis to verify that HO-GSVD handles it correctly, not just thin-sample cases where all layers are full rank."

---

## Flagged ambiguities

- **"state"** is overloaded: used for *biological disease state* (Early state, Late state, CML state) and for *mathematical state variable* (the transcriptome position in state-space). In code and issues: prefer **disease state** for the biological phenotype and **state variable** for the mathematical object. "State-space" and "state-transition" are compound terms with fixed meaning — do not shorten to just "state."

- **"stage"** collides between *pipeline stage* (Stage 0, Stage 1, Stage 2) and *disease stage* (Early state Es, Transition state Ts, Late state Ls). In landscapeR contexts always use **Stage N** (capital S, numeral) for pipeline stages and **disease state** for biological stages.

- **"potential"** is used both loosely ("potential landscape") and precisely (**quasi-potential**, a specific mathematical object). Always write **quasi-potential** when referring to U(x) = −log p(x); reserve "potential landscape" for informal explanations only.

- **"layer"** appears as *omic layer* (mRNA, miRNA), *computational layer*, and occasionally in the Docker/infrastructure sense (from omhq discussions). In landscapeR, use **omic layer** unambiguously; never abbreviate to just "layer."

- **"eigengene"** is a loading value (a scalar per gene from V*), not a gene in the conventional sense. It does not identify a gene; it quantifies a gene's directional contribution to the disease axis. Clarify when talking to biologists who may expect it to name a specific transcript.

- **"recovery"** is used both for *quasi-potential recovery* (Stage 2 accurately reconstructs a known potential from Stage 0 data) and loosely for *biological recovery* (a treated mouse returning toward the healthy state). Always qualify: **potential recovery** or **disease recovery**.
