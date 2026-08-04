# Deep association-strategy authoring contract (ADR 0020; issue #117)

.association_contract_fields <- c(
    "version", "sampling_designs", "target_types", "estimand",
    "cohort_policy", "diagnostic_prefix", "abstention_statuses",
    "refit_policy", "evidence_version"
)

.new_association_contract <- function(
    sampling_designs,
    target_types,
    estimand,
    cohort_policy,
    diagnostic_prefix,
    abstention_statuses,
    refit_policy,
    evidence_version,
    version = "1.0.0"
) {
    structure(
        list(
            version = version,
            sampling_designs = sampling_designs,
            target_types = target_types,
            estimand = estimand,
            cohort_policy = cohort_policy,
            diagnostic_prefix = diagnostic_prefix,
            abstention_statuses = abstention_statuses,
            refit_policy = refit_policy,
            evidence_version = evidence_version
        ),
        class = "landscapeR_association_contract"
    )
}

.association_contract_errors <- function(contract) {
    errors <- character()
    if (!is.list(contract) ||
        !identical(names(contract), .association_contract_fields)) {
        return(paste0(
            "contract must contain exactly: ",
            paste(.association_contract_fields, collapse = ", ")
        ))
    }
    scalar_fields <- c(
        "version", "estimand", "cohort_policy", "diagnostic_prefix",
        "refit_policy", "evidence_version"
    )
    for (field in scalar_fields) {
        if (!.is_scalar_nonempty_text(contract[[field]])) {
            errors <- c(errors, sprintf("contract '%s' must be non-empty", field))
        }
    }
    vector_fields <- c(
        "sampling_designs", "target_types", "abstention_statuses"
    )
    for (field in vector_fields) {
        value <- contract[[field]]
        if (!is.character(value) || !length(value) || anyNA(value) ||
            any(!nzchar(value)) || anyDuplicated(value)) {
            errors <- c(errors, sprintf(
                "contract '%s' must be unique non-empty text",
                field
            ))
        }
    }
    errors
}

.validated_association_contract <- function(strategy) {
    if (!is(strategy, "AssociationStrategy")) {
        .stop_landscapeR_validation(
            "association strategy must inherit from AssociationStrategy"
        )
    }
    contract <- association_contract(strategy)
    errors <- .association_contract_errors(contract)
    if (length(errors)) {
        .stop_landscapeR_validation(sprintf(
            "AssociationStrategy '%s' has an invalid contract: %s",
            class(strategy)[[1L]],
            paste(errors, collapse = "; ")
        ))
    }
    contract
}

.metadata_target_type <- function(values) {
    observed <- values[!is.na(values)]
    if (is.ordered(values)) return("ordered")
    if (is.numeric(values) && !is.logical(values)) return("continuous")
    if (!is.null(.binary_level_order(values))) return("binary")
    if (is.factor(values) && nlevels(droplevels(observed)) > 2L) {
        return("unordered")
    }
    "unsupported"
}

.new_association_preparation <- function(
    strategy,
    values,
    complete,
    nuisance_values = list(),
    context = list()
) {
    if (!is(strategy, "AssociationStrategy")) {
        .stop_landscapeR_validation(
            "prepared strategy must inherit from AssociationStrategy"
        )
    }
    if (!is.logical(complete) || length(complete) != length(values) ||
        anyNA(complete)) {
        .stop_landscapeR_validation(
            "association cohort mask must be complete logical metadata"
        )
    }
    if (!is.list(nuisance_values) || !is.list(context)) {
        .stop_landscapeR_validation(
            "association preparation context must be represented by lists"
        )
    }
    list(
        strategy = strategy,
        values = values,
        complete = complete,
        nuisance_values = nuisance_values,
        context = context
    )
}

#' @rdname prepare_association
#' @export
setMethod(
    "prepare_association",
    signature(
        strategy = "AssociationStrategy",
        data = "StateTransitionData",
        specification = "ANY",
        values = "ANY"
    ),
    function(strategy, data, specification, values) {
        contract <- .validated_association_contract(strategy)
        if (!data@sampling_design@kind %in% contract$sampling_designs) {
            .stop_landscapeR_validation(sprintf(
                "AssociationStrategy '%s' does not support design '%s'",
                class(strategy)[[1L]],
                data@sampling_design@kind
            ))
        }
        target_type <- .metadata_target_type(values)
        if (!target_type %in% contract$target_types) {
            .stop_landscapeR_validation(sprintf(
                "AssociationStrategy '%s' does not support target type '%s'",
                class(strategy)[[1L]],
                target_type
            ))
        }
        complete <- !is.na(values)
        if (is.numeric(values)) complete <- complete & is.finite(values)
        .new_association_preparation(strategy, values, complete)
    }
)

#' @rdname refit_association
#' @export
setMethod(
    "refit_association",
    signature(
        strategy = "AssociationStrategy",
        scores = "numeric",
        values = "ANY",
        index = "integer"
    ),
    function(strategy, scores, values, index, context = list()) {
        if (length(context)) {
            .stop_landscapeR_validation(
                "default association refitting does not accept context"
            )
        }
        associate_component(strategy, scores[index], values[index])
    }
)

.resolve_registered_association_strategy <- function(data, values) {
    keys <- list_strategies("AssociationStrategy")
    names <- sort(sub("^AssociationStrategy:", "", keys))
    strategies <- lapply(names, function(name) {
        get_strategy("AssociationStrategy", name)()
    })
    applicable <- Filter(function(strategy) {
        if (!association_applicable(strategy, data, values)) return(FALSE)
        contract <- .validated_association_contract(strategy)
        data@sampling_design@kind %in% contract$sampling_designs &&
            .metadata_target_type(values) %in% contract$target_types
    }, strategies)
    if (length(applicable) != 1L) return(NULL)
    applicable[[1L]]
}
