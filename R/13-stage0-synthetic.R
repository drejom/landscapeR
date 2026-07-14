# Stage 0 — Synthetic control generator
#
# Produces StateTransitionData objects with known ground truth for validating
# Stages 1 and 2.  Each synthetic control embeds a single shared gene-space
# direction (v_true) across K layers with independent noise.  The BBP signal
# threshold  (n*p)^(1/4)  separates the detectable and undetectable regimes.
#
# Primary entry points:
#
#   synthetic_control()   — build one synthetic control with a SubspaceGroundTruth
#   control_ladder()      — sweep a grid of (n, p, K, signal) configs
#
# The returned StateTransitionData has:
#   ground_truth        <- SubspaceGroundTruth(shared = v_true as 1-column matrix,
#                                              exclusive = list of per-layer v_spec,
#                                              angles = numeric(0))
#   metadata()$control  <- the generating parameters (reproducible)

# ---------------------------------------------------------------------------
# Single synthetic control
# ---------------------------------------------------------------------------

#' Generate one synthetic control dataset
#'
#' Each layer is  X_i = signal * outer(u_shared, v_true)
#'                     + signal_spec * outer(u_spec_i, v_spec_i) + noise.
#' Both u and v vectors are unit-norm, so \code{signal} is the true singular
#' value of the shared component.  The BBP detectability threshold at this
#' scale is \code{(n*p)^(1/4)}.
#'
#' @param n integer number of samples (columns in the omic matrix convention)
#' @param p integer number of features / genes per layer
#' @param K integer number of layers (>= 1)
#' @param signal numeric singular value of the shared component (must be > 0)
#' @param signal_spec numeric singular value of each layer-specific component
#' @param noise_sd numeric standard deviation of the additive i.i.d. Gaussian noise
#' @param seed integer RNG seed for reproducibility
#' @return \code{StateTransitionData} with \code{SubspaceGroundTruth}
#' @export
synthetic_control <- function(n        = 40L,
                               p        = 5000L,
                               K        = 2L,
                               signal      = 25,
                               signal_spec = 8,
                               noise_sd    = 1,
                               seed        = 42L) {
    stopifnot(
        is.numeric(n), n >= 2L,
        is.numeric(p), p >= 2L,
        is.numeric(K), K >= 1L,
        is.numeric(signal), signal > 0,
        is.numeric(noise_sd), noise_sd > 0
    )
    n <- as.integer(n); p <- as.integer(p); K <- as.integer(K)

    setup_rng(seed)

    # Shared gene direction and sample direction (same across all layers)
    v_true   <- .unit_rnorm(p)
    u_shared <- .unit_rnorm(n)

    # Per-layer matrices
    mats <- vector("list", K)
    v_specs <- vector("list", K)
    for (i in seq_len(K)) {
        # Layer-specific gene direction, orthogonal to v_true
        v_sp <- .unit_rnorm(p)
        v_sp <- .orthogonalize(v_sp, v_true)
        v_specs[[i]] <- v_sp
        # Layer-specific sample direction, orthogonal to u_shared
        u_sp <- .unit_rnorm(n)
        u_sp <- .orthogonalize(u_sp, u_shared)
        # Data matrix: rows = samples, cols = genes  (n x p)
        mats[[i]] <- signal      * outer(u_shared, v_true) +
                     signal_spec * outer(u_sp,     v_sp)   +
                     matrix(rnorm(n * p, sd = noise_sd), n, p)
    }

    # Wrap as SummarizedExperiment (features x samples, so transpose)
    sample_ids <- paste0("s", seq_len(n))
    feature_ids <- paste0("g", seq_len(p))
    expts <- lapply(seq_len(K), function(i) {
        mat <- t(mats[[i]])   # p x n (features x samples)
        rownames(mat) <- feature_ids
        colnames(mat) <- sample_ids
        SummarizedExperiment::SummarizedExperiment(assays = list(counts = mat))
    })
    names(expts) <- paste0("layer", seq_len(K))

    # colData: store the planted sample coordinate and a binary group label.
    # u_shared is the true shared sample direction; its sign defines "high" vs
    # "low" on the state-transition axis — the correct colour_by variable for plots.
    col_df <- S4Vectors::DataFrame(
        row.names     = sample_ids,
        u_shared      = u_shared,
        planted_group = ifelse(u_shared > 0, "high", "low")
    )

    gt <- new("SubspaceGroundTruth",
        shared    = matrix(v_true, ncol = 1L,
                           dimnames = list(NULL, "shared_axis")),
        exclusive = v_specs,
        angles    = numeric(0L)
    )

    bbp_thr <- (as.numeric(n) * as.numeric(p))^0.25
    ctrl_params <- list(
        n = n, p = p, K = K,
        signal = signal, signal_spec = signal_spec,
        noise_sd = noise_sd, seed = seed,
        bbp_threshold = bbp_thr,
        signal_above_bbp = signal > bbp_thr
    )

    std <- StateTransitionData(
        experiments     = expts,
        colData         = col_df,
        ground_truth    = gt,
        sampling_design = cross_sectional()
    )
    md <- metadata(std)
    md$control <- ctrl_params
    metadata(std) <- md

    std
}

