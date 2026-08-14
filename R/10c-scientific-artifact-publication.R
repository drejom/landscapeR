# Shared filesystem publication for immutable scientific artifacts.
# Scientific adapters own payload meaning and semantic verification. This
# module owns declared-file integrity, content addressing, cleanup, and the
# atomic move into the published address.

.artifact_manifest_name <- "MANIFEST.tsv"

.artifact_atomic_move <- function(from, to) file.rename(from, to)

.artifact_file_digest <- function(path) {
    digest::digest(file = path, algo = "sha256", serialize = FALSE)
}

.artifact_digest <- function(manifest) {
    digest::digest(
        list(
            file = as.character(manifest$file),
            sha256 = as.character(manifest$sha256)
        ),
        algo = "sha256"
    )
}

.artifact_message <- function(messages, key) {
    value <- messages[[key]]
    if (is.null(value)) value <- messages$invalid
    if (!.is_scalar_nonempty_text(value)) {
        .stop_landscapeR_validation(
            paste("scientific artifact adapter must declare", key, "message")
        )
    }
    value
}

.artifact_fail <- function(abort, messages, key) {
    abort(.artifact_message(messages, key))
    invisible(NULL)
}

.artifact_validate_files <- function(
    governed, abort, messages
) {
    valid <- is.character(governed) && length(governed) > 0L &&
        !anyNA(governed) && all(nzchar(governed)) &&
        !anyDuplicated(governed) &&
        !any(grepl("(^|/)[.][.](/|$)|^/", governed)) &&
        !.artifact_manifest_name %in% governed
    if (!valid) .artifact_fail(abort, messages, "invalid")
    invisible(TRUE)
}

.artifact_read_manifest <- function(path, abort, messages) {
    suppressWarnings(tryCatch(
        utils::read.delim(
            path, stringsAsFactors = FALSE, check.names = FALSE
        ),
        error = function(condition) {
            .artifact_fail(abort, messages, "invalid")
        }
    ))
}

.artifact_verify_payload <- function(
    artifact, governed, abort, messages
) {
    .artifact_validate_files(governed, abort, messages)
    artifact <- path.expand(artifact)
    manifest_path <- file.path(
        artifact, .artifact_manifest_name
    )
    if (!dir.exists(artifact) || !file.exists(manifest_path)) {
        .artifact_fail(abort, messages, "missing_manifest")
    }
    manifest <- .artifact_read_manifest(
        manifest_path, abort, messages
    )
    valid_manifest <- is.data.frame(manifest) &&
        identical(names(manifest), c("file", "sha256")) &&
        identical(manifest$file, governed) && !anyNA(manifest) &&
        !anyDuplicated(manifest$file) &&
        !any(grepl("(^|/)[.][.](/|$)|^/", manifest$file))
    if (!valid_manifest) {
        .artifact_fail(abort, messages, "invalid")
    }
    actual <- list.files(
        artifact, recursive = TRUE, all.files = TRUE,
        no.. = TRUE, include.dirs = FALSE
    )
    payload_files <- setdiff(actual, .artifact_manifest_name)
    if (any(!governed %in% payload_files)) {
        .artifact_fail(abort, messages, "missing_payload")
    }
    if (any(!payload_files %in% governed)) {
        .artifact_fail(abort, messages, "undeclared")
    }
    observed <- vapply(
        file.path(artifact, governed),
        .artifact_file_digest,
        character(1L)
    )
    if (!identical(unname(observed), manifest$sha256)) {
        .artifact_fail(abort, messages, "digest")
    }
    manifest
}

.artifact_publish <- function(
    artifact_root, address_prefix, governed, write_payload,
    semantic_verifier, abort, messages, staging_prefix,
    atomic_move = .artifact_atomic_move
) {
    if (!.is_scalar_nonempty_text(artifact_root)) {
        .stop_landscapeR_validation("artifact_root must be one non-empty path")
    }
    if (!.is_scalar_nonempty_text(address_prefix) ||
            address_prefix %in% c(".", "..") ||
            grepl("[/\\\\]", address_prefix)) {
        .artifact_fail(abort, messages, "invalid")
    }
    if (!is.function(write_payload) || !is.function(semantic_verifier) ||
            !is.function(abort) || !is.function(atomic_move) ||
            !.is_scalar_nonempty_text(staging_prefix)) {
        .artifact_fail(abort, messages, "invalid")
    }
    .artifact_validate_files(governed, abort, messages)

    artifact_root <- path.expand(artifact_root)
    dir.create(artifact_root, recursive = TRUE, showWarnings = FALSE)
    staging <- tempfile(staging_prefix, tmpdir = artifact_root)
    payload <- file.path(staging, "payload")
    dir.create(payload, recursive = TRUE, showWarnings = FALSE)
    on.exit({
        if (dir.exists(staging)) unlink(staging, recursive = TRUE)
    }, add = TRUE)

    write_payload(payload)
    actual <- list.files(
        payload, recursive = TRUE, all.files = TRUE,
        no.. = TRUE, include.dirs = FALSE
    )
    if (any(!governed %in% actual)) {
        .artifact_fail(abort, messages, "incomplete")
    }
    if (any(!actual %in% governed)) {
        .artifact_fail(abort, messages, "undeclared")
    }
    manifest <- data.frame(
        file = governed,
        sha256 = vapply(
            file.path(payload, governed),
            .artifact_file_digest,
            character(1L)
        ),
        stringsAsFactors = FALSE
    )
    artifact_digest <- .artifact_digest(manifest)
    artifact <- file.path(artifact_root, paste0(
        address_prefix, "-", substr(artifact_digest, 1L, 16L)
    ))
    if (dir.exists(artifact)) {
        semantic_verifier(artifact)
        return(artifact)
    }
    utils::write.table(
        manifest,
        file.path(payload, .artifact_manifest_name),
        sep = "\t", quote = FALSE, row.names = FALSE
    )
    candidate <- file.path(staging, basename(artifact))
    if (!file.rename(payload, candidate)) {
        .artifact_fail(abort, messages, "atomic")
    }
    .artifact_verify_payload(candidate, governed, abort, messages)
    semantic_verifier(candidate)
    if (!atomic_move(candidate, artifact)) {
        .artifact_fail(abort, messages, "atomic")
    }
    artifact
}
