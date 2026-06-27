test_that("register_strategy / get_strategy round-trip", {
    register_strategy("_TestContract", "impl_a", function(p) list(type = "a"))
    ctor <- get_strategy("_TestContract", "impl_a")
    expect_type(ctor, "closure")
    expect_equal(ctor(list())$type, "a")
})

test_that("get_strategy errors on unknown implementation", {
    expect_error(get_strategy("Decomposer", "_nonexistent"), "No implementation")
})

test_that("list_strategies filters by contract", {
    register_strategy("_C1", "x", function(p) NULL)
    register_strategy("_C1", "y", function(p) NULL)
    register_strategy("_C2", "z", function(p) NULL)
    keys <- list_strategies("_C1")
    expect_true(all(startsWith(keys, "_C1:")))
    expect_length(keys, 2L)
})
