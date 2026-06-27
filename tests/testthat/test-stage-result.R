test_that("stage_success() constructs correctly", {
    r <- stage_success(value = list(x = 1))
    expect_equal(r@status, "success")
    expect_equal(r@value$x, 1)
    expect_equal(r@reason, "")
})

test_that("stage_failure() constructs correctly", {
    r <- stage_failure("something went wrong")
    expect_equal(r@status, "failure")
    expect_null(r@value)
    expect_match(r@reason, "something went wrong")
})

test_that("StageResult rejects invalid status", {
    expect_error(
        validObject(new("StageResult", status = "maybe", value = NULL,
                        reason = "", provenance = list())),
        "success.*failure"
    )
})
