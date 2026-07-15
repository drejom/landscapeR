# Pure metadata-mapping helpers shared by the GSE133642 data-raw workflow and
# its package tests. These functions are reproducibility seams, not exported
# landscapeR runtime APIs.

.gse133642_mapping_columns <- c(
    "expression_name", "library_id", "source_cohort",
    "prepared_layer", "mouse_id", "sample_weeks"
)

validate_gse133642_sample_weeks <- function(mapping) {
    if (!is.data.frame(mapping) ||
        !identical(names(mapping), .gse133642_mapping_columns)) {
        stop("GSE133642 sample-weeks mapping has an unexpected schema")
    }
    if (!is.numeric(mapping$sample_weeks) ||
        anyNA(mapping) ||
        any(!is.finite(mapping$sample_weeks))) {
        stop("GSE133642 sample-weeks mapping must be numeric, complete, and finite")
    }
    if (anyDuplicated(mapping$expression_name) > 0L ||
        anyDuplicated(mapping$library_id) > 0L) {
        stop("GSE133642 sample-weeks mapping contains duplicate observation keys")
    }
    mapping$mouse_id <- as.character(mapping$mouse_id)
    mapping
}

read_gse133642_sample_weeks <- function(path) {
    mapping <- utils::read.csv(
        path,
        stringsAsFactors = FALSE,
        check.names = FALSE
    )
    validate_gse133642_sample_weeks(mapping)
}

extract_gse133642_library_id <- function(sample_names) {
    terminal_id <- sub("^.*_", "", sample_names)
    if (any(!grepl("^[0-9]+$", terminal_id))) {
        stop("GSE133642 expression names must end in the numeric library identifier")
    }
    paste0("COHP_", terminal_id)
}

attach_gse133642_sample_weeks <- function(meta, prepared_layer, source_cohort,
                                          mapping) {
    mapping <- validate_gse133642_sample_weeks(mapping)
    sample_names <- rownames(meta)
    expected <- mapping[
        mapping$prepared_layer == prepared_layer &
            mapping$source_cohort == source_cohort,
        ,
        drop = FALSE
    ]
    if (!length(sample_names) || anyDuplicated(sample_names) > 0L) {
        stop(sprintf(
            "%s must contain unique expression sample names",
            prepared_layer
        ))
    }
    idx <- match(sample_names, expected$expression_name)
    if (anyNA(idx) || nrow(expected) != length(sample_names)) {
        stop(sprintf(
            "%s does not map one-to-one to authoritative sample_weeks",
            prepared_layer
        ))
    }
    if (!identical(
        extract_gse133642_library_id(sample_names),
        expected$library_id[idx]
    )) {
        stop(sprintf(
            "%s library_id mapping does not match expression names",
            prepared_layer
        ))
    }
    if (!"mouse_id" %in% names(meta) ||
        !identical(as.character(meta$mouse_id), expected$mouse_id[idx])) {
        stop(sprintf(
            "%s mouse identifiers disagree with source metadata",
            prepared_layer
        ))
    }
    meta$sample_weeks <- expected$sample_weeks[idx]
    meta
}
