#' Run the pipeline sequentially (development / testing helper)
#'
#' In production, replace with a \code{targets} plan that wraps these stages
#' for caching and parallelism. This runner exists so the pipeline can be
#' exercised without a targets dependency.
#'
#' @param data StateTransitionData
#' @param config PipelineConfig
#' @return StageResult
#' @export
run_pipeline <- function(data, config) {
    stage_defs <- list(
        list(contract = "Decomposer",        fn = decompose,          name = "decompose"),
        list(contract = "DynamicsEstimator", fn = estimate_dynamics,  name = "estimate_dynamics")
    )

    for (s in stage_defs) {
        impl_name <- config@strategies[[s$contract]]
        if (is.null(impl_name)) next

        analysis_valid <- .validate_analysis_specification_data(
            config@analysis,
            data,
            require_component = identical(s$contract, "DynamicsEstimator")
        )
        if (!isTRUE(analysis_valid))
            return(stage_failure(sprintf("[%s] invalid analysis specification: %s",
                                         s$name, analysis_valid)))

        ctor     <- get_strategy(s$contract, impl_name)
        params   <- config@params[[impl_name]] %||% list()
        params$analysis_specification <- .analysis_spec_provenance(config@analysis)
        if (identical(s$contract, "DynamicsEstimator"))
            params$component <- config@analysis@selected_component
        strategy <- ctor(params)

        result <- s$fn(strategy, data)

        if (!is(result, "StageResult"))
            return(stage_failure(sprintf("[%s] did not return a StageResult", s$name)))
        if (result@status == "failure") return(result)

        data <- result@value
    }

    stage_success(data)
}

`%||%` <- function(x, y) if (is.null(x)) y else x
