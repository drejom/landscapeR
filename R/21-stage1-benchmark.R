# Stage 0 — manifest-backed Stage 1 candidate benchmark artifacts
#
# ADR 0011 defines the immutable full-tier protocol. This module deliberately
# runs an explicitly requested subset; it never selects a candidate.

.stage1_benchmark_abort <- function(message) {
    stop(structure(list(message = message, call = NULL),
                   class = c("stage1_benchmark_error", "error", "condition")))
}

.protocol_digest <- function(manifest) {
    digest::digest(manifest[c("artifact_version", "protocol_id", "generator", "candidates",
                              "rank", "feature_counts", "grid", "seeds",
                              "selection_rules", "reporting_rules")], algo = "sha256")
}

.generator_digest <- function() {
    # All helpers whose body can affect generated controls, candidate outputs,
    # gates, or metrics must be included here so that any modification to any
    # of them changes the digest and invalidates previously stored artifacts.
    functions <- c(".stage1_heterogeneous_control", ".centered_orthonormal",
                   ".prototype_complete_layers", ".prototype_preprocess",
                   ".prototype_responses",
                   ".prototype_consensus", ".prototype_block_svd",
                   ".prototype_project", ".prototype_metrics", "stage1_candidate_smoke",
                   ".projector", ".frobenius", "setup_rng")
    digest::digest(lapply(functions, function(name) body(get(name, envir = asNamespace("landscapeR")))),
                   algo = "sha256")
}

#' Construct the frozen Stage 1 heterogeneous benchmark manifest
#'
#' @return a canonical list for protocol `stage1-heterogeneous-v2`.
#' @export
stage1_benchmark_manifest <- function() {
    list(
        artifact_version = "2",
        protocol_id = "stage1-heterogeneous-v2",
        generator = "heterogeneous_shared_subspace_v1",
        candidates = c("C1_symmetric_consensus", "C2_block_scaled_svd"),
        rank = 2L,
        feature_counts = list(`2` = c(80L, 400L), `3` = c(80L, 400L, 1200L)),
        environment = list(r_version = R.version.string,
                           package_version = as.character(utils::packageVersion("landscapeR"))),
        grid = list(
            n = c(20L, 60L), K = c(2L, 3L),
            shared_signal = c(12, 24), exclusive_signal = c(0, 12),
            confounder_signal = c(0, 12), noise_sd = c(1, 2),
            missing_block_rate = c(0, .20),
            sample_order = c("canonical", "permuted"),
            feature_order = c("canonical", "permuted"),
            projection_case = c("exact_ids", "missing_id")
        ),
        seeds = data.frame(seed = 1001:1040,
                           split = rep(c("calibration", "holdout"), each = 20L),
                           stringsAsFactors = FALSE),
        selection_rules = list(
            bootstrap_resamples = 10000L,
            bootstrap_seed = 11001L,
            bootstrap = "paired seeds resampled within stratum",
            statistic = "equal-stratum-weighted mean C1 minus C2 shared-recovery error",
            ci = "two-sided 95% percentile",
            shared_recovery_advantage = -0.03,
            maximum_leakage_or_projection_disadvantage = 0.02,
            maximum_elapsed_ratio = 1.5,
            runtime_gate = "diagnostic_only"
        ),
        reporting_rules = list(
            bootstrap_resamples = 10000L,
            bootstrap_seed_start = 11002L,
            bootstrap = "seeds resampled within canonical stratum",
            statistic = "median",
            ci = "two-sided 95% percentile"
        )
    )
}

