artifact_test_messages <- function() {
    list(
        incomplete = "artifact incomplete",
        missing_manifest = "artifact incomplete",
        missing_payload = "artifact incomplete",
        invalid = "artifact manifest invalid",
        undeclared = "artifact has undeclared files",
        digest = "artifact digest mismatch",
        atomic = "artifact atomic publication failed"
    )
}

artifact_test_abort <- function(message) stop(message, call. = FALSE)

artifact_test_writer <- function(staging) {
    writeLines("alpha", file.path(staging, "alpha.txt"))
    writeLines("beta", file.path(staging, "beta.txt"))
}

artifact_test_verify <- function(artifact) {
    landscapeR:::.artifact_verify_payload(
        artifact,
        c("alpha.txt", "beta.txt"),
        artifact_test_abort,
        artifact_test_messages()
    )
    invisible(TRUE)
}

artifact_test_publish <- function(
    root, writer = artifact_test_writer,
    atomic_move = landscapeR:::.artifact_atomic_move,
    semantic_verifier = artifact_test_verify
) {
    landscapeR:::.artifact_publish(
        artifact_root = root,
        address_prefix = "fixture-v1",
        governed = c("alpha.txt", "beta.txt"),
        write_payload = writer,
        semantic_verifier = semantic_verifier,
        abort = artifact_test_abort,
        messages = artifact_test_messages(),
        staging_prefix = ".fixture-tmp-",
        atomic_move = atomic_move
    )
}

test_that("scientific artifacts publish deterministically and verify", {
    root <- tempfile("scientific-artifact-")
    dir.create(root)
    artifact <- artifact_test_publish(root)

    expect_true(artifact_test_verify(artifact))
    expect_match(basename(artifact), "^fixture-v1-[0-9a-f]{16}$")
    expect_identical(artifact_test_publish(root), artifact)
    expect_identical(
        sort(list.files(artifact)),
        sort(c("alpha.txt", "beta.txt", "MANIFEST.tsv"))
    )
})

test_that("scientific artifact manifests reject structural drift", {
    root <- tempfile("scientific-artifact-")
    dir.create(root)
    artifact <- artifact_test_publish(root)
    manifest_path <- file.path(artifact, "MANIFEST.tsv")
    manifest <- utils::read.delim(manifest_path, stringsAsFactors = FALSE)

    utils::write.table(
        rbind(manifest, manifest[1L, , drop = FALSE]),
        manifest_path, sep = "\t", quote = FALSE, row.names = FALSE
    )
    expect_error(artifact_test_verify(artifact), "manifest invalid")

    utils::write.table(
        manifest, manifest_path, sep = "\t", quote = FALSE, row.names = FALSE
    )
    writeLines("extra", file.path(artifact, "extra.txt"))
    expect_error(artifact_test_verify(artifact), "undeclared files")
})

test_that("scientific artifacts reject missing and altered payloads", {
    missing_root <- tempfile("scientific-artifact-")
    dir.create(missing_root)
    missing <- artifact_test_publish(missing_root)
    unlink(file.path(missing, "beta.txt"))
    expect_error(artifact_test_verify(missing), "incomplete")

    altered_root <- tempfile("scientific-artifact-")
    dir.create(altered_root)
    altered <- artifact_test_publish(altered_root)
    writeLines("changed", file.path(altered, "alpha.txt"))
    expect_error(artifact_test_verify(altered), "digest mismatch")
    expect_error(
        artifact_test_publish(
            altered_root, semantic_verifier = function(artifact) TRUE
        ),
        "digest mismatch"
    )
})

test_that("scientific artifact staging is cleaned after failure", {
    interrupted_root <- tempfile("scientific-artifact-")
    dir.create(interrupted_root)
    interrupted_writer <- function(staging) {
        writeLines("alpha", file.path(staging, "alpha.txt"))
        stop("writer interrupted", call. = FALSE)
    }
    expect_error(
        artifact_test_publish(interrupted_root, interrupted_writer),
        "writer interrupted"
    )
    expect_length(list.files(interrupted_root, all.files = TRUE, no.. = TRUE), 0L)

    atomic_root <- tempfile("scientific-artifact-")
    dir.create(atomic_root)
    expect_error(
        artifact_test_publish(
            atomic_root, atomic_move = function(from, to) FALSE
        ),
        "atomic publication failed"
    )
    expect_length(list.files(atomic_root, all.files = TRUE, no.. = TRUE), 0L)

    semantic_root <- tempfile("scientific-artifact-")
    dir.create(semantic_root)
    rejecting_verifier <- function(artifact) {
        artifact_test_verify(artifact)
        stop("semantic replay failed", call. = FALSE)
    }
    expect_error(
        artifact_test_publish(
            semantic_root, semantic_verifier = rejecting_verifier
        ),
        "semantic replay failed"
    )
    expect_length(
        list.files(semantic_root, all.files = TRUE, no.. = TRUE), 0L
    )

    mutation_root <- tempfile("scientific-artifact-")
    dir.create(mutation_root)
    mutating_verifier <- function(artifact) {
        artifact_test_verify(artifact)
        writeLines("changed during replay", file.path(artifact, "alpha.txt"))
        invisible(TRUE)
    }
    expect_error(
        artifact_test_publish(
            mutation_root, semantic_verifier = mutating_verifier
        ),
        "digest mismatch"
    )
    expect_length(
        list.files(mutation_root, all.files = TRUE, no.. = TRUE), 0L
    )
})

test_that("scientific artifacts reject links and undeclared directories", {
    link_root <- tempfile("scientific-artifact-")
    dir.create(link_root)
    external <- tempfile("external-payload-")
    writeLines("external", external)
    link_writer <- function(staging) {
        file.symlink(external, file.path(staging, "alpha.txt"))
        writeLines("beta", file.path(staging, "beta.txt"))
    }
    expect_error(
        artifact_test_publish(link_root, link_writer),
        "manifest invalid"
    )
    expect_length(list.files(link_root, all.files = TRUE, no.. = TRUE), 0L)

    directory_root <- tempfile("scientific-artifact-")
    dir.create(directory_root)
    directory_writer <- function(staging) {
        artifact_test_writer(staging)
        dir.create(file.path(staging, "undeclared"))
    }
    expect_error(
        artifact_test_publish(directory_root, directory_writer),
        "undeclared files"
    )
    expect_length(
        list.files(directory_root, all.files = TRUE, no.. = TRUE), 0L
    )
})

test_that("a concurrent valid publisher wins the address race", {
    root <- tempfile("scientific-artifact-")
    dir.create(root)
    racing_move <- function(from, to) {
        dir.create(to)
        files <- list.files(from, all.files = TRUE, no.. = TRUE)
        file.copy(file.path(from, files), to, recursive = TRUE)
        FALSE
    }

    artifact <- artifact_test_publish(root, atomic_move = racing_move)

    expect_true(artifact_test_verify(artifact))
    expect_length(
        list.files(root, all.files = TRUE, no.. = TRUE), 1L
    )
})
