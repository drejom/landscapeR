fake_phase_a_merge <- function() strrep("1", 40L)
fake_runner_merge <- function() strrep("2", 40L)
fake_aml_acceptance_provenance <- function() list(
    version = "1.0.0",
    evidence_status = "independent_acceptance",
    generator_and_decomposition = list(fixture = TRUE),
    atlas = list(fixture = TRUE),
    proposal = list(fixture = TRUE),
    identifiability = list(fixture = TRUE),
    stage2 = list(fixture = TRUE)
)

test_that("acceptance manifest expands every frozen cell and replicate", {
    manifest <- k1_acceptance_manifest(fake_phase_a_merge())

    expect_s3_class(manifest, "K1AcceptanceManifest")
    expect_true(validate_k1_acceptance_manifest(manifest))
    expect_identical(nrow(manifest$tasks), 17000L)
    expect_identical(
        as.integer(table(manifest$tasks$control)),
        unname(c(
            aml_synchronized = 900L,
            generic_double_well = 3200L,
            pure_noise = 6400L,
            shared_baseline_missing_cells = 100L,
            single_well = 6400L
        ))
    )
    expect_identical(manifest$phase_a_merge_commit, fake_phase_a_merge())
    expect_identical(manifest$artifact_version, "2")
    expect_match(manifest$digest, "^[0-9a-f]{64}$")
    expect_false(any(manifest$tasks$seed_root %in%
        k1_acceptance_protocol()$separation$reserved_calibration_rng_streams))
    expect_identical(
        anyDuplicated(unlist(manifest$tasks$stream_seeds)),
        0L
    )
})

test_that("runner provenance does not alter frozen manifest tasks or seeds", {
    historical <- k1_acceptance_manifest(fake_phase_a_merge())
    reviewed_runner <- k1_acceptance_manifest(
        fake_phase_a_merge(),
        runner_revision = fake_runner_merge()
    )

    expect_null(historical$runner_revision)
    expect_identical(reviewed_runner$runner_revision, fake_runner_merge())
    expect_identical(reviewed_runner$tasks, historical$tasks)
    expect_false(identical(reviewed_runner$digest, historical$digest))
    expect_true(validate_k1_acceptance_manifest(reviewed_runner))
    expect_true(landscapeR:::.k1_validate_runtime_revision(
        list(source_revision = fake_runner_merge()),
        reviewed_runner
    ))
    expect_error(
        landscapeR:::.k1_validate_runtime_revision(
            list(source_revision = fake_phase_a_merge()),
            reviewed_runner
        ),
        "reviewed runner revision"
    )
})

test_that("collector ignores dynamic-branch names but preserves task order", {
    tasks <- data.frame(
        task_id = c("task-a", "task-b"),
        stringsAsFactors = FALSE
    )
    results <- list(
        branch_a = list(task_id = "task-a"),
        branch_b = list(task_id = "task-b")
    )

    expect_identical(
        landscapeR:::.k1_acceptance_collect(results, tasks),
        results
    )
    expect_error(
        landscapeR:::.k1_acceptance_collect(rev(results), tasks),
        "result order or task identity",
        class = "k1_acceptance_runner_error"
    )
})

test_that("acceptance seed derivation follows the frozen canonical contract", {
    manifest <- k1_acceptance_manifest(fake_phase_a_merge())
    first <- manifest$tasks[manifest$tasks$control == "generic_double_well", ][1L, ]

    expect_identical(
        first$canonical_cell,
        "control=generic_double_well;n=8;p=100"
    )
    expect_identical(first$replicate_index, 1L)
    expect_identical(first$task_ordinal, 1L)
    expect_identical(first$seed_root, 627208489L)
    expect_identical(first$stream_seeds[[1L]], c(
        state_coordinates = 627208489L,
        expression = 627208490L
    ))
    expect_identical(
        manifest,
        k1_acceptance_manifest(fake_phase_a_merge())
    )

    legacy_protocol <- k1_acceptance_protocol("1")
    legacy <- k1_acceptance_manifest(
        fake_phase_a_merge(),
        protocol = legacy_protocol
    )
    expect_true(validate_k1_acceptance_manifest(legacy))
    expect_identical(nrow(legacy$tasks), 9300L)
    expect_identical(legacy$artifact_version, "1")
    legacy_first <- legacy$tasks[
        legacy$tasks$control == "generic_double_well",
        ,
        drop = FALSE
    ][1L, ]
    expect_identical(
        legacy_first$canonical_cell,
        "control=generic_double_well;n=24;p=100"
    )
    expect_identical(legacy_first$seed_root, 1773915921L)
})

