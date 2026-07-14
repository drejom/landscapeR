# Stage 2 — Quasi-potential dynamics

Stage 2 takes the disease-axis coordinates from Stage 1 and fits a quasi-potential landscape: U(x) = −log p(x). It locates critical points, quantifies barrier heights, and optionally solves the Fokker-Planck equation to predict time-to-disease. It generalises the Rockne-Frankhouser MATLAB pipeline from single-layer SVD to multi-layer GSVD/HO-GSVD coordinates.

## Language

**quasi-potential**:
The scalar energy function U(x) = −log p(x) derived by log-density inversion of the empirical distribution of state-space coordinates. Local minima are stable states; local maxima are unstable transition boundaries. Not a physical potential — has no physical units. Its scientific interpretation is constrained by the declared sampling design and estimator.
_Avoid_: potential energy, energy landscape, attractor landscape, effective potential (use only when specifically referring to the ODE-derived theoretical potential from Frankhouser2024)

**sampling design**:
The declared observation structure used to constrain Stage 2 claims. **Cross-sectional** data support a distributional quasi-potential estimate from independent biological units; the planned diabetes application uses independent donors in the predeclared order non-diabetic → autoantibody-positive → T1D. **Longitudinal** data include subject identity and ordered repeated measurements; AML is the reference application and requires a distinct subject-aware strategy to test trajectory divergence, direction, or temporal quantities. These are complementary capabilities with different estimands, not interchangeable approximations. A predeclared one-observation-per-subject AML snapshot may be a separate sensitivity analysis but does not substitute for the longitudinal progression analysis.

**Stage 2 descriptive evidence**:
The selected state-space coordinates and their empirical distribution, shown before and beside any fitted quasi-potential. The empirical density, sample support, exclusions, and uncertainty remain inspectable; a smooth landscape must never be the only published representation (ADR 0017).

**Stage 2 interpretation**:
The fitted quasi-potential, geometrically classified critical points, uncertainty, and biological labels derived from the descriptive evidence. Geometric classifications (well, barrier) remain distinct from biological labels (healthy, leukemic), and every interpretation references its descriptive precursor.

**common static longitudinal potential**:
The first Rockne-style longitudinal target: one time-homogeneous 1D potential is shared across conditions, with CTL mice anchoring healthy occupancy and CM mice traversing toward disease; Langevin/Fokker–Planck dynamics evolve probability through time. The subject-aware strategy uses ordered within-mouse transitions, respects irregular intervals, and tests static/Markov adequacy assumptions. If unsupported it returns no-supported-static-longitudinal-potential rather than fitting a preferred landscape. It must not estimate this quantity by naively treating repeated observations as independent. A CM-specific landscape with CTL as an external reference, condition-specific comparative landscapes, and time-varying U(x,t) are separate future estimands.

**log-density inversion**:
The cross-sectional Stage 2 estimation approach: estimate p(x) by KDE on independent biological-unit coordinates, then compute U(x) = −log p(x). It is not the longitudinal estimator.
_Avoid_: KDE-based potential, negative log-density

**cross-layer concordance**:
The predeclared criterion under which target-axis coordinates from multiple omic layers may be pooled for one Stage 2 estimate. Each layer is assessed first; disagreement yields layer-specific results or a no-joint-transition result, not silent pooling.

**KDE**:
Kernel density estimation — the non-parametric method used to estimate p(x) from the distribution of state-space coordinates. The bandwidth-selection rule is fixed by Stage 0; its data-adaptive application to a cohort is permitted, but real-data outcomes or apparent topology must not select the rule.
_Avoid_: kernel smoothing (too generic)

**validated Stage 2 configuration**:
The estimator family, bandwidth-selection rule, polynomial-smoothing rule, topology/false-positive rule, and minimum-sample requirement accepted from Stage 0 evidence. It is frozen before real-data analysis; AML or other real data may not tune it for a preferred-looking landscape.

**polynomial smoothing**:
Fitting a polynomial whose derivative has zeros at the estimated critical point locations, applied to smooth the KDE-derived quasi-potential. Polynomial degree is configurable; not hardcoded.
_Avoid_: polynomial fit, spline smoothing

**critical point**:
A location x* where ∇U(x*) = 0. Either stable (a well) or unstable (a barrier peak). Found by automated zero-finding of the KDE derivative — never by visual inspection or hardcoded coordinates.
_Avoid_: fixed point (reserve for ODE contexts), equilibrium (ambiguous)

**biological-unit bootstrap**:
A resampling procedure that samples complete paired biological observations (all required omic layers together), reruns the applicable Stage 1 and Stage 2 steps, and reports selection, topology, well-location, and barrier-height stability. It never resamples individual layer coordinates as independent observations.

