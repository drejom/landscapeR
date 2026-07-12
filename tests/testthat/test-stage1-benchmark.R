test_that("stage1 benchmark manifest is frozen and validates", {
    manifest <- stage1_benchmark_manifest()
    expect_silent(validate_stage1_benchmark_manifest(manifest))
    expect_equal(manifest$seeds$split, rep(c("calibration", "holdout"), each = 20L))
    manifest$candidates <- "wrong"
    expect_error(validate_stage1_benchmark_manifest(manifest), class = "stage1_benchmark_error")
    manifest <- stage1_benchmark_manifest()
    manifest$rank <- 3L
    expect_error(validate_stage1_benchmark_manifest(manifest), class = "stage1_benchmark_error")
})

# ---- Issue #38 regression tests --------------------------------------------------

test_that("generator_digest changes when a digested helper body changes (regression #38)", {
    # Capture the baseline digest from the unmodified package namespace.
    baseline <- landscapeR:::.generator_digest()
    expect_type(baseline, "character")
    expect_equal(nchar(baseline), 64L)  # sha256 hex

    # Temporarily replace the body of a digested helper with a trivially
    # different version and confirm the digest changes.  We use body<- on a
    # copy of the function object and reassign in the namespace; package source
    # files are never touched.
    ns <- asNamespace("landscapeR")
    original_fn <- get(".frobenius", envir = ns)

    # Build modified function: identical except body has an unreachable sentinel
    modified_fn <- original_fn
    body(modified_fn) <- quote({
        .DIGEST_SENTINEL <- "changed"  # synthetic change, never executed
        sqrt(sum(x^2))
    })

    # Patch the namespace in-process (no source files touched)
    unlockBinding(".frobenius", ns)
    assign(".frobenius", modified_fn, envir = ns)
    lockBinding(".frobenius", ns)

    patched <- landscapeR:::.generator_digest()

    # Restore immediately before any teardown
    unlockBinding(".frobenius", ns)
    assign(".frobenius", original_fn, envir = ns)
    lockBinding(".frobenius", ns)

    # The digest must differ after the patch and return to baseline once restored
    expect_false(identical(baseline, patched))
    restored <- landscapeR:::.generator_digest()
    expect_identical(baseline, restored)
})

test_that("generator_digest covers .projector .frobenius .prototype_responses setup_rng (regression #38)", {
    # All four newly-added helpers must actually be retrievable from the namespace
    # (a missing name would throw in .generator_digest(), which would be a bug).
    ns <- asNamespace("landscapeR")
    required <- c(".projector", ".frobenius", ".prototype_responses", "setup_rng")
    for (nm in required) {
        expect_true(exists(nm, envir = ns, inherits = FALSE),
            info = sprintf("%s must exist in landscapeR namespace", nm))
    }
    # The digest must complete without error — it fetches all named helpers
    expect_no_error(landscapeR:::.generator_digest())
})

test_that("missing-ID negative controls produce stage1_prototype_error not just try-error (regression #38)", {
    # Build the minimal smoke control and fit C1 so we can test .prototype_project
    # directly before touching the benchmark runner path.
    std <- landscapeR:::.stage1_heterogeneous_smoke_control(seed = 1001L)
    ext <- landscapeR:::.prototype_complete_layers(std)
    prepared <- landscapeR:::.prototype_preprocess(ext$matrices)
    fit <- landscapeR:::.prototype_consensus(prepared)
    fit$prepared <- prepared

    # Construct a valid holdout then remove one feature from layer 1
    n_h <- 10L
    holdout <- Map(function(prep) {
        x <- matrix(rnorm(n_h * length(prep$means)), n_h, length(prep$means))
        colnames(x) <- names(prep$means)
        x
    }, prepared)
    malformed <- holdout
    malformed[[1L]] <- malformed[[1L]][, -1L, drop = FALSE]

    # Must throw — and the condition must inherit stage1_prototype_error
    err <- tryCatch(
        landscapeR:::.prototype_project(malformed, fit),
        stage1_prototype_error = function(e) e,
        error = function(e) e
    )
    # Must be a typed stage1_prototype_error (not just any error / try-error)
    expect_s3_class(err, "stage1_prototype_error")
    expect_s3_class(err, "error")

    # Confirm the gate in stage1_candidate_smoke now records typed rejection
    smoke <- stage1_candidate_smoke(1001L)
    expect_true(all(smoke$gates$missing_projection_id_rejected))

    # Extra-ID path must also produce a typed error
    extra_malformed <- holdout
    extra_malformed[[1L]] <- cbind(extra_malformed[[1L]], extra_col = 0)
    err2 <- tryCatch(
        landscapeR:::.prototype_project(extra_malformed, fit),
        stage1_prototype_error = function(e) e,
        error = function(e) e
    )
    expect_s3_class(err2, "stage1_prototype_error")
})

