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
