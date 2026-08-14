# Design-aware K=1 calibration adapters for shared artifact publication.
# Scientific validators, plots, captions, displayed data, and the retained
# failure-injection seam remain here; filesystem publication is owned by the
# shared artifact module.

.k1_calibration_artifact_files <- function() c(
    "assessment.rds", "replicates.csv", "cell-summary.csv",
    "operating-map-data.csv", "operating-map.png",
    "operating-map-caption.txt", "environment.rds"
)

# Compatibility seam retained for existing failure-injection tests. Publication
# semantics and the default move remain owned by the shared artifact module.
.k1_calibration_atomic_move <- function(from, to) {
    .artifact_atomic_move(from, to)
}

.k1_calibration_read_or_abort <- function(expression, message) {
    suppressWarnings(tryCatch(
        force(expression),
        error = function(condition) .k1_acceptance_runner_abort(message)
    ))
}

.k1_design_calibration_artifact_manifest <- function(
    artifact, governed, messages
) {
    .artifact_verify_payload(
        artifact = artifact,
        governed = governed,
        abort = .k1_acceptance_runner_abort,
        messages = list(
            incomplete = messages$incomplete,
            missing_manifest = messages$incomplete,
            missing_payload = messages$invalid,
            invalid = messages$invalid,
            undeclared = messages$invalid,
            digest = messages$invalid
        )
    )
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
    environment_fields <- c(
        "assessment_digest", "runtime_identity", "claim_status"
    )
    if (!is.list(environment) ||
            !identical(names(environment), environment_fields)) {
        .k1_acceptance_runner_abort(messages$invalid)
    }
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
    plot <- plotter(assessment)
    display <- normalize_display(attr(plot, map_attribute))
    write_payload <- function(staging) {
        saveRDS(assessment, file.path(staging, "assessment.rds"))
        utils::write.csv(
            assessment$replicates, file.path(staging, "replicates.csv"),
            row.names = FALSE
        )
        utils::write.csv(
            assessment$cells, file.path(staging, "cell-summary.csv"),
            row.names = FALSE
        )
        utils::write.csv(
            display, file.path(staging, "operating-map-data.csv"),
            row.names = FALSE
        )
        ggplot2::ggsave(
            file.path(staging, "operating-map.png"), plot,
            width = width, height = height, units = "mm", dpi = 450,
            bg = "white"
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
    }
    verifier <- function(path) .k1_design_calibration_verify_artifact(
        path, validator, plotter, map_attribute, normalize_display,
        governed, messages
    )
    .artifact_publish(
        artifact_root = artifact_root,
        address_prefix = assessment$version,
        governed = governed,
        write_payload = write_payload,
        semantic_verifier = verifier,
        abort = .k1_acceptance_runner_abort,
        messages = list(
            incomplete = messages$incomplete,
            missing_manifest = messages$incomplete,
            missing_payload = messages$invalid,
            invalid = messages$invalid,
            undeclared = messages$invalid,
            digest = messages$invalid,
            atomic = messages$atomic
        ),
        staging_prefix = staging_prefix,
        atomic_move = .k1_calibration_atomic_move,
        preserve_condition = function(condition) {
            inherits(condition, "k1_acceptance_runner_error")
        }
    )
}
