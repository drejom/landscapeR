summary_aml_acceptance_provenance <- function() list(
    version = "1.0.0",
    evidence_status = "independent_acceptance",
    generator_and_decomposition = list(fixture = TRUE),
    atlas = list(
        fixture = TRUE,
        time_course_models = lapply(1:2, function(component) list(
            component = component,
            unadjusted = list(status = "estimable", diagnostic = ""),
            adjusted = list(status = "estimable", diagnostic = "")
        ))
    ),
    proposal = list(fixture = TRUE),
    identifiability = list(fixture = TRUE),
    stage2 = list(fixture = TRUE)
)

acceptance_summary_fixture <- function(version = "2") {
    protocol <- k1_acceptance_protocol(version)
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
            artifact_version = protocol$artifact_version,
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
            artifact_version = protocol$artifact_version,
            task_id = "g2", control = "generic_double_well",
            canonical_cell = tasks$canonical_cell[[2L]], replicate_index = 2L,
            status = "failure", reason = "deliberate fixture failure",
            metrics = list(),
            protocol_digest = protocol$digest,
            runner_contract = protocol$execution_contracts$version
        ), class = c("K1AcceptanceReplicate", "list")),
        structure(list(
            artifact_version = protocol$artifact_version,
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
            artifact_version = protocol$artifact_version,
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
    expect_false("subjects_per_condition" %in% names(summary$cells))
    expect_false("mean_target_loading_cosine" %in% names(summary$cells))
    expect_true(is.na(summary$supported_minimum_n))
    expect_identical(summary$claim_status, "incomplete_execution_summary")
})

test_that("shared-baseline safety cells pass only through typed abstention", {
    protocol <- k1_acceptance_protocol()
    manifest <- k1_acceptance_manifest(strrep("1", 40L))
    task <- manifest$tasks[
        manifest$tasks$control == "shared_baseline_missing_cells",
        ,
        drop = FALSE
    ][1L, , drop = FALSE]
    result <- landscapeR:::.k1_acceptance_run_task(
        task,
        protocol,
        expected_identity = NULL,
        sequential_internal = TRUE
    )

    summary <- summarize_k1_acceptance(list(result), task, protocol)

    expect_identical(summary$cells$control, "shared_baseline_missing_cells")
    expect_identical(summary$cells$n_completed, 1L)
    expect_identical(summary$cells$n_passed, 1L)
    expect_equal(summary$cells$replicate_pass_rate, 1)
    expect_false(summary$cells$complete_cell)
    expect_false(summary$complete_execution)

    wrong_total <- result
    wrong_total$metrics$total_observations <- 14L
    wrong_summary <- summarize_k1_acceptance(
        list(wrong_total),
        task,
        protocol
    )
    expect_identical(wrong_summary$cells$n_passed, 0L)
})