# ---------------------------------------------------------------------------
# Generic K=1 cross-sectional double-well calibration control
# ---------------------------------------------------------------------------

#' Generate a K=1 expression control with a planted double-well coordinate
#'
#' Draws cross-sectional coordinates from the known double-well Langevin
#' control, embeds them along one planted feature direction in a single
#' high-dimensional expression matrix, and retains both subspace and potential
#' ground truth. This is a disclosed calibration/development control, never an
#' acceptance artifact (ADR 0016).
#'
#' @param n integer number of independent cross-sectional observations
#' @param p integer number of expression features
#' @param noise_sd numeric expression noise standard deviation
#' @param beta numeric inverse temperature for the double-well simulation
#' @param n_steps integer Langevin steps between collected observations
#' @param dt numeric Langevin integration step size
#' @param seed integer reproducibility seed
#' @return single-layer \code{StateTransitionData} with
#'   \code{K1DoubleWellGroundTruth}
#' @export
synthetic_k1_double_well_control <- function(n = 200L,
                                              p = 100L,
                                              noise_sd = 0.05,
                                              beta = 2,
                                              n_steps = 1000L,
                                              dt = 0.01,
                                              seed = 42L) {
    stopifnot(
        is.numeric(n), n >= 2L,
        is.numeric(p), p >= 2L,
        is.numeric(noise_sd), noise_sd > 0,
        is.numeric(beta), beta > 0,
        is.numeric(n_steps), n_steps >= 1L,
        is.numeric(dt), dt > 0
    )
    n <- as.integer(n)
    p <- as.integer(p)
    seed <- as.integer(seed)

    potential_control <- synthetic_potential_control(
        n = n,
        beta = beta,
        n_steps = n_steps,
        dt = dt,
        seed = seed
    )
    x_raw <- as.numeric(colData(potential_control)$x_coord)
    center_shift <- mean(x_raw)
    x_coord <- x_raw - center_shift

    # Use a separate deterministic stream for the expression observation model.
    setup_rng(seed + 1L)
    v_true <- .unit_rnorm(p)
    X <- outer(x_coord, v_true) +
        matrix(rnorm(n * p, sd = noise_sd), nrow = n, ncol = p)

    sample_ids <- paste0("s", seq_len(n))
    feature_ids <- paste0("g", seq_len(p))
    expression <- t(X)
    rownames(expression) <- feature_ids
    colnames(expression) <- sample_ids
    experiment <- SummarizedExperiment::SummarizedExperiment(
        assays = list(expression = expression)
    )

    col_df <- S4Vectors::DataFrame(
        row.names = sample_ids,
        x_coord = x_coord,
        source_x_coord = x_raw,
        well = ifelse(x_raw < 0, "left", "right")
    )

    subspace_truth <- new("SubspaceGroundTruth",
        shared = matrix(v_true, ncol = 1L,
                        dimnames = list(feature_ids, "target_axis")),
        exclusive = list(),
        angles = numeric(0L)
    )
    potential_truth <- new("PotentialGroundTruth",
        potential = function(x) ((x + center_shift)^2 - 1)^2,
        wells = matrix(
            c(-1 - center_shift, 0, 1 - center_shift, 0),
            ncol = 2L,
            byrow = TRUE,
            dimnames = list(c("left", "right"), c("x", "U"))
        ),
        barrier = 1
    )
    truth <- new("K1DoubleWellGroundTruth",
        subspace = subspace_truth,
        potential = potential_truth
    )

    std <- StateTransitionData(
        experiments = list(layer1 = experiment),
        colData = col_df,
        ground_truth = truth,
        sampling_design = cross_sectional()
    )
    md <- metadata(std)
    md$k1_double_well_control <- list(
        n = n,
        p = p,
        K = 1L,
        noise_sd = noise_sd,
        beta = beta,
        n_steps = as.integer(n_steps),
        dt = dt,
        seed = seed,
        expression_seed = seed + 1L,
        coordinate_center = center_shift,
        true_wells = c(-1 - center_shift, 1 - center_shift),
        true_barrier = -center_shift,
        true_barrier_height = 1,
        calibration_only = TRUE,
        evidence_status = "non_evidentiary_calibration"
    )
    metadata(std) <- md
    std
}

