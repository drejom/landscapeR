.assoc_exec_normalize <- function(value) {
    if (is.data.frame(value)) {
        value[] <- lapply(value, .assoc_exec_normalize)
        rownames(value) <- NULL
        return(value)
    }
    if (is.factor(value)) return(as.character(value))
    if (is.list(value)) {
        return(lapply(value, .assoc_exec_normalize))
    }
    value
}

.assoc_exec_payload <- function(atlas) {
    provenance <- atlas_provenance(atlas)
    provenance$model_engine_version <- NULL
    if (is.list(provenance$evidence_contract)) {
        provenance$evidence_contract$digests <- NULL
    }
    provenance$time_course_models <- lapply(
        provenance$time_course_models,
        function(model) {
            for (variant in c(
                "unadjusted_uncertainty",
                "adjusted_uncertainty"
            )) {
                if (
                    is.list(model[[variant]]) &&
                        is.list(model[[variant]]$execution)
                ) {
                    model[[variant]]$execution$digest <- NULL
                }
            }
            model
        }
    )
    .assoc_exec_normalize(list(
        version = atlas@version,
        dataset_id = atlas@dataset_id,
        associations = atlas_associations(atlas),
        observations = atlas_observations(atlas),
        exclusions = atlas_exclusions(atlas),
        cohort_members = atlas_evidence_contract(atlas)$cohort_members,
        sampling_design = atlas@sampling_design@kind,
        input_digest = atlas@input_digest,
        state_space_digest = atlas@state_space_digest,
        compute_tier = atlas@compute_tier,
        evidence_status = atlas@evidence_status,
        provenance = provenance
    ))
}

.assoc_exec_payload_equal <- function(
    observed,
    expected,
    tolerance = 1e-6
) {
    compare <- function(left, right) {
        if (!identical(typeof(left), typeof(right))) return(FALSE)
        if (!identical(attributes(left), attributes(right))) return(FALSE)
        if (is.double(left)) {
            if (!identical(length(left), length(right))) return(FALSE)
            left_state <- ifelse(
                is.nan(left), "NaN",
                ifelse(
                    is.na(left), "NA",
                    ifelse(
                        left == Inf, "Inf",
                        ifelse(left == -Inf, "-Inf", "finite")
                    )
                )
            )
            right_state <- ifelse(
                is.nan(right), "NaN",
                ifelse(
                    is.na(right), "NA",
                    ifelse(
                        right == Inf, "Inf",
                        ifelse(right == -Inf, "-Inf", "finite")
                    )
                )
            )
            if (!identical(left_state, right_state)) return(FALSE)
            finite <- left_state == "finite"
            return(all(abs(left[finite] - right[finite]) <= tolerance))
        }
        if (is.list(left)) {
            if (!identical(length(left), length(right))) return(FALSE)
            return(all(vapply(
                seq_along(left),
                function(index) compare(left[[index]], right[[index]]),
                logical(1)
            )))
        }
        identical(left, right)
    }
    compare(observed, expected)
}

.assoc_exec_reference_revision <-
    "e8e0c5284156bcf2d5f7f8612d096738db7a1daa"

.assoc_exec_repo_path <- function(...) {
    path <- file.path(...)
    if (file.exists(path)) return(path)
    testthat::test_path("..", "..", ...)
}

.assoc_exec_fixture <- function(case, fixture_dir = NULL) {
    expected_schema <- c(
        "case", "source_revision", "generator_sha256",
        "projector_sha256", "fixture_sha256", "dataset_id",
        "association_rows", "observation_rows", "exclusion_rows",
        "r_version", "lme4_version"
    )
    if (is.null(fixture_dir)) {
        fixture_dir <- .assoc_exec_repo_path(
            "tests", "testthat", "fixtures"
        )
    }
    manifest <- utils::read.delim(
        file.path(fixture_dir, "association-execution-manifest.tsv"),
        stringsAsFactors = FALSE,
        check.names = FALSE
    )
    if (!identical(names(manifest), expected_schema)) {
        stop("Issue 210 fixture manifest schema is invalid", call. = FALSE)
    }
    if (!identical(manifest$case, c("success", "partial"))) {
        stop("Issue 210 fixture manifest cases are invalid", call. = FALSE)
    }
    if (!all(manifest$source_revision == .assoc_exec_reference_revision)) {
        stop("Issue 210 fixture source revision is stale", call. = FALSE)
    }
    generator_path <- .assoc_exec_repo_path(
        "tests", "testthat", "fixtures",
        "generate-association-execution-reference.R"
    )
    projector_path <- .assoc_exec_repo_path(
        "tests", "testthat",
        "helper-association-execution-fingerprint.R"
    )
    generator_digest <- digest::digest(
        file = generator_path,
        algo = "sha256",
        serialize = FALSE
    )
    projector_digest <- digest::digest(
        file = projector_path,
        algo = "sha256",
        serialize = FALSE
    )
    if (!all(manifest$generator_sha256 == generator_digest)) {
        stop("Issue 210 fixture generator digest is stale", call. = FALSE)
    }
    if (!all(manifest$projector_sha256 == projector_digest)) {
        stop("Issue 210 fixture projector digest is stale", call. = FALSE)
    }
    row <- manifest[match(case, manifest$case), , drop = FALSE]
    if (nrow(row) != 1L || is.na(row$case[[1L]])) {
        stop("Unknown issue 210 fixture case", call. = FALSE)
    }
    path <- file.path(
        fixture_dir,
        sprintf("association-execution-%s.hex", case)
    )
    fixture_digest <- digest::digest(
        file = path,
        algo = "sha256",
        serialize = FALSE
    )
    if (!identical(fixture_digest, row$fixture_sha256[[1L]])) {
        stop("Issue 210 fixture payload digest is invalid", call. = FALSE)
    }
    hex <- paste(readLines(path, warn = FALSE), collapse = "")
    starts <- seq.int(1L, nchar(hex), by = 2L)
    bytes <- as.raw(strtoi(
        substring(hex, starts, starts + 1L),
        base = 16L
    ))
    payload <- unserialize(memDecompress(bytes, type = "gzip"))
    observed_counts <- c(
        nrow(payload$associations),
        nrow(payload$observations),
        nrow(payload$exclusions)
    )
    expected_counts <- unname(as.integer(row[
        c("association_rows", "observation_rows", "exclusion_rows")
    ]))
    if (
        !identical(payload$dataset_id, row$dataset_id[[1L]]) ||
            !identical(observed_counts, expected_counts)
    ) {
        stop("Issue 210 fixture structural identity is invalid", call. = FALSE)
    }
    payload
}

.assoc_exec_matches_fixture <- function(atlas, case, tolerance = 1e-6) {
    .assoc_exec_payload_equal(
        .assoc_exec_payload(atlas),
        .assoc_exec_fixture(case),
        tolerance = tolerance
    )
}
