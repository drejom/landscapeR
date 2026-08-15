protocol_merge_v3 <- function() {
    "4d2ee67653c7de2f7caf2e52da4a8f7fa05ab111"
}

runner_revision_v3 <- function() strrep("a", 40L)

protocol_merge_v4 <- function() {
    "92db509aa1724cbeac62ac79d4e4858c94e5aa20"
}

runner_revision_v4 <- function() strrep("b", 40L)

revised_identity_v3 <- function() list(
    source_revision = runner_revision_v3(),
    r_version = paste(R.version$major, R.version$minor, sep = "."),
    package_versions = c(
        landscapeR = "0.3.0", digest = "0.6.39", targets = "1.11.4"
    )
)

test_that("revised acceptance manifest exactly expands the frozen grid", {
    manifest <- k1_revised_acceptance_manifest(
        protocol_merge_v3(), runner_revision_v3(), k1_acceptance_protocol("3")
    )

    expect_s3_class(manifest, "K1RevisedAcceptanceManifest")
    expect_true(validate_k1_revised_acceptance_manifest(manifest))
    expect_identical(manifest$protocol_id, "k1-stage0-acceptance-v3")
    expect_identical(nrow(manifest$tasks), 7200L)
    expect_identical(as.integer(table(manifest$tasks$control)[c(
        "independent_time_course", "repeated_subject",
        "high_dimensional_signal", "high_dimensional_null"
    )]), c(1800L, 1200L, 3600L, 600L))
    expect_identical(manifest$tasks$task_ordinal, seq_len(7200L))
    expect_true(all(lengths(manifest$tasks$stream_seeds) == 8L))
    expect_identical(anyDuplicated(unlist(manifest$tasks$stream_seeds)), 0L)
    expect_false(any(unlist(manifest$tasks$stream_seeds) %in%
        1505953920:1506021917))
    expect_identical(
        manifest,
        k1_revised_acceptance_manifest(
            protocol_merge_v3(), runner_revision_v3(),
            k1_acceptance_protocol("3")
        )
    )
})

test_that("version 4 manifest is authenticated and disjoint before execution", {
    protocol <- k1_acceptance_protocol("4")
    manifest <- k1_revised_acceptance_manifest(
        protocol_merge_v4(), runner_revision_v4(), protocol
    )

    expect_true(validate_k1_revised_acceptance_manifest(manifest))
    expect_identical(manifest$protocol_id, "k1-stage0-acceptance-v4")
    expect_identical(manifest$artifact_version, "4")
    expect_identical(nrow(manifest$tasks), 7200L)
    expect_true(manifest$historical_stream_authentication$
        authenticated_for_execution)
    expect_identical(
        manifest$historical_stream_authentication$schema_version,
        "k1-calibration-rng-manifest-v1"
    )
    retired <- protocol$separation$retired_version3_seed_block
    scalar <- unlist(manifest$tasks$stream_seeds, use.names = FALSE)
    expect_false(any(
        scalar >= retired$first_seed_root &
            scalar <= retired$last_reserved_scalar_seed
    ))
    expect_false(any(scalar %in%
        protocol$separation$reserved_calibration_rng_streams))
    calibration_children <- unlist(lapply(
        protocol$separation$calibration_stream_manifests$manifest_payload,
        function(payload) unlist(payload$child_seeds, use.names = FALSE)
    ), use.names = FALSE)
    expect_false(any(scalar %in% calibration_children))
    expect_true(any(grepl(
        "association",
        names(protocol$separation$calibration_stream_manifests$
            manifest_payload[[1L]]$child_seeds[[1L]])
    )))
    retired_manifest <- k1_revised_acceptance_manifest(
        protocol_merge_v3(), strrep("0", 40L), k1_acceptance_protocol("3")
    )
    stream_key <- function(streams) vapply(
        streams, paste, collapse = ":", character(1L)
    )
    expect_false(any(
        stream_key(manifest$tasks$task_stream) %in%
            stream_key(retired_manifest$tasks$task_stream)
    ))
    good_identity <- revised_identity_v3()
    good_identity$source_revision <- runner_revision_v4()
    expect_true(landscapeR:::.k1_validate_runtime_revision(
        good_identity, manifest
    ))
    bad_identity <- good_identity
    bad_identity$source_revision <- strrep("c", 40L)
    expect_error(
        landscapeR:::.k1_validate_runtime_revision(bad_identity, manifest),
        "must equal the reviewed runner revision",
        class = "k1_acceptance_runner_error"
    )
})