test_that("AML-only acceptance summary recognizes the complete frozen grid", {
    protocol <- k1_acceptance_protocol()
    manifest <- k1_acceptance_manifest(strrep("1", 40L))
    tasks <- manifest$tasks[
        manifest$tasks$control == "aml_synchronized",
        ,
        drop = FALSE
    ]
    results <- lapply(seq_len(nrow(tasks)), function(index) {
        structure(list(
            artifact_version = protocol$artifact_version,
            task_id = tasks$task_id[[index]],
            control = "aml_synchronized",
            canonical_cell = tasks$canonical_cell[[index]],
            replicate_index = tasks$replicate_index[[index]],
            status = "success",
            reason = "",
            metrics = list(
                target_loading_cosine = 0.95,
                target_subspace_angle_deg = 10,
                mean_bootstrap_subspace_angle_deg = 8,
                q95_bootstrap_subspace_angle_deg = 12,
                target_component = 2L,
                nuisance_component = 1L,
                target_proposal_rank = 1L,
                nuisance_proposal_rank = 2L,
                target_unadjusted_estimate = -1.2,
                target_adjusted_estimate = -1.1,
                nuisance_unadjusted_estimate = 0.2,
                nuisance_adjusted_estimate = 0.1,
                target_unadjusted_status = "estimable-exploratory-only",
                target_adjusted_status = "estimable-exploratory-only",
                nuisance_unadjusted_status = "estimable-exploratory-only",
                nuisance_adjusted_status = "estimable-exploratory-only",
                target_index_recurrence = 0.90,
                mean_matched_loading_cosine = 0.90,
                identifiability_completion_rate = 0.95,
                stage2_ineligible = TRUE,
                orientation_recurrence = 0.80,
                rank_one_fraction = 0.90,
                matched_fraction = 0.95,
                acceptance_evidence_status = "independent_acceptance",
                acceptance_provenance = summary_aml_acceptance_provenance(),
                acceptance_provenance_digest = digest::digest(
                    summary_aml_acceptance_provenance(),
                    algo = "sha256"
                )
            ),
            protocol_digest = protocol$digest,
            runner_contract = protocol$execution_contracts$version
        ), class = c("K1AcceptanceReplicate", "list"))
    })

    summary <- summarize_k1_acceptance(results, tasks, protocol)

    expect_true(summary$complete_execution)
    expect_identical(summary$claim_status,
        "independent_aml_acceptance_summary")
    expect_identical(nrow(summary$cells), 9L)
    expect_true(all(summary$cells$cell_pass))
    expect_identical(
        sort(unique(summary$cells$subjects_per_condition)),
        c(4L, 7L, 12L)
    )
    expect_true(all(summary$cells$mean_bootstrap_subspace_angle_deg == 8))
    expect_true(all(summary$cells$mean_target_adjusted_estimate == -1.1))

    view <- visual_evidence(summary)
    expect_s4_class(view, "VisualEvidenceView")
    expect_identical(visual_evidence_surface(view), "aml_acceptance")
    pass_rate <- plot_k1_aml_acceptance_summary(summary, "pass_rate")
    recovery <- plot_k1_aml_acceptance_summary(summary, "recovery")
    expect_s3_class(pass_rate, "ggplot")
    expect_s3_class(recovery, "ggplot")
    expect_match(scientific_caption(pass_rate), "90%")
    expect_match(
        scientific_caption(recovery),
        "planted condition-by-time target\\s+axis"
    )
    expect_length(ggplot2::ggplot_build(pass_rate)$layout$layout$PANEL, 3L)
    expect_length(ggplot2::ggplot_build(recovery)$layout$layout$PANEL, 3L)
    layer_labels <- function(plot) {
        unlist(lapply(ggplot2::ggplot_build(plot)$data, function(layer) {
            if (is.null(layer$label)) character() else as.character(layer$label)
        }))
    }
    expect_identical(
        sum(layer_labels(pass_rate) == "Pass \u2265 90%"),
        3L
    )
    expect_identical(
        sum(layer_labels(recovery) == "Loading \u2265 90%"),
        3L
    )
    expect_identical(
        sum(layer_labels(recovery) == "Index \u2265 80%"),
        3L
    )
    panel_labels <- as.character(
        ggplot2::ggplot_build(pass_rate)$layout$layout$p_label
    )
    expect_true(all(grepl("^\\([A-C]\\)", unique(panel_labels))))
    expect_error(
        plot_k1_aml_acceptance_summary(list(), "pass_rate"),
        class = "k1_acceptance_runner_error"
    )
    redigest <- function(value) {
        payload <- unclass(value)
        payload$digest <- NULL
        value$digest <- digest::digest(payload, algo = "sha256")
        value
    }
    altered_threshold <- summary
    altered_threshold$display_thresholds$minimum_target_loading_cosine <- 0.75
    altered_threshold <- redigest(altered_threshold)
    altered_plot <- plot_k1_aml_acceptance_summary(
        altered_threshold,
        "recovery"
    )
    altered_caption <- scientific_caption(altered_plot)
    expect_match(altered_caption, "75%")
    altered_build <- ggplot2::ggplot_build(altered_plot)
    x_lines <- unlist(lapply(altered_build$data, function(layer) {
        if (is.null(layer$xintercept)) numeric() else layer$xintercept
    }))
    expect_true(0.75 %in% x_lines)
    expect_identical(
        sum(layer_labels(altered_plot) == "Loading \u2265 75%"),
        3L
    )

    development_fixture <- summary
    development_fixture$claim_status <- "development_only_visual_fixture"
    development_fixture <- redigest(development_fixture)
    development_plot <- plot_k1_aml_acceptance_summary(
        development_fixture,
        "pass_rate"
    )
    expect_match(
        scientific_caption(development_plot),
        "fabricated solely to\\s+demonstrate"
    )

    partial <- summary
    partial$complete_execution <- FALSE
    partial <- redigest(partial)
    expect_error(
        visual_evidence(partial),
        class = "landscapeR_validation_error"
    )

    wrong_stage2 <- results
    wrong_stage2[[1L]]$metrics$stage2_ineligible <- FALSE
    wrong_summary <- summarize_k1_acceptance(
        wrong_stage2,
        tasks,
        protocol
    )
    affected <- wrong_summary$cells$canonical_cell ==
        tasks$canonical_cell[[1L]]
    expect_equal(wrong_summary$cells$stage2_ineligibility_rate[affected], 0.99)
    expect_false(wrong_summary$cells$cell_pass[affected])

    failed_stage2 <- results
    failed_stage2[[1L]]$status <- "failure"
    failed_stage2[[1L]]$reason <- "deliberate fixture failure"
    failed_stage2[[1L]]$metrics <- list()
    failed_summary <- summarize_k1_acceptance(
        failed_stage2,
        tasks,
        protocol
    )
    affected <- failed_summary$cells$canonical_cell ==
        tasks$canonical_cell[[1L]]
    expect_equal(
        failed_summary$cells$stage2_ineligibility_rate[affected],
        0.99
    )
    expect_false(failed_summary$cells$cell_pass[affected])
})