**stable critical point**:
A local minimum of the quasi-potential — a disease phenotype the system tends to occupy. Corresponds to a well.
_Avoid_: attractor (only correct in continuous dynamical systems), stable state (acceptable synonym, but prefer stable critical point in technical contexts)

**unstable critical point**:
A local maximum of the quasi-potential — the tipping point between two stable states. The system crosses this under noise-driven fluctuations.
_Avoid_: saddle point (only correct in 2D), separatrix (different concept)

**barrier height**:
The difference in quasi-potential value between an unstable critical point and the adjacent well. Quantifies the energetic cost of the state-transition — higher barrier = more irreversible transition.
_Avoid_: activation energy (implies physical units), transition cost

**well**:
A stable region around a stable critical point — the basin of a biological state. The depth and width of a well reflect how stable that state is.
_Avoid_: basin, attractor basin

**no-transition result**:
A valid Stage 2 conclusion that the selected target biological axis has a single well or no supported barrier. It means the data do not support a state-transition topology on that axis; it is not an estimation failure and must not be smoothed into a multi-well claim.

**multi-axis ineligible result**:
A successful applicability conclusion that Stage 1 supports a stable target-associated subspace but not a stable one-dimensional target axis. The current 1D estimator must not flatten or select within that subspace. A future 2D strategy requires its own ADR, Stage 0 control ladder, and acceptance criteria before use.

**claim status**:
A machine-readable statement of the evidence scope for a Stage 2 result: confirmatory, exploratory, ineligible for the current estimator, or a no-transition result. It is derived from declared sampling design, applicability, discovery/confirmation, concordance, and stability gates rather than a vignette disclaimer. Ineligible and no-transition results are successful scientific outcomes, distinct from typed computational or input failures.

**double-well potential**:
A quasi-potential with exactly two wells (two stable critical points) separated by one unstable critical point. Characterises two-state biological systems (e.g. AML: healthy → leukemic).
_Avoid_: bistable landscape (acceptable synonym in biological contexts)

**three-well potential**:
A quasi-potential with three wells (three stable critical points) separated by two unstable critical points. Characterises CML-like three-state progression (Early → Transition → Late).
_Avoid_: tristable landscape, tri-stable potential

**Langevin equation**:
The stochastic differential equation `dX_t = −∇U_p dt + √(2β⁻¹) dB_t` describing how the state variable moves in the quasi-potential under noise. β⁻¹ is the diffusion coefficient.
_Avoid_: equation of motion (too generic)

**diffusion coefficient**:
The noise parameter β⁻¹ in the Langevin and Fokker-Planck equations. The first longitudinal strategy estimates one constant diffusion coefficient from within-subject increments, with biological-unit uncertainty and adequacy checks for variation by state, time, or condition; it is never copied as a fixed value from the reference scripts. Unsupported constant diffusion yields an explicit adequacy result. State-, condition-, or time-dependent diffusion are separate future strategies.
_Avoid_: noise strength, stochastic amplitude

**mean squared displacement (MSD)**:
The empirical measure used to estimate the diffusion coefficient: `MSD(t) = ⟨|x(t) − x_mean|²⟩` computed over observed state-space trajectories.
_Avoid_: displacement variance

**Fokker-Planck equation**:
The deterministic PDE governing the time-evolution of probability density P(x,t) of the state variable: `∂P/∂t = −∂/∂x[∇U_p P] + β⁻¹ ∂²P/∂x²`. Solved numerically (via `deSolve` + `ReacTran`) to predict time-to-disease.
_Avoid_: FPE, diffusion equation, probability transport equation

**time-to-disease**:
The expected first-passage time from a subject's initial state-space position across the unstable critical point to the disease well, derived by integrating the Fokker-Planck solution forward in time.
_Avoid_: disease onset time, survival time (only for clinical comparison contexts)

**point of no return**:
The unstable critical point at which stochastic transitions become highly probable and the Fokker-Planck solution places most probability mass in the disease well. In the CML three-well landscape this is c₂ (Early-Transition state).
_Avoid_: tipping point (acceptable in non-technical explanations only)

**eigengene contribution**:
The sign and magnitude of a gene's eigengene on the disease axis, indicating whether the gene drives the system toward or away from the disease well. Pro-disease: positive contribution toward the disease well. Anti-disease: negative contribution (resisting progression).
_Avoid_: gene direction, gene effect

### Open thresholds (from ADR 0002 — filled by Stage 0)

- KDE bandwidth selection criterion: `[tbd]`
- Polynomial degree selection method: `[tbd]`
- Maximum tolerated error in recovered barrier height: `[tbd]`
- Minimum sample requirement for reliable estimation: `[tbd]`