test_that("acceptance manifest rejects invalid commits and mutation", {
    expect_error(
        k1_acceptance_manifest("not-a-commit"),
        class = "k1_acceptance_runner_error"
    )

    changed <- k1_acceptance_manifest(fake_phase_a_merge())
    changed$tasks$seed_root[[1L]] <- changed$tasks$seed_root[[1L]] + 1L
    expect_error(
        validate_k1_acceptance_manifest(changed),
        class = "k1_acceptance_runner_error"
    )
})

test_that("shared-baseline safety control retains missing cells and abstains", {
    protocol <- k1_acceptance_protocol()
    manifest <- k1_acceptance_manifest(fake_phase_a_merge())
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

    expect_identical(result$status, "success")
    expect_identical(
        result$metrics$abstention_reason,
        "non-identifiable-design"
    )
    expect_identical(result$metrics$missing_control_time_cells, 3L)
    expect_identical(result$metrics$unique_control_observations, 3L)
    expect_identical(result$metrics$total_observations, 15L)

    audit_row <- landscapeR:::.k1_acceptance_flatten_results(list(result))
    expect_identical(
        audit_row$abstention_reason,
        "non-identifiable-design"
    )
    expect_identical(audit_row$missing_control_time_cells, 3L)
    expect_identical(audit_row$unique_control_observations, 3L)
    expect_identical(audit_row$total_observations, 15L)

    source <- landscapeR:::.k1_acceptance_shared_baseline_source(
        task,
        protocol
    )
    expect_length(source@provenance, 1L)
    step <- source@provenance[[1L]]
    expect_identical(
        step@implementation,
        protocol$generators$shared_baseline_missing_cells$id
    )
    expect_identical(step@input_hashes[["protocol"]], protocol$digest)
    expect_identical(
        step@params$rng$streams,
        task$stream_seeds[[1L]]
    )
    expect_identical(
        step@params$rng$run_seed,
        task$stream_seeds[[1L]][["generation"]]
    )

    mismatched_task <- task
    mismatched_task$seed_root <- task$seed_root + 1L
    expect_error(
        landscapeR:::.k1_acceptance_shared_baseline_source(
            mismatched_task,
            protocol
        ),
        "seed root must equal its generation stream",
        class = "k1_acceptance_runner_error"
    )
})

