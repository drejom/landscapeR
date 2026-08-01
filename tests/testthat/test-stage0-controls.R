test_that("synthetic potential control typed-fails invalid public inputs", {
    invalid_calls <- list(
        function() synthetic_potential_control(n = 1L),
        function() synthetic_potential_control(n = 2.5),
        function() synthetic_potential_control(beta = -1),
        function() synthetic_potential_control(beta = Inf),
        function() synthetic_potential_control(n_steps = 0L),
        function() synthetic_potential_control(dt = NA_real_),
        function() synthetic_potential_control(seed = 1.5)
    )
    for (invalid_call in invalid_calls)
        expect_error(invalid_call(), class = "landscapeR_validation_error")
})

test_that("synthetic potential control rejects non-finite generated truth", {
    expect_error(
        synthetic_potential_control(n = 2L, n_steps = 2L, dt = 1e308),
        "generated coordinates must all be finite",
        class = "landscapeR_validation_error"
    )
})

test_that("synthetic potential control is deterministic, finite, and provenanced", {
    first <- synthetic_potential_control(n = 12L, n_steps = 20L, seed = 122L)
    second <- synthetic_potential_control(n = 12L, n_steps = 20L, seed = 122L)

    expect_identical(first, second)
    expect_true(all(is.finite(assay(experiments(first)[[1L]]))))
    expect_true(all(is.finite(first@ground_truth@wells)))
    expect_true(is.finite(first@ground_truth@barrier))
    expect_length(first@provenance, 1L)
    provenance <- first@provenance[[1L]]
    expect_identical(provenance@implementation, "langevin_potential")
    expect_identical(provenance@params$seed, 122L)
    expect_identical(
        provenance@params$claim_status, "known_truth_calibration_input"
    )
    expect_identical(
        unname(provenance@input_hashes[["specification"]]),
        digest::digest(metadata(first)$potential_control, algo = "sha256")
    )
})

test_that("all successful Stage 0 controls expose comparable provenance", {
    controls <- list(
        synthetic_control(n = 4L, p = 4L, K = 2L, seed = 1L),
        synthetic_branching_control(n_per_stage = 2L, p = 4L, seed = 2L),
        synthetic_k1_double_well_control(n = 4L, p = 4L, seed = 3L),
        synthetic_potential_control(n = 4L, n_steps = 10L, seed = 4L)
    )
    for (control in controls) {
        expect_length(control@provenance, 1L)
        params <- control@provenance[[1L]]@params
        expect_true(all(c("seed", "claim_status") %in% names(params)))
        expect_true(nzchar(params$claim_status))
    }
})

test_that("control ladder retains typed failures and completion accounting", {
    ladder <- suppressWarnings(control_ladder(
        ns = c(8L, 1L), ps = 8L, Ks = 2L, signals = 20,
        seed = 10L
    ))

    expect_s3_class(ladder, "ControlLadderResult")
    expect_identical(ladder$status, c("success", "failure"))
    expect_match(ladder$reason[[2L]], "n must")
    expect_identical(ladder$failure_class[[2L]], "landscapeR_validation_error")
    expect_identical(unique(ladder$requested_cells), 2L)
    expect_identical(unique(ladder$completed_cells), 1L)
    expect_identical(unique(ladder$failed_cells), 1L)
    expect_identical(
        attr(ladder, "accounting"),
        list(requested = 2L, completed = 1L, failed = 1L)
    )
    expect_true(is.finite(ladder$angle_deg[[1L]]))
    expect_true(is.na(ladder$angle_deg[[2L]]))
})

test_that("control ladder counts typed decomposition failures as failures", {
    ladder <- control_ladder(
        ns = 4L, ps = 4L, Ks = 1L, signals = 20, seed = 20L
    )

    expect_identical(ladder$status, "failure")
    expect_identical(ladder$failure_class, "StageResult")
    expect_match(ladder$reason, "requires at least 2 omic layers")
    expect_identical(ladder$completed_cells, 0L)
    expect_identical(ladder$failed_cells, 1L)
    expect_true(is.na(ladder$angle_deg))
})

test_that("control ladder typed-fails invalid sweep-level inputs", {
    expect_error(
        control_ladder(ns = numeric()),
        class = "landscapeR_validation_error"
    )
    expect_error(
        control_ladder(strategy_name = ""),
        class = "landscapeR_validation_error"
    )
    expect_error(
        control_ladder(seed = .Machine$integer.max),
        class = "landscapeR_validation_error"
    )
})
