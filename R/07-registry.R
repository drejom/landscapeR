# Algorithm implementation registry.
# Algorithms self-register under their contract on package load. The pipeline
# resolves them by name — no switch statements, no central dispatcher to edit.

.registry <- new.env(parent = emptyenv())
.registry_provenance <- new.env(parent = emptyenv())

.strategy_registry_key <- function(contract, name) {
    paste(contract, name, sep = ":")
}

.is_stable_strategy_environment <- function(environment) {
    isNamespace(environment) ||
        identical(environment, baseenv())
}

.resolve_strategy_binding <- function(name, environment) {
    current <- environment
    depth <- 0L
    while (!identical(current, emptyenv())) {
        if (exists(name, envir = current, inherits = FALSE)) {
            environment_name <- environmentName(current)
            source <- if (nzchar(environment_name)) {
                environment_name
            } else {
                sprintf("<anonymous:%d>", depth)
            }
            if (.is_stable_strategy_environment(current)) {
                return(list(name = name, source = source, stable = TRUE))
            }
            if (bindingIsActive(name, current)) {
                .stop_landscapeR_validation(sprintf(
                    paste0(
                        "constructor environment contains unsupported active ",
                        "binding '%s' at %s"
                    ),
                    name, source
                ))
            }
            value <- tryCatch(
                get(name, envir = current, inherits = FALSE),
                error = function(error) {
                    .stop_landscapeR_validation(sprintf(
                        "constructor captured state '%s' could not be inspected: %s",
                        name, conditionMessage(error)
                    ))
                }
            )
            return(list(
                name = name,
                source = source,
                stable = FALSE,
                value = value
            ))
        }
        current <- parent.env(current)
        depth <- depth + 1L
    }
    list(name = name, source = "<unbound>", stable = FALSE)
}

.find_strategy_globals_impl <- function(constructor) {
    codetools::findGlobals(constructor, merge = FALSE)
}

.find_strategy_globals <- function(constructor) {
    tryCatch(
        .find_strategy_globals_impl(constructor),
        error = function(error) {
            .stop_landscapeR_validation(sprintf(
                "constructor globals could not be inspected: %s",
                conditionMessage(error)
            ))
        }
    )
}

.digest_strategy_identity_impl <- function(identity) {
    digest::digest(identity, algo = "sha256")
}

.digest_strategy_identity <- function(identity) {
    tryCatch(
        .digest_strategy_identity_impl(identity),
        error = function(error) {
            .stop_landscapeR_validation(sprintf(
                "constructor identity could not be fingerprinted: %s",
                conditionMessage(error)
            ))
        }
    )
}

.strategy_constructor_fingerprint <- function(constructor) {
    if (typeof(constructor) != "closure") {
        .stop_landscapeR_validation(
            "constructor must be an R closure; primitive functions are unsupported"
        )
    }
    constructor_environment <- environment(constructor)
    environment_name <- environmentName(constructor_environment)
    stable_named_environment <- .is_stable_strategy_environment(
        constructor_environment
    )
    environment_identity <- if (stable_named_environment) {
        list(name = environment_name)
    } else {
        globals <- .find_strategy_globals(constructor)
        referenced_names <- sort(unique(c(
            globals$functions,
            globals$variables
        )))
        captured_bindings <- lapply(
            referenced_names,
            .resolve_strategy_binding,
            environment = constructor_environment
        )
        names(captured_bindings) <- referenced_names
        list(
            name = if (nzchar(environment_name)) {
                environment_name
            } else {
                "<anonymous>"
            },
            bindings = captured_bindings
        )
    }
    # Referenced direct bindings in anonymous closure environments distinguish
    # factory products with the same formals/body but different captured state,
    # without letting unrelated caller locals change constructor identity.
    # Actual namespaces and base remain stable references. Package-like names
    # and environment locks are insufficient because existing bindings may
    # still be mutable; all other environments are resolved binding-by-binding.
    # Mutable named environments such as .GlobalEnv and anonymous lexical
    # parents are resolved binding-by-binding; naming alone does not make state
    # stable.
    .digest_strategy_identity(
        list(
            formals = formals(constructor),
            body = body(constructor),
            environment = environment_identity
        )
    )
}

