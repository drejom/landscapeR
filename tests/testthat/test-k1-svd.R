test_that("synthetic_control supports one omic layer", {
    std <- synthetic_control(n = 12L, p = 30L, K = 1L,
                             signal = 40, seed = 101L)

    expect_s4_class(std, "StateTransitionData")
    expect_s4_class(std@ground_truth, "SubspaceGroundTruth")
    expect_length(experiments(std), 1L)
    expect_identical(names(experiments(std)), "layer1")
    expect_length(std@ground_truth@exclusive, 1L)
    expect_identical(metadata(std)$control$K, 1L)
    expect_length(std@provenance, 1L)
    expect_identical(std@provenance[[1L]]@implementation,
                     "single_omic_layer_subspace")
    expect_identical(std@sampling_design@kind, "cross_sectional")
})

test_that("synthetic_control typed-fails invalid public inputs", {
    invalid_calls <- list(
        function() synthetic_control(K = 1.5),
        function() synthetic_control(n = c(12L, 13L)),
        function() synthetic_control(signal_spec = "large"),
        function() synthetic_control(seed = NA_integer_)
    )

    for (invalid_call in invalid_calls) {
        expect_error(invalid_call(), class = "landscapeR_validation_error")
    }
})

test_that("developmental branching control carries reproducible known truth", {
    control_1 <- synthetic_branching_control(
        n_per_stage = 8L, p = 40L, noise_sd = 0.03, seed = 120L
    )
    control_2 <- synthetic_branching_control(
        n_per_stage = 8L, p = 40L, noise_sd = 0.03, seed = 120L
    )

    expect_identical(control_1, control_2)
    expect_s4_class(control_1@ground_truth, "SubspaceGroundTruth")
    expect_equal(dim(control_1@ground_truth@shared), c(40L, 2L))
    expect_equal(dim(assay(experiments(control_1)[[1L]])), c(40L, 40L))
    expect_identical(control_1@sampling_design@kind, "cross_sectional")
    expect_identical(
        metadata(control_1)$branching_control$sampling,
        "independent_destructive"
    )
    expect_identical(
        control_1@provenance[[1L]]@implementation,
        "developmental_branching"
    )
    expect_equal(
        as.numeric(crossprod(control_1@ground_truth@shared[, 1L],
                             control_1@ground_truth@shared[, 2L])),
        0,
        tolerance = 1e-12
    )
})

test_that("developmental branching control exposes the planted divergence", {
    control <- synthetic_branching_control(
        n_per_stage = 30L, p = 30L, noise_sd = 0.03, seed = 121L
    )
    metadata_df <- as.data.frame(colData(control))
    early <- metadata_df$observed_stage <=
        metadata(control)$branching_control$branch_point
    late <- metadata_df$observed_stage == max(metadata_df$observed_stage)

    expect_lt(stats::sd(metadata_df$branch_coord[early]), 0.12)
    late_branch <- droplevels(metadata_df$terminal_branch[late])
    expect_gt(
        abs(diff(tapply(metadata_df$branch_coord[late], late_branch, mean))),
        2
    )
    expect_true(all(metadata_df$terminal_branch[early] == "shared early state"))
})

test_that("developmental branching control typed-fails invalid public inputs", {
    invalid_calls <- list(
        function() synthetic_branching_control(n_per_stage = 1L),
        function() synthetic_branching_control(p = 1L),
        function() synthetic_branching_control(noise_sd = 0),
        function() synthetic_branching_control(branch_point = 1),
        function() synthetic_branching_control(seed = .Machine$integer.max)
    )

    for (invalid_call in invalid_calls)
        expect_error(invalid_call(), class = "landscapeR_validation_error")
})

test_that("registered svd decomposes one omic layer into the common result contract", {
    expect_true("Decomposer:svd" %in% list_strategies("Decomposer"))

    std <- synthetic_control(n = 12L, p = 30L, K = 1L,
                             signal = 40, seed = 102L)
    ctor <- get_strategy("Decomposer", "svd")
    result <- suppressWarnings(decompose(ctor(), std))

    expect_s4_class(result, "StageResult")
    expect_identical(result@status, "success")
    expect_s4_class(metadata(result@value)$stage1, "DecompositionResult")

    decomposition <- metadata(result@value)$stage1
    expect_identical(dr_k(decomposition), 6L)
    expect_equal(dim(dr_V_k(decomposition)), c(30L, 6L))
    expect_equal(dim(dr_sigma_k(decomposition)), c(1L, 6L))
    expect_length(dr_coords_k(decomposition), 1L)
    expect_equal(dim(dr_coords_k(decomposition)[[1L]]), c(12L, 6L))
    expect_length(shared_axis(decomposition), 30L)
})