#' Run the generic K=1 double-well calibration path
#'
#' Runs the registered single-layer SVD and cross-sectional dynamics strategy
#' on one disclosed synthetic control. The return value contains recovery
#' diagnostics but deliberately contains no acceptance/pass judgement.
#'
#' @inheritParams synthetic_k1_double_well_control
#' @param decomposer character registered K=1 Decomposer name
#' @param dynamics_estimator character registered cross-sectional
#'   DynamicsEstimator name
#' @return named list of labelled non-evidentiary calibration diagnostics
#' @export
k1_double_well_calibration <- function(n = 200L,
                                        p = 100L,
                                        noise_sd = 0.05,
                                        beta = 2,
                                        n_steps = 1000L,
                                        dt = 0.01,
                                        seed = 42L,
                                        decomposer = "svd",
                                        dynamics_estimator = "kde_logdensity") {
    std <- synthetic_k1_double_well_control(
        n = n,
        p = p,
        noise_sd = noise_sd,
        beta = beta,
        n_steps = n_steps,
        dt = dt,
        seed = seed
    )
    evidence_status <- metadata(std)$k1_double_well_control$evidence_status

    decomposition_result <- decompose(get_strategy("Decomposer", decomposer)(), std)
    if (decomposition_result@status != "success")
        return(list(
            status = "failure",
            evidence_status = evidence_status,
            decomposer = decomposer,
            dynamics_estimator = dynamics_estimator,
            reason = decomposition_result@reason
        ))

    decomposed <- decomposition_result@value
    stage1 <- metadata(decomposed)$stage1
    v_true <- std@ground_truth@subspace@shared[, 1L]
    v_hat <- shared_axis(stage1)
    cosine <- sum(v_true * v_hat) /
        (sqrt(sum(v_true^2)) * sqrt(sum(v_hat^2)))
    cosine_abs <- min(1, abs(cosine))
    subspace_angle <- acos(cosine_abs) * 180 / pi

    # Component sign is mathematically arbitrary. Synthetic truth supplies the
    # calibration orientation until the real-data proposal workflow exists.
    orientation <- if (cosine < 0) -1 else 1
    if (orientation < 0) {
        V_k <- dr_V_k(stage1)
        V_k[, 1L] <- -V_k[, 1L]
        coords_k <- dr_coords_k(stage1)
        coords_k[[1L]][, 1L] <- -coords_k[[1L]][, 1L]
        stage1 <- DecompositionResult(
            V_star = V_k[, 1L],
            sigma = dr_sigma(stage1),
            coords = list(drop(coords_k[[1L]][, 1L])),
            warnings = dr_warnings(stage1),
            V_k = V_k,
            sigma_k = dr_sigma_k(stage1),
            coords_k = coords_k,
            k = dr_k(stage1)
        )
        md <- metadata(decomposed)
        md$stage1 <- stage1
        metadata(decomposed) <- md
    }

    dynamics_result <- estimate_dynamics(
        get_strategy("DynamicsEstimator", dynamics_estimator)(),
        decomposed
    )
    if (dynamics_result@status != "success")
        return(list(
            status = "failure",
            evidence_status = evidence_status,
            decomposer = decomposer,
            dynamics_estimator = dynamics_estimator,
            subspace_angle_deg = subspace_angle,
            reason = dynamics_result@reason
        ))

    stage2 <- metadata(dynamics_result@value)$stage2
    control <- metadata(std)$k1_double_well_control
    well_error <- if (length(stage2$wells) >= 2L) {
        mean(vapply(control$true_wells, function(well) {
            min(abs(stage2$wells - well))
        }, numeric(1L)))
    } else {
        NA_real_
    }
    barrier_error <- if (length(stage2$barriers) >= 1L) {
        min(abs(stage2$barriers - control$true_barrier))
    } else {
        NA_real_
    }
    barrier_heights <- unlist(lapply(
        stage2$barrier_heights,
        function(height) height[!is.na(height)]
    ))
    barrier_height_error <- if (length(barrier_heights)) {
        min(abs(barrier_heights - control$true_barrier_height))
    } else {
        NA_real_
    }

    list(
        status = "success",
        evidence_status = evidence_status,
        decomposer = decomposer,
        dynamics_estimator = dynamics_estimator,
        seed = as.integer(seed),
        subspace_angle_deg = subspace_angle,
        orientation_flipped = orientation < 0,
        well_error = well_error,
        barrier_error = barrier_error,
        barrier_height_error = barrier_height_error,
        n_wells_found = length(stage2$wells),
        n_barriers_found = length(stage2$barriers)
    )
}

