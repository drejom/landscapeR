test_that("validate_boundary passes a current-version object through", {
    d <- empty_std()
    result <- validate_boundary(d, stage = "test")
    expect_s4_class(result, "StateTransitionData")
})

test_that("validate_boundary fails on wrong input type", {
    result <- validate_boundary(list(x = 1), stage = "test")
    expect_s4_class(result, "StageResult")
    expect_equal(result@status, "failure")
    expect_match(result@reason, "expected StateTransitionData")
})

test_that("validate_boundary fails when no migration path exists", {
    d <- empty_std()
    d@schema_version <- "0.0.99"
    result <- validate_boundary(d, required_schema = "9.9.9", stage = "test")
    expect_s4_class(result, "StageResult")
    expect_equal(result@status, "failure")
})

test_that("validate_boundary converts malformed sampling design to typed failure", {
    d <- empty_std()
    d@sampling_design@kind <- "not-a-design"
    result <- validate_boundary(d, stage = "test")
    expect_s4_class(result, "StageResult")
    expect_equal(result@status, "failure")
    expect_match(result@reason, "invalid StateTransitionData")
})

test_that("validate_boundary catches stale longitudinal column references", {
    d <- synthetic_control(n = 4L, p = 5L, K = 2L, signal = 10, seed = 3L)
    cd <- colData(d)
    cd$mouse_id <- c("m1", "m1", "m2", "m2")
    cd$day <- c(0, 1, 0, 1)
    colData(d) <- cd
    d <- declare_sampling_design(d, longitudinal("mouse_id", "day"))
    cd <- colData(d)
    cd$day <- NULL
    colData(d) <- cd

    result <- validate_boundary(d, stage = "test")
    expect_s4_class(result, "StageResult")
    expect_equal(result@status, "failure")
    expect_match(result@reason, "time_col 'day' not found")
})

# ---------------------------------------------------------------------------
# Structural guarantee: boundary validation cannot be bypassed by a new
# Decomposer strategy that only implements .decompose_impl(). The public
# decompose() generic runs validate_boundary() once at the Decomposer-level
# dispatch (R/08-contracts.R) -- a fake strategy below writes NO validation
# code of its own and still gets a typed StageResult failure on a
# schema-mismatched object.
# ---------------------------------------------------------------------------

test_that("a new Decomposer strategy that skips validate_boundary still gets boundary enforcement", {
    setClass("FakeDecomposerForTest",
        contains = "Decomposer",
        representation(params = "list"))

    # Only the strategy-specific hook is implemented -- no call to
    # validate_boundary() anywhere in this method body.
    setMethod(".decompose_impl", signature("FakeDecomposerForTest", "StateTransitionData"),
        function(strategy, data, ...) {
            stage_success(data)
        }
    )

    d <- empty_std()
    d@schema_version <- "99.99.99"  # sentinel: never a real schema version

    strategy <- new("FakeDecomposerForTest", params = list())
    result <- decompose(strategy, d)

    expect_s4_class(result, "StageResult")
    expect_equal(result@status, "failure")
    expect_match(result@reason, "schema mismatch")

    removeMethod(".decompose_impl", signature("FakeDecomposerForTest", "StateTransitionData"))
    removeClass("FakeDecomposerForTest")
})

test_that("a new Decomposer strategy that skips validate_boundary still runs for valid data", {
    setClass("FakeDecomposerForTest2",
        contains = "Decomposer",
        representation(params = "list"))

    called <- FALSE
    setMethod(".decompose_impl", signature("FakeDecomposerForTest2", "StateTransitionData"),
        function(strategy, data, ...) {
            called <<- TRUE
            stage_success(data)
        }
    )

    d <- empty_std()
    strategy <- new("FakeDecomposerForTest2", params = list())
    result <- decompose(strategy, d)

    expect_true(called)
    expect_s4_class(result, "StageResult")
    expect_equal(result@status, "success")

    removeMethod(".decompose_impl", signature("FakeDecomposerForTest2", "StateTransitionData"))
    removeClass("FakeDecomposerForTest2")
})
