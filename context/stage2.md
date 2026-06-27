# Stage 2 — Quasi-potential dynamics

Stage 2 takes the disease-axis coordinates from Stage 1 and fits a quasi-potential landscape: U(x) = −log p(x). It locates critical points, quantifies barrier heights, and optionally solves the Fokker-Planck equation to predict time-to-disease. It generalises the Rockne-Frankhouser MATLAB pipeline from single-layer SVD to multi-layer GSVD/HO-GSVD coordinates.

## Language

**quasi-potential**:
The scalar energy function U(x) = −log p(x) derived by log-density inversion of the empirical distribution of state-space coordinates. Local minima are stable states; local maxima are unstable transition boundaries. Not a physical potential — has no physical units.
_Avoid_: potential energy, energy landscape, attractor landscape, effective potential (use only when specifically referring to the ODE-derived theoretical potential from Frankhouser2024)

**log-density inversion**:
The Stage 2 estimation approach: estimate p(x) by KDE on the state-space coordinates, then compute U(x) = −log p(x). The primary estimation strategy.
_Avoid_: KDE-based potential, negative log-density

**KDE**:
Kernel density estimation — the non-parametric method used to estimate p(x) from the distribution of state-space coordinates. Bandwidth selection is a configurable parameter, not a hardcoded value.
_Avoid_: kernel smoothing (too generic)

**polynomial smoothing**:
Fitting a polynomial whose derivative has zeros at the estimated critical point locations, applied to smooth the KDE-derived quasi-potential. Polynomial degree is configurable; not hardcoded.
_Avoid_: polynomial fit, spline smoothing

**critical point**:
A location x* where ∇U(x*) = 0. Either stable (a well) or unstable (a barrier peak). Found by automated zero-finding of the KDE derivative — never by visual inspection or hardcoded coordinates.
_Avoid_: fixed point (reserve for ODE contexts), equilibrium (ambiguous)

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
A stable region around a stable critical point — the basin of attraction of a disease state. The depth and width of a well reflect how stable that disease state is.
_Avoid_: basin, attractor basin

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
The noise parameter β⁻¹ in the Langevin and Fokker-Planck equations. Estimated from the mean squared displacement of state-space trajectories. Controls how rapidly the system fluctuates.
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