# ---- End Issue #38 regression tests -----------------------------------------------

test_that("one benchmark replicate is deterministic and artifact hashes verify", {
    manifest <- stage1_benchmark_manifest()
    first <- run_stage1_benchmark_replicate(manifest)
    second <- run_stage1_benchmark_replicate(manifest)
    compare <- setdiff(names(first), c("elapsed_sec", "peak_vcells_bytes"))
    expect_equal(first[, compare], second[, compare])
    other_seed <- run_stage1_benchmark_replicate(manifest, 1002L)
    expect_equal(other_seed$seed, c(1002L, 1002L))
    missing_block <- run_stage1_benchmark_replicate(
        manifest, stratum = modifyList(list(n = 20L, K = 2L, shared_signal = 24,
        exclusive_signal = 12, confounder_signal = 12, noise_sd = 1,
        missing_block_rate = 0, sample_order = "permuted", feature_order = "permuted",
        projection_case = "exact_ids"), list(missing_block_rate = .20)))
    expect_true(all(missing_block$gate_passed))
    three_layer_missing <- run_stage1_benchmark_replicate(manifest, seed = 1001L,
        stratum = modifyList(list(n = 20L, K = 2L, shared_signal = 24,
        exclusive_signal = 12, confounder_signal = 12, noise_sd = 1,
        missing_block_rate = 0, sample_order = "permuted", feature_order = "permuted",
        projection_case = "exact_ids"), list(K = 3L, missing_block_rate = .20)))
    expect_true(all(three_layer_missing$gate_passed))
    control <- landscapeR:::.stage1_heterogeneous_control(
        seed = 1001L, n = 20L, p = c(80L, 400L, 1200L), missing_block_rate = .20)
    expect_equal(nrow(landscapeR:::.prototype_complete_layers(control)$matrices[[1L]]), 20L)
    expect_equal(manifest$feature_counts[["3"]], c(80L, 400L, 1200L))
    missing_id <- run_stage1_benchmark_replicate(manifest, stratum = modifyList(
        list(n = 20L, K = 2L, shared_signal = 24, exclusive_signal = 12,
             confounder_signal = 12, noise_sd = 1, missing_block_rate = 0,
             sample_order = "permuted", feature_order = "permuted",
             projection_case = "exact_ids"), list(projection_case = "missing_id")))
    expect_true(all(missing_id$typed_failure_rate == 1L))
    expect_true(all(is.na(missing_id$projection_error)))

    expect_error(run_stage1_benchmark_replicate(manifest,
        stratum = modifyList(list(n = 20L, K = 2L, shared_signal = 24,
        exclusive_signal = 12, confounder_signal = 12, noise_sd = 1,
        missing_block_rate = 0, sample_order = "permuted", feature_order = "permuted",
        projection_case = "exact_ids"), list(n = 21L))), class = "stage1_benchmark_error")

    path <- tempfile("stage1-artifact-")
    write_stage1_benchmark_artifact(path, manifest)
    saved <- utils::read.csv(file.path(path, "results.csv"), stringsAsFactors = FALSE)
    expect_true(all(c("stratum", "exclusions", "failure_reason", "protocol_digest", "generator_digest") %in% names(saved)))
    expect_true(verify_stage1_benchmark_artifact(path))
    expect_error(write_stage1_benchmark_artifact(path, manifest), class = "stage1_benchmark_error")
    file_path <- tempfile("stage1-artifact-file-")
    file.create(file_path)
    expect_error(write_stage1_benchmark_artifact(file_path, manifest), class = "stage1_benchmark_error")
    expect_error(verify_stage1_benchmark_artifact(tempfile("missing-artifact-")),
                 class = "stage1_benchmark_error")
})
