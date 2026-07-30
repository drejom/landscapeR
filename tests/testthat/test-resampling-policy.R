test_that("resampling policy plans are deterministic and RNG isolated", {
    set.seed(9301L)
    before <- .Random.seed
    first <- landscapeR:::.resampling_policy_plan(
        lifecycle = "bootstrap",
        method = "test-stratified-bootstrap",
        unit = "biological-unit",
        n_requested = 4L,
        seed = 9302L,
        design = list(strata = list(a = 1:3, b = 4:6)),
        draw_factory = function(replicate_index) {
            sample.int(6L, replace = TRUE)
        },
        materialize_replicate_seeds = TRUE
    )
    after <- .Random.seed
    second <- landscapeR:::.resampling_policy_plan(
        lifecycle = "bootstrap",
        method = "test-stratified-bootstrap",
        unit = "biological-unit",
        n_requested = 4L,
        seed = 9302L,
        design = list(strata = list(a = 1:3, b = 4:6)),
        draw_factory = function(replicate_index) {
            sample.int(6L, replace = TRUE)
        },
        materialize_replicate_seeds = TRUE
    )

    expect_identical(before, after)
    expect_identical(first, second)
    expect_s3_class(first, "landscapeR_resampling_plan")
    expect_identical(first$status, "planned")
    expect_identical(first$n_requested, 4L)
    expect_length(first$draws, 4L)
    expect_length(first$replicate_seeds, 4L)
    expect_match(first$digest, "^[[:xdigit:]]{64}$")
    expect_identical(unserialize(serialize(first, NULL)), first)
    expect_true(landscapeR:::.validate_resampling_policy_plan(first))
    tampered <- first
    tampered$draws[[1L]] <- rev(tampered$draws[[1L]])
    expect_error(
        landscapeR:::.validate_resampling_policy_plan(tampered),
        "digest"
    )
})

test_that("resampling accounting preserves requested failure denominators", {
    plan <- landscapeR:::.resampling_policy_plan(
        lifecycle = "permutation",
        method = "test-permutation",
        unit = "exchangeable-unit",
        n_requested = 4L,
        seed = 9303L,
        design = list(exchangeability = "independent"),
        draw_factory = function(replicate_index) sample.int(8L)
    )
    partial <- landscapeR:::.resampling_policy_account(
        plan,
        completed = c(TRUE, FALSE, TRUE, FALSE),
        failure_codes = c("", "fit-failed", "", "non-finite-effect")
    )

    expect_identical(partial$status, "partial")
    expect_identical(partial$n_requested, 4L)
    expect_identical(partial$n_completed, 2L)
    expect_identical(partial$n_failed, 2L)
    expect_identical(
        unname(partial$failure_counts[c(
            "fit-failed", "non-finite-effect"
        )]),
        c(1L, 1L)
    )
    expect_match(partial$digest, "^[[:xdigit:]]{64}$")
    expect_true(landscapeR:::.validate_resampling_policy_account(partial))
    tampered <- partial
    tampered$n_failed <- 1L
    expect_error(
        landscapeR:::.validate_resampling_policy_account(tampered),
        "schema|digest"
    )

    failed <- landscapeR:::.resampling_policy_account(
        plan,
        completed = rep(FALSE, 4L),
        failure_codes = rep("fit-failed", 4L)
    )
    expect_identical(failed$status, "not-identifiable")
    expect_identical(failed$n_completed, 0L)
    expect_identical(failed$n_failed, 4L)
})

test_that("unavailable resampling policies are typed and validated", {
    insufficient <- landscapeR:::.resampling_policy_unavailable(
        lifecycle = "permutation",
        method = "subject-label-permutation",
        unit = "complete-subject",
        n_requested = 25L,
        seed = 9304L,
        status = "insufficient-support",
        diagnostic = "insufficient-distinct-rearrangements",
        design = list(exchangeability = "between-subject")
    )
    not_identifiable <- landscapeR:::.resampling_policy_unavailable(
        lifecycle = "bootstrap",
        method = "condition-time-cell-bootstrap",
        unit = "independent-biological-observation",
        n_requested = 9L,
        seed = 9305L,
        status = "not-identifiable",
        diagnostic = "empty-design-cell"
    )

    expect_identical(insufficient$status, "insufficient-support")
    expect_identical(not_identifiable$status, "not-identifiable")
    expect_length(insufficient$draws, 0L)
    expect_match(insufficient$digest, "^[[:xdigit:]]{64}$")
    expect_error(
        landscapeR:::.resampling_policy_unavailable(
            lifecycle = "bootstrap",
            method = "broken",
            unit = "unit",
            n_requested = 2L,
            seed = 1L,
            status = "complete",
            diagnostic = "not unavailable"
        ),
        "status"
    )
    expect_error(
        landscapeR:::.resampling_policy_plan(
            lifecycle = "bootstrap",
            method = "broken-count",
            unit = "unit",
            n_requested = 2.9,
            seed = 1L,
            draw_factory = identity
        ),
        "whole number"
    )
    expect_error(
        landscapeR:::.resampling_policy_plan(
            lifecycle = "bootstrap",
            method = "broken-seed",
            unit = "unit",
            n_requested = 2L,
            seed = 1.5,
            draw_factory = identity
        ),
        "whole number"
    )
    for (invalid in list(NA_real_, Inf)) {
        expect_error(
            landscapeR:::.resampling_policy_plan(
                lifecycle = "bootstrap",
                method = "broken-input",
                unit = "unit",
                n_requested = invalid,
                seed = 1L,
                draw_factory = identity
            ),
            "whole number"
        )
    }
})