test_that("revised acceptance manifest is revision-bound and immutable", {
    expect_error(
        k1_revised_acceptance_manifest("not-a-commit", runner_revision_v3()),
        class = "k1_acceptance_runner_error"
    )
    expect_error(
        k1_revised_acceptance_manifest(
            protocol_merge_v4(), protocol_merge_v4()
        ),
        "must differ",
        class = "k1_acceptance_runner_error"
    )

    manifest <- k1_revised_acceptance_manifest(
        protocol_merge_v3(), runner_revision_v3(), k1_acceptance_protocol("3")
    )
    manifest$tasks$seed_root[[1L]] <- manifest$tasks$seed_root[[1L]] + 1L
    expect_error(
        validate_k1_revised_acceptance_manifest(manifest),
        class = "k1_acceptance_runner_error"
    )
})

.revised_fixture_results <- function(tasks, recovered) {
    lapply(seq_len(nrow(tasks)), function(index) structure(list(
        version = "k1-revised-acceptance-replicate-v1",
        task_id = tasks$task_id[[index]],
        control = tasks$control[[index]],
        status = "success",
        outcome = if (recovered[[index]]) {
            "recovered_and_estimable"
        } else {
            "recovery_below_threshold"
        },
        recovery = list(
            evaluable = TRUE,
            met = recovered[[index]],
            absolute_loading_cosine = if (recovered[[index]]) 0.95 else 0.2
        ),
        downstream = list(
            estimable = if (recovered[[index]]) TRUE else NA,
            diagnostic = ""
        ),
        scientific_evidence = list(
            fixture = TRUE,
            claim_status = "implementation_proof_only"
        ),
        runtime_identity = revised_identity_v3()
    ), class = c(
        "K1RevisedAcceptanceImplementationFixture",
        "K1RevisedAcceptanceReplicate", "list"
    )))
}

test_that("cell decisions retain failures and apply both Wilson gates", {
    protocol <- k1_acceptance_protocol("3")
    manifest <- k1_revised_acceptance_manifest(
        protocol_merge_v3(), runner_revision_v3(), protocol
    )
    positive <- manifest$tasks[
        manifest$tasks$canonical_cell ==
            unique(manifest$tasks$canonical_cell[
                manifest$tasks$control == "independent_time_course"
            ])[[1L]],
        , drop = FALSE
    ]
    null <- manifest$tasks[
        manifest$tasks$canonical_cell ==
            unique(manifest$tasks$canonical_cell[
                manifest$tasks$control == "high_dimensional_null"
            ])[[1L]],
        , drop = FALSE
    ]
    tasks <- rbind(positive, null)
    recovered <- c(rep(TRUE, 95L), rep(FALSE, 5L), rep(FALSE, 100L))
    summary <- summarize_k1_revised_acceptance(
        .revised_fixture_results(tasks, recovered), tasks, protocol
    )

    expect_s3_class(summary, "K1RevisedAcceptanceSummary")
    expect_identical(summary$cells$decision, c("supported", "passed_null"))
    expect_identical(summary$cells$n_requested, c(100L, 100L))
    expect_identical(summary$cells$n_recovery_evaluable, c(100L, 100L))
    expect_equal(summary$cells$recovery_probability, c(0.95, 0))
    expect_true(summary$cells$wilson_95_lower[[1L]] >= 0.8)
    expect_true(summary$cells$wilson_95_upper[[2L]] <= 0.1)
    expect_identical(summary$claim_status, "implementation_proof_only")
    expect_identical(summary$advancement$null_controls_pass, FALSE)
    expect_identical(summary$advancement$conclusion, "no_advance")
})

