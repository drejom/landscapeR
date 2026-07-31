.cross_evidence_fixture <- function() {
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
    coords <- cbind(
        PC1 = seq_len(n),
        PC2 = rep(c(-1, 1), times = n / 2L)
    )
    md <- metadata(std)
    md$stage1 <- DecompositionResult(
        V_star = c(1, 0, 0, 0),
        sigma = 1,
        coords = list(coords[, 1L]),
        V_k = diag(4)[, 1:2, drop = FALSE],
        sigma_k = matrix(c(2, 1), nrow = 1L),
        coords_k = list(coords),
        k = 2L
    )
    metadata(std) <- md
    std
}

test_that("cross-sectional workflow exposes its complete evidence contract", {
    atlas <- associate_metadata(
        .cross_evidence_fixture(),
        non_analytical_fields = "mouse_id",
        dataset_id = "evidence-contract"
    )

    contract <- atlas_evidence_contract(atlas)

    expect_identical(contract$version, "cross-sectional-v1")
    expect_identical(contract$sampling_design, "cross_sectional")
    expect_identical(
        contract$row_counts,
        c(associations = 2L, observations = 16L, exclusions = 1L)
    )
    expect_named(
        contract$digests,
        c(
            "associations", "observations", "exclusions", "cohort_members",
            "display_evidence"
        )
    )
    expect_true(all(grepl("^[[:xdigit:]]{64}$", contract$digests)))
    expect_identical(
        names(contract$cohorts),
        c(
            "metadata_field", "component", "evidence_variant",
            "cohort_digest", "n_available", "n_missing"
        )
    )
    expect_identical(contract$cohorts$metadata_field, rep("condition", 2L))
    expect_identical(contract$cohorts$component, c(1L, 2L))
    expect_identical(nrow(contract$cohort_members), 16L)
    expect_identical(
        unique(contract$cohort_members$primary_sample),
        sprintf("sample_%02d", seq_len(8L))
    )
    expect_true(all(contract$cohort_members$included))
    expect_true(validObject(atlas))

    restored <- unserialize(serialize(atlas, NULL))
    expect_identical(atlas_evidence_contract(restored), contract)
    expect_identical(atlas_associations(restored), atlas_associations(atlas))
})

test_that("cross-sectional evidence contract retains missing and collapsed states", {
    missing_std <- .cross_evidence_fixture()
    colData(missing_std)$condition[[2L]] <- NA
    missing_atlas <- associate_metadata(
        missing_std,
        non_analytical_fields = "mouse_id"
    )
    missing_contract <- atlas_evidence_contract(missing_atlas)

    expect_identical(missing_contract$cohorts$n_available, c(7L, 7L))
    expect_identical(missing_contract$cohorts$n_missing, c(1L, 1L))
    expect_identical(missing_contract$row_counts[["observations"]], 16L)
    expect_identical(sum(!missing_contract$cohort_members$included), 2L)

    collapsed_std <- .cross_evidence_fixture()
    colData(collapsed_std)$condition <- factor(rep("control", 8L))
    collapsed_atlas <- associate_metadata(
        collapsed_std,
        non_analytical_fields = "mouse_id"
    )
    collapsed_contract <- atlas_evidence_contract(collapsed_atlas)

    expect_identical(
        collapsed_contract$row_counts,
        c(associations = 0L, observations = 0L, exclusions = 2L)
    )
    expect_identical(
        atlas_exclusions(collapsed_atlas)$reason,
        c("unsupported-non-binary-field", "declared-non-analytical")
    )
    expect_true(validObject(collapsed_atlas))
})

