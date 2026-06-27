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
