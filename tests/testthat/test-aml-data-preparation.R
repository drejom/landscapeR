mapping_script <- system.file(
    "scripts",
    "gse133642-metadata.R",
    package = "landscapeR"
)
expect_true(nzchar(mapping_script), info = "AML mapping code is installed")
source(mapping_script, local = TRUE)

aml_sample_mapping <- function() {
    path <- system.file(
        "extdata",
        "gse133642-sample-weeks.csv",
        package = "landscapeR"
    )
    testthat::expect_true(nzchar(path), info = "AML source-time mapping is installed")
    read_gse133642_sample_weeks(path)
}

test_that("AML source-time mapping fixes cohort identity and covers every observation", {
    mapping <- aml_sample_mapping()

    expect_identical(
        names(mapping),
        c(
            "expression_name", "library_id", "source_cohort",
            "prepared_layer", "mouse_id", "sample_weeks"
        )
    )
    expect_equal(nrow(mapping), 233L)
    expect_false(anyNA(mapping))
    expect_false(anyDuplicated(mapping$expression_name) > 0L)
    expect_false(anyDuplicated(mapping$library_id) > 0L)

    expect_identical(
        as.integer(table(mapping$prepared_layer)[
            c("mrna_primary_2018", "mrna_supp_2016")
        ]),
        c(132L, 101L)
    )
    expect_true(all(
        mapping$source_cohort[mapping$prepared_layer == "mrna_primary_2018"] ==
            "AML.mRNA.2018.all_samples"
    ))
    expect_true(all(
        mapping$source_cohort[mapping$prepared_layer == "mrna_supp_2016"] ==
            "AML.mRNA.2016"
    ))
})

test_that("AML mapping rejects duplicates, unmatched samples, and identity drift", {
    mapping <- aml_sample_mapping()
    example <- mapping[mapping$prepared_layer == "mrna_primary_2018", ]
    meta <- data.frame(
        mouse_id = example$mouse_id,
        row.names = example$expression_name,
        stringsAsFactors = FALSE
    )

    attached <- attach_gse133642_sample_weeks(
        meta,
        prepared_layer = "mrna_primary_2018",
        source_cohort = "AML.mRNA.2018.all_samples",
        mapping = mapping
    )
    expect_identical(attached$sample_weeks, example$sample_weeks)

    duplicate <- mapping
    duplicate$library_id[2L] <- duplicate$library_id[1L]
    expect_error(
        validate_gse133642_sample_weeks(duplicate),
        "duplicate observation keys"
    )

    unmatched <- meta[1L, , drop = FALSE]
    rownames(unmatched) <- "T0_9999_CM_CHW_M_G1_99999"
    expect_error(
        attach_gse133642_sample_weeks(
            unmatched,
            prepared_layer = "mrna_primary_2018",
            source_cohort = "AML.mRNA.2018.all_samples",
            mapping = mapping
        ),
        "does not map one-to-one"
    )

    wrong_mouse <- meta
    wrong_mouse$mouse_id[1L] <- "not-the-source-mouse"
    expect_error(
        attach_gse133642_sample_weeks(
            wrong_mouse,
            prepared_layer = "mrna_primary_2018",
            source_cohort = "AML.mRNA.2018.all_samples",
            mapping = mapping
        ),
        "mouse identifiers disagree"
    )
})

test_that("AML source weeks preserve authoritative decimals without endpoint schema", {
    mapping <- aml_sample_mapping()

    expect_type(mapping$sample_weeks, "double")
    expect_true(all(is.finite(mapping$sample_weeks)))
    expect_true(any(mapping$sample_weeks %% 1 != 0))
    expect_false(any(grepl("endpoint|event|timepoint", names(mapping))))

    terminal_weeks <- c(
        COHP_11548 = 25.9,
        COHP_12124 = 19.0,
        COHP_12125 = 19.0,
        COHP_12126 = 31.0,
        COHP_12127 = 19.0,
        COHP_12128 = 13.4
    )
    observed <- mapping$sample_weeks[match(names(terminal_weeks), mapping$library_id)]
    expect_identical(observed, unname(terminal_weeks))
})

test_that("AML source weeks are complete and strictly ordered within mouse", {
    mapping <- aml_sample_mapping()
    subject <- interaction(
        mapping$source_cohort,
        mapping$mouse_id,
        drop = TRUE
    )
    ordered <- tapply(mapping$sample_weeks, subject, function(weeks) {
        !anyDuplicated(weeks) && all(diff(sort(weeks)) > 0)
    })

    expect_equal(length(ordered), 30L)
    expect_true(all(ordered))
})
