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

# ---------------------------------------------------------------------------
# Issue #23: StageResult@provenance must contain ProvenanceStep objects
# ---------------------------------------------------------------------------

test_that("StageResult validity rejects non-ProvenanceStep in provenance", {
    bad_prov <- list("not a ProvenanceStep")
    expect_error(
        validObject(new("StageResult", status = "success", value = NULL,
                        reason = "", provenance = bad_prov)),
        "ProvenanceStep"
    )
})

test_that("StageResult validity rejects StateTransitionData in provenance", {
    std <- empty_std()
    expect_error(
        validObject(new("StageResult", status = "success", value = NULL,
                        reason = "", provenance = list(std))),
        "ProvenanceStep"
    )
})

test_that("stage_success with a real ProvenanceStep passes validation", {
    pstep <- new("ProvenanceStep",
        stage          = "test",
        contract       = "TestContract",
        implementation = "test_impl",
        pkg_version    = "0.0.1",
        params         = list(a = 1L),
        input_hashes   = c(data = "abc123"),
        rng_seed       = 1L,
        timestamp      = Sys.time(),
        status         = "success"
    )
    r <- stage_success(value = NULL, provenance = list(pstep))
    expect_s4_class(r, "StageResult")
    expect_equal(r@status, "success")
    expect_true(is(r@provenance[[1L]], "ProvenanceStep"))
})