test_that("frozen AML acceptance task returns typed longitudinal metrics", {
    protocol <- k1_acceptance_protocol()
    manifest <- k1_acceptance_manifest(fake_phase_a_merge())
    task <- manifest$tasks[
        manifest$tasks$control == "aml_synchronized" &
            manifest$tasks$subjects_per_condition == 4L &
            manifest$tasks$p == 100L,
        ,
        drop = FALSE
    ][1L, , drop = FALSE]

    result <- suppressWarnings(landscapeR:::.k1_acceptance_run_task(
        task,
        protocol,
        expected_identity = NULL,
        sequential_internal = TRUE
    ))

    expect_identical(result$status, "success")
    expect_identical(names(result$metrics), c(
        "target_loading_cosine", "target_subspace_angle_deg",
        "mean_bootstrap_subspace_angle_deg",
        "q95_bootstrap_subspace_angle_deg",
        "target_component", "nuisance_component",
        "target_proposal_rank", "nuisance_proposal_rank",
        "target_unadjusted_estimate", "target_adjusted_estimate",
        "nuisance_unadjusted_estimate", "nuisance_adjusted_estimate",
        "target_unadjusted_status", "target_adjusted_status",
        "nuisance_unadjusted_status", "nuisance_adjusted_status",
        "target_index_recurrence", "mean_matched_loading_cosine",
        "identifiability_completion_rate", "stage2_ineligible",
        "orientation_recurrence", "rank_one_fraction", "matched_fraction",
        "acceptance_evidence_status", "acceptance_provenance",
        "acceptance_provenance_digest"
    ))
    expect_identical(result$metrics$target_component, 2L)
    expect_identical(result$metrics$nuisance_component, 1L)
    expect_identical(
        result$metrics$acceptance_evidence_status,
        "independent_acceptance"
    )
    expect_match(
        result$metrics$acceptance_provenance_digest,
        "^[0-9a-f]{64}$"
    )
    changed <- result
    changed$metrics$acceptance_provenance$stage2$reason <- "changed"
    expect_error(
        landscapeR:::.k1_acceptance_validate_result(changed, task, protocol),
        "AML acceptance metrics violate"
    )
    expect_true(result$metrics$stage2_ineligible)
    expect_true(is.finite(result$metrics$target_unadjusted_estimate))
    expect_true(is.finite(result$metrics$target_adjusted_estimate))
    expect_true(is.finite(result$metrics$mean_bootstrap_subspace_angle_deg) ||
        is.na(result$metrics$mean_bootstrap_subspace_angle_deg))
    expect_true(nzchar(result$metrics$target_adjusted_status))
    expect_type(
        landscapeR:::.k1_acceptance_replicate_pass(result, protocol),
        "logical"
    )
})

test_that("protocol and manifest identities cannot be mixed across versions", {
    expect_error(
        landscapeR:::.k1_acceptance_validate_protocol_manifest_identity(
            k1_acceptance_protocol("2"),
            k1_acceptance_manifest(
                fake_phase_a_merge(),
                k1_acceptance_protocol("1")
            )
        ),
        class = "k1_acceptance_runner_error"
    )
})

test_that("artifact verification translates malformed serialized input", {
    artifact <- tempfile("malformed-k1-artifact-")
    dir.create(artifact)
    governed <- landscapeR:::.k1_acceptance_governed_files()
    paths <- file.path(artifact, governed)
    invisible(vapply(paths, file.create, logical(1L)))
    files <- data.frame(
        file = governed,
        sha256 = vapply(
            paths,
            landscapeR:::.k1_acceptance_file_digest,
            character(1L)
        ),
        stringsAsFactors = FALSE
    )
    utils::write.table(
        files,
        file.path(artifact, "MANIFEST.tsv"),
        sep = "\t",
        quote = FALSE,
        row.names = FALSE
    )

    expect_error(
        verify_k1_acceptance_artifact(artifact),
        class = "k1_acceptance_runner_error"
    )
})

test_that("acceptance targets graph has one scheduler-owned parallel layer", {
    skip_if_not_installed("targets")

    pipeline <- k1_acceptance_targets(
        phase_a_merge_commit = fake_phase_a_merge(),
        artifact_root = tempfile("k1-acceptance-artifacts-"),
        controller = "medium"
    )
    expected <- c(
        "k1_protocol", "k1_manifest", "k1_identity", "k1_preflight",
        "k1_tasks", "k1_task",
        "k1_result", "k1_results", "k1_artifact",
        "k1_artifact_verified", "k1_evidence"
    )
    expect_identical(
        unname(vapply(pipeline, `[[`, character(1L), "name")),
        expected
    )

    by_name <- stats::setNames(pipeline, expected)
    expect_match(
        by_name$k1_tasks$command$string,
        "shared_baseline_missing_cells",
        fixed = TRUE
    )
    expect_false(grepl(
        "aml_synchronized",
        by_name$k1_tasks$command$string,
        fixed = TRUE
    ))
    worker <- as.list.environment(by_name$k1_result$settings)
    expect_identical(worker$deployment, "worker")
    expect_identical(worker$iteration, "list")
    expect_identical(worker$resources$crew$controller, "medium")
    expect_match(
        by_name$k1_result$command$string,
        "sequential_internal = TRUE",
        fixed = TRUE
    )
    expect_match(
        by_name$k1_tasks$command$string,
        "k1_preflight",
        fixed = TRUE
    )
    expect_identical(
        as.list.environment(by_name$k1_artifact$settings)$deployment,
        "main"
    )
})

