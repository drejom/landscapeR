test_that("PipelineConfig() is the validated public construction boundary", {
    analysis <- confirmed_planted_analysis()
    config <- PipelineConfig(
        dataset = "test",
        analysis = analysis,
        strategies = list(Decomposer = "svd"),
        params = list(svd = list(k = 1L))
    )

    expect_s4_class(config, "PipelineConfig")
    expect_identical(config@dataset, "test")
    expect_identical(config@analysis, analysis)
    expect_error(
        PipelineConfig("test", analysis, strategies = list("svd")),
        "unique non-empty names",
        class = "landscapeR_validation_error"
    )
    expect_error(
        PipelineConfig("test", analysis, params = list(svd = 1L)),
        "params values must be lists",
        class = "landscapeR_validation_error"
    )
})

test_that("StateTransitionData construction and coercion share defaults", {
    direct <- empty_std()
    mae <- MultiAssayExperiment::MultiAssayExperiment(
        experiments = experiments(direct),
        colData = colData(direct),
        sampleMap = sampleMap(direct)
    )
    coerced <- as(mae, "StateTransitionData")

    for (field in names(landscapeR:::.state_transition_defaults())) {
        expect_identical(methods::slot(direct, field), methods::slot(coerced, field))
    }
})

.valid_decomposition_result <- function() {
    DecompositionResult(
        V_star = c(1, 0),
        sigma = 2,
        coords = list(c(1, 2, 3)),
        V_k = matrix(c(1, 0), nrow = 2L, ncol = 1L),
        sigma_k = matrix(2, nrow = 1L, ncol = 1L),
        coords_k = list(matrix(c(1, 2, 3), ncol = 1L)),
        k = 1L
    )
}

test_that("DecompositionResult validity branches are tested directly", {
    invalid <- list(
        V_star = function(x) { x@V_star <- numeric(); x },
        k = function(x) { x@k <- 0L; x },
        V_k_rows = function(x) {
            x@V_k <- matrix(1, nrow = 1L, ncol = 1L); x
        },
        V_k_cols = function(x) {
            x@V_k <- matrix(1, nrow = 2L, ncol = 2L); x
        },
        sigma_k_cols = function(x) {
            x@sigma_k <- matrix(1, nrow = 1L, ncol = 2L); x
        },
        sigma_layers = function(x) { x@sigma <- c(1, 2); x },
        coords_layers = function(x) { x@coords_k <- list(); x }
    )
    messages <- c(
        V_star = "V_star must be a non-empty",
        k = "k must be a positive",
        V_k_rows = "V_k must have nrow",
        V_k_cols = "V_k must have ncol",
        sigma_k_cols = "sigma_k must have ncol",
        sigma_layers = "sigma length must equal",
        coords_layers = "coords_k must have length"
    )

    for (case in names(invalid)) {
        object <- .valid_decomposition_result()
        object <- invalid[[case]](object)
        expect_error(validObject(object), messages[[case]], info = case)
    }
})

test_that("DecompositionResult accessors share typed validation", {
    for (accessor in list(
        dr_V_star, dr_sigma, dr_coords, dr_warnings,
        dr_V_k, dr_sigma_k, dr_coords_k, dr_k
    )) {
        expect_error(
            accessor(list()),
            "requires a DecompositionResult",
            class = "landscapeR_validation_error"
        )
    }
})

test_that("stage_artifact() exposes presence and typed values", {
    data <- empty_std()
    expect_false(has_stage_artifact(data, "stage1"))
    expect_null(stage_artifact(data, "stage1", required = FALSE))
    expect_error(
        stage_artifact(data, "stage1"),
        "stage1 artifact is not available",
        class = "landscapeR_validation_error"
    )

    md <- metadata(data)
    md$stage1 <- .valid_decomposition_result()
    md$stage2 <- list(x = 1)
    metadata(data) <- md
    expect_true(has_stage_artifact(data, "stage1"))
    expect_s4_class(stage_artifact(data, "stage1"), "DecompositionResult")
    expect_identical(stage_artifact(data, "stage2"), list(x = 1))

    md$stage1 <- list(untyped = TRUE)
    metadata(data) <- md
    expect_error(
        stage_artifact(data, "stage1"),
        "requires a DecompositionResult",
        class = "landscapeR_validation_error"
    )
})

test_that("record_provenance requires scoped hashes and declared RNG identity", {
    data <- empty_std()
    expect_error(
        record_provenance(data, "test", "Contract", "implementation"),
        "input_hashes must be supplied explicitly",
        class = "landscapeR_validation_error"
    )

    set.seed(918L)
    recorded <- record_provenance(
        data,
        stage = "test",
        contract = "Contract",
        implementation = "implementation",
        input_hashes = c(expression_matrix = digest::digest(matrix(1:4, 2L))),
        rng = list(
            run_seed = 918L,
            rng_kind = "L'Ecuyer-CMRG",
            seed_derivation = "sha256-lecuyer-state-v1",
            task_id = "test-task"
        )
    )
    step <- recorded@provenance[[1L]]
    expect_length(step@rng_seed, 0L)
    expect_identical(step@params$rng$run_seed, 918L)
    expect_named(step@input_hashes, "expression_matrix")
})

test_that("record_provenance rejects incomplete RNG identities", {
    data <- empty_std()
    base <- list(
        run_seed = 7L,
        rng_kind = "L'Ecuyer-CMRG",
        seed_derivation = "direct-set-seed-v1",
        task_id = "unit-test"
    )
    expect_error(
        record_provenance(
            data, "test", "Contract", "implementation",
            input_hashes = c(expression_matrix = strrep("a", 32L)),
            rng = list(note = "unknown")
        ),
        "containing run_seed, rng_kind, seed_derivation, task_id",
        class = "landscapeR_validation_error"
    )
    expect_error(
        record_provenance(
            data, "test", "Contract", "implementation",
            input_hashes = c(expression_matrix = strrep("a", 32L)),
            rng = c(base, list(streams = c(unnamed = -1L)))
        ),
        "rng\\$streams",
        class = "landscapeR_validation_error"
    )
})

test_that("provenance hashes are unique named hexadecimal digests", {
    data <- empty_std()
    expect_error(
        record_provenance(
            data, "test", "Contract", "implementation",
            input_hashes = c(first = strrep("a", 32L), first = strrep("b", 32L))
        ),
        "unique non-empty names",
        class = "landscapeR_validation_error"
    )
    expect_error(
        record_provenance(
            data, "test", "Contract", "implementation",
            input_hashes = c(expression_matrix = "not-a-digest")
        ),
        "hexadecimal",
        class = "landscapeR_validation_error"
    )
})

test_that("general parameters cannot bypass RNG identity validation", {
    expect_error(
        record_provenance(
            empty_std(), "test", "Contract", "implementation",
            params = list(rng = list(note = "not replayable")),
            input_hashes = c(expression_matrix = strrep("a", 32L))
        ),
        "params\\$rng is reserved",
        class = "landscapeR_validation_error"
    )
})
