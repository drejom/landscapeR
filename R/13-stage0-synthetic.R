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
#' @param K integer number of layers (>= 2)
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
        is.numeric(K), K >= 2L,
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

    col_df <- S4Vectors::DataFrame(row.names = sample_ids)

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
        experiments  = expts,
        colData      = col_df,
        ground_truth = gt
    )
    md <- metadata(std)
    md$control <- ctrl_params
    metadata(std) <- md

    std
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
    v_hat     <- metadata(res@value)$stage1$V_star
    cos_angle <- min(1, abs(sum(v_true * v_hat) /
                            (sqrt(sum(v_true^2)) * sqrt(sum(v_hat^2)))))
    angle_deg <- acos(cos_angle) * 180 / pi

    list(
        angle_deg        = angle_deg,
        signal_above_bbp = metadata(std)$control$signal_above_bbp,
        elapsed_sec      = elapsed,
        warnings         = metadata(res@value)$stage1$warnings
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