test_that("design adapters expose the shared resampling policy", {
    cross <- landscapeR:::.association_resampling_plan(
        values = factor(rep(c("control", "treatment"), each = 4L)),
        nuisance_values = list(),
        n_resamples = 3L,
        seed = 9306L
    )
    independent <- landscapeR:::.time_course_resampling_plan(
        target = factor(rep(c("control", "treatment"), each = 4L)),
        observed_time = rep(c(1, 2), times = 4L),
        study_time_grid = c(1, 2),
        n_resamples = 3L,
        seed = 9307L
    )
    repeated <- landscapeR:::.repeated_resampling_plan(
        target = factor(rep(c("control", "treatment"), each = 6L)),
        subject = rep(paste0("mouse", 1:4), each = 3L),
        n_resamples = 3L,
        seed = 9308L
    )

    expect_s3_class(cross$policy, "landscapeR_resampling_plan")
    expect_s3_class(independent$policy, "landscapeR_resampling_plan")
    expect_s3_class(repeated$policy, "landscapeR_resampling_plan")
    expect_identical(
        c(cross$policy$lifecycle, independent$policy$lifecycle,
          repeated$policy$lifecycle),
        rep("bootstrap", 3L)
    )
    expect_identical(independent$policy$method, independent$method)
    expect_identical(repeated$policy$unit, "complete-subject")
    expect_true(all(vapply(
        seq_along(repeated$replicate_subject_ids),
        function(index) {
            length(unique(repeated$replicate_subject_ids[[index]])) ==
                length(repeated$source_subject_ids[[index]])
        },
        logical(1L)
    )))
})

test_that("zero-request uncertainty retains the normalized account schema", {
    plan <- landscapeR:::.association_resampling_plan(
        values = factor(c("control", "treatment")),
        nuisance_values = list(),
        n_resamples = 0L,
        seed = 9310L
    )
    summary <- landscapeR:::.resampling_summary(numeric(), plan)

    expect_identical(summary$n_resamples, 0L)
    expect_identical(summary$resample_failures, 0L)
    expect_identical(summary$resampling_method, "not-requested")
    expect_s3_class(
        summary$resampling_account,
        "landscapeR_resampling_account"
    )
    expect_identical(summary$resampling_account$status, "not-requested")
    expect_identical(
        unserialize(serialize(summary, NULL)),
        summary
    )
})

test_that("permutation evidence retains normalized policy accounting", {
    draws <- landscapeR:::.permutation_indices(
        n_observations = 8L,
        n_permutations = 5L,
        seed = 9309L
    )
    evidence <- landscapeR:::.new_permutation_evidence(
        method = "label-permutation",
        status = "complete",
        n_requested = 5L,
        n_completed = 5L,
        observed_max_effect = 0.75,
        null_max_effect = seq(0.1, 0.5, length.out = 5L),
        search_aware_p_value = 1 / 6,
        seed = 9309L,
        cohort_digest = digest::digest(
            sprintf("sample_%02d", 1:8),
            algo = "sha256",
            serialize = TRUE
        ),
        resampling_policy = attr(
            draws,
            "resampling_policy",
            exact = TRUE
        )
    )
    account <- landscapeR:::.permutation_resampling_account(
        evidence
    )

    expect_s3_class(account, "landscapeR_resampling_account")
    expect_identical(account$lifecycle, "permutation")
    expect_identical(account$status, "complete")
    expect_identical(account$n_requested, 5L)
    expect_identical(account$n_completed, 5L)
    expect_identical(account$n_failed, 0L)
    expect_match(account$plan_digest, "^[[:xdigit:]]{64}$")
    expect_identical(account$method, "label-permutation")
    expect_true(methods::validObject(evidence))
    tampered <- evidence
    attr(tampered, "resampling_policy")$n_failed <- 1L
    expect_error(
        methods::validObject(tampered),
        "resampling policy account is invalid"
    )
    other_draws <- landscapeR:::.permutation_indices(
        n_observations = 8L,
        n_permutations = 5L,
        seed = 9311L
    )
    other <- landscapeR:::.new_permutation_evidence(
        method = "label-permutation",
        status = "complete",
        n_requested = 5L,
        n_completed = 5L,
        observed_max_effect = 0.75,
        null_max_effect = seq(0.1, 0.5, length.out = 5L),
        search_aware_p_value = 1 / 6,
        seed = 9311L,
        cohort_digest = digest::digest(
            sprintf("sample_%02d", 1:8),
            algo = "sha256",
            serialize = TRUE
        ),
        resampling_policy = attr(
            other_draws,
            "resampling_policy",
            exact = TRUE
        )
    )
    mismatched <- evidence
    attr(mismatched, "resampling_policy") <- attr(
        other,
        "resampling_policy",
        exact = TRUE
    )
    expect_error(
        methods::validObject(mismatched),
        "does not agree"
    )
})