test_that("svd returns available components for the smallest valid sample size", {
    std <- synthetic_control(n = 2L, p = 10L, K = 1L,
                             signal = 20, signal_spec = 1,
                             noise_sd = 0.001, seed = 109L)
    ctor <- get_strategy("Decomposer", "svd")
    result <- suppressWarnings(decompose(ctor(), std))

    expect_identical(result@status, "success")
    expect_identical(dr_k(metadata(result@value)$stage1), 1L)
})

test_that("svd typed-fails invalid component requests", {
    std <- synthetic_control(n = 12L, p = 30L, K = 1L,
                             signal = 40, seed = 110L)
    ctor <- get_strategy("Decomposer", "svd")

    for (invalid_k in list(0L, -1L, NA_integer_, 1.5, "two", 2^31)) {
        result <- suppressWarnings(decompose(
            ctor(list(k_components = invalid_k)), std
        ))
        expect_identical(result@status, "failure")
        expect_match(result@reason, "k_components")
    }
})

test_that("svd typed-fails invalid centering and non-finite assay values", {
    std <- synthetic_control(n = 12L, p = 30L, K = 1L,
                             signal = 40, seed = 111L)
    ctor <- get_strategy("Decomposer", "svd")

    invalid_center <- decompose(ctor(list(center = NA)), std)
    expect_identical(invalid_center@status, "failure")
    expect_match(invalid_center@reason, "center")

    assay(experiments(std)[[1L]])[1L, 1L] <- NA_real_
    non_finite <- decompose(ctor(), std)
    expect_identical(non_finite@status, "failure")
    expect_match(non_finite@reason, "finite numeric")
})

test_that("svd typed-fails outside its exactly-one-omic-layer capability", {
    std <- synthetic_control(n = 12L, p = 30L, K = 2L,
                             signal = 40, seed = 103L)
    ctor <- get_strategy("Decomposer", "svd")
    result <- decompose(ctor(), std)

    expect_s4_class(result, "StageResult")
    expect_identical(result@status, "failure")
    expect_match(result@reason, "svd requires exactly 1 omic layer", fixed = TRUE)
})

test_that("hogsvd_averaged does not silently handle K=1", {
    std <- synthetic_control(n = 12L, p = 30L, K = 1L,
                             signal = 40, seed = 104L)
    ctor <- get_strategy("Decomposer", "hogsvd_averaged")
    result <- decompose(ctor(), std)

    expect_s4_class(result, "StageResult")
    expect_identical(result@status, "failure")
    expect_match(result@reason, "requires at least 2 omic layers", fixed = TRUE)
})

test_that("svd deterministically recovers planted K=1 subspace", {
    make_control <- function() {
        synthetic_control(
            n = 20L, p = 60L, K = 1L,
            signal = 100, signal_spec = 5,
            noise_sd = 0.001, seed = 105L
        )
    }

    benchmark_1 <- suppressWarnings(recovery_benchmark(make_control(), "svd"))
    benchmark_2 <- suppressWarnings(recovery_benchmark(make_control(), "svd"))

    expect_lt(benchmark_1$angle_deg, 1)
    expect_identical(benchmark_1$angle_deg, benchmark_2$angle_deg)
    expect_identical(benchmark_1$signal_above_bbp, TRUE)
})

test_that("svd records truthful deterministic provenance", {
    std <- synthetic_control(n = 15L, p = 40L, K = 1L,
                             signal = 50, seed = 106L)
    input_hash <- digest::digest(std)
    ctor <- get_strategy("Decomposer", "svd")

    result_1 <- suppressWarnings(decompose(ctor(), std))
    result_2 <- suppressWarnings(decompose(ctor(), std))

    expect_identical(result_1@status, "success")
    expect_length(result_1@provenance, 1L)
    expect_length(result_1@value@provenance, 2L)

    provenance <- result_1@provenance[[1L]]
    expect_identical(provenance@implementation, "svd")
    expect_identical(provenance@contract, "Decomposer")
    expect_identical(provenance@params$K, 1L)
    expect_identical(provenance@params$center, TRUE)
    expect_identical(provenance@params$k_components, 6L)
    expect_identical(unname(provenance@input_hashes[["data"]]), input_hash)
    expect_identical(result_1@value, result_2@value)

    forged <- suppressWarnings(decompose(
        ctor(list(n = 999L, p = 888L, K = 99L, k = 77L)), std
    ))
    forged_provenance <- tail(forged@value@provenance, 1L)[[1L]]
    expect_identical(forged_provenance@params$n, 15L)
    expect_identical(forged_provenance@params$p, 40L)
    expect_identical(forged_provenance@params$K, 1L)
    expect_identical(forged_provenance@params$k, 6L)
})

test_that("K=1 double-well constructor typed-fails invalid public inputs", {
    expect_error(
        synthetic_k1_double_well_control(n = 1L),
        class = "landscapeR_validation_error"
    )
    expect_error(
        synthetic_k1_double_well_control(beta = c(1, 2)),
        class = "landscapeR_validation_error"
    )
    expect_error(
        synthetic_k1_double_well_control(seed = .Machine$integer.max),
        class = "landscapeR_validation_error"
    )
})