#' Validate a Stage 1 benchmark manifest
#' @param manifest manifest returned by `stage1_benchmark_manifest()`.
#' @return invisibly `TRUE`, or throws a typed error.
#' @export
validate_stage1_benchmark_manifest <- function(manifest) {
    required <- c("artifact_version", "protocol_id", "generator", "candidates", "rank", "feature_counts", "environment", "grid", "seeds", "selection_rules", "reporting_rules")
    if (!is.list(manifest) || !all(required %in% names(manifest)))
        .stage1_benchmark_abort("benchmark manifest is missing required fields")
    if (!identical(manifest$artifact_version, "2") || !identical(manifest$rank, 2L) ||
        !identical(manifest$protocol_id, "stage1-heterogeneous-v2") ||
        !identical(manifest$generator, "heterogeneous_shared_subspace_v1"))
        .stage1_benchmark_abort("benchmark manifest identity, version, or rank is invalid")
    if (!identical(manifest$candidates, c("C1_symmetric_consensus", "C2_block_scaled_svd")))
        .stage1_benchmark_abort("benchmark manifest candidates differ from frozen protocol")
    if (!is.data.frame(manifest$seeds) || !identical(manifest$seeds$seed, 1001:1040) ||
        !identical(manifest$seeds$split, rep(c("calibration", "holdout"), each = 20L)))
        .stage1_benchmark_abort("benchmark manifest seed/split assignment is invalid")
    frozen <- stage1_benchmark_manifest()
    legacy_selection_rules <- frozen$selection_rules
    legacy_selection_rules$runtime_gate <- NULL
    is_legacy_v2 <- identical(manifest$protocol_id, "stage1-heterogeneous-v2") &&
        identical(manifest$selection_rules, legacy_selection_rules)
    if (!identical(manifest$grid, frozen$grid) || !identical(manifest$feature_counts, frozen$feature_counts) ||
        (!identical(manifest$selection_rules, frozen$selection_rules) && !is_legacy_v2) ||
        !identical(manifest$reporting_rules, frozen$reporting_rules))
        .stage1_benchmark_abort("benchmark manifest differs from frozen protocol")
    invisible(TRUE)
}

.validate_stage1_benchmark_stratum <- function(stratum, manifest) {
    required <- c("n", "K", "shared_signal", "exclusive_signal", "confounder_signal",
                  "noise_sd", "missing_block_rate", "sample_order", "feature_order", "projection_case")
    if (!is.list(stratum) || !identical(sort(names(stratum)), sort(required)))
        .stage1_benchmark_abort("stratum must contain exactly the frozen grid fields")
    g <- manifest$grid
    valid <- stratum$n %in% g$n && stratum$K %in% g$K &&
        stratum$shared_signal %in% g$shared_signal && stratum$exclusive_signal %in% g$exclusive_signal &&
        stratum$confounder_signal %in% g$confounder_signal && stratum$noise_sd %in% g$noise_sd &&
        stratum$missing_block_rate %in% g$missing_block_rate &&
        stratum$sample_order %in% g$sample_order && stratum$feature_order %in% g$feature_order &&
        stratum$projection_case %in% g$projection_case
    if (!isTRUE(valid)) .stage1_benchmark_abort("stratum contains values outside the frozen grid")
    invisible(TRUE)
}

#' Run one deterministic benchmark replicate
#'
#' Runs one explicitly requested frozen-grid stratum. It does not execute a
#' sweep or select a candidate.
#'
#' @param manifest validated benchmark manifest.
#' @param seed one manifest seed.
#' @param stratum one explicit list from the frozen grid. The default is the
#'   smoke stratum; callers may run any currently supported non-missing stratum.
#' @return one row per candidate with split, metrics, gate state, and timing.
#' @export
run_stage1_benchmark_replicate <- function(manifest = stage1_benchmark_manifest(), seed = 1001L,
                                            stratum = list(n = 20L, K = 2L,
                                                shared_signal = 24, exclusive_signal = 12,
                                                confounder_signal = 12, noise_sd = 1,
                                                missing_block_rate = 0,
                                                sample_order = "permuted", feature_order = "permuted",
                                                projection_case = "exact_ids")) {
    validate_stage1_benchmark_manifest(manifest)
    seed <- as.integer(seed)
    if (!seed %in% manifest$seeds$seed)
        .stage1_benchmark_abort("seed is not declared in the benchmark manifest")
    .validate_stage1_benchmark_stratum(stratum, manifest)
    p <- manifest$feature_counts[[as.character(as.integer(stratum$K))]]
    control <- .stage1_heterogeneous_control(seed = seed, n = stratum$n, p = p,
        signal = c(shared = unname(stratum$shared_signal), exclusive = unname(stratum$exclusive_signal),
                   confounder = unname(stratum$confounder_signal)), noise_sd = unname(stratum$noise_sd),
        missing_block_rate = unname(stratum$missing_block_rate),
        sample_permuted = identical(stratum$sample_order, "permuted"),
        feature_permuted = identical(stratum$feature_order, "permuted"))
    smoke <- stage1_candidate_smoke(seed, control = control)
    split <- manifest$seeds$split[match(seed, manifest$seeds$seed)]
    out <- smoke$results
    out$seed <- seed
    out$split <- split
    out$protocol_id <- manifest$protocol_id
    out$generator <- manifest$generator
    out$protocol_digest <- .protocol_digest(manifest)
    out$generator_digest <- .generator_digest()
    out$stratum_digest <- digest::digest(stratum, algo = "sha256")
    out$stratum <- vapply(seq_len(nrow(out)), function(i) paste(utils::capture.output(dput(stratum)), collapse = ""), character(1L))
    for (field in names(stratum)) out[[field]] <- stratum[[field]]
    out$tier <- "full"
    out$exclusions <- paste(smoke$gates$complete_case_exclusions, collapse = ";")
    base_gate <- all(smoke$gates$sample_map_aligned, smoke$gates$heterogeneous_features,
                     all(smoke$gates$extra_projection_id_rejected), all(smoke$gates$permutation_invariant))
    is_missing_projection <- identical(stratum$projection_case, "missing_id")
    if (is_missing_projection) {
        typed <- all(smoke$gates$missing_projection_id_rejected)
        out$gate_expected <- "typed_failure"
        out$gate_observed <- if (typed) "typed_failure" else "unexpected_success"
        out$gate_passed <- typed
        out$typed_failure_rate <- as.integer(typed)
        out[, c("shared_recovery_error", "response_recovery_error", "exclusive_leakage", "projection_error")] <- NA_real_
        out$failure_reason <- if (typed) "expected projection feature-ID typed failure" else
            "missing-ID negative control did not produce a typed failure"
    } else {
        out$gate_expected <- "success"
        out$gate_observed <- if (base_gate && all(smoke$gates$missing_projection_id_rejected)) "success" else "failure"
        out$gate_passed <- base_gate && all(smoke$gates$missing_projection_id_rejected)
        out$failure_reason <- NA_character_
    }
    out
}

