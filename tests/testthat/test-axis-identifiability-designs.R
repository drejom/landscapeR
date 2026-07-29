test_that("independent time-course draws preserve condition-time cells", {
    data <- independent_time_course_fixture()
    specification <- independent_time_course_specification()
    plan <- landscapeR:::.identifiability_resampling_plan(
        data,
        specification,
        n_resamples = 9L,
        seed = 8311L
    )
    metadata <- as.data.frame(SummarizedExperiment::colData(data))
    expected <- table(metadata$condition, metadata$day)

    expect_identical(plan$unit, "independent-biological-observation")
    expect_identical(plan$method, "condition-time-cell-bootstrap")
    for (draw in plan$draws) {
        observed <- metadata[
            match(draw$source_primary, rownames(metadata)),
            ,
            drop = FALSE
        ]
        expect_identical(
            unname(table(observed$condition, observed$day)),
            unname(expected)
        )
        expect_null(draw$replicate_subject)
    }
})

test_that("longitudinal draws preserve complete subject trajectories", {
    data <- repeated_time_course_fixture(
        subjects_per_condition = 4L,
        dropout = c("c1", "t4"),
        irregular = TRUE
    )
    specification <- repeated_time_course_specification()
    plan <- landscapeR:::.identifiability_resampling_plan(
        data,
        specification,
        n_resamples = 7L,
        seed = 8312L
    )
    metadata <- as.data.frame(SummarizedExperiment::colData(data))

    expect_identical(plan$unit, "complete-subject-trajectory")
    expect_identical(
        plan$method,
        "condition-stratified-subject-trajectory-bootstrap"
    )
    for (replicate_index in seq_along(plan$draws)) {
        draw <- plan$draws[[replicate_index]]
        expect_length(draw$replicate_subject, length(draw$source_primary))
        source <- metadata[
            match(draw$source_primary, rownames(metadata)),
            ,
            drop = FALSE
        ]
        groups <- split(seq_len(nrow(source)), draw$replicate_subject)
        for (rows in groups) {
            expect_length(unique(source$mouse_id[rows]), 1L)
            original <- metadata[
                metadata$mouse_id == source$mouse_id[rows[[1L]]],
                ,
                drop = FALSE
            ]
            expect_equal(source$day[rows], original$day)
            expect_length(unique(source$condition[rows]), 1L)
        }
        expect_true(all(grepl(
            sprintf("^bootstrap_%04d_subject_", replicate_index),
            unique(draw$replicate_subject)
        )))
    }
})

test_that("identifiability resampling is deterministic and RNG-isolated", {
    data <- independent_time_course_fixture()
    specification <- independent_time_course_specification()
    set.seed(99)
    before <- .Random.seed
    first <- landscapeR:::.identifiability_resampling_plan(
        data,
        specification,
        n_resamples = 5L,
        seed = 8313L
    )
    expect_identical(.Random.seed, before)
    second <- landscapeR:::.identifiability_resampling_plan(
        data,
        specification,
        n_resamples = 5L,
        seed = 8313L
    )

    expect_identical(first, second)
})
