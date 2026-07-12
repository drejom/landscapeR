test_that("stage1 benchmark manifest is frozen and validates", {
    manifest <- stage1_benchmark_manifest()
    expect_silent(validate_stage1_benchmark_manifest(manifest))
    expect_equal(manifest$seeds$split, rep(c("calibration", "holdout"), each = 20L))
    manifest$candidates <- "wrong"
    expect_error(validate_stage1_benchmark_manifest(manifest), class = "stage1_benchmark_error")
})

test_that("one benchmark replicate is deterministic and artifact hashes verify", {
    manifest <- stage1_benchmark_manifest()
    first <- run_stage1_benchmark_replicate(manifest)
    second <- run_stage1_benchmark_replicate(manifest)
    compare <- setdiff(names(first), c("elapsed_sec", "peak_vcells_bytes"))
    expect_equal(first[, compare], second[, compare])
    expect_error(run_stage1_benchmark_replicate(manifest, 1002L), class = "stage1_benchmark_error")

    path <- tempfile("stage1-artifact-")
    write_stage1_benchmark_artifact(path, manifest)
    expect_true(verify_stage1_benchmark_artifact(path))
    expect_error(write_stage1_benchmark_artifact(path, manifest), class = "stage1_benchmark_error")
})
