# Stage 0 — manifest-backed Stage 1 candidate benchmark artifacts
#
# ADR 0011 defines the immutable full-tier protocol. This module deliberately
# runs an explicitly requested subset; it never selects a candidate.

.stage1_benchmark_abort <- function(message) {
    stop(structure(list(message = message, call = NULL),
                   class = c("stage1_benchmark_error", "error", "condition")))
}

#' Construct the frozen Stage 1 heterogeneous benchmark manifest
#'
#' @return a canonical list for protocol `stage1-heterogeneous-v1`.
#' @export
stage1_benchmark_manifest <- function() {
    list(
        artifact_version = "1",
        protocol_id = "stage1-heterogeneous-v1",
        generator = "heterogeneous_shared_subspace_v1",
        candidates = c("C1_symmetric_consensus", "C2_block_scaled_svd"),
        rank = 2L,
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
                           stringsAsFactors = FALSE)
    )
}

#' Validate a Stage 1 benchmark manifest
#' @param manifest manifest returned by `stage1_benchmark_manifest()`.
#' @return invisibly `TRUE`, or throws a typed error.
#' @export
validate_stage1_benchmark_manifest <- function(manifest) {
    required <- c("artifact_version", "protocol_id", "generator", "candidates", "rank", "grid", "seeds")
    if (!is.list(manifest) || !all(required %in% names(manifest)))
        .stage1_benchmark_abort("benchmark manifest is missing required fields")
    if (!identical(manifest$protocol_id, "stage1-heterogeneous-v1") ||
        !identical(manifest$generator, "heterogeneous_shared_subspace_v1"))
        .stage1_benchmark_abort("benchmark manifest protocol/generator identity is invalid")
    if (!identical(manifest$candidates, c("C1_symmetric_consensus", "C2_block_scaled_svd")))
        .stage1_benchmark_abort("benchmark manifest candidates differ from frozen protocol")
    if (!is.data.frame(manifest$seeds) || !identical(manifest$seeds$seed, 1001:1040) ||
        !identical(manifest$seeds$split, rep(c("calibration", "holdout"), each = 20L)))
        .stage1_benchmark_abort("benchmark manifest seed/split assignment is invalid")
    invisible(TRUE)
}

#' Run one deterministic benchmark replicate
#'
#' This initial runner intentionally supports the frozen smoke stratum only.
#' It provides the validated artifact seam for the later parameterised full
#' generator; requesting another stratum fails rather than silently running a
#' different simulation.
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
    required <- c("n", "K", "shared_signal", "exclusive_signal", "confounder_signal",
                  "noise_sd", "missing_block_rate", "sample_order", "feature_order", "projection_case")
    if (!is.list(stratum) || !all(required %in% names(stratum)))
        .stage1_benchmark_abort("stratum is missing frozen grid fields")
    if (!identical(as.numeric(stratum$missing_block_rate), 0))
        .stage1_benchmark_abort("missing-block strata require the deferred complete-case generator")
    p <- if (identical(as.integer(stratum$K), 2L)) c(80L, 400L) else c(80L, 400L, 1200L)
    control <- .stage1_heterogeneous_control(seed = seed, n = stratum$n, p = p,
        signal = c(shared = unname(stratum$shared_signal), exclusive = unname(stratum$exclusive_signal),
                   confounder = unname(stratum$confounder_signal)), noise_sd = unname(stratum$noise_sd),
        sample_permuted = identical(stratum$sample_order, "permuted"),
        feature_permuted = identical(stratum$feature_order, "permuted"))
    smoke <- stage1_candidate_smoke(seed, control = control)
    split <- manifest$seeds$split[match(seed, manifest$seeds$seed)]
    out <- smoke$results
    out$seed <- seed
    out$split <- split
    out$protocol_id <- manifest$protocol_id
    out$generator <- manifest$generator
    out$gate_passed <- all(smoke$gates$sample_map_aligned,
                           smoke$gates$heterogeneous_features,
                           all(smoke$gates$missing_projection_id_rejected),
                           all(smoke$gates$extra_projection_id_rejected),
                           all(smoke$gates$permutation_invariant))
    out
}

#' Write an immutable Stage 1 benchmark artifact
#'
#' @param artifact_dir new destination directory.
#' @param manifest benchmark manifest.
#' @param seed seed to execute.
#' @return named character vector of written artifact paths.
#' @export
write_stage1_benchmark_artifact <- function(artifact_dir, manifest = stage1_benchmark_manifest(), seed = 1001L) {
    validate_stage1_benchmark_manifest(manifest)
    if (dir.exists(artifact_dir) && length(list.files(artifact_dir, all.files = TRUE, no.. = TRUE)))
        .stage1_benchmark_abort("benchmark artifact directory must be new or empty")
    dir.create(artifact_dir, recursive = TRUE, showWarnings = FALSE)
    results <- run_stage1_benchmark_replicate(manifest, seed)
    manifest_path <- file.path(artifact_dir, "manifest.rds")
    seeds_path <- file.path(artifact_dir, "seed-manifest.csv")
    results_path <- file.path(artifact_dir, "results.csv")
    env_path <- file.path(artifact_dir, "environment.rds")
    saveRDS(manifest, manifest_path)
    utils::write.csv(manifest$seeds, seeds_path, row.names = FALSE)
    utils::write.csv(results, results_path, row.names = FALSE)
    saveRDS(list(r_version = R.version.string,
                 package_version = as.character(utils::packageVersion("landscapeR")),
                 commit = tryCatch(system2("git", c("rev-parse", "HEAD"), stdout = TRUE), error = function(e) NA_character_)), env_path)
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
    hashes <- utils::read.csv(file.path(artifact_dir, "hashes.csv"), stringsAsFactors = FALSE)
    all(vapply(seq_len(nrow(hashes)), function(i)
        identical(digest::digest(file.path(artifact_dir, hashes$file[[i]]), file = TRUE, algo = "sha256"), hashes$sha256[[i]]), logical(1L)))
}