#' Write a Stage 1 benchmark artifact to an exact directory
#'
#' This compatibility entry point preserves the original direct-directory
#' contract. For content-addressed publication, use
#' [publish_stage1_benchmark_artifact()].
#'
#' @param artifact_dir new or empty destination directory.
#' @param manifest benchmark manifest.
#' @param seed seed to execute.
#' @param stratum one explicit frozen-grid stratum.
#' @return named character vector of verified artifact paths.
#' @export
write_stage1_benchmark_artifact <- function(artifact_dir, manifest = stage1_benchmark_manifest(), seed = 1001L,
                                            stratum = list(n = 20L, K = 2L,
                                                shared_signal = 24, exclusive_signal = 12,
                                                confounder_signal = 12, noise_sd = 1,
                                                missing_block_rate = 0,
                                                sample_order = "permuted", feature_order = "permuted",
                                                projection_case = "exact_ids")) {
    .publish_stage1_benchmark_artifact(
        dirname(path.expand(artifact_dir)), manifest, seed, stratum,
        artifact_path = path.expand(artifact_dir), legacy_hashes = TRUE
    )
}

#' Publish a content-addressed Stage 1 benchmark artifact
#'
#' @param artifact_root root directory for content-addressed artifacts.
#' @inheritParams write_stage1_benchmark_artifact
#' @return named character vector of verified artifact paths.
#' @export
publish_stage1_benchmark_artifact <- function(artifact_root,
        manifest = stage1_benchmark_manifest(), seed = 1001L,
        stratum = list(n = 20L, K = 2L,
            shared_signal = 24, exclusive_signal = 12,
            confounder_signal = 12, noise_sd = 1,
            missing_block_rate = 0,
            sample_order = "permuted", feature_order = "permuted",
            projection_case = "exact_ids")) {
    .publish_stage1_benchmark_artifact(
        artifact_root, manifest, seed, stratum
    )
}