.stop_strategy_registry_collision <- function(
    contract, name, existing_fingerprint, proposed_fingerprint
) {
    stop(structure(
        list(
            message = sprintf(
                paste0(
                    "Strategy '%s:%s' is already registered. ",
                    "Use replace = TRUE with a non-empty reason only when ",
                    "replacement is deliberate."
                ),
                contract, name
            ),
            call = sys.call(-1L),
            contract = contract,
            name = name,
            existing_fingerprint = existing_fingerprint,
            proposed_fingerprint = proposed_fingerprint
        ),
        class = c(
            "landscapeR_registry_collision_error",
            "landscapeR_validation_error",
            "error",
            "condition"
        )
    ))
}

.prepare_strategy_registration <- function(
    contract, name, fingerprint, action, reason = NA_character_,
    previous_fingerprint = NA_character_
) {
    key <- .strategy_registry_key(contract, name)
    history <- if (exists(key, envir = .registry_provenance, inherits = FALSE)) {
        get(key, envir = .registry_provenance, inherits = FALSE)
    } else {
        list()
    }
    record <- list(
        sequence = length(history) + 1L,
        contract = contract,
        name = name,
        action = action,
        reason = reason,
        previous_fingerprint = previous_fingerprint,
        fingerprint = fingerprint
    )
    list(key = key, history = c(history, list(record)))
}

.registered_strategy_fingerprint <- function(key) {
    if (!exists(key, envir = .registry_provenance, inherits = FALSE)) {
        .stop_landscapeR_validation(sprintf(
            "strategy registry provenance is missing for '%s'",
            key
        ))
    }
    history <- get(key, envir = .registry_provenance, inherits = FALSE)
    history[[length(history)]]$fingerprint
}

.commit_strategy_registration <- function(prepared, constructor) {
    # Fingerprinting and complete record construction happen before this
    # two-store commit. Both targets are private, writable environments, so
    # these assignments cannot invoke user code.
    assign(
        prepared$key,
        prepared$history,
        envir = .registry_provenance
    )
    assign(prepared$key, constructor, envir = .registry)
    invisible(NULL)
}

