.kernel_cross_fixture <- function() {
    n <- 8L
    primary <- sprintf("sample_%02d", seq_len(n))
    assay_ids <- sprintf("rna_%02d", seq_len(n))
    se <- SummarizedExperiment::SummarizedExperiment(
        assays = list(logcounts = matrix(
            seq_len(4L * n),
            nrow = 4L,
            dimnames = list(sprintf("gene_%02d", 1:4), assay_ids)
        ))
    )
    std <- StateTransitionData(
        experiments = list(rna = se),
        colData = S4Vectors::DataFrame(
            condition = factor(
                rep(c("control", "treatment"), each = n / 2L),
                levels = c("control", "treatment")
            ),
            mouse_id = sprintf("mouse_%02d", seq_len(n)),
            row.names = primary
        ),
        sampleMap = S4Vectors::DataFrame(
            assay = factor(rep("rna", n), levels = "rna"),
            primary = primary,
            colname = assay_ids
        )
    )
    std <- declare_sampling_design(std, cross_sectional())
    coordinates <- cbind(
        PC1 = seq_len(n),
        PC2 = rep(c(-1, 1), times = n / 2L)
    )
    md <- metadata(std)
    md$stage1 <- DecompositionResult(
        V_star = c(1, 0, 0, 0),
        sigma = 1,
        coords = list(coordinates[, 1L]),
        V_k = diag(4)[, 1:2, drop = FALSE],
        sigma_k = matrix(c(2, 1), nrow = 1L),
        coords_k = list(coordinates),
        k = 2L
    )
    metadata(std) <- md
    std
}

test_that("association execution preserves successful evidence identities", {
    cross <- associate_metadata(
        .kernel_cross_fixture(),
        non_analytical_fields = "mouse_id",
        dataset_id = "kernel-cross",
        n_resamples = 3L,
        seed = 17L,
        sequential_internal = TRUE
    )
    independent <- associate_metadata(
        independent_time_course_fixture(),
        specification = independent_time_course_specification("batch"),
        non_analytical_fields = "sample_id",
        dataset_id = "kernel-independent",
        n_resamples = 3L,
        seed = 17L,
        sequential_internal = TRUE
    )

    expect_identical(
        atlas_digest(cross),
        "e9a80c9b4a59b685a78827a4affcb3288200df4f38008ac5333f10abb1081862"
    )
    expect_identical(
        atlas_evidence_contract(cross)$digests,
        c(
            associations =
                "25d46fad7494d22796dbf458aa159f43a8dc06a029c0e17f420d0e3b905771ae",
            observations =
                "502f75ba839a11d0028e1302e359d93b44ca4c8293152c6d33a4e4a551a86b48",
            exclusions =
                "d7f577eceee6b36862c85beb86a84f7f3f276afd081f6407e645817a7a8a55bf",
            cohort_members =
                "06bd8696bc6e7d421b5edba42a5cfa6af1181fbdca7cf55ff09fb5d4722b7d2e",
            display_evidence =
                "ceafb3b56ebb332ba7df955f583084d0106e9c0bbdb4aea5e17a1269c4877f9d"
        )
    )
    expect_identical(
        .assoc_exec_fingerprint(independent),
        "ceebfccce6d0beb6affa639cee17c6a442203c9d87e98d764937c14549175780"
    )
})

test_that("association execution preserves partial-case evidence identities", {
    cross_fixture <- .kernel_cross_fixture()
    colData(cross_fixture)$condition[[2L]] <- NA
    cross <- associate_metadata(
        cross_fixture,
        non_analytical_fields = "mouse_id",
        dataset_id = "kernel-cross-partial",
        n_resamples = 3L,
        seed = 17L,
        sequential_internal = TRUE
    )
    independent_fixture <- independent_time_course_fixture()
    colData(independent_fixture)$batch[[2L]] <- NA
    independent <- associate_metadata(
        independent_fixture,
        specification = independent_time_course_specification("batch"),
        non_analytical_fields = "sample_id",
        dataset_id = "kernel-independent-partial",
        n_resamples = 3L,
        seed = 17L,
        sequential_internal = TRUE
    )

    expect_identical(
        atlas_digest(cross),
        "44bc45c654ca7761513643ca2992af8c6382668014960a5ea43e8f11e33a9d04"
    )
    expect_identical(
        .assoc_exec_fingerprint(independent),
        "8869e089769e5f244830a838bb65c526f5e6d2f39df701c3c962a76edb943647"
    )
})