test_that("acceptance targets graph can select the frozen AML phase alone", {
    skip_if_not_installed("targets")

    pipeline <- k1_acceptance_targets(
        phase_a_merge_commit = fake_phase_a_merge(),
        artifact_root = tempfile("k1-aml-acceptance-artifacts-"),
        controller = "medium",
        controls = "aml_synchronized",
        runner_revision = fake_runner_merge()
    )
    by_name <- stats::setNames(
        pipeline,
        vapply(pipeline, `[[`, character(1L), "name")
    )

    expect_match(
        by_name$k1_tasks$command$string,
        "aml_synchronized",
        fixed = TRUE
    )
    expect_false(grepl(
        "generic_double_well",
        by_name$k1_tasks$command$string,
        fixed = TRUE
    ))
    expect_match(
        by_name$k1_manifest$command$string,
        fake_runner_merge(),
        fixed = TRUE
    )
})

test_that("AML targets require a distinct reviewed runner revision", {
    skip_if_not_installed("targets")

    expect_error(
        k1_acceptance_targets(
            phase_a_merge_commit = fake_phase_a_merge(),
            artifact_root = tempfile("k1-aml-missing-runner-"),
            controls = "aml_synchronized"
        ),
        "requires the reviewed runner_revision"
    )
    expect_error(
        k1_acceptance_targets(
            phase_a_merge_commit = fake_phase_a_merge(),
            artifact_root = tempfile("k1-aml-same-runner-"),
            controls = "aml_synchronized",
            runner_revision = fake_phase_a_merge()
        ),
        "must differ"
    )
})

test_that("generic development task returns typed frozen metrics", {
    protocol <- k1_acceptance_protocol()
    task <- data.frame(
        task_id = "development-generic",
        control = "generic_double_well",
        n = 24L,
        p = 100L,
        subjects_per_condition = NA_integer_,
        replicate_index = 1L,
        seed_root = 91001L,
        canonical_cell = "development-only",
        stringsAsFactors = FALSE
    )
    task$stream_seeds <- list(c(
        state_coordinates = 91001L,
        expression = 91002L
    ))

    result <- suppressWarnings(landscapeR:::.k1_acceptance_run_task(
        task,
        protocol,
        expected_identity = NULL,
        sequential_internal = TRUE
    ))

    expect_s3_class(result, "K1AcceptanceReplicate")
    expect_identical(result$status, "success")
    expect_identical(result$control, "generic_double_well")
    expect_true(all(c(
        "subspace_angle_deg", "well_error", "barrier_error",
        "barrier_height_error", "n_wells_found", "n_barriers_found"
    ) %in% names(result$metrics)))
    expect_identical(result$runner_contract, "k1-stage0-acceptance-runner-v2")
})

test_that("generic acceptance generation is acceptance-native", {
    protocol <- k1_acceptance_protocol()
    task <- data.frame(
        task_id = "development-generic-provenance",
        control = "generic_double_well",
        n = 4L,
        p = 4L,
        subjects_per_condition = NA_integer_,
        replicate_index = 1L,
        seed_root = 91011L,
        canonical_cell = "development-only",
        stringsAsFactors = FALSE
    )
    task$stream_seeds <- list(c(
        state_coordinates = 91011L,
        expression = 91012L
    ))

    generated <- landscapeR:::.k1_acceptance_generate_generic(task, protocol)
    control <- metadata(generated)$k1_double_well_control
    step <- generated@provenance[[1L]]

    expect_false(control$calibration_only)
    expect_identical(control$evidence_status, "independent_acceptance")
    expect_identical(step@implementation, protocol$generators$generic_double_well)
    expect_false(step@params$calibration_only)
    expect_identical(step@input_hashes[["protocol"]], protocol$digest)
    expect_length(generated@provenance, 1L)
})

