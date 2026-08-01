#' landscapeR: Comparative Decomposition and State-Transition Dynamics
#'
#' @import MultiAssayExperiment
#' @import methods
#' @importFrom S4Vectors DataFrame metadata
#' @importFrom digest digest
#' @importFrom future plan
#' @importFrom utils packageVersion modifyList
#' @importFrom stats approx rnorm var cor ave
#' @importFrom rlang .data
"_PACKAGE"

.landscapeR_scratch_root <- function(start = getwd()) {
    configured <- getOption("landscapeR.scratch_root")
    if (!is.null(configured)) {
        if (!is.character(configured) || length(configured) != 1L ||
            is.na(configured) || !nzchar(configured))
            .stop_landscapeR_validation(
                "option 'landscapeR.scratch_root' must be one non-empty path",
                call = sys.call(-1L)
            )
        return(configured)
    }

    if (!is.character(start) || length(start) != 1L || is.na(start) ||
        !nzchar(start) || !dir.exists(start))
        .stop_landscapeR_validation(
            "scratch-root search start must be one existing directory",
            call = sys.call(-1L)
        )
    current <- normalizePath(start, mustWork = TRUE)
    repeat {
        git_marker <- file.path(current, ".git")
        if (dir.exists(git_marker) || file.exists(git_marker))
            return(file.path(current, ".scratch"))
        parent <- dirname(current)
        if (identical(parent, current)) break
        current <- parent
    }

    .stop_landscapeR_validation(
        "repository root could not be resolved; set option 'landscapeR.scratch_root'",
        call = sys.call(-1L)
    )
}