#' Register an algorithm implementation under a stage contract
#'
#' @param contract character contract class name (e.g. \code{"Decomposer"})
#' @param name character unique implementation name
#' @param constructor R closure with signature
#'   \code{function(params_list)} returning a contract-class instance.
#'   Primitive functions are unsupported because their implementation state
#'   cannot satisfy the registry fingerprint contract.
#' @param replace logical; whether to deliberately replace a different
#'   constructor already registered under the same key. Re-registering the
#'   identical constructor is an idempotent no-op.
#' @param reason non-empty character rationale required when \code{replace} is
#'   \code{TRUE}; retained in registry provenance.
#' @return invisible NULL
#' @export
register_strategy <- function(
    contract, name, constructor, replace = FALSE, reason = NULL
) {
    if (!is.character(contract) || length(contract) != 1L ||
        is.na(contract) || !nzchar(trimws(contract))) {
        .stop_landscapeR_validation(
            "contract must be a single non-empty character value"
        )
    }
    if (grepl(":", contract, fixed = TRUE)) {
        .stop_landscapeR_validation(
            "contract must not contain the reserved ':' registry delimiter"
        )
    }
    if (!is.character(name) || length(name) != 1L ||
        is.na(name) || !nzchar(trimws(name))) {
        .stop_landscapeR_validation(
            "name must be a single non-empty character value"
        )
    }
    if (grepl(":", name, fixed = TRUE)) {
        .stop_landscapeR_validation(
            "name must not contain the reserved ':' registry delimiter"
        )
    }
    if (!is.function(constructor))
        .stop_landscapeR_validation("constructor must be a function")
    if (!is.logical(replace) || length(replace) != 1L || is.na(replace))
        .stop_landscapeR_validation("replace must be TRUE or FALSE")

    fingerprint <- .strategy_constructor_fingerprint(constructor)
    key <- .strategy_registry_key(contract, name)
    if (exists(key, envir = .registry, inherits = FALSE)) {
        existing <- get(key, envir = .registry, inherits = FALSE)
        registered_fingerprint <- .registered_strategy_fingerprint(key)
        current_fingerprint <- .strategy_constructor_fingerprint(existing)
        if (!identical(current_fingerprint, registered_fingerprint)) {
            .stop_landscapeR_validation(sprintf(
                paste0(
                    "registered strategy '%s' has changed captured state; ",
                    "restart with a stable constructor before replacing it"
                ),
                key
            ))
        }
        if (identical(existing, constructor))
            return(invisible(NULL))
        if (!replace) {
            .stop_strategy_registry_collision(
                contract, name, registered_fingerprint, fingerprint
            )
        }
        if (!is.character(reason) || length(reason) != 1L ||
            is.na(reason) || !nzchar(trimws(reason))) {
            .stop_landscapeR_validation(
                "reason must be a single non-empty character value when replace = TRUE"
            )
        }
        prepared <- .prepare_strategy_registration(
            contract, name, fingerprint,
            action = "replacement",
            reason = trimws(reason),
            previous_fingerprint = registered_fingerprint
        )
        return(.commit_strategy_registration(prepared, constructor))
    }

    if (replace) {
        .stop_landscapeR_validation(
            "replace = TRUE requires an existing strategy registration"
        )
    }
    prepared <- .prepare_strategy_registration(
        contract, name, fingerprint, action = "registration"
    )
    .commit_strategy_registration(prepared, constructor)
}

#' Inspect deterministic strategy-registration provenance
#'
#' Returns accepted registrations and deliberate replacements. Rejected
#' collisions are exposed on the typed error condition and never mutate this
#' history.
#'
#' @param contract character contract name to filter by, or \code{NULL} for all
#' @param name character implementation name to filter by, or \code{NULL} for all
#' @return data frame with one row per accepted registry mutation
#' @export
strategy_registration_history <- function(contract = NULL, name = NULL) {
    keys <- ls(.registry_provenance, all.names = TRUE)
    records <- unlist(
        lapply(keys, function(key) {
            get(key, envir = .registry_provenance, inherits = FALSE)
        }),
        recursive = FALSE
    )
    if (length(records) == 0L) {
        return(data.frame(
            sequence = integer(), contract = character(), name = character(),
            action = character(), reason = character(),
            previous_fingerprint = character(), fingerprint = character(),
            stringsAsFactors = FALSE
        ))
    }
    out <- do.call(rbind, lapply(records, as.data.frame,
                                 stringsAsFactors = FALSE))
    if (!is.null(contract))
        out <- out[out$contract %in% contract, , drop = FALSE]
    if (!is.null(name))
        out <- out[out$name %in% name, , drop = FALSE]
    rownames(out) <- NULL
    out
}

#' Retrieve an implementation constructor from the registry
#'
#' @param contract character contract class name
#' @param name character implementation name
#' @return constructor function
#' @export
get_strategy <- function(contract, name) {
    key <- .strategy_registry_key(contract, name)
    if (!exists(key, envir = .registry, inherits = FALSE))
        stop(sprintf(
            "No implementation '%s' registered for contract '%s'.",
            name, contract
        ))
    get(key, envir = .registry)
}

#' List registered implementations, optionally filtered by contract
#'
#' @param contract character contract name to filter by, or \code{NULL} for all
#' @return character vector of keys (\code{"Contract:name"})
#' @export
list_strategies <- function(contract = NULL) {
    keys <- ls(.registry, all.names = TRUE)
    if (!is.null(contract))
        keys <- keys[startsWith(keys, paste0(contract, ":"))]
    keys
}
