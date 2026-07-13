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
            maximum_elapsed_ratio = 1.5
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
    if (!identical(manifest$grid, frozen$grid) || !identical(manifest$feature_counts, frozen$feature_counts) ||
        !identical(manifest$selection_rules, frozen$selection_rules) ||
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

#' Write an immutable Stage 1 benchmark artifact
#'
#' @param artifact_dir new destination directory.
#' @param manifest benchmark manifest.
#' @param seed seed to execute.
#' @param stratum one explicit frozen-grid stratum.
#' @return named character vector of written artifact paths.
#' @export
write_stage1_benchmark_artifact <- function(artifact_dir, manifest = stage1_benchmark_manifest(), seed = 1001L,
                                            stratum = list(n = 20L, K = 2L,
                                                shared_signal = 24, exclusive_signal = 12,
                                                confounder_signal = 12, noise_sd = 1,
                                                missing_block_rate = 0,
                                                sample_order = "permuted", feature_order = "permuted",
                                                projection_case = "exact_ids")) {
    validate_stage1_benchmark_manifest(manifest)
    if (file.exists(artifact_dir) && !dir.exists(artifact_dir))
        .stage1_benchmark_abort("benchmark artifact path exists but is not a directory")
    if (dir.exists(artifact_dir) && length(list.files(artifact_dir, all.files = TRUE, no.. = TRUE)))
        .stage1_benchmark_abort("benchmark artifact directory must be new or empty")
    if (!dir.exists(artifact_dir) && !dir.create(artifact_dir, recursive = TRUE, showWarnings = FALSE))
        .stage1_benchmark_abort("could not create benchmark artifact directory")
    results <- run_stage1_benchmark_replicate(manifest, seed, stratum)
    manifest_path <- file.path(artifact_dir, "manifest.rds")
    seeds_path <- file.path(artifact_dir, "seed-manifest.csv")
    results_path <- file.path(artifact_dir, "results.csv")
    env_path <- file.path(artifact_dir, "environment.rds")
    saveRDS(manifest, manifest_path)
    utils::write.csv(manifest$seeds, seeds_path, row.names = FALSE)
    utils::write.csv(results, results_path, row.names = FALSE)
    saveRDS(list(r_version = R.version.string,
                 package_version = as.character(utils::packageVersion("landscapeR")),
                 commit = suppressWarnings(tryCatch(system2("git", c("rev-parse", "HEAD"),
                     stdout = TRUE, stderr = FALSE), error = function(e) NA_character_))), env_path)
    paths <- c(manifest = manifest_path, seeds = seeds_path, results = results_path, environment = env_path)
    hashes <- data.frame(file = basename(paths), sha256 = vapply(paths, digest::digest, character(1L), file = TRUE, algo = "sha256"), stringsAsFactors = FALSE)
    hash_path <- file.path(artifact_dir, "hashes.csv")
    utils::write.csv(hashes, hash_path, row.names = FALSE)
    c(paths, hashes = hash_path)
}

#' Verify a Stage 1 benchmark artifact hash manifest
#' @param artifact_dir artifact directory written by `write_stage1_benchmark_artifact()`.
#' @return `TRUE` when every recorded hash matches.
#' @export
verify_stage1_benchmark_artifact <- function(artifact_dir) {
    hash_path <- file.path(artifact_dir, "hashes.csv")
    if (!dir.exists(artifact_dir) || !file.exists(hash_path))
        .stage1_benchmark_abort("benchmark artifact hash manifest does not exist")
    hashes <- tryCatch(utils::read.csv(hash_path, stringsAsFactors = FALSE),
                       error = function(e) .stage1_benchmark_abort("benchmark artifact hash manifest is invalid"))
    all(vapply(seq_len(nrow(hashes)), function(i)
        identical(digest::digest(file.path(artifact_dir, hashes$file[[i]]), file = TRUE, algo = "sha256"), hashes$sha256[[i]]), logical(1L)))
}
