test_that("symmetric association families use one Holm contract", {
    symmetric <- data.frame(
        metadata_field = rep("condition", 4L),
        evidence_variant = rep("unadjusted", 4L),
        p_value = c(0.01, 0.03, 0.2, NA_real_),
        q_value = rep(NA_real_, 4L),
        stringsAsFactors = FALSE
    )
    designs <- c(
        "cross_sectional",
        "independent_time_course",
        "longitudinal"
    )
    adjusted <- stats::setNames(lapply(
        designs,
        function(design) landscapeR:::.adjust_association_multiplicity(symmetric)
    ), designs)

    expect_identical(
        landscapeR:::.association_multiplicity_contract()$method,
        "holm"
    )
    expect_true(all(vapply(
        adjusted,
        function(result) identical(result$p_value, symmetric$p_value),
        logical(1L)
    )))
    expect_equal(
        adjusted$cross_sectional$q_value,
        stats::p.adjust(symmetric$p_value, method = "holm")
    )
    expect_identical(
        adjusted$cross_sectional$q_value,
        adjusted$independent_time_course$q_value
    )
    expect_identical(
        adjusted$cross_sectional$q_value,
        adjusted$longitudinal$q_value
    )
})

test_that("multiplicity families separate metadata fields and evidence variants", {
    associations <- data.frame(
        metadata_field = c("condition", "condition", "condition", "batch"),
        evidence_variant = c("raw", "raw", "adjusted", "raw"),
        p_value = c(0.02, 0.04, 0.03, 0.01),
        q_value = NA_real_,
        stringsAsFactors = FALSE
    )
    adjusted <- landscapeR:::.adjust_association_multiplicity(associations)

    expect_equal(adjusted$q_value, c(0.04, 0.04, 0.03, 0.01))
})