.publish_stage1_benchmark_artifact <- function(
    artifact_root, manifest, seed, stratum,
    artifact_path = NULL, legacy_hashes = FALSE
) {
    validate_stage1_benchmark_manifest(manifest)
    results <- run_stage1_benchmark_replicate(manifest, seed, stratum)
    environment <- .stage1_benchmark_environment()
    governed <- .stage1_benchmark_governed_files(legacy_hashes)
    write_payload <- function(staging) {
        saveRDS(manifest, file.path(staging, "manifest.rds"))
        utils::write.csv(
            manifest$seeds,
            file.path(staging, "seed-manifest.csv"),
            row.names = FALSE
        )
        utils::write.csv(
            results, file.path(staging, "results.csv"), row.names = FALSE
        )
        saveRDS(environment, file.path(staging, "environment.rds"))
        if (legacy_hashes) {
            files <- .stage1_benchmark_governed_files(FALSE)
            hashes <- data.frame(
                file = files,
                sha256 = vapply(
                    file.path(staging, files), .artifact_file_digest,
                    character(1L)
                ),
                stringsAsFactors = FALSE
            )
            utils::write.csv(
                hashes, file.path(staging, "hashes.csv"), row.names = FALSE
            )
        }
    }
    artifact <- .artifact_publish(
        artifact_root = artifact_root,
        address_prefix = paste0(manifest$protocol_id, "-replicate-", seed),
        governed = governed,
        write_payload = write_payload,
        semantic_verifier = .stage1_benchmark_verify_current,
        abort = .stage1_benchmark_abort,
        messages = .stage1_benchmark_artifact_errors(),
        staging_prefix = ".stage1-benchmark-",
        preserve_condition = function(condition) {
            inherits(condition, "stage1_benchmark_error")
        },
        identity_digest = .stage1_benchmark_identity_digest,
        artifact_path = artifact_path
    )
    payload <- .stage1_benchmark_governed_files(FALSE)
    paths <- file.path(artifact, payload)
    hash_path <- if (legacy_hashes) {
        file.path(artifact, "hashes.csv")
    } else {
        file.path(artifact, "MANIFEST.tsv")
    }
    stats::setNames(
        c(paths, hash_path),
        c("manifest", "seeds", "results", "environment", "hashes")
    )
}

.stage1_benchmark_environment <- function() {
    list(
        r_version = R.version.string,
        package_version = as.character(utils::packageVersion("landscapeR")),
        commit = suppressWarnings(tryCatch(
            system2("git", c("rev-parse", "HEAD"),
                stdout = TRUE, stderr = FALSE),
            error = function(condition) NA_character_
        ))
    )
}

#' Verify a Stage 1 benchmark artifact
#' @param artifact_dir artifact directory written by
#'   [write_stage1_benchmark_artifact()] or returned by
#'   [publish_stage1_benchmark_artifact()].
#' @return `TRUE` when every recorded hash matches.
#' @export
verify_stage1_benchmark_artifact <- function(artifact_dir) {
    if (file.exists(file.path(artifact_dir, "MANIFEST.tsv"))) {
        return(.stage1_benchmark_verify_current(artifact_dir))
    }
    hash_path <- file.path(artifact_dir, "hashes.csv")
    if (!dir.exists(artifact_dir) || !file.exists(hash_path))
        .stage1_benchmark_abort("benchmark artifact hash manifest does not exist")
    hashes <- tryCatch(utils::read.csv(hash_path, stringsAsFactors = FALSE),
                       error = function(e) .stage1_benchmark_abort("benchmark artifact hash manifest is invalid"))
    all(vapply(seq_len(nrow(hashes)), function(i)
        identical(digest::digest(file.path(artifact_dir, hashes$file[[i]]), file = TRUE, algo = "sha256"), hashes$sha256[[i]]), logical(1L)))
}

.stage1_benchmark_governed_files <- function(legacy_hashes = FALSE) {
    files <- c(
        "manifest.rds", "seed-manifest.csv", "results.csv", "environment.rds"
    )
    if (legacy_hashes) c(files, "hashes.csv") else files
}

.stage1_benchmark_artifact_errors <- function() list(
    incomplete = "Stage 1 benchmark artifact is incomplete",
    missing_manifest = "Stage 1 benchmark artifact has no MANIFEST.tsv",
    missing_payload = "Stage 1 benchmark artifact is incomplete",
    invalid = "Stage 1 benchmark artifact manifest is invalid",
    undeclared = "Stage 1 benchmark artifact contains undeclared files",
    digest = "Stage 1 benchmark artifact payload hash mismatch",
    atomic = "could not atomically publish Stage 1 benchmark artifact"
)

.stage1_benchmark_identity_digest <- function(file_manifest, artifact_dir) {
    manifest <- readRDS(file.path(artifact_dir, "manifest.rds"))
    results <- utils::read.csv(
        file.path(artifact_dir, "results.csv"), stringsAsFactors = FALSE
    )
    environment <- readRDS(file.path(artifact_dir, "environment.rds"))
    digest::digest(list(
        manifest = manifest,
        results = .stage1_scientific_results(results),
        environment = environment
    ), algo = "sha256")
}

