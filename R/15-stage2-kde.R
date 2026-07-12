# Stage 2 — Log-density inversion with constrained polynomial smoothing
#
# Strategy: "kde_logdensity"
#
# Algorithm (follows Rockne-Frankhouser CML_Potentials.m):
#   1. Pool Stage 1 state-transition axis coordinates across all K layers
#   2. KDE with plug-in bandwidth (ks::hpi)
#   3. Evaluate p(x) on a grid; U(x) = -log p(x)
#   4. Find critical points via zero-crossings of dU/dx (= -d/dx log p)
#   5. Classify: local minima -> wells, local maxima -> barriers
#   6. Constrained polynomial smooth (degree poly_degree): simultaneously
#      satisfies F(x_i) = U(x_i) and dF/dx|_{x_i} = 0 at critical points
#   7. Write metadata()$stage2: x, U, U_poly, wells, barriers, barrier_heights
#
# Constrained polynomial is optional (requires >= 2 critical points); when
# fewer are found the raw KDE-based U(x) is returned as both U and U_poly.

# ---------------------------------------------------------------------------
# Strategy class and method
# ---------------------------------------------------------------------------

#' @rdname estimate_dynamics
#' @export
setClass("KdeLogDensityEstimator",
    contains  = "DynamicsEstimator",
    representation(params = "list")
)

#' @rdname estimate_dynamics
setMethod(".estimate_dynamics_impl",
    signature("KdeLogDensityEstimator", "StateTransitionData"),
    function(strategy, data, ...) {
        # `data` has already passed validate_boundary() -- enforced
        # structurally by the DynamicsEstimator-level estimate_dynamics()
        # method in R/08-contracts.R. This strategy only implements its own
        # logic.

        input_hashes <- c(data = digest::digest(data))
        s1 <- metadata(data)$stage1
        if (is.null(s1))
            return(stage_failure(
                "estimate_dynamics: Stage 1 has not been run. Call decompose() first."))

        # Parameters with defaults
        p         <- modifyList(list(n_grid = 512L, poly_degree = 6L,
                                     layer = 1L, pool_layers = TRUE,
                                     component = 1L),
                                strategy@params)

        # Collect state-transition axis coordinates for the chosen component
        comp <- as.integer(p$component)
        k_avail <- dr_k(s1)
        if (comp < 1L || comp > k_avail)
            return(stage_failure(paste0(
                "estimate_dynamics: component ", comp,
                " requested but only ", k_avail,
                " components available (dr_k = ", k_avail, ")")))
        coords_list <- lapply(dr_coords_k(s1), function(m) drop(m[, comp]))
        if (isTRUE(p$pool_layers)) {
            x_obs <- unlist(coords_list)
        } else {
            idx   <- min(as.integer(p$layer), length(coords_list))
            x_obs <- coords_list[[idx]]
        }
        x_obs <- as.numeric(x_obs)

        if (length(x_obs) < 5L)
            return(stage_failure(
                "estimate_dynamics: fewer than 5 coordinate values -- cannot fit KDE."))

        # KDE with plug-in bandwidth
        h   <- ks::hpi(x_obs)
        kde <- ks::kde(x_obs, h = h,
                       eval.points = seq(min(x_obs) - 2 * h,
                                         max(x_obs) + 2 * h,
                                         length.out = p$n_grid))
        x_grid <- kde$eval.points
        p_grid <- pmax(kde$estimate, .Machine$double.eps)   # guard against log(0)
        U_grid <- -log(p_grid)

        # Critical points: zero-crossings of dU/dx
        dU <- diff(U_grid) / diff(x_grid)
        x_mid <- (x_grid[-1L] + x_grid[-length(x_grid)]) / 2
        sign_changes <- which(diff(sign(dU)) != 0L)

        wells    <- numeric(0)
        barriers <- numeric(0)

        for (idx in sign_changes) {
            x_cp <- x_mid[idx]
            # Refine via linear interpolation
            x_cp <- x_mid[idx] - dU[idx] * (x_mid[idx + 1L] - x_mid[idx]) /
                                             (dU[idx + 1L] - dU[idx])
            x_cp <- max(x_grid[1L], min(x_grid[length(x_grid)], x_cp))
            # Classify: if dU goes - -> +, it's a minimum (well); + -> - is maximum (barrier)
            if (dU[idx] < 0 && dU[idx + 1L] > 0) {
                wells <- c(wells, x_cp)
            } else if (dU[idx] > 0 && dU[idx + 1L] < 0) {
                barriers <- c(barriers, x_cp)
            }
        }

        # Constrained polynomial smooth
        U_poly <- .fit_constrained_poly(x_grid, U_grid, wells, barriers,
                                         degree = p$poly_degree)

        # Barrier heights: U(barrier) - U(adjacent well)  [on smoothed curve]
        U_at <- function(xv) approx(x_grid, U_poly, xv)$y
        barrier_heights <- lapply(barriers, function(b) {
            left_wells  <- wells[wells < b]
            right_wells <- wells[wells > b]
            h_left  <- if (length(left_wells))  U_at(b) - U_at(left_wells[length(left_wells)])  else NA_real_
            h_right <- if (length(right_wells)) U_at(b) - U_at(right_wells[1L])                 else NA_real_
            c(left = h_left, right = h_right)
        })
        if (length(barriers))
            names(barrier_heights) <- paste0("barrier_", seq_along(barriers))

        s2 <- list(
            x               = x_grid,
            U               = U_poly,
            U_raw           = U_grid,
            wells           = wells,
            barriers        = barriers,
            barrier_heights = barrier_heights,
            h_bandwidth     = h,
            n_obs           = length(x_obs),
            params          = p
        )

        md <- metadata(data)
        md$stage2 <- s2
        metadata(data) <- md

        data <- record_provenance(data, "estimate_dynamics", "DynamicsEstimator",
                    "kde_logdensity",
                    params = c(list(n = length(x_obs)), p),
                    input_hashes = input_hashes)
        prov_step <- data@provenance[[length(data@provenance)]]

        stage_success(data, provenance = list(prov_step))
    }
)