test_that("an incomplete cell is indeterminate rather than supported", {
    protocol <- k1_acceptance_protocol("3")
    manifest <- k1_revised_acceptance_manifest(
        protocol_merge_v3(), runner_revision_v3(), protocol
    )
    tasks <- manifest$tasks[
        manifest$tasks$canonical_cell ==
            unique(manifest$tasks$canonical_cell)[[1L]],
        , drop = FALSE
    ]
    results <- .revised_fixture_results(tasks, rep(TRUE, nrow(tasks)))
    results[[1L]]$status <- "failure"
    results[[1L]]$outcome <- "execution_failure"
    results[[1L]]$recovery <- list(
        evaluable = FALSE, met = FALSE, absolute_loading_cosine = NA_real_
    )
    results[[1L]]$downstream <- list(
        estimable = NA, diagnostic = "declared test execution failure"
    )
    results[[1L]]["scientific_evidence"] <- list(NULL)
    summary <- summarize_k1_revised_acceptance(results, tasks, protocol)

    expect_identical(summary$cells$decision, "indeterminate")
    expect_identical(summary$cells$n_completed, 99L)
    expect_identical(summary$cells$n_recovery_evaluable, 99L)
    expect_equal(summary$cells$recovery_probability, 0.99)
})

test_that("revised acceptance targets expose one branch per replicate", {
    skip_if_not_installed("targets")
    previous_resources <- targets::tar_option_get("resources")
    withr::defer(targets::tar_option_set(resources = previous_resources))
    targets::tar_option_set(resources = targets::tar_resources(
        crew = targets::tar_resources_crew(controller = "small")
    ))
    graph <- k1_revised_acceptance_targets(
        phase_a_merge_commit = protocol_merge_v3(),
        runner_revision = runner_revision_v3(),
        artifact_root = tempfile("k1-revised-acceptance-")
    )

    expect_identical(vapply(graph, `[[`, character(1L), "name"), c(
        "k1_v3_protocol", "k1_v3_manifest", "k1_v3_identity",
        "k1_v3_preflight", "k1_v3_tasks", "k1_v3_task",
        "k1_v3_result", "k1_v3_results", "k1_v3_artifact",
        "k1_v3_artifact_verified", "k1_v3_evidence"
    ))
    result <- graph[[7L]]
    expect_identical(result$settings$deployment, "worker")
    expect_identical(
        result$settings$resources$crew$controller, "small"
    )
    expect_match(deparse(result$settings$pattern), "map\\(k1_v3_task\\)")
    expect_match(
        paste(capture.output(print(graph[[4L]])), collapse = "\n"),
        "k1_revised_assert_execution_authorized"
    )

    explicit <- k1_revised_acceptance_targets(
        phase_a_merge_commit = protocol_merge_v3(),
        runner_revision = runner_revision_v3(),
        artifact_root = tempfile("k1-revised-acceptance-"),
        controller = "large"
    )
    expect_identical(
        explicit[[7L]]$settings$resources$crew$controller, "large"
    )
})

test_that("version 4 targets expose a retired audit topology", {
    skip_if_not_installed("targets")
    graph <- k1_revised_acceptance_targets(
        phase_a_merge_commit = protocol_merge_v4(),
        runner_revision = runner_revision_v4(),
        artifact_root = tempfile("k1-revised-v4-")
    )

    expect_identical(vapply(graph, `[[`, character(1L), "name"), c(
        "k1_v4_protocol", "k1_v4_manifest", "k1_v4_identity",
        "k1_v4_preflight", "k1_v4_tasks", "k1_v4_task",
        "k1_v4_result", "k1_v4_results", "k1_v4_artifact",
        "k1_v4_artifact_verified", "k1_v4_evidence"
    ))
    expect_match(
        paste(capture.output(print(graph[[4L]])), collapse = "\n"),
        "k1_revised_assert_execution_authorized"
    )
    expect_match(deparse(graph[[7L]]$settings$pattern), "map\\(k1_v4_task\\)")
    expect_identical(graph[[7L]]$settings$error, "null")
    expect_error(
        k1_revised_acceptance_targets(
            phase_a_merge_commit = strrep("c", 40L),
            runner_revision = runner_revision_v4(),
            artifact_root = tempfile("k1-revised-unknown-")
        ),
        "not a reviewed revised protocol merge",
        class = "k1_acceptance_runner_error"
    )
})

