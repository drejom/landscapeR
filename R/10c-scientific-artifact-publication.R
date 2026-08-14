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

.artifact_attempt <- function(
    expression, abort, messages, preserve_condition, key = "invalid"
) {
    tryCatch(
        force(expression),
        error = function(condition) {
            if (isTRUE(preserve_condition(condition))) stop(condition)
            .artifact_fail(abort, messages, key)
        }
    )
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

.artifact_governed_options <- function(governed, abort, messages) {
    options <- if (is.character(governed)) list(governed) else governed
    if (!is.list(options) || length(options) == 0L) {
        .artifact_fail(abort, messages, "invalid")
    }
    lapply(options, .artifact_validate_files,
        abort = abort, messages = messages)
    options
}

.artifact_identity <- function(
    identity_digest, manifest, artifact, abort, messages, preserve_condition
) {
    value <- .artifact_attempt(
        identity_digest(manifest, artifact),
        abort, messages, preserve_condition
    )
    if (!is.character(value) || length(value) != 1L || is.na(value) ||
            !grepl("^[0-9a-f]{64}$", value)) {
        .artifact_fail(abort, messages, "invalid")
    }
    value
}

.artifact_governed_directories <- function(governed) {
    directories <- dirname(governed)
    directories <- directories[directories != "."]
    unique(unlist(lapply(directories, function(directory) {
        parts <- strsplit(directory, "/", fixed = TRUE)[[1L]]
        vapply(seq_along(parts), function(index) {
            paste(parts[seq_len(index)], collapse = "/")
        }, character(1L))
    }), use.names = FALSE))
}

.artifact_inventory <- function(path, governed, abort, messages) {
    entries <- list.files(
        path, recursive = TRUE, all.files = TRUE,
        no.. = TRUE, include.dirs = TRUE
    )
    if (length(entries) == 0L) {
        return(list(files = character(), directories = character()))
    }
    full_paths <- file.path(path, entries)
    info <- file.info(full_paths)
    links <- nzchar(Sys.readlink(full_paths))
    invalid_entry <- anyNA(info$isdir) || any(links) ||
        any(!info$isdir & !file_test("-f", full_paths))
    if (invalid_entry) {
        .artifact_fail(abort, messages, "invalid")
    }
    directories <- entries[info$isdir]
    if (any(!directories %in% .artifact_governed_directories(governed))) {
        .artifact_fail(abort, messages, "undeclared")
    }
    list(files = entries[!info$isdir], directories = directories)
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
    options <- .artifact_governed_options(governed, abort, messages)
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
    valid_shape <- is.data.frame(manifest) &&
        identical(names(manifest), c("file", "sha256")) &&
        !anyNA(manifest) && !anyDuplicated(manifest$file) &&
        !any(grepl("(^|/)[.][.](/|$)|^/", manifest$file))
    if (!valid_shape) {
        .artifact_fail(abort, messages, "invalid")
    }
    matches <- vapply(options, identical, logical(1L), manifest$file)
    if (sum(matches) != 1L) {
        .artifact_fail(abort, messages, "invalid")
    }
    governed <- options[[which(matches)]]
    inventory <- .artifact_inventory(
        artifact, governed, abort, messages
    )
    payload_files <- setdiff(inventory$files, .artifact_manifest_name)
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
    atomic_move = .artifact_atomic_move,
    preserve_condition = function(condition) {
        inherits(condition, "landscapeR_validation_error")
    },
    identity_digest = function(manifest, artifact) {
        .artifact_digest(manifest)
    },
    artifact_path = NULL
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
            !is.function(preserve_condition) || !is.function(identity_digest) ||
            !.is_scalar_nonempty_text(staging_prefix)) {
        .artifact_fail(abort, messages, "invalid")
    }
    if (!is.null(artifact_path) &&
            !.is_scalar_nonempty_text(artifact_path)) {
        .artifact_fail(abort, messages, "invalid")
    }
    .artifact_validate_files(governed, abort, messages)

    artifact_root <- path.expand(artifact_root)
    if (!is.null(artifact_path)) {
        artifact_path <- path.expand(artifact_path)
        if (!identical(dirname(artifact_path), artifact_root) ||
                basename(artifact_path) %in% c(".", "..")) {
            .artifact_fail(abort, messages, "invalid")
        }
        if (file.exists(artifact_path) && !dir.exists(artifact_path)) {
            .artifact_fail(abort, messages, "invalid")
        }
        if (dir.exists(artifact_path) && length(list.files(
                artifact_path, all.files = TRUE, no.. = TRUE))) {
            .artifact_fail(abort, messages, "invalid")
        }
    }
    if (!dir.exists(artifact_root)) {
        .artifact_attempt(
            suppressWarnings(dir.create(
                artifact_root, recursive = TRUE, showWarnings = FALSE
            )),
            abort, messages, preserve_condition
        )
    }
    if (!dir.exists(artifact_root)) {
        .artifact_fail(abort, messages, "invalid")
    }
    staging <- tempfile(staging_prefix, tmpdir = artifact_root)
    payload <- file.path(staging, "payload")
    .artifact_attempt(
        suppressWarnings(dir.create(
            payload, recursive = TRUE, showWarnings = FALSE
        )),
        abort, messages, preserve_condition
    )
    if (!dir.exists(payload)) {
        .artifact_fail(abort, messages, "invalid")
    }
    on.exit({
        if (dir.exists(staging)) {
            suppressWarnings(unlink(staging, recursive = TRUE))
        }
    }, add = TRUE)

    .artifact_attempt(
        write_payload(payload), abort, messages, preserve_condition
    )
    actual <- .artifact_inventory(
        payload, governed, abort, messages
    )$files
    if (any(!governed %in% actual)) {
        .artifact_fail(abort, messages, "incomplete")
    }
    if (any(!actual %in% governed)) {
        .artifact_fail(abort, messages, "undeclared")
    }
    manifest <- .artifact_attempt(
        data.frame(
            file = governed,
            sha256 = vapply(
                file.path(payload, governed),
                .artifact_file_digest,
                character(1L)
            ),
            stringsAsFactors = FALSE
        ),
        abort, messages, preserve_condition
    )
    .artifact_attempt(
        utils::write.table(
            manifest,
            file.path(payload, .artifact_manifest_name),
            sep = "\t", quote = FALSE, row.names = FALSE
        ),
        abort, messages, preserve_condition
    )
    .artifact_verify_payload(payload, governed, abort, messages)
    artifact_digest <- .artifact_identity(
        identity_digest, manifest, payload, abort, messages,
        preserve_condition
    )
    artifact <- if (is.null(artifact_path)) {
        file.path(artifact_root, paste0(
            address_prefix, "-", substr(artifact_digest, 1L, 16L)
        ))
    } else {
        artifact_path
    }
    candidate <- file.path(staging, basename(artifact))
    moved_to_candidate <- .artifact_attempt(
        suppressWarnings(file.rename(payload, candidate)),
        abort, messages, preserve_condition, "atomic"
    )
    if (!moved_to_candidate) {
        .artifact_fail(abort, messages, "atomic")
    }
    .artifact_verify_payload(candidate, governed, abort, messages)
    semantic_verifier(candidate)
    candidate_manifest <- .artifact_verify_payload(
        candidate, governed, abort, messages
    )
    candidate_identity <- .artifact_identity(
        identity_digest, candidate_manifest, candidate, abort, messages,
        preserve_condition
    )
    if (!identical(candidate_identity, artifact_digest)) {
        .artifact_fail(abort, messages, "digest")
    }
    verify_existing <- function() {
        observed <- .artifact_verify_payload(
            artifact, governed, abort, messages
        )
        observed_identity <- .artifact_identity(
            identity_digest, observed, artifact, abort, messages,
            preserve_condition
        )
        .artifact_verify_payload(artifact, governed, abort, messages)
        if (!identical(observed_identity, artifact_digest)) {
            .artifact_fail(abort, messages, "digest")
        }
        artifact
    }
    if (is.null(artifact_path) && dir.exists(artifact)) {
        return(verify_existing())
    }
    if (!is.null(artifact_path) && dir.exists(artifact)) {
        suppressWarnings(unlink(artifact, recursive = TRUE))
        if (dir.exists(artifact)) {
            .artifact_fail(abort, messages, "atomic")
        }
    }
    if (!atomic_move(candidate, artifact)) {
        if (is.null(artifact_path) && dir.exists(artifact)) {
            return(verify_existing())
        }
        .artifact_fail(abort, messages, "atomic")
    }
    artifact
}
