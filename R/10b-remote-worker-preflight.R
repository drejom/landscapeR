# Remote future-worker validation and payload benchmarking (issue #134)

.worker_preflight_error <- function(message, diagnostics = data.frame()) {
    stop(structure(
        list(message = message, call = sys.call(-1L), diagnostics = diagnostics),
        class = c("landscapeR_worker_preflight_error",
                  "landscapeR_validation_error", "error", "condition")
    ))
}

.future_benchmark_error <- function(message, stage, condition = NULL) {
    diagnostics <- data.frame(
        stage = stage,
        cause_class = if (is.null(condition)) NA_character_ else class(condition)[[1L]],
        cause_message = if (is.null(condition)) NA_character_ else conditionMessage(condition),
        stringsAsFactors = FALSE
    )
    stop(structure(
        list(message = message, call = sys.call(-1L), diagnostics = diagnostics),
        class = c("landscapeR_future_benchmark_error",
                  "landscapeR_validation_error", "error", "condition")
    ))
}

#' Report the identity of the loaded landscapeR artifact
#'
#' Uses revision metadata embedded by an installer when available. Otherwise it
#' computes a SHA-256 identity from the installed package files. It never trusts
#' an environment variable supplied by the calling job.
#'
#' @return One non-empty revision identity.
#' @export
landscapeR_revision <- function() {
    description <- tryCatch(
        utils::packageDescription("landscapeR"),
        error = function(condition) NULL
    )
    if (!is.null(description)) {
        candidates <- unlist(description[c(
            "Config/landscapeR/Revision", "RemoteSha", "GithubSHA1"
        )])
        candidates <- candidates[!is.na(candidates) & nzchar(candidates)]
        if (length(candidates)) return(unname(candidates[[1L]]))
    }
    namespace <- asNamespace("landscapeR")
    symbols <- ls(namespace, all.names = TRUE)
    definitions <- lapply(symbols, function(symbol) {
        value <- get0(symbol, envir = namespace, inherits = FALSE)
        if (!is.function(value)) return(NULL)
        list(formals = formals(value), body = body(value))
    })
    names(definitions) <- symbols
    definitions <- definitions[!vapply(definitions, is.null, logical(1L))]
    manifest <- list(
        package_version = as.character(utils::packageVersion("landscapeR")),
        functions = definitions
    )
    paste0("sha256:", digest::digest(
        manifest, algo = "sha256", serialize = TRUE
    ))
}

.validate_preflight_packages <- function(packages) {
    if (!is.character(packages) || !length(packages) || anyNA(packages) ||
        any(!nzchar(packages)) || anyDuplicated(packages)) {
        .stop_landscapeR_validation(
            "packages must contain unique non-empty package names"
        )
    }
    missing <- packages[!vapply(
        packages, requireNamespace, logical(1L), quietly = TRUE
    )]
    if (length(missing)) {
        .stop_landscapeR_validation(paste0(
            "controller is missing required package(s): ",
            paste(missing, collapse = ", ")
        ))
    }
    packages
}