test_that("retired version 3 tasks cannot execute", {
    protocol <- k1_acceptance_protocol("3")
    manifest <- k1_revised_acceptance_manifest(
        protocol_merge_v3(), runner_revision_v3(), protocol
    )
    expect_error(
        landscapeR:::.k1_revised_run_task(
            manifest$tasks[1L, , drop = FALSE], protocol
        ),
        "version 3 acceptance execution is retired",
        class = "k1_acceptance_runner_error"
    )
})

test_that("retired version 4 tasks cannot execute", {
    protocol <- k1_acceptance_protocol("4")
    manifest <- k1_revised_acceptance_manifest(
        protocol_merge_v4(), runner_revision_v4(), protocol
    )
    expect_error(
        landscapeR:::.k1_revised_run_task(
            manifest$tasks[1L, , drop = FALSE], protocol
        ),
        "version 4 acceptance execution is retired",
        class = "k1_acceptance_runner_error"
    )
})

test_that("revised acceptance maps use established encodings and captions", {
    protocol <- k1_acceptance_protocol("3")
    manifest <- k1_revised_acceptance_manifest(
        protocol_merge_v3(), runner_revision_v3(), protocol
    )
    keep <- manifest$tasks$canonical_cell %in% c(
        unique(manifest$tasks$canonical_cell[
            manifest$tasks$control == "independent_time_course"
        ])[[1L]],
        unique(manifest$tasks$canonical_cell[
            manifest$tasks$control == "high_dimensional_signal"
        ])[[1L]],
        unique(manifest$tasks$canonical_cell[
            manifest$tasks$control == "high_dimensional_null"
        ])[[1L]]
    )
    tasks <- manifest$tasks[keep, , drop = FALSE]
    summary <- summarize_k1_revised_acceptance(
        .revised_fixture_results(tasks, rep(TRUE, nrow(tasks))),
        tasks, protocol
    )
    sampling <- plot_k1_revised_acceptance(summary, "sampling_design")
    signal <- plot_k1_revised_acceptance(summary, "signal_regime")
    semantic <- landscapeR_palette("semantic")

    expect_s3_class(sampling, "ggplot")
    expect_s3_class(signal, "ggplot")
    expect_match(
        scientific_caption(sampling),
        "Recovery across declared longitudinal sampling designs"
    )
    expect_match(
        scientific_caption(signal),
        "Recovery across high-dimensional signal regimes"
    )
    expect_false(grepl("Figure [0-9]", scientific_caption(sampling)))
    expect_false(grepl("Figure [0-9]", scientific_caption(signal)))
    expect_true(is.data.frame(attr(
        sampling, "landscapeR_k1_revised_map_data"
    )))
    expect_false(grepl(
        scientific_caption(signal),
        paste(capture.output(print(signal)), collapse = "\n"), fixed = TRUE
    ))
    expect_identical(
        unname(sampling$scales$get_scales("fill")$palette(3L)),
        unname(semantic[c("focal", "paper", "structure")])
    )
    expect_identical(
        unname(vapply(sampling$layers[seq_len(4L)], function(layer) {
            layer$aes_params$colour
        }, character(1L))),
        unname(semantic[c("focal", "nuisance", "nuisance", "ink")])
    )
    expect_identical(
        signal$scales$get_scales("fill")$palette(c(0, 1)),
        c("#FFEA46", "#00204D")
    )
})

