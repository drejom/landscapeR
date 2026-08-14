test_that("repeated time courses traverse the shared execution kernel", {
    original <- .execute_assoc_components
    observed_adapter <- NULL
    testthat::local_mocked_bindings(
        .execute_assoc_components = function(adapter, context) {
            observed_adapter <<- adapter
            original(adapter, context)
        },
        .package = "landscapeR"
    )

    atlas <- associate_metadata(
        repeated_time_course_fixture(),
        specification = repeated_time_course_specification("batch"),
        non_analytical_fields = "mouse_id",
        dataset_id = "kernel-repeated",
        n_resamples = 3L,
        seed = 17L,
        sequential_internal = TRUE
    )

    expect_s3_class(
        observed_adapter,
        "landscapeR_association_execution_adapter"
    )
    expect_identical(
        observed_adapter$id,
        "repeated-time-course-random-slope-v1"
    )
    expect_identical(observed_adapter$sampling_design, "longitudinal")

    associations <- atlas_associations(atlas)
    expect_equal(
        associations$estimate,
        c(
            0.564453125,
            2.21607839338599,
            2.2160783933859,
            -0.001953125,
            0.0816847942946047,
            0.08168479429467
        ),
        tolerance = 1e-6
    )
    expect_identical(
        associations$proposal_eligible,
        c(FALSE, TRUE, TRUE, FALSE, TRUE, TRUE)
    )
    expect_identical(
        associations$resample_failures,
        rep(0L, 6L)
    )
    expect_identical(
        unique(stats::na.omit(associations$resampling_plan_digest)),
        "9f5cbad9fed3c40f003759793a9ac2330dc8e47d66befe799fba8f36b4ede9cc"
    )
    expect_identical(
        atlas_evidence_contract(atlas)$row_counts,
        c(associations = 6L, observations = 128L, exclusions = 3L)
    )
    expect_identical(
        atlas_provenance(atlas)$time_course_rank_summary$rank_one_fraction,
        c(1, 0)
    )
})

test_that("repeated refits preserve seeded results across future backends", {
    old_plan <- future::plan()
    on.exit(future::plan(old_plan), add = TRUE)

    skip_if(
        pkgload::is_dev_package("landscapeR"),
        "multisession requires the installed-package check context"
    )
    multisession_available <- suppressWarnings(tryCatch({
        future::plan(future::multisession, workers = 2L)
        identical(future::value(future::future(TRUE)), TRUE)
    }, error = function(condition) FALSE))
    if (!multisession_available) {
        if (nzchar(Sys.getenv("CI"))) {
            testthat::fail("CI must provide a working multisession backend")
        }
        testthat::skip("multisession workers are unavailable")
    }

    future::plan(future::sequential)
    sequential <- associate_metadata(
        repeated_time_course_fixture(),
        specification = repeated_time_course_specification(),
        non_analytical_fields = c("mouse_id", "batch"),
        n_resamples = 3L,
        seed = 212L,
        sequential_internal = FALSE
    )
    future::plan(future::multisession, workers = 2L)
    parallel <- associate_metadata(
        repeated_time_course_fixture(),
        specification = repeated_time_course_specification(),
        non_analytical_fields = c("mouse_id", "batch"),
        n_resamples = 3L,
        seed = 212L,
        sequential_internal = FALSE
    )

    expect_identical(
        atlas_associations(parallel),
        atlas_associations(sequential)
    )
    expect_identical(
        atlas_provenance(parallel)$time_course_resample_rankings,
        atlas_provenance(sequential)$time_course_resample_rankings
    )
    expect_identical(
        atlas_provenance(parallel)$resampling_plan$replicate_subject_ids,
        atlas_provenance(sequential)$resampling_plan$replicate_subject_ids
    )
})
