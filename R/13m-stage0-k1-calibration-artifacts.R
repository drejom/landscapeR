# Shared publication machinery for design-aware K=1 calibration artifacts.
# Scientific validators, plots, captions, and displayed data remain owned by
# each calibration module; this file owns only the repeated governed-file and
# atomic-publication contract.

.k1_calibration_artifact_files <- function() c(
    "assessment.rds", "replicates.csv", "cell-summary.csv",
    "operating-map-data.csv", "operating-map.png",
    "operating-map-caption.txt", "environment.rds"
)

.k1_calibration_atomic_move <- function(from, to) file.rename(from, to)

.k1_calibration_read_or_abort <- function(expression, message) {
    suppressWarnings(tryCatch(
        force(expression),
        error = function(condition) .k1_acceptance_runner_abort(message)
    ))
}

.k1_design_calibration_artifact_manifest <- function(
    artifact, governed, messages
) {
    artifact <- path.expand(artifact)
    manifest_path <- file.path(artifact, "MANIFEST.tsv")
    if (!dir.exists(artifact) || !file.exists(manifest_path)) {
        .k1_acceptance_runner_abort(messages$incomplete)
    }
    manifest <- .k1_calibration_read_or_abort(
        utils::read.delim(
            manifest_path, stringsAsFactors = FALSE, check.names = FALSE
        ),
        messages$invalid
    )
    actual <- list.files(
        artifact, recursive = TRUE, all.files = TRUE,
        no.. = TRUE, include.dirs = FALSE
    )
    valid <- identical(names(manifest), c("file", "sha256")) &&
        identical(manifest$file, governed) && !anyNA(manifest) &&
        !anyDuplicated(manifest$file) &&
        !any(grepl("(^|/)[.][.](/|$)|^/", manifest$file)) &&
        setequal(actual, c("MANIFEST.tsv", governed)) &&
        identical(
            unname(vapply(
                file.path(artifact, governed),
                .k1_acceptance_file_digest, character(1L)
            )),
            manifest$sha256
        )
    if (!valid) .k1_acceptance_runner_abort(messages$invalid)
    manifest
}

.k1_calibration_normalize_display <- function(display) display

.k1_design_calibration_verify_artifact <- function(
    artifact, validator, plotter, map_attribute,
    normalize_display = .k1_calibration_normalize_display,
    governed = .k1_calibration_artifact_files(), messages
) {
    artifact <- path.expand(artifact)
    manifest <- .k1_design_calibration_artifact_manifest(
        artifact, governed, messages
    )
    assessment <- .k1_calibration_read_or_abort(
        readRDS(file.path(artifact, "assessment.rds")), messages$invalid
    )
    environment <- .k1_calibration_read_or_abort(
        readRDS(file.path(artifact, "environment.rds")), messages$invalid
    )
    validator(assessment)
    .k1_acceptance_validate_identity(environment$runtime_identity)

    plot <- plotter(assessment)
    temporary <- tempfile(fileext = c(
        "-replicates.csv", "-cells.csv", "-map.csv"
    ))
    on.exit(unlink(temporary), add = TRUE)
    utils::write.csv(
        assessment$replicates, temporary[[1L]], row.names = FALSE
    )
    utils::write.csv(assessment$cells, temporary[[2L]], row.names = FALSE)
    display <- normalize_display(attr(plot, map_attribute))
    utils::write.csv(display, temporary[[3L]], row.names = FALSE)
    same_lines <- function(expected, observed) identical(
        readLines(expected, warn = FALSE),
        readLines(observed, warn = FALSE)
    )
    caption <- .k1_calibration_read_or_abort(
        paste(readLines(
            file.path(artifact, "operating-map-caption.txt"), warn = FALSE
        ), collapse = "\n"),
        messages$derivatives
    )
    expected_environment <- list(
        assessment_digest = assessment$digest,
        runtime_identity = environment$runtime_identity,
        claim_status = assessment$claim_status
    )
    artifact_digest <- .k1_acceptance_artifact_digest(manifest)
    valid_derivatives <-
        same_lines(temporary[[1L]], file.path(artifact, "replicates.csv")) &&
        same_lines(temporary[[2L]], file.path(artifact, "cell-summary.csv")) &&
        same_lines(
            temporary[[3L]], file.path(artifact, "operating-map-data.csv")
        ) &&
        identical(caption, scientific_caption(plot)) &&
        identical(environment, expected_environment) &&
        identical(basename(artifact), paste0(
            assessment$version, "-", substr(artifact_digest, 1L, 16L)
        ))
    if (!valid_derivatives) {
        .k1_acceptance_runner_abort(messages$derivatives)
    }
    invisible(TRUE)
}

.k1_calibration_publish_artifact <- function(
    artifact_root, assessment, validator, plotter, map_attribute,
    normalize_display = .k1_calibration_normalize_display,
    width, height, staging_prefix,
    governed = .k1_calibration_artifact_files(), messages
) {
    validator(assessment)
    if (!.is_scalar_nonempty_text(artifact_root)) {
        .stop_landscapeR_validation("artifact_root must be one non-empty path")
    }
    artifact_root <- path.expand(artifact_root)
    dir.create(artifact_root, recursive = TRUE, showWarnings = FALSE)
    staging <- tempfile(staging_prefix, tmpdir = artifact_root)
    dir.create(staging, recursive = TRUE, showWarnings = FALSE)
    on.exit(if (dir.exists(staging)) unlink(staging, recursive = TRUE), add = TRUE)

    plot <- plotter(assessment)
    saveRDS(assessment, file.path(staging, "assessment.rds"))
    utils::write.csv(
        assessment$replicates, file.path(staging, "replicates.csv"),
        row.names = FALSE
    )
    utils::write.csv(
        assessment$cells, file.path(staging, "cell-summary.csv"),
        row.names = FALSE
    )
    display <- normalize_display(attr(plot, map_attribute))
    utils::write.csv(
        display, file.path(staging, "operating-map-data.csv"),
        row.names = FALSE
    )
    ggplot2::ggsave(
        file.path(staging, "operating-map.png"), plot,
        width = width, height = height, units = "mm", dpi = 450, bg = "white"
    )
    writeLines(
        scientific_caption(plot),
        file.path(staging, "operating-map-caption.txt")
    )
    saveRDS(list(
        assessment_digest = assessment$digest,
        runtime_identity = .k1_calibration_runtime_identity(),
        claim_status = assessment$claim_status
    ), file.path(staging, "environment.rds"))

    manifest <- data.frame(
        file = governed,
        sha256 = vapply(
            file.path(staging, governed),
            .k1_acceptance_file_digest, character(1L)
        ),
        stringsAsFactors = FALSE
    )
    artifact_digest <- .k1_acceptance_artifact_digest(manifest)
    artifact <- file.path(artifact_root, paste0(
        assessment$version, "-", substr(artifact_digest, 1L, 16L)
    ))
    verifier <- function(path) .k1_design_calibration_verify_artifact(
        path, validator, plotter, map_attribute, normalize_display,
        governed, messages
    )
    if (dir.exists(artifact)) {
        verifier(artifact)
        return(artifact)
    }
    utils::write.table(
        manifest, file.path(staging, "MANIFEST.tsv"),
        sep = "\t", quote = FALSE, row.names = FALSE
    )
    if (!.k1_calibration_atomic_move(staging, artifact)) {
        .k1_acceptance_runner_abort(messages$atomic)
    }
    verifier(artifact)
    artifact
}
