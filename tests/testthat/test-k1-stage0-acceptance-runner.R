fake_phase_a_merge <- function() strrep("1", 40L)

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

test_that("acceptance seed derivation follows the frozen canonical contract", {
    manifest <- k1_acceptance_manifest(fake_phase_a_merge())
    first <- manifest$tasks[manifest$tasks$control == "generic_double_well", ][1L, ]

    expect_identical(
        first$canonical_cell,
        "control=generic_double_well;n=8;p=100"
    )
    expect_identical(first$replicate_index, 1L)
    expect_identical(first$task_ordinal, 1L)
    expect_identical(first$seed_root, 1873862853L)
    expect_identical(first$stream_seeds[[1L]], c(
        state_coordinates = 1873862853L,
        expression = 1873862854L
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
        "k1_protocol", "k1_manifest", "k1_identity", "k1_tasks", "k1_task",
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
    expect_identical(worker$resources$crew$controller, "medium")
    expect_match(
        by_name$k1_result$command$string,
        "sequential_internal = TRUE",
        fixed = TRUE
    )
    expect_identical(
        as.list.environment(by_name$k1_artifact$settings)$deployment,
        "main"
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

test_that("published artifacts bind runtime identity and semantic contents", {
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
    identity <- list(
        source_revision = strrep("2", 40L),
        r_version = paste(R.version$major, R.version$minor, sep = "."),
        package_versions = c(
            landscapeR = as.character(utils::packageVersion("landscapeR"))
        )
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
    expect_match(environment$scientific_payload_digest, "^[0-9a-f]{64}$")

    manifest_path <- file.path(artifact, "MANIFEST.tsv")
    complete_file_manifest <- utils::read.delim(
        manifest_path,
        stringsAsFactors = FALSE
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