# ---------------------------------------------------------------------------
# Recovery benchmark: run Stage 1 on a synthetic control and measure angle
# ---------------------------------------------------------------------------

#' Measure Stage 1 subspace recovery on a synthetic control
#'
#' Runs \code{decompose()} with the given strategy and computes the principal
#' angle between the recovered shared axis and the ground-truth shared axis.
#'
#' @param std \code{StateTransitionData} from \code{synthetic_control()}
#' @param strategy_name character name registered under the "Decomposer" contract
#' @return named list: angle_deg, signal_above_bbp, elapsed_sec, warnings
#' @export
recovery_benchmark <- function(std, strategy_name = "hogsvd_averaged") {
    if (is.null(std@ground_truth))
        stop("recovery_benchmark() requires a synthetic control with ground truth")

    ctor     <- get_strategy("Decomposer", strategy_name)
    strategy <- ctor()

    t0  <- proc.time()
    res <- withCallingHandlers(
        decompose(strategy, std),
        warning = function(w) { invokeRestart("muffleWarning") }
    )
    elapsed <- (proc.time() - t0)[["elapsed"]]

    if (res@status != "success")
        return(list(angle_deg = NA_real_, elapsed_sec = elapsed,
                    signal_above_bbp = NA, warnings = res@reason))

    v_true    <- std@ground_truth@shared[, 1L]
    v_hat     <- shared_axis(metadata(res@value)$stage1)
    cos_angle <- min(1, abs(sum(v_true * v_hat) /
                            (sqrt(sum(v_true^2)) * sqrt(sum(v_hat^2)))))
    angle_deg <- acos(cos_angle) * 180 / pi

    list(
        angle_deg        = angle_deg,
        signal_above_bbp = metadata(std)$control$signal_above_bbp,
        elapsed_sec      = elapsed,
        warnings         = dr_warnings(metadata(res@value)$stage1)
    )
}

# ---------------------------------------------------------------------------
# Control ladder: structured sweep
# ---------------------------------------------------------------------------

#' Run the Stage 1 control ladder
#'
#' Sweeps a grid of (n, p, K, signal) configurations and records recovery
#' angle and timing for each combination.
#'
#' @param ns integer vector of sample sizes
#' @param ps integer vector of feature counts (genes per layer)
#' @param Ks integer vector of layer counts
#' @param signals numeric vector of signal singular values to test
#' @param strategy_name character Decomposer strategy to benchmark
#' @param seed integer base seed (incremented per config)
#' @return data.frame with columns n, p, K, signal, bbp_threshold,
#'   signal_above_bbp, angle_deg, elapsed_sec
#' @export
control_ladder <- function(ns      = c(20L, 40L),
                           ps      = c(500L, 5000L),
                           Ks      = c(2L, 3L),
                           signals = c(10, 20, 30, 50),
                           strategy_name = "hogsvd_averaged",
                           seed    = 42L) {
    grid <- expand.grid(n = ns, p = ps, K = Ks, signal = signals,
                        stringsAsFactors = FALSE)

    rows <- vector("list", nrow(grid))
    for (i in seq_len(nrow(grid))) {
        cfg <- grid[i, ]
        std <- synthetic_control(
            n    = cfg$n, p = cfg$p, K = cfg$K,
            signal = cfg$signal, signal_spec = cfg$signal / 3,
            seed = seed + i
        )
        bm <- recovery_benchmark(std, strategy_name)
        rows[[i]] <- data.frame(
            n                = cfg$n,
            p                = cfg$p,
            K                = cfg$K,
            signal           = cfg$signal,
            bbp_threshold    = round(metadata(std)$control$bbp_threshold, 2),
            signal_above_bbp = bm$signal_above_bbp,
            angle_deg        = round(bm$angle_deg, 2),
            elapsed_sec      = round(bm$elapsed_sec, 3),
            stringsAsFactors = FALSE
        )
    }
    do.call(rbind, rows)
}