test_that("association execution preserves typed abstention", {
    fixture <- independent_time_course_fixture()
    colData(fixture)$day <- 0

    result <- associate_metadata(
        fixture,
        specification = independent_time_course_specification("batch"),
        non_analytical_fields = "sample_id",
        dataset_id = "kernel-independent-abstain",
        n_resamples = 3L,
        seed = 17L,
        sequential_internal = TRUE
    )

    expect_s4_class(result, "AssociationAbstention")
    expect_identical(result@reason, "non-identifiable-design")
    expect_match(result@diagnostic, "fewer than two finite values")
})

test_that("portable fingerprints retain scientific provenance and evidence", {
    atlas <- associate_metadata(
        independent_time_course_fixture(),
        specification = independent_time_course_specification("batch"),
        non_analytical_fields = "sample_id",
        dataset_id = "kernel-independent",
        n_resamples = 3L,
        seed = 17L,
        sequential_internal = TRUE
    )
    baseline <- .assoc_exec_fingerprint(atlas)

    changed_formula <- atlas
    formula_provenance <- atlas_provenance(changed_formula)
    formula_provenance$model_formula_digest <- paste(rep("0", 64L), collapse = "")
    changed_formula@provenance <- formula_provenance
    expect_false(identical(.assoc_exec_fingerprint(changed_formula), baseline))

    changed_specification <- atlas
    specification_provenance <- atlas_provenance(changed_specification)
    specification_provenance$analysis_specification_digest <-
        paste(rep("1", 64L), collapse = "")
    changed_specification@provenance <- specification_provenance
    expect_false(identical(
        .assoc_exec_fingerprint(changed_specification),
        baseline
    ))

    changed_resampling <- atlas
    resampling_provenance <- atlas_provenance(changed_resampling)
    resampling_provenance$resampling_plan$digest <-
        paste(rep("2", 64L), collapse = "")
    changed_resampling@provenance <- resampling_provenance
    expect_false(identical(
        .assoc_exec_fingerprint(changed_resampling),
        baseline
    ))

    changed_model <- atlas
    model_provenance <- atlas_provenance(changed_model)
    model_provenance$time_course_models[[1L]]$unadjusted$estimate <-
        model_provenance$time_course_models[[1L]]$unadjusted$estimate + 1e-4
    changed_model@provenance <- model_provenance
    expect_false(identical(.assoc_exec_fingerprint(changed_model), baseline))

    changed_engine <- atlas
    engine_provenance <- atlas_provenance(changed_engine)
    engine_provenance$model_engine <- "stats::glm"
    changed_engine@provenance <- engine_provenance
    expect_false(identical(.assoc_exec_fingerprint(changed_engine), baseline))

    changed_runtime <- atlas
    runtime_provenance <- atlas_provenance(changed_runtime)
    runtime_provenance$model_engine_version <- "different-runtime-version"
    runtime_provenance$time_course_models[[1L]]$
        unadjusted_uncertainty$execution$digest <-
        paste(rep("3", 64L), collapse = "")
    changed_runtime@provenance <- runtime_provenance
    expect_identical(.assoc_exec_fingerprint(changed_runtime), baseline)

    changed_execution <- atlas
    execution_provenance <- atlas_provenance(changed_execution)
    execution_provenance$time_course_models[[1L]]$
        unadjusted_uncertainty$execution$values[[1L]] <-
        execution_provenance$time_course_models[[1L]]$
        unadjusted_uncertainty$execution$values[[1L]] + 1e-4
    changed_execution@provenance <- execution_provenance
    expect_false(identical(
        .assoc_exec_fingerprint(changed_execution),
        baseline
    ))

    changed_association <- atlas
    changed_association@associations$estimate[[1L]] <-
        changed_association@associations$estimate[[1L]] + 1e-4
    expect_false(identical(
        .assoc_exec_fingerprint(changed_association),
        baseline
    ))
})

test_that("portable fingerprint uses explicit six-decimal quantization", {
    expect_identical(.assoc_exec_normalize(1 + 4e-7), 1)
    expect_identical(.assoc_exec_normalize(1 + 6e-6), 1.000006)
    expect_false(identical(
        .assoc_exec_normalize(1.00000049),
        .assoc_exec_normalize(1.00000051)
    ))
})
