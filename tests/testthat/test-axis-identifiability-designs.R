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

.decomposable_time_identifiability_fixture <- function(
    design = c("independent_time_course", "longitudinal")
) {
    design <- match.arg(design)
    if (identical(design, "independent_time_course")) {
        grid <- expand.grid(
            replicate = seq_len(4L),
            day = 0:2,
            condition = c("control", "treatment"),
            KEEP.OUT.ATTRS = FALSE,
            stringsAsFactors = FALSE
        )
        subject <- NULL
    } else {
        subject_table <- expand.grid(
            mouse_number = seq_len(8L),
            condition = c("control", "treatment"),
            KEEP.OUT.ATTRS = FALSE,
            stringsAsFactors = FALSE
        )
        grid <- subject_table[rep(
            seq_len(nrow(subject_table)),
            each = 4L
        ), ]
        grid$day <- rep(0:3, times = nrow(subject_table))
        grid$replicate <- grid$mouse_number
        subject <- paste0(
            substr(grid$condition, 1L, 1L),
            grid$mouse_number
        )
    }
    grid$condition <- factor(
        grid$condition,
        levels = c("control", "treatment")
    )
    n <- nrow(grid)
    primary <- sprintf("sample_%03d", seq_len(n))
    assay_ids <- sprintf("rna_%03d", seq_len(n))
    treatment <- as.numeric(grid$condition == "treatment")
    subject_intercept <- if (is.null(subject)) {
        rep(0, n)
    } else {
        0.25 * sin(grid$mouse_number * 1.3 + treatment * 0.4)
    }
    subject_slope <- if (is.null(subject)) {
        rep(0, n)
    } else {
        0.18 * cos(grid$mouse_number * 1.1 + treatment * 0.3)
    }
    target_axis <- 1.7 * treatment * grid$day +
        subject_intercept +
        subject_slope * grid$day +
        0.08 * sin(seq_len(n) * 1.7)
    time_axis <- grid$day -
        0.7 * subject_intercept +
        0.6 * subject_slope * grid$day +
        0.1 * cos(seq_len(n) * 0.9)
    nuisance_axis <- rep(c(-1, 1), length.out = n)
    loadings <- rbind(
        c(1.0, 0.2, 0.1),
        c(0.8, -0.3, 0.2),
        c(-0.4, 1.0, 0.1),
        c(0.2, 0.8, -0.3),
        c(0.1, -0.2, 1.0),
        c(-0.2, 0.1, 0.8),
        c(0.5, 0.4, -0.2),
        c(-0.3, 0.5, 0.4)
    )
    latent <- rbind(target_axis, time_axis, nuisance_axis)
    expression <- loadings %*% latent
    expression <- expression + matrix(
        0.03 * sin(seq_len(length(expression)) * 0.37),
        nrow = nrow(expression)
    )
    rownames(expression) <- sprintf("gene_%02d", seq_len(nrow(expression)))
    colnames(expression) <- assay_ids
    metadata <- S4Vectors::DataFrame(
        condition = grid$condition,
        day = grid$day,
        sample_id = primary,
        row.names = primary
    )
    if (!is.null(subject)) metadata$mouse_id <- subject
    data <- StateTransitionData(
        experiments = list(
            rna = SummarizedExperiment::SummarizedExperiment(
                assays = list(logcounts = expression)
            )
        ),
        colData = metadata,
        sampleMap = S4Vectors::DataFrame(
            assay = factor(rep("rna", n), levels = "rna"),
            primary = primary,
            colname = assay_ids
        )
    )
    data <- if (identical(design, "independent_time_course")) {
        declare_sampling_design(
            data,
            independent_time_course("day", "days")
        )
    } else {
        declare_sampling_design(
            data,
            longitudinal("mouse_id", "day", "days")
        )
    }
    specification <- analysis_specification(
        id = paste0("axis-identifiability-", design),
        target_field = "condition",
        target_type = "binary",
        reference_level = "control",
        comparison_level = "treatment"
    )
    config <- new(
        "PipelineConfig",
        strategies = list(Decomposer = "svd"),
        params = list(svd = list(center = TRUE, k_components = 3L)),
        dataset = paste0("axis-identifiability-", design),
        analysis = specification
    )
    discovery <- decompose(
        get_strategy("Decomposer", "svd")(config@params$svd),
        data
    )
    expect_identical(discovery@status, "success")
    non_analytical <- c(
        "sample_id",
        if (!is.null(subject)) "mouse_id" else character()
    )
    atlas <- associate_metadata(
        discovery@value,
        specification = specification,
        non_analytical_fields = non_analytical,
        dataset_id = config@dataset
    )
    proposal <- propose_component(atlas)
    list(
        data = data,
        config = config,
        proposal = proposal,
        non_analytical = non_analytical
    )
}

