#!/usr/bin/env Rscript

source_revision <- "e8e0c5284156bcf2d5f7f8612d096738db7a1daa"
scratch_root <- file.path(".scratch", "issue-210-reference-source")
source_dir <- file.path(scratch_root, "source")
archive <- file.path(scratch_root, "source.tar")
output_dir <- file.path("tests", "testthat", "fixtures")
projector_path <- file.path(
    "tests", "testthat",
    "helper-association-execution-fingerprint.R"
)

dir.create(scratch_root, recursive = TRUE, showWarnings = FALSE)
if (dir.exists(source_dir)) unlink(source_dir, recursive = TRUE)
dir.create(source_dir, recursive = TRUE, showWarnings = FALSE)
archive_status <- system2(
    "git",
    c(
        "archive",
        "--format=tar",
        sprintf("--output=%s", normalizePath(archive, mustWork = FALSE)),
        source_revision
    )
)
if (!identical(archive_status, 0L)) {
    stop("Could not archive the pinned issue 210 source revision", call. = FALSE)
}
utils::untar(archive, exdir = source_dir)

devtools::load_all(source_dir, quiet = TRUE)
sys.source(
    file.path(source_dir, "tests", "testthat", "helper-independent-time-course.R"),
    envir = environment()
)
sys.source(projector_path, envir = environment())

build_atlas <- function(partial = FALSE) {
    fixture <- independent_time_course_fixture()
    if (partial) colData(fixture)$batch[[2L]] <- NA
    associate_metadata(
        fixture,
        specification = independent_time_course_specification("batch"),
        non_analytical_fields = "sample_id",
        dataset_id = if (partial) {
            "kernel-independent-partial"
        } else {
            "kernel-independent"
        },
        n_resamples = 3L,
        seed = 17L,
        sequential_internal = TRUE
    )
}

encode_payload <- function(payload) {
    bytes <- memCompress(
        serialize(payload, NULL, version = 3L),
        type = "gzip"
    )
    paste(sprintf("%02x", as.integer(bytes)), collapse = "")
}

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
cases <- c("success", "partial")
atlases <- list(build_atlas(FALSE), build_atlas(TRUE))
payloads <- lapply(atlases, .assoc_exec_payload)
fixture_paths <- file.path(
    output_dir,
    sprintf("association-execution-%s.hex", cases)
)
invisible(Map(writeLines, lapply(payloads, encode_payload), fixture_paths))

script_argument <- grep("^--file=", commandArgs(), value = TRUE)
script_path <- sub("^--file=", "", script_argument[[1L]])
manifest <- data.frame(
    case = cases,
    source_revision = source_revision,
    generator_sha256 = digest::digest(
        file = script_path,
        algo = "sha256",
        serialize = FALSE
    ),
    projector_sha256 = digest::digest(
        file = projector_path,
        algo = "sha256",
        serialize = FALSE
    ),
    fixture_sha256 = vapply(
        fixture_paths,
        digest::digest,
        character(1),
        algo = "sha256",
        serialize = FALSE,
        file = TRUE
    ),
    dataset_id = vapply(payloads, `[[`, character(1), "dataset_id"),
    association_rows = vapply(
        payloads,
        function(payload) nrow(payload$associations),
        integer(1)
    ),
    observation_rows = vapply(
        payloads,
        function(payload) nrow(payload$observations),
        integer(1)
    ),
    exclusion_rows = vapply(
        payloads,
        function(payload) nrow(payload$exclusions),
        integer(1)
    ),
    r_version = R.version.string,
    lme4_version = as.character(utils::packageVersion("lme4")),
    stringsAsFactors = FALSE
)
utils::write.table(
    manifest,
    file.path(output_dir, "association-execution-manifest.tsv"),
    sep = "\t",
    quote = FALSE,
    row.names = FALSE
)
message("Regenerated issue 210 reference fixtures from ", source_revision)