#' Preflight the workers selected by the current future plan
#'
#' Executes environment probes through the user's active future plan before a
#' scientific workload starts. The package does not select or modify that plan.
#'
#' @param expected_revision Non-empty installed-artifact revision expected on
#'   every worker. Obtain it from the intended controller installation with
#'   [landscapeR_revision()] or use revision metadata embedded at installation.
#' @param packages Unique package names whose versions must match the controller.
#' @param workers Positive number of distinct workers expected. `NULL` uses
#'   `future::nbrOfWorkers()` when that value is finite.
#' @return A typed list containing the expected environment, one diagnostic row
#'   per worker probe, and a content digest. Inconsistent or incomplete worker
#'   environments raise `landscapeR_worker_preflight_error` with the diagnostic
#'   table attached as `condition$diagnostics`.
#' @export
preflight_future_workers <- function(
    expected_revision,
    packages = c("landscapeR", "future", "future.apply", "digest"),
    workers = NULL
) {
    if (!.is_scalar_nonempty_text(expected_revision)) {
        .stop_landscapeR_validation(
            "expected_revision must be one non-empty source revision"
        )
    }
    packages <- .validate_preflight_packages(packages)
    if (is.null(workers)) workers <- future::nbrOfWorkers()
    if (!is.numeric(workers) || length(workers) != 1L || is.na(workers) ||
        !is.finite(workers) || workers < 1 || workers != as.integer(workers)) {
        .stop_landscapeR_validation(
            "workers must be one positive finite integer; declare it explicitly for unbounded backends"
        )
    }
    workers <- as.integer(workers)
    expected_versions <- vapply(
        packages,
        function(package) as.character(utils::packageVersion(package)),
        character(1L)
    )
    expected_r <- paste(R.version$major, R.version$minor, sep = ".")
    expected <- list(
        revision = expected_revision,
        r_version = expected_r,
        package_versions = expected_versions
    )

    probe <- function(probe_id, expected, packages) {
        Sys.sleep(0.1)
        revision <- tryCatch(
            landscapeR_revision(),
            landscapeR_worker_preflight_error = function(condition) ""
        )
        installed <- vapply(
            packages,
            function(package) requireNamespace(package, quietly = TRUE),
            logical(1L)
        )
        versions <- setNames(rep(NA_character_, length(packages)), packages)
        versions[installed] <- vapply(
            packages[installed],
            function(package) as.character(utils::packageVersion(package)),
            character(1L)
        )
        worker_r <- paste(R.version$major, R.version$minor, sep = ".")
        missing_packages <- names(installed)[!installed]
        version_mismatches <- names(versions)[
            installed & versions != expected$package_versions
        ]
        mismatches <- c(
            if (!nzchar(revision)) "revision-unavailable" else character(),
            if (nzchar(revision) && !identical(revision, expected$revision))
                "revision-mismatch" else character(),
            if (!identical(worker_r, expected$r_version))
                "r-version-mismatch" else character(),
            if (length(missing_packages))
                paste0("missing-package:", missing_packages) else character(),
            if (length(version_mismatches))
                paste0("package-version-mismatch:", version_mismatches)
            else character()
        )
        list(
            probe_id = as.integer(probe_id),
            worker_id = paste(Sys.info()[["nodename"]], Sys.getpid(), sep = ":"),
            hostname = unname(Sys.info()[["nodename"]]),
            pid = as.integer(Sys.getpid()),
            revision = revision,
            r_version = worker_r,
            package_versions = versions,
            ok = !length(mismatches),
            diagnostic = paste(mismatches, collapse = ";")
        )
    }

    probes <- tryCatch(
        future.apply::future_lapply(
            seq_len(workers), probe, expected = expected, packages = packages,
            future.seed = FALSE, future.scheduling = Inf
        ),
        error = function(condition) {
            diagnostic <- data.frame(
                probe_id = NA_integer_, worker_id = NA_character_,
                hostname = NA_character_, pid = NA_integer_,
                revision = NA_character_, r_version = NA_character_,
                ok = FALSE,
                diagnostic = paste0(
                    "worker-launch-failure:", conditionMessage(condition)
                ),
                stringsAsFactors = FALSE
            )
            .worker_preflight_error(
                "future worker preflight could not launch every probe",
                diagnostic
            )
        }
    )
    diagnostics <- do.call(rbind, lapply(probes, function(result) {
        data.frame(
            probe_id = result$probe_id, worker_id = result$worker_id,
            hostname = result$hostname, pid = result$pid,
            revision = result$revision, r_version = result$r_version,
            package_versions = paste(
                paste(names(result$package_versions), result$package_versions,
                      sep = "="),
                collapse = ";"
            ),
            ok = result$ok, diagnostic = result$diagnostic,
            stringsAsFactors = FALSE
        )
    }))
    if (length(unique(diagnostics$worker_id)) != workers) {
        diagnostics$ok <- FALSE
        diagnostics$diagnostic <- ifelse(
            nzchar(diagnostics$diagnostic),
            paste(diagnostics$diagnostic, "worker-coverage-incomplete", sep = ";"),
            "worker-coverage-incomplete"
        )
    }
    if (!all(diagnostics$ok)) {
        .worker_preflight_error(
            "future worker preflight found an incomplete or inconsistent environment",
            diagnostics
        )
    }
    payload <- list(expected = expected, workers = diagnostics)
    structure(
        c(payload, list(digest = digest::digest(
            payload, algo = "sha256", serialize = TRUE
        ))),
        class = c("landscapeR_worker_preflight", "list")
    )
}

