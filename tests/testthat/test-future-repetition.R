multisession_worker_available <- function(workers = 2L) {
    suppressWarnings(tryCatch({
        future::plan(future::multisession, workers = workers)
        identical(future::value(future::future(TRUE)), TRUE)
    }, error = function(condition) FALSE))
}

test_that("compute tiers and run seeds are validated", {
    expect_identical(landscapeR:::.validate_compute_tier("inspect"), "inspect")
    expect_identical(landscapeR:::.validate_compute_tier("standard"), "standard")
    expect_identical(landscapeR:::.validate_compute_tier("evidence"), "evidence")
    expect_error(landscapeR:::.validate_compute_tier("quick"), class = "landscapeR_validation_error")
    expect_error(
        landscapeR:::.future_repetition(list(1), "task", NA_integer_, "standard", identity),
        class = "landscapeR_validation_error"
    )
    fixture <- independent_time_course_fixture(include_nuisance = FALSE)
    specification <- independent_time_course_specification()
    for (bad_seed in list(-1, Inf, 1.5, .Machine$integer.max + 1)) {
        expect_error(
            associate_metadata(fixture, specification, seed = bad_seed),
            class = "landscapeR_validation_error"
        )
    }
})

test_that("legacy serialized atlas compute tiers remain valid", {
    atlas <- associate_metadata(
        independent_time_course_fixture(include_nuisance = FALSE),
        independent_time_course_specification()
    )
    for (legacy_tier in landscapeR:::.legacy_compute_tiers) {
        legacy <- atlas
        legacy@compute_tier <- legacy_tier
        expect_true(methods::validObject(legacy))
    }
})

test_that("future repetition is deterministic across plans and worker counts", {
    previous <- future::plan()
    on.exit(future::plan(previous), add = TRUE)
    tasks <- as.list(1:8)
    ids <- sprintf("task_%02d", seq_along(tasks))
    worker <- function(task, task_id, task_stream) stats::runif(2L) + task

    future::plan(future::sequential)
    sequential <- landscapeR:::.future_repetition(
        tasks, ids, 4101L, "standard", worker
    )
    forced <- landscapeR:::.future_repetition(
        tasks, ids, 4101L, "standard", worker,
        sequential_internal = TRUE
    )
    expect_identical(forced, sequential)
    skip_if(
        pkgload::is_dev_package("landscapeR"),
        "multisession requires the installed-package check context"
    )
    multisession_available <- multisession_worker_available()
    if (!multisession_available) {
        if (nzchar(Sys.getenv("CI"))) {
            testthat::fail("CI must provide a working multisession backend")
        }
        testthat::skip("multisession workers are unavailable in this test context")
    }
    parallel <- landscapeR:::.future_repetition(
        tasks, ids, 4101L, "standard", worker
    )

    expect_identical(parallel, sequential)
    expect_identical(sequential$account$n_requested, 8L)
    expect_identical(sequential$account$n_completed, 8L)
    expect_identical(sequential$provenance$compute_tier, "standard")
    expect_identical(sequential$provenance$rng_kind, "L'Ecuyer-CMRG")
    expect_length(unique(vapply(
        sequential$provenance$task_streams,
        paste,
        collapse = ":",
        character(1L)
    )), 8L)
})

test_that("sequential_internal executes in the current worker without nesting futures", {
    previous <- future::plan()
    on.exit(future::plan(previous), add = TRUE)
    future::plan(future::multicore, workers = 2L)

    observations <- new.env(parent = emptyenv())
    observations$count <- 0L
    result <- landscapeR:::.future_repetition(
        tasks = as.list(1:3),
        task_ids = paste0("inner-", 1:3),
        run_seed = 42L,
        compute_tier = "evidence",
        worker = function(task, task_id, task_stream) {
            observations$count <- observations$count + 1L
            task
        },
        sequential_internal = TRUE
    )

    expect_identical(observations$count, 3L)
    expect_identical(result$values, as.list(1:3))
})

test_that("legacy stream derivation restores caller RNG state", {
    previous_kind <- RNGkind()
    had_seed <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
    if (had_seed) previous_seed <- get(".Random.seed", envir = .GlobalEnv)
    on.exit({
        do.call(RNGkind, as.list(previous_kind))
        if (had_seed) {
            assign(".Random.seed", previous_seed, envir = .GlobalEnv)
        } else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
            rm(".Random.seed", envir = .GlobalEnv)
        }
    }, add = TRUE)
    RNGkind("Mersenne-Twister")
    set.seed(991L)
    caller_kind <- RNGkind()
    caller_seed <- .Random.seed

    streams <- landscapeR:::.legacy_sequential_task_streams(
        11001L,
        as.list(1:3),
        sprintf("legacy:%02d", 1:3),
        function(task, task_id) stats::runif(task)
    )

    expect_length(streams, 3L)
    expect_true(all(vapply(streams, length, integer(1L)) == 7L))
    expect_identical(RNGkind(), caller_kind)
    expect_identical(.Random.seed, caller_seed)
})