# ---------------------------------------------------------------------------
# Stage 0 — Potential control (Stage 2 validation)
# ---------------------------------------------------------------------------

#' Generate a synthetic potential control via Langevin simulation
#'
#' Simulates samples from the double-well potential \eqn{U(x) = (x^2 - 1)^2}
#' using Euler-Maruyama integration of the overdamped Langevin equation
#' \eqn{dX_t = -U'(X_t) dt + \sqrt{2\beta^{-1}} dW_t}.
#' Samples are wrapped as a \code{StateTransitionData} with a
#' \code{PotentialGroundTruth} recording the known well locations,
#' barrier position, and barrier height.
#'
#' The ground truth for this potential:
#' - Wells at x = ±1 (minima of U)
#' - Barrier at x = 0 (maximum of U between wells)
#' - Barrier height = U(0) - U(1) = 1
#'
#' @param n integer number of samples to collect
#' @param beta numeric inverse temperature (higher = sharper wells, default 2)
#' @param n_steps integer Euler-Maruyama steps per sample (default 5000)
#' @param dt numeric step size (default 0.01)
#' @param seed integer RNG seed
#' @return \code{StateTransitionData} with \code{PotentialGroundTruth} and
#'   \code{metadata()$potential_control} carrying generating parameters.
#'   The single experiment "coords" has one feature row: the simulated x values.
#'   \code{colData} carries \code{x_coord} and \code{well} ("left"/"right").
#' @export
synthetic_potential_control <- function(n       = 100L,
                                         beta    = 2,
                                         n_steps = 5000L,
                                         dt      = 0.01,
                                         seed    = 42L) {
    setup_rng(seed)

    U_prime <- function(x) 4 * x * (x^2 - 1)   # dU/dx for U = (x^2-1)^2
    noise_sd <- sqrt(2 / beta * dt)

    # Burn-in: start from left well, run long chain, then subsample.
    # Streamed rather than materialised in full: only the n_steps-spaced
    # samples after burn-in are ever read, so we capture directly into a
    # length-n buffer instead of allocating an O(n * n_steps) vector
    # (issue #15). Sample k lands on iteration n_burn + k * n_steps, matching
    # the previous `idx <- n_burn + seq_len(n) * as.integer(n_steps)` stride
    # exactly. The RNG call pattern (one rnorm(1L, ...) per step) is
    # unchanged, so the random stream — and therefore x_samp — is identical.
    n_burn    <- 2000L
    n_stepsi  <- as.integer(n_steps)
    n_total   <- n_burn + n * n_stepsi
    x         <- -1                               # start at left well
    x_samp    <- numeric(n)
    sample_i  <- 0L
    for (i in seq_len(n_total)) {
        x <- x - U_prime(x) * dt + rnorm(1L, sd = noise_sd)
        if (i > n_burn && (i - n_burn) %% n_stepsi == 0L) {
            sample_i <- sample_i + 1L
            x_samp[sample_i] <- x
            if (sample_i >= n) break
        }
    }

    sample_ids <- paste0("s", seq_len(n))
    mat        <- matrix(x_samp, nrow = 1L, ncol = n,
                         dimnames = list("x_coord", sample_ids))
    expt <- SummarizedExperiment::SummarizedExperiment(
        assays = list(coords = mat))

    col_df <- S4Vectors::DataFrame(
        row.names = sample_ids,
        x_coord   = x_samp,
        well      = ifelse(x_samp < 0, "left", "right")
    )

    gt <- new("PotentialGroundTruth",
        potential = function(x) (x^2 - 1)^2,
        wells     = matrix(c(-1, 0, 1, 0), ncol = 2L,
                           dimnames = list(c("left", "right"), c("x", "U"))),
        barrier   = 1
    )

    ctrl_params <- list(n = n, beta = beta, n_steps = n_steps,
                        dt = dt, seed = seed,
                        true_wells = c(-1, 1), true_barrier = 0,
                        true_barrier_height = 1)

    std <- StateTransitionData(
        experiments     = list(coords = expt),
        colData         = col_df,
        ground_truth    = gt,
        sampling_design = cross_sectional()
    )
    md <- metadata(std)
    md$potential_control <- ctrl_params
    metadata(std) <- md

    std
}