#' Benchmark assay transfer and chunk collection through the current future plan
#'
#' @param assay Numeric feature-by-observation matrix.
#' @param chunk_sizes Positive observation counts per submitted chunk.
#' @param repetitions Positive number of timing repetitions.
#' @return A data frame with serialization, global-export/collection, chunked
#'   dispatch/collection, result-size measurements, and execution provenance.
#'   Times are medians in seconds and are operational observations, not
#'   performance guarantees. Operational failures raise
#'   `landscapeR_future_benchmark_error` with stage diagnostics attached.
#' @export
benchmark_future_assay <- function(
    assay,
    chunk_sizes = unique(c(1L, min(8L, ncol(assay)), ncol(assay))),
    repetitions = 3L
) {
    if (!is.matrix(assay) || !is.numeric(assay) || !length(assay) ||
        any(!is.finite(assay))) {
        .stop_landscapeR_validation(
            "assay must be one non-empty finite numeric matrix"
        )
    }
    if (!is.numeric(chunk_sizes) || !length(chunk_sizes) ||
        anyNA(chunk_sizes) || any(!is.finite(chunk_sizes)) ||
        any(chunk_sizes < 1) || any(chunk_sizes != as.integer(chunk_sizes))) {
        .stop_landscapeR_validation(
            "chunk_sizes must contain positive finite integers"
        )
    }
    chunk_sizes <- unique(pmin(as.integer(chunk_sizes), ncol(assay)))
    if (!is.numeric(repetitions) || length(repetitions) != 1L ||
        is.na(repetitions) || !is.finite(repetitions) || repetitions < 1 ||
        repetitions != as.integer(repetitions)) {
        .stop_landscapeR_validation("repetitions must be one positive integer")
    }
    repetitions <- as.integer(repetitions)
    benchmarked_at <- format(
        as.POSIXct(Sys.time(), tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"
    )
    plan <- future::plan("list")
    backend <- if (length(plan)) class(plan[[1L]])[[1L]] else "unknown"
    worker_count <- future::nbrOfWorkers()
    package_versions <- vapply(
        c("landscapeR", "future", "future.apply", "digest"),
        function(package) as.character(utils::packageVersion(package)),
        character(1L)
    )
    source_digest <- digest::digest(assay, algo = "sha256", serialize = TRUE)
    serialized <- serialize(assay, NULL, version = 3L)
    serialization_times <- replicate(repetitions, unname(system.time(
        serialize(assay, NULL, version = 3L)
    )[["elapsed"]]))
    export_times <- tryCatch(
        replicate(repetitions, unname(system.time({
            exported <- future::value(future::future(
                digest::digest(assay, algo = "sha256", serialize = TRUE),
                seed = FALSE
            ))
            if (!identical(exported, source_digest)) {
                .future_benchmark_error(
                    "future global export changed the assay digest",
                    "global-export-digest"
                )
            }
        })[["elapsed"]])),
        landscapeR_future_benchmark_error = function(condition) stop(condition),
        error = function(condition) .future_benchmark_error(
            "future global export or collection failed",
            "global-export-collection", condition
        )
    )

    rows <- lapply(chunk_sizes, function(chunk_size) {
        chunks <- split(
            seq_len(ncol(assay)),
            ceiling(seq_len(ncol(assay)) / chunk_size)
        )
        elapsed <- numeric(repetitions)
        collected <- NULL
        for (i in seq_len(repetitions)) {
            elapsed[[i]] <- tryCatch(
                unname(system.time({
                    pieces <- future.apply::future_lapply(
                        chunks,
                        function(columns, assay) assay[, columns, drop = FALSE],
                        assay = assay, future.seed = FALSE,
                        future.scheduling = Inf
                    )
                    collected <- do.call(cbind, pieces)
                })[["elapsed"]]),
                error = function(condition) .future_benchmark_error(
                    "future chunk dispatch or collection failed",
                    "chunk-dispatch-collection", condition
                )
            )
        }
        collected_digest <- digest::digest(
            collected, algo = "sha256", serialize = TRUE
        )
        data.frame(
            features = nrow(assay), observations = ncol(assay),
            chunk_size = chunk_size, chunks = length(chunks),
            payload_bytes = length(serialized),
            serialization_seconds = stats::median(serialization_times),
            global_export_collect_seconds = stats::median(export_times),
            chunk_dispatch_collect_seconds = stats::median(elapsed),
            collection_bytes = length(serialize(collected, NULL, version = 3L)),
            source_digest = source_digest, collected_digest = collected_digest,
            identical = identical(source_digest, collected_digest),
            repetitions = repetitions, backend = backend,
            workers = worker_count, r_version = R.version.string,
            platform = R.version$platform,
            package_versions = paste(
                paste(names(package_versions), package_versions, sep = "="),
                collapse = ";"
            ),
            benchmarked_at_utc = benchmarked_at,
            stringsAsFactors = FALSE
        )
    })
    structure(
        do.call(rbind, rows),
        class = c("landscapeR_future_assay_benchmark", "data.frame")
    )
}