test_that("cross-sectional evidence contract retains typed non-identifiability", {
    std <- .cross_evidence_fixture()
    colData(std)$batch <- colData(std)$condition
    specification <- analysis_specification(
        id = "contract-confounded-binary",
        target_field = "condition",
        target_type = "binary",
        reference_level = "control",
        comparison_level = "treatment",
        nuisance_fields = "batch"
    )
    atlas <- associate_metadata(
        std,
        specification = specification,
        non_analytical_fields = "mouse_id"
    )

    target <- atlas_associations(atlas)
    target <- target[
        target$metadata_field == "condition" &
            target$evidence_variant == "adjusted",
        ,
        drop = FALSE
    ]
    expect_true(all(is.na(target$estimate)))
    expect_identical(
        target$diagnostic,
        rep("non-identifiable-design", 2L)
    )
    expect_true(validObject(atlas))
    expect_s4_class(propose_component(atlas), "ComponentAbstention")
    expect_identical(
        propose_component(atlas)@reason,
        "non-identifiable-design"
    )
})

test_that("evidence contract accessor rejects invalid public input", {
    expect_error(
        atlas_evidence_contract(list()),
        class = "landscapeR_validation_error"
    )
})

test_that("cross-sectional module marker makes its contract mandatory", {
    atlas <- associate_metadata(
        .cross_evidence_fixture(),
        non_analytical_fields = "mouse_id"
    )
    missing_contract <- atlas
    missing_contract@provenance$evidence_contract <- NULL
    expect_error(
        validObject(missing_contract),
        "requires evidence contract"
    )

    missing_marker <- atlas
    missing_marker@provenance$interpretation_module <- NULL
    expect_error(
        validObject(missing_marker),
        "requires a recognized interpretation module"
    )
})

test_that("cohort membership must cover the exact observation universe", {
    atlas <- associate_metadata(
        .cross_evidence_fixture(),
        non_analytical_fields = "mouse_id"
    )
    altered <- atlas
    altered@provenance$evidence_contract$cohort_members <-
        altered@provenance$evidence_contract$cohort_members[-1L, , drop = FALSE]

    expect_error(
        validObject(altered),
        "cohort membership does not match association evidence"
    )
})

test_that("cohort membership rejects undeclared association groups", {
    atlas <- associate_metadata(
        .cross_evidence_fixture(),
        non_analytical_fields = "mouse_id"
    )
    altered <- atlas
    orphan <- altered@provenance$evidence_contract$cohort_members[1L, ]
    orphan$component <- 99L
    altered@provenance$evidence_contract$cohort_members <- rbind(
        altered@provenance$evidence_contract$cohort_members,
        orphan
    )

    expect_error(
        validObject(altered),
        "cohort membership groups do not equal association groups"
    )
})

test_that("evidence contract rejects duplicate association groups", {
    atlas <- associate_metadata(
        .cross_evidence_fixture(),
        non_analytical_fields = "mouse_id"
    )
    altered <- atlas
    altered@associations <- rbind(
        altered@associations,
        altered@associations[1L, , drop = FALSE]
    )

    expect_error(
        validObject(altered),
        "association groups must be unique"
    )
})

test_that("public cross-sectional atlas plot renders all diagnostic panels", {
    atlas <- associate_metadata(
        .cross_evidence_fixture(),
        non_analytical_fields = "mouse_id"
    )

    expect_s3_class(
        ggplot2::ggplotGrob(plot(atlas)),
        "gtable"
    )
})

test_that("all supported designs expose one evidence-contract list shape", {
    cross <- associate_metadata(
        .cross_evidence_fixture(),
        non_analytical_fields = "mouse_id"
    )
    independent <- associate_metadata(
        independent_time_course_fixture(include_nuisance = FALSE),
        specification = independent_time_course_specification(),
        non_analytical_fields = c("sample_id", "batch")
    )
    repeated <- associate_metadata(
        repeated_time_course_fixture(),
        specification = repeated_time_course_specification(),
        non_analytical_fields = c("mouse_id", "batch")
    )
    contracts <- lapply(
        list(cross, independent, repeated),
        atlas_evidence_contract
    )

    expect_true(all(vapply(
        contracts,
        function(contract) {
            identical(
                names(contract),
                c(
                    "version", "sampling_design", "row_counts", "digests",
                    "cohorts", "cohort_members"
                )
            )
        },
        logical(1L)
    )))
    expect_identical(
        vapply(contracts, `[[`, character(1L), "sampling_design"),
        c("cross_sectional", "independent_time_course", "longitudinal")
    )
})