# ---------------------------------------------------------------------------
# Constrained polynomial fit
# ---------------------------------------------------------------------------

# Fit a polynomial of given degree such that it simultaneously interpolates
# U(x_i) at critical points and has zero derivative there.
# Falls back to unconstrained polynomial when fewer than 2 critical points exist.
.fit_constrained_poly <- function(x_grid, U_grid, wells, barriers, degree = 6L) {
    cps <- sort(c(wells, barriers))
    if (length(cps) < 2L) return(U_grid)

    # Build the Vandermonde-style design matrix for the constraint system:
    #   value constraints:     poly(x_i, degree) . coef = U(x_i)
    #   derivative constraints: d/dx poly(x_i, degree) . coef = 0
    U_at_cp <- approx(x_grid, U_grid, cps)$y
    if (anyNA(U_at_cp)) return(U_grid)

    # Scale x to [-1, 1] for numerical stability
    xr  <- range(x_grid)
    scl <- function(x) 2 * (x - xr[1]) / (xr[2] - xr[1]) - 1

    xs  <- scl(x_grid)
    xcs <- scl(cps)

    # Value rows
    V <- outer(xcs, 0:degree, `^`)           # n_cp x (degree+1)
    # Derivative rows: d/dx x^k = k * x^(k-1), scaled by 2/(xr[2]-xr[1])
    dscl <- 2 / (xr[2] - xr[1])
    Vd   <- outer(xcs, 0:degree,
                  function(x, k) ifelse(k == 0, 0, k * x^(k - 1L) * dscl))

    lhs <- rbind(V, Vd)
    rhs <- c(U_at_cp, rep(0, length(cps)))

    # Least-squares solve (over-determined system)
    coef <- tryCatch(
        qr.solve(lhs, rhs),
        error = function(e) NULL
    )
    if (is.null(coef)) return(U_grid)

    poly_vals <- as.vector(outer(xs, 0:degree, `^`) %*% coef)
    poly_vals
}

# ---------------------------------------------------------------------------
# Sampling-design capability
# ---------------------------------------------------------------------------

#' @rdname estimate_dynamics
#' @export
setMethod("supported_sampling_designs",
    signature("KdeLogDensityEstimator"),
    function(strategy) "cross_sectional"
)

# ---------------------------------------------------------------------------
# Registration
# ---------------------------------------------------------------------------

register_strategy("DynamicsEstimator", "kde_logdensity",
    function(params = list()) new("KdeLogDensityEstimator", params = params))
