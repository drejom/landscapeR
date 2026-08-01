local({
initial_registry_keys <- ls(landscapeR:::.registry, all.names = TRUE)
initial_provenance_keys <- ls(
    landscapeR:::.registry_provenance,
    all.names = TRUE
)
on.exit({
    added_registry_keys <- setdiff(
        ls(landscapeR:::.registry, all.names = TRUE),
        initial_registry_keys
    )
    if (length(added_registry_keys) > 0L) {
        rm(list = added_registry_keys, envir = landscapeR:::.registry)
    }
    added_provenance_keys <- setdiff(
        ls(landscapeR:::.registry_provenance, all.names = TRUE),
        initial_provenance_keys
    )
    if (length(added_provenance_keys) > 0L) {
        rm(
            list = added_provenance_keys,
            envir = landscapeR:::.registry_provenance
        )
    }
}, add = TRUE)

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

test_that("duplicate strategy registration is a typed non-mutating error", {
    original <- function(p) list(author = "original")
    collision <- function(p) list(author = "collision")
    register_strategy("_CollisionContract", "shared_name", original)

    condition <- expect_error(
        register_strategy("_CollisionContract", "shared_name", collision),
        class = "landscapeR_registry_collision_error"
    )
    expect_s3_class(condition, "landscapeR_validation_error")
    expect_identical(condition$contract, "_CollisionContract")
    expect_identical(condition$name, "shared_name")
    expect_false(identical(
        condition$existing_fingerprint,
        condition$proposed_fingerprint
    ))
    expect_identical(
        get_strategy("_CollisionContract", "shared_name"),
        original
    )
})

test_that("fingerprint-equivalent registration is an idempotent no-op", {
    constructor_factory <- function(type) {
        force(type)
        function(p) list(type = type)
    }
    constructor <- constructor_factory("stable")
    register_strategy("_IdempotentContract", "stable", constructor)
    before <- strategy_registration_history(
        "_IdempotentContract", "stable"
    )

    equivalent_constructor <- constructor_factory("stable")
    expect_false(identical(constructor, equivalent_constructor))
    expect_invisible(register_strategy(
        "_IdempotentContract", "stable", equivalent_constructor
    ))
    after <- strategy_registration_history("_IdempotentContract", "stable")

    expect_identical(after, before)
    expect_identical(
        get_strategy("_IdempotentContract", "stable"),
        constructor
    )
})

test_that("strategy identifiers have one whitespace-normalized identity", {
    constructor <- function(p) list(type = "canonical")
    register_strategy(
        "  _WhitespaceContract  ",
        "  canonical  ",
        constructor
    )
    expect_identical(
        get_strategy(" _WhitespaceContract ", " canonical "),
        constructor
    )
    expect_identical(
        list_strategies(" _WhitespaceContract "),
        "_WhitespaceContract:canonical"
    )
    history <- strategy_registration_history(
        " _WhitespaceContract ", " canonical "
    )
    expect_identical(history$contract, "_WhitespaceContract")
    expect_identical(history$name, "canonical")
})

test_that("explicit replacement requires and retains a rationale", {
    constructor_factory <- function(version) {
        force(version)
        function(p) list(version = version)
    }
    original <- constructor_factory(1L)
    replacement <- constructor_factory(2L)
    register_strategy("_ReplacementContract", "versioned", original)
    assign("irrelevant_caller_local", 42L, envir = environment(original))

    expect_error(
        register_strategy(
            "_ReplacementContract", "versioned", replacement,
            replace = TRUE
        ),
        "reason must be"
    )
    expect_identical(
        get_strategy("_ReplacementContract", "versioned"),
        original
    )

    expect_invisible(register_strategy(
        "_ReplacementContract", "versioned", replacement,
        replace = TRUE,
        reason = "Correct the published method implementation"
    ))
    expect_identical(
        get_strategy("_ReplacementContract", "versioned"),
        replacement
    )

    history <- strategy_registration_history(
        "_ReplacementContract", "versioned"
    )
    expect_identical(history$action, c("registration", "replacement"))
    expect_identical(
        history$reason,
        c(NA_character_, "Correct the published method implementation")
    )
    expect_identical(
        history$previous_fingerprint[[2L]],
        history$fingerprint[[1L]]
    )
    expect_identical(
        history$fingerprint[[2L]],
        landscapeR:::.strategy_constructor_fingerprint(replacement)
    )
    expect_false(identical(
        history$fingerprint[[1L]],
        history$fingerprint[[2L]]
    ))
})

test_that("replacement cannot invent a missing registry entry", {
    expect_error(
        register_strategy(
            "_MissingReplacementContract", "missing",
            function(p) NULL,
            replace = TRUE,
            reason = "There is nothing to replace"
        ),
        "requires an existing strategy",
        class = "landscapeR_validation_error"
    )
})

test_that("registry identifiers reject the reserved delimiter", {
    expect_error(
        register_strategy("_Contract:ambiguous", "name", function(p) NULL),
        "reserved ':' registry delimiter",
        class = "landscapeR_validation_error"
    )
    expect_error(
        register_strategy("_Contract", "ambiguous:name", function(p) NULL),
        "reserved ':' registry delimiter",
        class = "landscapeR_validation_error"
    )
})

test_that("unsupported constructor fingerprinting cannot partially mutate", {
    primitive_key <- "_FingerprintContract:primitive"
    expect_error(
        register_strategy("_FingerprintContract", "primitive", sum),
        "primitive functions are unsupported",
        class = "landscapeR_validation_error"
    )
    expect_false(exists(
        primitive_key,
        envir = landscapeR:::.registry,
        inherits = FALSE
    ))
    expect_false(exists(
        primitive_key,
        envir = landscapeR:::.registry_provenance,
        inherits = FALSE
    ))

    active_environment <- new.env(parent = baseenv())
    makeActiveBinding(
        "unstable",
        function(value) stop("fingerprint exploded"),
        active_environment
    )
    active_constructor <- eval(quote(function(p) unstable), active_environment)
    active_key <- "_FingerprintContract:active"
    expect_error(
        register_strategy(
            "_FingerprintContract", "active", active_constructor
        ),
        "unsupported active binding",
        class = "landscapeR_validation_error"
    )
    expect_false(exists(
        active_key,
        envir = landscapeR:::.registry,
        inherits = FALSE
    ))
    expect_false(exists(
        active_key,
        envir = landscapeR:::.registry_provenance,
        inherits = FALSE
    ))
})

test_that("captured-state drift is rejected without breaking provenance", {
    constructor_factory <- function(version) {
        force(version)
        function(p) list(version = version)
    }
    original <- constructor_factory(1L)
    replacement <- constructor_factory(2L)
    register_strategy("_DriftContract", "versioned", original)
    before <- strategy_registration_history("_DriftContract", "versioned")

    assign("version", 99L, envir = environment(original))
    expect_error(
        register_strategy(
            "_DriftContract", "versioned", replacement,
            replace = TRUE,
            reason = "Replace a stable constructor"
        ),
        "changed captured state",
        class = "landscapeR_validation_error"
    )
    expect_identical(
        strategy_registration_history("_DriftContract", "versioned"),
        before
    )
    expect_identical(
        get_strategy("_DriftContract", "versioned"),
        original
    )
})

test_that("global constructor-state drift is detected", {
    global_name <- ".landscapeR_registry_global_state"
    assign(global_name, 1L, envir = .GlobalEnv)
    on.exit(rm(list = global_name, envir = .GlobalEnv), add = TRUE)
    constructor <- eval(
        quote(function(p) .landscapeR_registry_global_state),
        envir = .GlobalEnv
    )
    register_strategy("_GlobalDriftContract", "global", constructor)
    before <- strategy_registration_history(
        "_GlobalDriftContract", "global"
    )

    assign(global_name, 2L, envir = .GlobalEnv)
    expect_error(
        register_strategy(
            "_GlobalDriftContract", "global", constructor
        ),
        "changed captured state",
        class = "landscapeR_validation_error"
    )
    expect_identical(
        strategy_registration_history("_GlobalDriftContract", "global"),
        before
    )
})

test_that("inherited mutable constructor-state drift is detected", {
    parent_environment <- new.env(parent = baseenv())
    parent_environment$version <- 1L
    child_environment <- new.env(parent = parent_environment)
    constructor <- eval(
        quote(function(p) list(version = version)),
        envir = child_environment
    )
    register_strategy("_ParentDriftContract", "inherited", constructor)
    before <- strategy_registration_history(
        "_ParentDriftContract", "inherited"
    )

    parent_environment$version <- 2L
    expect_error(
        register_strategy(
            "_ParentDriftContract", "inherited", constructor
        ),
        "changed captured state",
        class = "landscapeR_validation_error"
    )
    expect_identical(
        strategy_registration_history("_ParentDriftContract", "inherited"),
        before
    )
})

test_that("partially locked package-named environments are not trusted", {
    search_name <- "package:landscapeR_registry_test_mutable"
    attach(list(registry_state = 1L), name = search_name)
    on.exit(detach(search_name, character.only = TRUE), add = TRUE)
    mutable_environment <- as.environment(search_name)
    lockEnvironment(mutable_environment, bindings = FALSE)
    constructor <- eval(
        quote(function(p) list(registry_state = registry_state)),
        envir = mutable_environment
    )
    register_strategy("_NamedMutableContract", "mutable", constructor)
    before <- strategy_registration_history(
        "_NamedMutableContract", "mutable"
    )

    assign("registry_state", 2L, envir = mutable_environment)
    expect_error(
        register_strategy(
            "_NamedMutableContract", "mutable", constructor
        ),
        "changed captured state",
        class = "landscapeR_validation_error"
    )
    expect_identical(
        strategy_registration_history("_NamedMutableContract", "mutable"),
        before
    )
})

test_that("fingerprint helper failures remain typed and non-mutating", {
    globals_key <- "_HelperFailureContract:globals"
    testthat::local_mocked_bindings(
        .find_strategy_globals_impl = function(...) stop("globals exploded"),
        .package = "landscapeR"
    )
    expect_error(
        register_strategy(
            "_HelperFailureContract", "globals", function(p) NULL
        ),
        "constructor globals could not be inspected: globals exploded",
        class = "landscapeR_validation_error"
    )
    expect_false(exists(
        globals_key, envir = landscapeR:::.registry, inherits = FALSE
    ))
    expect_false(exists(
        globals_key,
        envir = landscapeR:::.registry_provenance,
        inherits = FALSE
    ))
})

test_that("digest helper failures remain typed and non-mutating", {
    digest_key <- "_HelperFailureContract:digest"
    testthat::local_mocked_bindings(
        .digest_strategy_identity_impl = function(...) stop("digest exploded"),
        .package = "landscapeR"
    )
    expect_error(
        register_strategy(
            "_HelperFailureContract", "digest", function(p) NULL
        ),
        "constructor identity could not be fingerprinted: digest exploded",
        class = "landscapeR_validation_error"
    )
    expect_false(exists(
        digest_key, envir = landscapeR:::.registry, inherits = FALSE
    ))
    expect_false(exists(
        digest_key,
        envir = landscapeR:::.registry_provenance,
        inherits = FALSE
    ))
})

test_that("dot-prefixed contracts remain visible in provenance", {
    register_strategy(".HiddenContract", "visible", function(p) NULL)
    history <- strategy_registration_history(".HiddenContract", "visible")
    expect_equal(nrow(history), 1L)
    expect_identical(history$contract, ".HiddenContract")
    expect_identical(history$name, "visible")
    expect_identical(
        list_strategies(".HiddenContract"),
        ".HiddenContract:visible"
    )
})
})