test_that("version 3 historical streams are recorded but not authenticated", {
    protocol <- k1_acceptance_protocol("3")
    manifest <- k1_revised_acceptance_manifest(
        protocol_merge_v3(), runner_revision_v3(), protocol
    )
    authentication <- manifest$historical_stream_authentication

    expect_identical(authentication$authenticated_for_execution, FALSE)
    expect_identical(
        authentication$frozen_manifest_serialization_schema,
        "not_recorded_in_v3"
    )
    expect_match(authentication$v4_requirement, "version 4")
})

test_that("retired or fabricated evidence cannot publish acceptance artifacts", {
    testthat::local_mocked_bindings(
        .k1_acceptance_worker_identity = revised_identity_v3,
        .package = "landscapeR"
    )
    protocol <- k1_acceptance_protocol("3")
    manifest <- k1_revised_acceptance_manifest(
        protocol_merge_v3(), runner_revision_v3(), protocol
    )
    recovered <- with(manifest$tasks,
        control != "high_dimensional_null")
    results <- .revised_fixture_results(manifest$tasks, recovered)
    root <- tempfile("k1-revised-artifacts-")
    dir.create(root)

    expect_error(
        landscapeR:::.k1_revised_publish(
            root, protocol, manifest, manifest$tasks, results,
            revised_identity_v3()
        ),
        "retired version 3",
        class = "k1_acceptance_runner_error"
    )
})

test_that("retired version 4 evidence cannot publish acceptance artifacts", {
    protocol <- k1_acceptance_protocol("4")
    manifest <- k1_revised_acceptance_manifest(
        protocol_merge_v4(), runner_revision_v4(), protocol
    )
    identity <- revised_identity_v3()
    identity$source_revision <- runner_revision_v4()
    results <- lapply(seq_len(nrow(manifest$tasks)), function(index) {
        landscapeR:::.k1_revised_failure(
            manifest$tasks[index, , drop = FALSE],
            simpleError("declared implementation-proof failure"),
            identity
        )
    })
    root <- tempfile("k1-revised-artifacts-")
    dir.create(root)

    expect_error(
        landscapeR:::.k1_revised_publish(
            root, protocol, manifest, manifest$tasks, results, identity
        ),
        "retired version 4 evidence",
        class = "k1_acceptance_runner_error"
    )
})

test_that("collector rejects incoherent typed results", {
    protocol <- k1_acceptance_protocol("3")
    manifest <- k1_revised_acceptance_manifest(
        protocol_merge_v3(), runner_revision_v3(), protocol
    )
    task <- manifest$tasks[1L, , drop = FALSE]
    result <- .revised_fixture_results(task, TRUE)[[1L]]
    result$outcome <- "execution_failure"
    expect_error(
        summarize_k1_revised_acceptance(list(result), task, protocol),
        "internally inconsistent",
        class = "k1_acceptance_runner_error"
    )
    result <- .revised_fixture_results(task, TRUE)[[1L]]
    result$runtime_identity$source_revision <- strrep("b", 40L)
    expect_error(
        landscapeR:::.k1_revised_collect(
            list(result), task, protocol, runner_revision_v3(),
            allow_implementation_fixture = TRUE
        ),
        "worker revision",
        class = "k1_acceptance_runner_error"
    )
})

test_that("collector retains a missing scheduler branch as a typed failure", {
    protocol <- k1_acceptance_protocol("3")
    manifest <- k1_revised_acceptance_manifest(
        protocol_merge_v3(), runner_revision_v3(), protocol
    )
    task <- manifest$tasks[1L, , drop = FALSE]
    result <- landscapeR:::.k1_revised_collect(
        list(NULL), task, protocol, runner_revision_v3()
    )[[1L]]

    expect_identical(result$status, "failure")
    expect_identical(result$outcome, "execution_failure")
    expect_null(result$runtime_identity)
    expect_match(result$downstream$diagnostic, "no serialized result")
})

