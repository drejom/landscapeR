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

.kde_logdensity_params <- function(params) {
    defaults <- list(
        n_grid = 512L,
        poly_degree = 6L,
        layer = 1L,
        pool_layers = TRUE,
        component = 1L,
        bandwidth_method = "hpi",
        bandwidth_value = NULL
    )
    p <- modifyList(defaults, params)
    whole_scalar <- function(value, minimum) {
        if (!is.numeric(value) || length(value) != 1L || is.na(value) ||
            !is.finite(value))
            return(FALSE)
        integer_value <- suppressWarnings(as.integer(value))
        !is.na(integer_value) && value == integer_value && value >= minimum
    }

    if (!whole_scalar(p$n_grid, 3L))
        return(list(error = "estimate_dynamics: n_grid must be one integer >= 3."))
    if (!whole_scalar(p$poly_degree, 1L))
        return(list(error = "estimate_dynamics: poly_degree must be one integer >= 1."))
    if (!whole_scalar(p$layer, 1L))
        return(list(error = "estimate_dynamics: layer must be one positive integer."))
    if (!whole_scalar(p$component, 1L))
        return(list(error = "estimate_dynamics: component must be one positive integer."))
    if (!is.logical(p$pool_layers) || length(p$pool_layers) != 1L ||
        is.na(p$pool_layers))
        return(list(error = "estimate_dynamics: pool_layers must be TRUE or FALSE."))
    if (!is.character(p$bandwidth_method) || length(p$bandwidth_method) != 1L ||
        is.na(p$bandwidth_method) ||
        !p$bandwidth_method %in% c("hpi", "explicit"))
        return(list(error = paste0(
            "estimate_dynamics: bandwidth_method must be 'hpi' or 'explicit'."
        )))

    if (identical(p$bandwidth_method, "explicit")) {
        if (!is.numeric(p$bandwidth_value) || length(p$bandwidth_value) != 1L ||
            is.na(p$bandwidth_value) || !is.finite(p$bandwidth_value) ||
            p$bandwidth_value <= 0)
            return(list(error = paste0(
                "estimate_dynamics: bandwidth_value must be one finite positive ",
                "number when bandwidth_method = 'explicit'."
            )))
        p$bandwidth_value <- as.numeric(p$bandwidth_value)
    } else if (!is.null(p$bandwidth_value)) {
        return(list(error = paste0(
            "estimate_dynamics: bandwidth_value must be NULL when ",
            "bandwidth_method = 'hpi'."
        )))
    }

    p$n_grid <- as.integer(p$n_grid)
    p$poly_degree <- as.integer(p$poly_degree)
    p$layer <- as.integer(p$layer)
    p$component <- as.integer(p$component)
    list(params = p)
}

#' @rdname estimate_dynamics
setMethod(".estimate_dynamics_impl",
    signature("KdeLogDensityEstimator", "StateTransitionData"),
    function(strategy, data, ...) {
        # `data` has already passed validate_boundary() -- enforced
        # structurally by the DynamicsEstimator-level estimate_dynamics()
        # method in R/08-contracts.R. This strategy only implements its own
        # logic.

        s1 <- stage_result(data, "stage1", required = FALSE)
        if (is.null(s1))
            return(stage_failure(
                "estimate_dynamics: Stage 1 has not been run. Call decompose() first."))
        input_hashes <- c(stage1_result = digest::digest(s1))

        normalized <- .kde_logdensity_params(strategy@params)
        if (!is.null(normalized$error))
            return(stage_failure(normalized$error))
        p <- normalized$params

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
            p$layer <- idx
        }
        x_obs <- as.numeric(x_obs)

        if (length(x_obs) < 5L)
            return(stage_failure(
                "estimate_dynamics: fewer than 5 coordinate values -- cannot fit KDE."))
        if (any(!is.finite(x_obs)) || length(unique(x_obs)) < 2L ||
            !is.finite(diff(range(x_obs))) || diff(range(x_obs)) <= 0)
            return(stage_failure(paste0(
                "estimate_dynamics: coordinate support must contain at least two ",
                "distinct finite values with a finite positive range."
            )))

        # KDE with a declared plug-in or explicit sweep bandwidth.
        if (identical(p$bandwidth_method, "hpi")) {
            h <- tryCatch(
                ks::hpi(x_obs),
                error = function(error) NULL
            )
            if (!is.numeric(h) || length(h) != 1L || !is.finite(h) || h <= 0)
                return(stage_failure(paste0(
                    "estimate_dynamics: KDE bandwidth selection failed for ",
                    "bandwidth_method = 'hpi'."
                )))
            h <- as.numeric(h)
        } else {
            h <- p$bandwidth_value
        }
        p$bandwidth_value <- h

        eval_points <- tryCatch(
            seq(
                min(x_obs) - 2 * h,
                max(x_obs) + 2 * h,
                length.out = p$n_grid
            ),
            error = function(error) NULL
        )
        if (!is.numeric(eval_points) || length(eval_points) != p$n_grid ||
            any(!is.finite(eval_points)))
            return(stage_failure(
                "estimate_dynamics: KDE evaluation grid is not finite."))
        kde <- tryCatch(
            ks::kde(x_obs, h = h, eval.points = eval_points),
            error = function(error) NULL
        )
        if (is.null(kde) || !is.numeric(kde$eval.points) ||
            !is.numeric(kde$estimate) ||
            length(kde$eval.points) != p$n_grid ||
            length(kde$estimate) != p$n_grid ||
            any(!is.finite(kde$eval.points)) || any(!is.finite(kde$estimate)))
            return(stage_failure(
                "estimate_dynamics: KDE density estimation failed."))
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
            bandwidth_method = p$bandwidth_method,
            bandwidth_value = h,
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