test_that("AML acceptance generation is acceptance-native", {
    protocol <- k1_acceptance_protocol()
    manifest <- k1_acceptance_manifest(fake_phase_a_merge())
    task <- manifest$tasks[
        manifest$tasks$control == "aml_synchronized",
        ,
        drop = FALSE
    ][1L, , drop = FALSE]

    generated <- landscapeR:::.k1_acceptance_generate_aml(task, protocol)
    control <- metadata(generated)$aml_k1_control
    step <- generated@provenance[[1L]]

    expect_false(control$calibration_only)
    expect_identical(control$evidence_status, "independent_acceptance")
    expect_identical(
        control$claim_status,
        "independent_acceptance_pending_aggregation"
    )
    expect_identical(step@implementation, protocol$generators$aml_synchronized)
    expect_false(step@params$calibration_only)
    expect_identical(step@input_hashes[["protocol"]], protocol$digest)
    expect_length(generated@provenance, 1L)
})

test_that("AML resource-pilot generation is explicitly non-evidentiary", {
    protocol <- k1_acceptance_protocol()
    manifest <- k1_acceptance_manifest(fake_phase_a_merge())
    task <- manifest$tasks[
        manifest$tasks$control == "aml_synchronized",
        ,
        drop = FALSE
    ][1L, , drop = FALSE]

    generated <- landscapeR:::.k1_aml_generate_governed(
        task,
        protocol,
        calibration_only = TRUE,
        evidence_status = "non_evidentiary_resource_pilot",
        claim_status = "non_evidentiary_resource_pilot",
        seed_derivation = "disclosed-development-seed-v1"
    )
    control <- metadata(generated)$aml_k1_control
    rng <- generated@provenance[[1L]]@params$rng

    expect_true(control$calibration_only)
    expect_identical(
        control$evidence_status,
        "non_evidentiary_resource_pilot"
    )
    expect_identical(
        control$claim_status,
        "non_evidentiary_resource_pilot"
    )
    expect_identical(rng$seed_derivation, "disclosed-development-seed-v1")

    testthat::local_mocked_bindings(
        .aml_k1_assess_control = function(
            std,
            config,
            n_resamples,
            n_permutations,
            seed,
            evidence_status,
            claim_status,
            sequential_internal
        ) {
            list(
                control = std,
                evidence_status = evidence_status,
                recovery = list(claim_status = claim_status),
                n_resamples = n_resamples,
                n_permutations = n_permutations,
                sequential_internal = sequential_internal
            )
        },
        .package = "landscapeR"
    )
    pilot <- landscapeR:::.k1_aml_resource_pilot(task, protocol, NULL)
    expect_identical(pilot$evidence_status, "non_evidentiary_resource_pilot")
    expect_identical(
        pilot$recovery$claim_status,
        "non_evidentiary_resource_pilot"
    )
    expect_identical(pilot$n_resamples, 99L)
    expect_identical(pilot$n_permutations, 99L)
    expect_true(pilot$sequential_internal)
})