test_that("control-specific evidence cannot drift from its manifest task", {
    protocol <- k1_acceptance_protocol("3")
    manifest <- k1_revised_acceptance_manifest(
        protocol_merge_v3(), runner_revision_v3(), protocol
    )
    task <- manifest$tasks[
        manifest$tasks$control == "independent_time_course",
        , drop = FALSE
    ][1L, , drop = FALSE]
    row <- list(
        template_id = task$design_id[[1L]], p = task$p[[1L]],
        execution_completed = TRUE, target_loading_cosine = 0.95,
        recovery_evaluable = TRUE, recovery_met = TRUE,
        downstream_estimable = TRUE, diagnostic = "",
        outcome = "recovered_and_estimable"
    )
    result <- structure(list(
        version = "k1-revised-acceptance-replicate-v1",
        task_id = task$task_id[[1L]], control = task$control[[1L]],
        status = "success", outcome = "recovered_and_estimable",
        recovery = list(
            evaluable = TRUE, met = TRUE, absolute_loading_cosine = 0.95
        ),
        downstream = list(estimable = TRUE, diagnostic = ""),
        scientific_evidence = list(
            version = "k1-revised-scientific-evidence-v1",
            control = task$control[[1L]], task_id = task$task_id[[1L]],
            stream_seeds = task$stream_seeds[[1L]],
            task_stream = task$task_stream[[1L]],
            execution_contract = landscapeR:::.k1_revised_execution_contract(
                task, protocol
            ),
            observed_generator = list(
                template_id = task$design_id[[1L]], p = task$p[[1L]],
                noise_sd = protocol$grids$independent_time_course$fixed$noise_sd,
                time_signal =
                    protocol$grids$independent_time_course$fixed$time_signal,
                condition_time_signal = protocol$grids$
                    independent_time_course$fixed$condition_time_signal,
                generator_seed = task$stream_seeds[[1L]][[1L]],
                association_seed = as.integer(
                    task$stream_seeds[[1L]][[1L]] + 1L
                )
            ),
            assessment = row
        ),
        runtime_identity = revised_identity_v3()
    ), class = c("K1RevisedAcceptanceReplicate", "list"))

    expect_true(landscapeR:::.k1_revised_validate_result(
        result, task, protocol, runner_revision_v3()
    ))
    result$scientific_evidence$assessment$p <- task$p[[1L]] + 1L
    expect_error(
        landscapeR:::.k1_revised_validate_result(
            result, task, protocol, runner_revision_v3()
        ),
        "does not match its task",
        class = "k1_acceptance_runner_error"
    )
})