test_that("time-course designs repeat the complete discovery workflow", {
    fixtures <- list(
        independent_time_course =
            .decomposable_time_identifiability_fixture(
                "independent_time_course"
            ),
        longitudinal = .decomposable_time_identifiability_fixture(
            "longitudinal"
        )
    )
    expected_units <- c(
        independent_time_course = "independent-biological-observation",
        longitudinal = "complete-subject-trajectory"
    )
    for (design in names(fixtures)) {
        fixture <- fixtures[[design]]
        assessed <- assess_component_identifiability(
            data = fixture$data,
            proposal = fixture$proposal,
            config = fixture$config,
            non_analytical_fields = fixture$non_analytical,
            n_resamples = 3L,
            seed = 8320L + match(design, names(fixtures))
        )
        evidence <- proposal_identifiability(assessed)
        expect_identical(evidence$resampling$unit, expected_units[[design]])
        plot <- plot_component_identifiability(assessed)
        caption <- gsub("\\s+", " ", scientific_caption(plot))
        expect_null(plot$labels$caption)
        expect_match(
            caption,
            "treatment versus control contrast",
            fixed = TRUE
        )
        expect_match(
            caption,
            "Observed time was recorded as day in days",
            fixed = TRUE
        )
        if (identical(design, "longitudinal")) {
            expect_match(
                caption,
                "Repeated observations were grouped by mouse_id",
                fixed = TRUE
            )
        }
        expect_identical(evidence$n_requested, 3L)
        expect_length(evidence$replicates, 3L)
        expect_true(all(vapply(
            evidence$replicates,
            function(x) {
                identical(x$decomposition_status, "success") &&
                    is.matrix(x$similarity) &&
                    nrow(x$ranking) == 3L
            },
            logical(1L)
        )))
        expect_identical(
            proposal_identifiability(unserialize(serialize(assessed, NULL))),
            evidence
        )
        exploratory <- confirm_component(
            assessed,
            index = assessed@recommended_component,
            decision = "accept",
            rationale = "Record the pre-calibration exploratory choice."
        )
        expect_identical(exploratory@claim_intent, "exploratory")
    }
})

test_that("evidence is identical across sequential and parallel plans", {
    skip_if(
        pkgload::is_dev_package("landscapeR"),
        "multisession requires the installed-package check context"
    )
    fixture <- .decomposable_time_identifiability_fixture(
        "independent_time_course"
    )
    old_plan <- future::plan()
    on.exit(future::plan(old_plan), add = TRUE)
    future::plan(future::sequential)
    sequential <- assess_component_identifiability(
        data = fixture$data,
        proposal = fixture$proposal,
        config = fixture$config,
        non_analytical_fields = fixture$non_analytical,
        n_resamples = 3L,
        seed = 8341L
    )
    future::plan(future::multisession, workers = 2L)
    parallel <- assess_component_identifiability(
        data = fixture$data,
        proposal = fixture$proposal,
        config = fixture$config,
        non_analytical_fields = fixture$non_analytical,
        n_resamples = 3L,
        seed = 8341L
    )
    expect_identical(
        proposal_identifiability(parallel),
        proposal_identifiability(sequential)
    )
})