test_that("published artifacts bind runtime identity and semantic contents", {
    expect_identical(
        landscapeR:::.k1_acceptance_wilson_lower(78L, 100L),
        round(landscapeR:::.k1_acceptance_wilson_lower(78L, 100L), 15L)
    )
    legacy_wilson <- landscapeR:::.k1_acceptance_wilson_lower(
        78L,
        100L,
        artifact_version = "1"
    )
    expect_false(identical(legacy_wilson, round(legacy_wilson, 15L)))
    protocol <- k1_acceptance_protocol()
    manifest <- k1_acceptance_manifest(fake_phase_a_merge())
    tasks <- manifest$tasks[
        manifest$tasks$control == "generic_double_well",
        ,
        drop = FALSE
    ][1L, , drop = FALSE]
    result <- structure(list(
        artifact_version = protocol$artifact_version,
        task_id = tasks$task_id[[1L]],
        control = tasks$control[[1L]],
        canonical_cell = tasks$canonical_cell[[1L]],
        replicate_index = tasks$replicate_index[[1L]],
        status = "success",
        reason = "",
        metrics = list(
            well_error = 0.05,
            barrier_error = 0.05,
            barrier_height_error = 0.1,
            n_wells_found = 2L,
            n_barriers_found = 1L,
            subspace_angle_deg = 5
        ),
        protocol_digest = protocol$digest,
        runner_contract = protocol$execution_contracts$version
    ), class = c("K1AcceptanceReplicate", "list"))
    unresolved_landmarks <- result
    unresolved_landmarks$metrics <- list(
        well_error = NA_real_,
        barrier_error = NA_real_,
        barrier_height_error = NA_real_,
        n_wells_found = 1L,
        n_barriers_found = 0L,
        subspace_angle_deg = 5
    )
    expect_invisible(landscapeR:::.k1_acceptance_validate_result(
        unresolved_landmarks,
        tasks,
        protocol
    ))
    identity <- list(
        source_revision = fake_phase_a_merge(),
        r_version = paste(R.version$major, R.version$minor, sep = "."),
        package_versions = c(
            landscapeR = as.character(utils::packageVersion("landscapeR"))
        )
    )
    recovery_identity <- identity
    recovery_identity$recovery <- list(
        mode = "approved_collection_only_patch",
        worker_results_modified = FALSE,
        corrections = "retain typed results",
        source_sha256 = c(procedure = strrep("a", 64L)),
        approved_by = "Denis O'Meally",
        approved_on = "2026-08-11"
    )
    expect_invisible(
        landscapeR:::.k1_acceptance_validate_collector_identity(
            recovery_identity
        )
    )
    invalid_recovery <- recovery_identity
    invalid_recovery$recovery$worker_results_modified <- TRUE
    expect_error(
        landscapeR:::.k1_acceptance_validate_collector_identity(
            invalid_recovery
        ),
        "recovery provenance is invalid"
    )
    root <- tempfile("k1-artifact-test-")
    artifact <- landscapeR:::.k1_acceptance_publish(
        root,
        protocol,
        manifest,
        tasks,
        list(result),
        identity
    )

    expect_true(verify_k1_acceptance_artifact(artifact))
    environment <- readRDS(file.path(artifact, "environment.rds"))
    expect_identical(environment$runtime_identity, identity)
    expect_identical(environment$collector_identity, identity)
    expect_match(environment$scientific_payload_digest, "^[0-9a-f]{64}$")

    manifest_path <- file.path(artifact, "MANIFEST.tsv")
    complete_file_manifest <- utils::read.delim(
        manifest_path,
        stringsAsFactors = FALSE
    )
    environment_path <- file.path(artifact, "environment.rds")
    altered_environment <- environment
    altered_environment$runtime_identity$source_revision <- strrep("2", 40L)
    saveRDS(altered_environment, environment_path)
    revision_manifest <- complete_file_manifest
    environment_row <- revision_manifest$file == "environment.rds"
    revision_manifest$sha256[environment_row] <-
        landscapeR:::.k1_acceptance_file_digest(environment_path)
    utils::write.table(
        revision_manifest,
        manifest_path,
        sep = "\t",
        quote = FALSE,
        row.names = FALSE
    )
    expect_error(
        verify_k1_acceptance_artifact(artifact),
        "runtime revision must equal",
        class = "k1_acceptance_runner_error"
    )
    saveRDS(environment, environment_path)
    utils::write.table(
        complete_file_manifest,
        manifest_path,
        sep = "\t",
        quote = FALSE,
        row.names = FALSE
    )

    utils::write.table(
        complete_file_manifest[
            complete_file_manifest$file != "pass-rate.png",
            ,
            drop = FALSE
        ],
        manifest_path,
        sep = "\t",
        quote = FALSE,
        row.names = FALSE
    )
    expect_error(
        verify_k1_acceptance_artifact(artifact),
        class = "k1_acceptance_runner_error"
    )
    utils::write.table(
        complete_file_manifest,
        manifest_path,
        sep = "\t",
        quote = FALSE,
        row.names = FALSE
    )

    summary_path <- file.path(artifact, "summary.rds")
    altered <- readRDS(summary_path)
    altered$n_completed <- altered$n_completed + 1L
    saveRDS(altered, summary_path)
    file_manifest <- utils::read.delim(
        file.path(artifact, "MANIFEST.tsv"),
        stringsAsFactors = FALSE
    )
    summary_row <- file_manifest$file == "summary.rds"
    file_manifest$sha256[summary_row] <-
        landscapeR:::.k1_acceptance_file_digest(summary_path)
    utils::write.table(
        file_manifest,
        file.path(artifact, "MANIFEST.tsv"),
        sep = "\t",
        quote = FALSE,
        row.names = FALSE
    )
    expect_error(
        verify_k1_acceptance_artifact(artifact),
        class = "k1_acceptance_runner_error"
    )
})