test_that("repeated-subject evidence uses its governed execution contract", {
    protocol <- k1_acceptance_protocol("4")
    manifest <- k1_revised_acceptance_manifest(
        protocol_merge_v4(), runner_revision_v4(), protocol
    )
    task <- manifest$tasks[
        manifest$tasks$control == "repeated_subject",
        , drop = FALSE
    ][1L, , drop = FALSE]
    fixture <- k1_acceptance_protocol("5")$separation$
        development_fixture_seed_blocks$repeated_subject_validator
    development_seed <- fixture$first_scalar_seed
    task$task_id <- fixture$task_id
    task$seed_root <- development_seed
    task$stream_seeds <- I(list(as.integer(development_seed + 0:7)))
    task$task_stream <- I(list(landscapeR:::.derive_task_stream(
        development_seed, task$task_id[[1L]]
    )))
    expect_false(task$task_id[[1L]] %in% manifest$tasks$task_id)
    expect_identical(
        range(task$stream_seeds[[1L]]),
        c(fixture$first_scalar_seed, fixture$last_scalar_seed)
    )
    expect_true(
        max(task$stream_seeds[[1L]]) <
            protocol$seed_derivation$minimum_seed_root
    )
    expect_false(any(task$stream_seeds[[1L]] %in%
        protocol$separation$reserved_calibration_rng_streams))
    identity <- revised_identity_v3()
    identity$source_revision <- runner_revision_v4()
    testthat::local_mocked_bindings(
        .k1_acceptance_worker_identity = function() identity,
        .k1_revised_assert_execution_authorized = function(protocol) {
            invisible(TRUE)
        },
        .package = "landscapeR"
    )
    result <- landscapeR:::.k1_revised_run_task(
        task, protocol, expected_identity = identity
    )
    expect_identical(result$status, "success")

    expect_true(landscapeR:::.k1_revised_validate_result(
        result, task, protocol, runner_revision_v4()
    ))

    changed_template <- result
    changed_template$scientific_evidence$assessment$evidence$template$label <-
        "changed after generation"
    expect_error(
        landscapeR:::.k1_revised_validate_result(
            changed_template, task, protocol, runner_revision_v4()
        ),
        "does not match its task",
        class = "k1_acceptance_runner_error"
    )
    missing_status <- result
    missing_status$scientific_evidence$assessment$evidence$recovery$status <-
        NULL
    expect_error(
        landscapeR:::.k1_revised_validate_result(
            missing_status, task, protocol, runner_revision_v4()
        ),
        "does not match its task",
        class = "k1_acceptance_runner_error"
    )
    for (field in c(
            "n_subjects", "minimum_subject_observations",
            "axis_refits_requested"
        )) {
        corrupted_row <- result
        row <- corrupted_row$scientific_evidence$assessment$row
        row[[field]] <- row[[field]] + 1L
        corrupted_row$scientific_evidence$assessment$row <- row
        expect_error(
            landscapeR:::.k1_revised_validate_result(
                corrupted_row, task, protocol, runner_revision_v4()
            ),
            "does not match its task",
            class = "k1_acceptance_runner_error",
            info = paste("collector must reject changed", field)
        )
    }
    wrong_p <- result
    wrong_p$scientific_evidence$execution_contract$p <- task$p[[1L]] + 1L
    expect_error(
        landscapeR:::.k1_revised_validate_result(
            wrong_p, task, protocol, runner_revision_v4()
        ),
        "internally inconsistent",
        class = "k1_acceptance_runner_error"
    )
    wrong_seed <- result
    wrong_seed$scientific_evidence$stream_seeds[[1L]] <-
        wrong_seed$scientific_evidence$stream_seeds[[1L]] + 1L
    expect_error(
        landscapeR:::.k1_revised_validate_result(
            wrong_seed, task, protocol, runner_revision_v4()
        ),
        "internally inconsistent",
        class = "k1_acceptance_runner_error"
    )
})

test_that("every control has an exact manifest-derived execution contract", {
    protocol <- k1_acceptance_protocol("3")
    manifest <- k1_revised_acceptance_manifest(
        protocol_merge_v3(), runner_revision_v3(), protocol
    )
    tasks <- manifest$tasks[match(
        c(
            "independent_time_course", "repeated_subject",
            "high_dimensional_signal", "high_dimensional_null"
        ),
        manifest$tasks$control
    ), , drop = FALSE]
    contracts <- lapply(seq_len(nrow(tasks)), function(index) {
        landscapeR:::.k1_revised_execution_contract(
            tasks[index, , drop = FALSE], protocol
        )
    })

    expect_identical(contracts[[1L]]$generator,
        protocol$grids$independent_time_course$fixed)
    expect_identical(contracts[[2L]]$axis_resampling_seed,
        as.integer(tasks$stream_seeds[[2L]][[1L]] + 3L))
    expect_identical(contracts[[3L]]$generator$n, 24L)
    expect_identical(contracts[[3L]]$generator$informative_features, 10L)
    expect_identical(contracts[[4L]]$generator$signal_strength,
        tasks$signal_strength[[4L]])
    expect_false(identical(
        within(contracts[[3L]], generator$noise_sd <- 999),
        landscapeR:::.k1_revised_execution_contract(tasks[3L, ], protocol)
    ))
})
