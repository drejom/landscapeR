test_that("StateTransitionData() constructs with defaults", {
    d <- empty_std()
    expect_s4_class(d, "StateTransitionData")
    expect_equal(d@schema_version, landscapeR:::SCHEMA_VERSION)
    expect_null(d@ground_truth)
    expect_equal(d@provenance, list())
})

test_that("validity rejects invalid schema_version", {
    d <- empty_std()
    expect_error(
        { d@schema_version <- "not-semver"; validObject(d) },
        "semver"
    )
})

test_that("migrate() is a no-op when versions match", {
    d <- empty_std()
    expect_equal(migrate(d)@schema_version, d@schema_version)
})

test_that("migrate() fails loudly with no registered path", {
    d <- empty_std()
    d@schema_version <- "0.0.1"
    expect_error(migrate(d, target = "9.9.9"), "No migration registered")
})

test_that("register_migration() + migrate() round-trip", {
    register_migration("0.0.1", "0.0.2", function(obj) {
        obj@schema_version <- "0.0.2"
        obj
    })
    d <- empty_std()
    d@schema_version <- "0.0.1"
    d2 <- migrate(d, target = "0.0.2")
    expect_equal(d2@schema_version, "0.0.2")
})

# ---------------------------------------------------------------------------
# Issue #26: Sampling-design declaration
# ---------------------------------------------------------------------------

test_that("StateTransitionData defaults to an unspecified sampling design", {
    d <- empty_std()
    expect_s4_class(d@sampling_design, "SamplingDesign")
    expect_equal(d@sampling_design@kind, "unspecified")
})

test_that("cross-sectional sampling design attaches to data", {
    d <- declare_sampling_design(empty_std(), cross_sectional())
    expect_equal(d@sampling_design@kind, "cross_sectional")
})

test_that("longitudinal declaration validates required colData structure", {
    d <- synthetic_control(n = 4L, p = 5L, K = 2L, signal = 10, seed = 1L)
    cd <- colData(d)
    cd$mouse_id <- c("m1", "m1", "m2", "m2")
    cd$day <- c(0, 1, 0, 1)
    colData(d) <- cd
    out <- declare_sampling_design(d, longitudinal("mouse_id", "day", "days"))
    expect_equal(out@sampling_design@kind, "longitudinal")
    expect_equal(out@sampling_design@time_unit, "days")

    d_dup <- synthetic_control(n = 2L, p = 5L, K = 2L, signal = 10, seed = 2L)
    cd_dup <- colData(d_dup)
    cd_dup$mouse_id <- c("m1", "m1")
    cd_dup$day <- c(0, 0)
    colData(d_dup) <- cd_dup
    expect_error(
        declare_sampling_design(d_dup, longitudinal("mouse_id", "day")),
        "duplicate subject/time"
    )
})

test_that("0.1.0 migration assigns an unspecified sampling design", {
    d <- empty_std()
    d@schema_version <- "0.1.0"
    migrated <- migrate(d)
    expect_equal(migrated@schema_version, landscapeR:::SCHEMA_VERSION)
    expect_equal(migrated@sampling_design@kind, "unspecified")
})