test_that("AML-only artifacts publish their governed acceptance surfaces", {
    protocol <- k1_acceptance_protocol()
    manifest <- k1_acceptance_manifest(
        fake_phase_a_merge(),
        runner_revision = fake_runner_merge()
    )
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
                acceptance_provenance = fake_aml_acceptance_provenance(),
                acceptance_provenance_digest = digest::digest(
                    fake_aml_acceptance_provenance(),
                    algo = "sha256"
                )
            ),
            protocol_digest = protocol$digest,
            runner_contract = protocol$execution_contracts$version
        ), class = c("K1AcceptanceReplicate", "list"))
    })
    identity <- list(
        source_revision = fake_runner_merge(),
        r_version = paste(R.version$major, R.version$minor, sep = "."),
        package_versions = c(
            landscapeR = as.character(utils::packageVersion("landscapeR"))
        )
    )

    artifact <- landscapeR:::.k1_acceptance_publish(
        tempfile("k1-aml-artifact-test-"),
        protocol,
        manifest,
        tasks,
        results,
        identity
    )

    expect_true(verify_k1_acceptance_artifact(artifact))
    stored_manifest <- readRDS(file.path(artifact, "seed-manifest.rds"))
    expect_identical(stored_manifest$phase_a_merge_commit, fake_phase_a_merge())
    expect_identical(stored_manifest$runner_revision, fake_runner_merge())
    files <- utils::read.delim(
        file.path(artifact, "MANIFEST.tsv"),
        stringsAsFactors = FALSE
    )$file
    expect_identical(
        files,
        landscapeR:::.k1_acceptance_governed_files(
            "independent_aml_acceptance_summary"
        )
    )
    expect_true(all(c(
        "aml-pass-rate.png", "aml-pass-rate-caption.txt",
        "aml-recovery.png", "aml-recovery-caption.txt"
    ) %in% files))
    expect_false(any(c("pass-rate.png", "false-positive.png") %in% files))
})

test_that("acceptance targets reject mixed publication phases", {
    skip_if_not_installed("targets")

    expect_error(
        k1_acceptance_targets(
            phase_a_merge_commit = fake_phase_a_merge(),
            artifact_root = tempfile("k1-mixed-acceptance-artifacts-"),
            controls = c("generic_double_well", "aml_synchronized"),
            runner_revision = fake_runner_merge()
        ),
        "complete phase-B1.*or aml_synchronized alone"
    )
})

test_that("artifact publication rejects mixed phases directly", {
    protocol <- k1_acceptance_protocol()
    manifest <- k1_acceptance_manifest(fake_phase_a_merge())
    tasks <- rbind(
        manifest$tasks[manifest$tasks$control == "generic_double_well", ][1L, ],
        manifest$tasks[manifest$tasks$control == "aml_synchronized", ][1L, ]
    )
    identity <- list(
        source_revision = fake_phase_a_merge(),
        r_version = paste(R.version$major, R.version$minor, sep = "."),
        package_versions = c(landscapeR = "0.3.0")
    )

    expect_error(
        landscapeR:::.k1_acceptance_publish(
            tempfile("k1-mixed-publication-"),
            protocol,
            manifest,
            tasks,
            list(),
            identity
        ),
        "require separate governed artifacts"
    )
})