test_that("historical v1 captions do not acquire version 2 panels", {
    fixture <- acceptance_summary_fixture("1")
    summary <- summarize_k1_acceptance(
        fixture$results,
        fixture$tasks,
        fixture$protocol
    )
    caption <- scientific_caption(plot_k1_acceptance_summary(summary))

    expect_false(grepl("Panel D", caption, fixed = TRUE))
    expect_false(grepl("shared-baseline", caption, ignore.case = TRUE))
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
    pass_caption <- gsub("[[:space:]]+", " ", scientific_caption(pass_rate))
    false_positive_caption <- gsub(
        "[[:space:]]+",
        " ",
        scientific_caption(false_positive)
    )
    expect_s3_class(pass_rate, "ggplot")
    expect_s3_class(false_positive, "ggplot")
    expect_match(pass_caption, "90%")
    expect_match(pass_caption, "incomplete")
    expect_match(false_positive_caption, "5%")
    expect_match(false_positive_caption, "(A)", fixed = TRUE)
    expect_match(
        pass_caption,
        "The estimand is the fraction of all requested replicates"
    )
    expect_false(grepl("..", pass_caption, fixed = TRUE))
    expect_false(grepl("; Open|; The", pass_caption))
    pass_words <- tolower(unlist(strsplit(
        pass_caption,
        "[^[:alnum:]-]+"
    )))
    expect_false(any(c("typed", "frozen") %in% pass_words))
    expect_false(grepl(
        "development fixture|execution failures",
        pass_caption,
        ignore.case = TRUE
    ))
    expect_match(
        false_positive_caption,
        "The estimand is the false-positive fraction"
    )
    expect_false(grepl("..", false_positive_caption, fixed = TRUE))
    expect_false(grepl("; Open|; The", false_positive_caption))
    false_positive_words <- tolower(unlist(strsplit(
        false_positive_caption,
        "[^[:alnum:]-]+"
    )))
    expect_false("frozen" %in% false_positive_words)
    expect_false(grepl(
        "development fixture|failed executions",
        false_positive_caption,
        ignore.case = TRUE
    ))
    expect_error(
        plot_k1_acceptance_summary(summary, "not-a-surface"),
        class = "k1_acceptance_runner_error"
    )
    false_positive_build <- ggplot2::ggplot_build(false_positive)
    expect_true(all(
        false_positive_build$data[[3L]]$fill ==
            unname(landscapeR_palette("semantic")[["paper"]])
    ))

    decision_summary <- summary
    decision_summary$cells$false_double_well_rate <- 0.02
    decision_summary$cells$false_target_selection_rate <- 0.03
    decision_plot <- plot_k1_acceptance_summary(
        decision_summary,
        "false_positive"
    )
    expect_identical(
        decision_plot$scales$get_scales("y")$limits,
        c(0, 0.1)
    )
    expect_identical(
        decision_plot$scales$get_scales("y")$get_labels(),
        c("0%", "2%", "4%", "6%", "8%", "10%")
    )

    decision_summary$cells$false_double_well_rate <- 0.2
    expanded_plot <- plot_k1_acceptance_summary(
        decision_summary,
        "false_positive"
    )
    expect_equal(
        expanded_plot$scales$get_scales("y")$limits,
        c(0, 0.25)
    )
})