#' Measure Stage 2 quasi-potential recovery on a synthetic potential control
#'
#' Runs Stage 2 directly on the simulated coordinate samples and measures
#' how accurately the recovered well locations and barrier height match
#' the known ground truth of the double-well potential \eqn{U(x) = (x^2-1)^2}.
#'
#' @param std \code{StateTransitionData} from \code{synthetic_potential_control()}
#' @param strategy_name character name registered under "DynamicsEstimator"
#' @return named list: well_error (mean absolute error in well x-positions),
#'   barrier_error (abs error in barrier x-position), barrier_height_error
#'   (abs error in barrier height), n_wells_found, n_barriers_found,
#'   elapsed_sec
#' @export
potential_recovery_benchmark <- function(std,
                                          strategy_name = "kde_logdensity") {
    if (is.null(std@ground_truth) ||
        !is(std@ground_truth, "PotentialGroundTruth"))
        stop("potential_recovery_benchmark() requires a PotentialGroundTruth object")

    ctrl <- metadata(std)$potential_control
    if (is.null(ctrl))
        stop("potential_recovery_benchmark() requires metadata()$potential_control")

    # Inject Stage 1 stub: coords are the raw x samples
    x_samp <- colData(std)$x_coord
    md <- metadata(std)
    md$stage1 <- DecompositionResult(
        V_star   = rep(1, 1L),
        sigma    = 1,
        coords   = list(x_samp),
        warnings = character(0),
        V_k      = matrix(1, nrow = 1L, ncol = 1L),
        sigma_k  = matrix(1, nrow = 1L, ncol = 1L),
        coords_k = list(matrix(x_samp, ncol = 1L)),
        k        = 1L
    )
    metadata(std) <- md

    ctor     <- get_strategy("DynamicsEstimator", strategy_name)
    strategy <- ctor()

    t0  <- proc.time()
    res <- estimate_dynamics(strategy, std)
    elapsed <- (proc.time() - t0)[["elapsed"]]

    if (res@status != "success")
        return(list(well_error = NA_real_, barrier_error = NA_real_,
                    barrier_height_error = NA_real_,
                    n_wells_found = 0L, n_barriers_found = 0L,
                    elapsed_sec = elapsed, reason = res@reason))

    s2 <- metadata(res@value)$stage2

    # Compare recovered vs true
    true_wells   <- ctrl$true_wells        # c(-1, 1)
    true_barrier <- ctrl$true_barrier      # 0
    true_bh      <- ctrl$true_barrier_height  # 1

    # Well error: match each true well to nearest recovered well
    well_error <- if (length(s2$wells) >= 2L) {
        mean(vapply(true_wells, function(w)
            min(abs(s2$wells - w)), numeric(1L)))
    } else NA_real_

    barrier_error <- if (length(s2$barriers) >= 1L)
        min(abs(s2$barriers - true_barrier))
    else NA_real_

    bh_found <- unlist(lapply(s2$barrier_heights, function(h) h[!is.na(h)]))
    barrier_height_error <- if (length(bh_found) >= 1L)
        min(abs(bh_found - true_bh))
    else NA_real_

    list(
        well_error           = well_error,
        barrier_error        = barrier_error,
        barrier_height_error = barrier_height_error,
        n_wells_found        = length(s2$wells),
        n_barriers_found     = length(s2$barriers),
        elapsed_sec          = elapsed
    )
}

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

.unit_rnorm <- function(d) {
    x <- rnorm(d)
    x / sqrt(sum(x^2))
}

.orthogonalize <- function(v, ref) {
    v <- v - sum(v * ref) * ref
    v / sqrt(sum(v^2))
}