test_that("runner revision preserves the version 1 manifest schema", {
    protocol <- k1_acceptance_protocol("1")
    expect_error(
        k1_acceptance_manifest(
            fake_phase_a_merge(),
            protocol,
            runner_revision = fake_runner_merge()
        ),
        "only by artifact version 2"
    )
    normalized <- k1_acceptance_manifest(
        fake_phase_a_merge(),
        runner_revision = fake_phase_a_merge()
    )
    expect_null(normalized$runner_revision)
    expect_identical(normalized, k1_acceptance_manifest(fake_phase_a_merge()))
})

test_that("runtime revision binding preserves the version 1 replay contract", {
    version_1 <- k1_acceptance_protocol("1")
    manifest <- k1_acceptance_manifest(
        fake_phase_a_merge(),
        protocol = version_1
    )
    replay_identity <- list(source_revision = strrep("2", 40L))

    expect_true(landscapeR:::.k1_validate_runtime_revision(
        replay_identity,
        manifest
    ))

    task <- manifest$tasks[
        manifest$tasks$control == "generic_double_well",
        ,
        drop = FALSE
    ][1L, , drop = FALSE]
    result <- structure(list(
        artifact_version = version_1$artifact_version,
        task_id = task$task_id[[1L]],
        control = task$control[[1L]],
        canonical_cell = task$canonical_cell[[1L]],
        replicate_index = task$replicate_index[[1L]],
        status = "success",
        reason = "",
        metrics = list(
            well_error = 0.05,
            barrier_error = 0.05,
            barrier_height_error = 0.1,
            n_wells_found = 2L,
            n_barriers_found = 1L,
            subspace_angle_deg = 5
        ),
        protocol_digest = version_1$digest,
        runner_contract = version_1$execution_contracts$version
    ), class = c("K1AcceptanceReplicate", "list"))
    identity <- list(
        source_revision = fake_phase_a_merge(),
        r_version = paste(R.version$major, R.version$minor, sep = "."),
        package_versions = c(
            landscapeR = as.character(utils::packageVersion("landscapeR"))
        )
    )
    root <- tempfile("k1-v1-artifact-test-")
    artifact <- landscapeR:::.k1_acceptance_publish(
        root,
        version_1,
        manifest,
        task,
        list(result),
        identity
    )
    environment_path <- file.path(artifact, "environment.rds")
    environment <- readRDS(environment_path)
    environment$collector_identity <- NULL
    summary <- readRDS(file.path(artifact, "summary.rds"))
    environment$scientific_payload_digest <-
        landscapeR:::.k1_acceptance_payload_digest(
            version_1,
            manifest,
            task,
            list(result),
            summary,
            identity,
            NULL
        )
    saveRDS(environment, environment_path)
    files <- utils::read.delim(
        file.path(artifact, "MANIFEST.tsv"),
        stringsAsFactors = FALSE
    )
    environment_row <- files$file == "environment.rds"
    files$sha256[environment_row] <-
        landscapeR:::.k1_acceptance_file_digest(environment_path)
    utils::write.table(
        files,
        file.path(artifact, "MANIFEST.tsv"),
        sep = "\t",
        quote = FALSE,
        row.names = FALSE
    )
    legacy_artifact <- file.path(
        dirname(artifact),
        paste0(
            version_1$protocol_id,
            "-",
            substr(
                landscapeR:::.k1_acceptance_artifact_digest(files),
                1L,
                16L
            )
        )
    )
    expect_true(file.rename(artifact, legacy_artifact))
    expect_true(verify_k1_acceptance_artifact(legacy_artifact))
})
