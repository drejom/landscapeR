acceptance_summary_fixture <- function() {
    protocol <- k1_acceptance_protocol()
    tasks <- data.frame(
        task_id = c("g1", "g2", "n1", "n2"),
        control = c(
            "generic_double_well", "generic_double_well",
            "pure_noise", "pure_noise"
        ),
        n = c(48L, 48L, 48L, 48L),
        p = c(100L, 100L, 100L, 100L),
        subjects_per_condition = NA_integer_,
        replicate_index = c(1L, 2L, 1L, 2L),
        seed_root = 1:4,
        canonical_cell = c(
            rep("control=generic_double_well;n=48;p=100", 2L),
            rep("control=pure_noise;n=48;p=100", 2L)
        ),
        stringsAsFactors = FALSE
    )
    tasks$stream_seeds <- replicate(4L, 1L, simplify = FALSE)
    results <- list(
        structure(list(
            artifact_version = "1",
            task_id = "g1", control = "generic_double_well",
            canonical_cell = tasks$canonical_cell[[1L]], replicate_index = 1L,
            status = "success", reason = "", metrics = list(
                well_error = 0.05, barrier_error = 0.05,
                barrier_height_error = 0.10, n_wells_found = 2L,
                n_barriers_found = 1L, subspace_angle_deg = 5
            ),
            protocol_digest = protocol$digest,
            runner_contract = protocol$execution_contracts$version
        ), class = c("K1AcceptanceReplicate", "list")),
        structure(list(
            artifact_version = "1",
            task_id = "g2", control = "generic_double_well",
            canonical_cell = tasks$canonical_cell[[2L]], replicate_index = 2L,
            status = "failure", reason = "deliberate fixture failure",
            metrics = list(),
            protocol_digest = protocol$digest,
            runner_contract = protocol$execution_contracts$version
        ), class = c("K1AcceptanceReplicate", "list")),
        structure(list(
            artifact_version = "1",
            task_id = "n1", control = "pure_noise",
            canonical_cell = tasks$canonical_cell[[3L]], replicate_index = 1L,
            status = "success", reason = "", metrics = list(
                n_wells_found = 1L, n_barriers_found = 0L,
                false_double_well = FALSE, false_target_selection = FALSE,
                search_aware_p_value = NA_real_,
                target_index_recurrence = NA_real_,
                mean_matched_loading_cosine = NA_real_,
                identifiability_completion_rate = NA_real_,
                nominated_component = NA_integer_
            ),
            protocol_digest = protocol$digest,
            runner_contract = protocol$execution_contracts$version
        ), class = c("K1AcceptanceReplicate", "list")),
        structure(list(
            artifact_version = "1",
            task_id = "n2", control = "pure_noise",
            canonical_cell = tasks$canonical_cell[[4L]], replicate_index = 2L,
            status = "success", reason = "", metrics = list(
                n_wells_found = 2L, n_barriers_found = 1L,
                false_double_well = TRUE, false_target_selection = FALSE,
                search_aware_p_value = NA_real_,
                target_index_recurrence = NA_real_,
                mean_matched_loading_cosine = NA_real_,
                identifiability_completion_rate = NA_real_,
                nominated_component = NA_integer_
            ),
            protocol_digest = protocol$digest,
            runner_contract = protocol$execution_contracts$version
        ), class = c("K1AcceptanceReplicate", "list"))
    )
    list(protocol = protocol, tasks = tasks, results = results)
}

test_that("acceptance summary keeps failures and incomplete cells visible", {
    fixture <- acceptance_summary_fixture()
    summary <- summarize_k1_acceptance(
        fixture$results,
        fixture$tasks,
        fixture$protocol
    )

    expect_s3_class(summary, "K1AcceptanceSummary")
    expect_identical(nrow(summary$cells), 2L)
    generic <- summary$cells[summary$cells$control == "generic_double_well", ]
    negative <- summary$cells[summary$cells$control == "pure_noise", ]
    expect_identical(generic$n_requested, 2L)
    expect_identical(generic$n_completed, 1L)
    expect_equal(generic$replicate_pass_rate, 0.5)
    expect_false(generic$complete_cell)
    expect_false(generic$cell_pass)
    expect_equal(negative$false_double_well_rate, 0.5)
    expect_equal(negative$false_target_selection_rate, 0)
    expect_true(is.na(summary$supported_minimum_n))
    expect_identical(summary$claim_status, "incomplete_execution_summary")
})

test_that("acceptance summary rejects malformed typed metrics", {
    fixture <- acceptance_summary_fixture()
    fixture$results[[1L]]$metrics$well_error <- -1

    expect_error(
        summarize_k1_acceptance(
            fixture$results,
            fixture$tasks,
            fixture$protocol
        ),
        class = "k1_acceptance_runner_error"
    )
})

test_that("acceptance summary translates malformed public inputs", {
    expect_error(
        summarize_k1_acceptance(
            list(list()),
            data.frame(task_id = "x"),
            k1_acceptance_protocol()
        ),
        class = "k1_acceptance_runner_error"
    )
})

test_that("acceptance summary plots carry threshold lines and captions", {
    fixture <- acceptance_summary_fixture()
    summary <- summarize_k1_acceptance(
        fixture$results,
        fixture$tasks,
        fixture$protocol
    )

    pass_rate <- plot_k1_acceptance_summary(summary, "pass_rate")
    false_positive <- plot_k1_acceptance_summary(summary, "false_positive")
    expect_s3_class(pass_rate, "ggplot")
    expect_s3_class(false_positive, "ggplot")
    expect_match(scientific_caption(pass_rate), "90%")
    expect_match(scientific_caption(pass_rate), "incomplete")
    expect_match(scientific_caption(false_positive), "5%")
    expect_match(scientific_caption(false_positive), "(A)", fixed = TRUE)
    expect_error(
        plot_k1_acceptance_summary(summary, "not-a-surface"),
        class = "k1_acceptance_runner_error"
    )
    false_positive_build <- ggplot2::ggplot_build(false_positive)
    expect_true(all(
        false_positive_build$data[[3L]]$fill ==
            unname(landscapeR_palette("semantic")[["paper"]])
    ))
})