test_that("scientific workflow is invariant across available future backends", {
    previous <- future::plan()
    on.exit(future::plan(previous), add = TRUE)
    args <- list(
        std = independent_time_course_fixture(include_nuisance = FALSE),
        specification = independent_time_course_specification(),
        non_analytical_fields = "sample_id",
        n_resamples = 3L,
        seed = 4104L
    )

    future::plan(future::sequential)
    sequential <- do.call(associate_metadata, c(args, list(future_scheduling = 0)))
    sequential_chunked <- do.call(
        associate_metadata,
        c(args, list(future_scheduling = Inf))
    )
    nested <- do.call(
        associate_metadata,
        c(args, list(sequential_internal = TRUE))
    )
    expect_identical(atlas_associations(sequential_chunked), atlas_associations(sequential))
    expect_identical(atlas_provenance(sequential_chunked), atlas_provenance(sequential))
    expect_identical(atlas_associations(nested), atlas_associations(sequential))
    expect_identical(atlas_provenance(nested), atlas_provenance(sequential))
    skip_if(
        pkgload::is_dev_package("landscapeR"),
        "multisession requires the installed-package check context"
    )
    multisession_available <- multisession_worker_available()
    if (!multisession_available) {
        if (nzchar(Sys.getenv("CI"))) {
            testthat::fail("CI must provide a working multisession backend")
        }
        testthat::skip("multisession workers are unavailable in this test context")
    }
    parallel <- do.call(
        associate_metadata,
        c(args, list(future_scheduling = 0.5))
    )

    expect_identical(atlas_associations(parallel), atlas_associations(sequential))
    expect_identical(atlas_provenance(parallel), atlas_provenance(sequential))
    expect_identical(parallel@input_digest, sequential@input_digest)
    expect_identical(parallel@state_space_digest, sequential@state_space_digest)
})

test_that("resampling plans are invariant to the ambient RNG kind", {
    previous_kind <- RNGkind()
    on.exit(do.call(RNGkind, as.list(previous_kind)), add = TRUE)
    factory <- function(i) sample.int(20L, 5L, replace = TRUE)

    RNGkind("Mersenne-Twister")
    first <- landscapeR:::.resampling_policy_plan(
        "bootstrap", "test", "sample", 4L, 4105L,
        draw_factory = factory
    )
    RNGkind("L'Ecuyer-CMRG")
    second <- landscapeR:::.resampling_policy_plan(
        "bootstrap", "test", "sample", 4L, 4105L,
        draw_factory = factory
    )

    expect_identical(second, first)
})

test_that("future repetition retains typed partial failures in the denominator", {
    result <- landscapeR:::.future_repetition(
        as.list(1:3),
        c("ok", "known", "error"),
        4102L,
        "evidence",
        function(task, task_id, task_stream) {
            if (task_id == "known") {
                return(landscapeR:::.repetition_failure("not-estimable", NA_real_))
            }
            if (task_id == "error") stop("pathological task")
            task
        }
    )
    expect_s3_class(result, "landscapeR_repetition_result")
    expect_identical(result$account$n_requested, 3L)
    expect_identical(result$account$n_completed, 1L)
    expect_identical(result$account$n_failed, 2L)
    expect_identical(
        result$account$failure_codes,
        c("", "not-estimable", "task-error")
    )
})

test_that("independent and repeated adapters retain typed execution evidence", {
    cases <- list(
        independent = list(
            data = independent_time_course_fixture(include_nuisance = FALSE),
            specification = independent_time_course_specification(),
            non_analytical = "sample_id",
            prefix = "independent:"
        ),
        repeated = list(
            data = repeated_time_course_fixture(),
            specification = repeated_time_course_specification(),
            non_analytical = "mouse_id",
            prefix = "repeated:"
        )
    )
    for (case in cases) {
        atlas <- associate_metadata(
            case$data,
            specification = case$specification,
            non_analytical_fields = case$non_analytical,
            n_resamples = 3L,
            seed = 4103L
        )
        expect_identical(atlas@compute_tier, "standard")
        executions <- lapply(
            atlas_provenance(atlas)$time_course_models,
            function(model) model$unadjusted_uncertainty$execution
        )
        expect_true(all(vapply(
            executions,
            inherits,
            logical(1L),
            "landscapeR_repetition_result"
        )))
        expect_true(all(vapply(executions, function(execution) {
            execution$account$n_requested == 3L &&
                all(startsWith(
                    execution$provenance$task_ids,
                    case$prefix
                ))
        }, logical(1L))))
    }
})