.stage1_benchmark_verify_current <- function(
    artifact_dir,
    verify_address = !file.exists(file.path(artifact_dir, "hashes.csv"))
) {
    files <- .artifact_verify_payload(
        artifact_dir,
        list(
            .stage1_benchmark_governed_files(FALSE),
            .stage1_benchmark_governed_files(TRUE)
        ),
        .stage1_benchmark_abort,
        .stage1_benchmark_artifact_errors()
    )
    legacy_hash_path <- file.path(artifact_dir, "hashes.csv")
    if (file.exists(legacy_hash_path)) {
        hashes <- tryCatch(
            utils::read.csv(legacy_hash_path, stringsAsFactors = FALSE),
            error = function(condition) {
                .stage1_benchmark_abort(
                    "benchmark artifact hash manifest is invalid"
                )
            }
        )
        valid_hashes <- identical(
            hashes$file, .stage1_benchmark_governed_files(FALSE)
        ) && identical(
            hashes$sha256,
            unname(vapply(
                file.path(artifact_dir, hashes$file),
                .artifact_file_digest,
                character(1L)
            ))
        )
        if (!valid_hashes) {
            .stage1_benchmark_abort(
                "benchmark artifact hash manifest is invalid"
            )
        }
    }
    manifest <- tryCatch(
        readRDS(file.path(artifact_dir, "manifest.rds")),
        error = function(condition) {
            .stage1_benchmark_abort("benchmark manifest is invalid")
        }
    )
    results <- tryCatch(
        utils::read.csv(
            file.path(artifact_dir, "results.csv"),
            stringsAsFactors = FALSE
        ),
        error = function(condition) {
            .stage1_benchmark_abort("benchmark results are invalid")
        }
    )
    environment <- tryCatch(
        readRDS(file.path(artifact_dir, "environment.rds")),
        error = function(condition) {
            .stage1_benchmark_abort("benchmark environment is invalid")
        }
    )
    validate_stage1_benchmark_manifest(manifest)
    seeds <- unique(results$seed)
    if (length(seeds) != 1L || !is.list(environment) ||
            !is.character(environment$commit) ||
            length(environment$commit) != 1L ||
            !grepl("^[0-9a-f]{40}$", environment$commit)) {
        .stage1_benchmark_abort(
            "benchmark artifact identity is invalid"
        )
    }
    stratum_fields <- c(
        "n", "K", "shared_signal", "exclusive_signal",
        "confounder_signal", "noise_sd", "missing_block_rate",
        "sample_order", "feature_order", "projection_case"
    )
    if (!all(stratum_fields %in% names(results))) {
        .stage1_benchmark_abort("benchmark results are invalid")
    }
    stratum <- as.list(results[1L, stratum_fields, drop = FALSE])
    stratum$n <- as.integer(stratum$n)
    stratum$K <- as.integer(stratum$K)
    numeric_fields <- c(
        "shared_signal", "exclusive_signal", "confounder_signal",
        "noise_sd", "missing_block_rate"
    )
    stratum[numeric_fields] <- lapply(
        stratum[numeric_fields], as.numeric
    )
    reproduced <- run_stage1_benchmark_replicate(
        manifest, seeds[[1L]], stratum
    )
    observed <- .stage1_scientific_results(results)
    expected <- .stage1_scientific_results(reproduced)
    observed_file <- tempfile(
        "stage1-benchmark-observed-", fileext = ".csv"
    )
    expected_file <- tempfile(
        "stage1-benchmark-expected-", fileext = ".csv"
    )
    on.exit(unlink(c(observed_file, expected_file)), add = TRUE)
    utils::write.csv(observed, observed_file, row.names = FALSE)
    utils::write.csv(expected, expected_file, row.names = FALSE)
    if (!identical(
            readLines(observed_file, warn = FALSE),
            readLines(expected_file, warn = FALSE)
        )) {
        .stage1_benchmark_abort(
            "benchmark results do not reproduce"
        )
    }
    seed_file <- tempfile("stage1-benchmark-seeds-", fileext = ".csv")
    on.exit(unlink(seed_file), add = TRUE)
    utils::write.csv(manifest$seeds, seed_file, row.names = FALSE)
    if (!identical(
            readLines(seed_file, warn = FALSE),
            readLines(
                file.path(artifact_dir, "seed-manifest.csv"),
                warn = FALSE
            )
        )) {
        .stage1_benchmark_abort(
            "benchmark seed manifest does not reproduce"
        )
    }
    identity <- .stage1_benchmark_identity_digest(files, artifact_dir)
    expected_name <- paste0(
        manifest$protocol_id, "-replicate-", seeds[[1L]], "-",
        substr(identity, 1L, 16L)
    )
    if (verify_address && !identical(basename(artifact_dir), expected_name)) {
        .stage1_benchmark_abort(
            "benchmark artifact address is inconsistent"
        )
    }
    invisible(TRUE)
}