test_that("K=1 calibration returns structured failure for invalid control inputs", {
    result <- k1_double_well_calibration(n = 1L)

    expect_identical(result$status, "failure")
    expect_identical(result$evidence_status, "non_evidentiary_calibration")
    expect_match(result$reason, "n must")
    expect_length(result$provenance, 0L)
})

test_that("K=1 double-well observations are independent stationary draws", {
    std <- synthetic_k1_double_well_control(
        n = 1000L, p = 5L, noise_sd = 0.02, seed = 114L
    )
    x <- colData(std)$source_x_coord
    control <- metadata(std)$k1_double_well_control

    expect_identical(control$sampler, "exact_cauchy_rejection")
    expect_lt(abs(stats::cor(x[-length(x)], x[-1L])), 0.1)
    expect_lt(abs(mean(x)), 0.1)
    expect_true(mean(x > 0) > 0.45 && mean(x > 0) < 0.55)
})

test_that("K=1 double-well constructor carries subspace and potential truth", {
    std <- synthetic_k1_double_well_control(
        n = 120L, p = 50L, noise_sd = 0.02, seed = 107L
    )

    expect_s4_class(std, "StateTransitionData")
    expect_length(std@provenance, 1L)
    expect_identical(std@provenance[[1L]]@implementation, "k1_double_well")
    expect_s4_class(std@ground_truth, "K1DoubleWellGroundTruth")
    expect_s4_class(std@ground_truth@subspace, "SubspaceGroundTruth")
    expect_s4_class(std@ground_truth@potential, "PotentialGroundTruth")
    expect_length(experiments(std), 1L)
    expect_equal(dim(assay(experiments(std)[[1L]])), c(50L, 120L))
    expect_identical(std@sampling_design@kind, "cross_sectional")

    control <- metadata(std)$k1_double_well_control
    expect_identical(std@ground_truth@potential@barrier, 2)
    expect_equal(
        std@ground_truth@potential@potential(-control$coordinate_center),
        2
    )
    expect_identical(control$calibration_only, TRUE)
    expect_identical(control$evidence_status, "non_evidentiary_calibration")
    expect_identical(control$true_barrier_height, 2)
    expect_identical(control$seed, 107L)
})

test_that("K=1 double-well calibration runs SVD and Stage 2 without judging acceptance", {
    calibration <- suppressWarnings(k1_double_well_calibration(
        n = 160L, p = 50L, noise_sd = 0.02, seed = 108L
    ))

    expect_identical(calibration$status, "success")
    expect_identical(calibration$evidence_status, "non_evidentiary_calibration")
    expect_identical(calibration$decomposer, "svd")
    expect_identical(calibration$dynamics_estimator, "kde_logdensity")
    expect_true(is.finite(calibration$subspace_angle_deg))
    expect_true(is.finite(calibration$well_error))
    expect_true(is.finite(calibration$barrier_error))
    expect_identical(calibration$true_barrier_height, 2)
    expect_length(calibration$provenance, 3L)
    expect_true(is.character(calibration$config_digest))
    expect_length(calibration$config_digest, 1L)
    expect_false(any(c("pass", "accepted", "eligible") %in% names(calibration)))
})

test_that("K=1 calibration reports configuration failures with control provenance", {
    wrong_type <- suppressWarnings(k1_double_well_calibration(
        n = 40L, p = 20L, seed = 112L,
        config = "not-a-config"
    ))
    expect_identical(wrong_type$status, "failure")
    expect_match(wrong_type$reason, "PipelineConfig")
    expect_length(wrong_type$provenance, 1L)

    bad_config <- new("PipelineConfig",
        strategies = list(
            Decomposer = "not_registered",
            DynamicsEstimator = "kde_logdensity"
        ),
        params = list(),
        dataset = "invalid_calibration_config",
        analysis = confirmed_potential_analysis(
            id = "invalid_calibration_config_PC1",
            component = 1L
        )
    )
    missing_strategy <- suppressWarnings(k1_double_well_calibration(
        n = 40L, p = 20L, seed = 113L,
        config = bad_config
    ))
    expect_identical(missing_strategy$status, "failure")
    expect_match(missing_strategy$reason, "not_registered")
    expect_length(missing_strategy$provenance, 1L)

    component_two_config <- new("PipelineConfig",
        strategies = list(
            Decomposer = "svd",
            DynamicsEstimator = "kde_logdensity"
        ),
        params = list(),
        dataset = "invalid_component_config",
        analysis = confirmed_potential_analysis(
            id = "invalid_component_config_PC2",
            component = 2L
        )
    )
    component_two <- suppressWarnings(k1_double_well_calibration(
        n = 40L, p = 20L, seed = 115L,
        config = component_two_config
    ))
    expect_identical(component_two$status, "failure")
    expect_match(component_two$reason, "component 1")
    expect_length(component_two$provenance, 1L)
})
