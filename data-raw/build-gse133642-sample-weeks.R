#!/usr/bin/env Rscript

# Rebuild the packaged GSE133642 source-time mapping from the immutable public
# haemdata snapshot and the local GEO expression headers. Run from repo root.

SOURCE_URL <- paste0(
  "https://raw.githubusercontent.com/cohmathonc/haemdata/",
  "38176c1192989bbd5ec0f278d05aaaba06833567/",
  "data-raw/metadata_mmu.rds"
)
SOURCE_SHA256 <- "73977189d4979279b3fb7127dd28d29e7c2d7fe447844f05090c2aee78773f5f"
OUTPUT <- "inst/extdata/gse133642-sample-weeks.csv"
GEO <- "data-raw/geo"

source("inst/scripts/gse133642-metadata.R", local = TRUE)

load_source_metadata <- function() {
  source_path <- Sys.getenv("HAEMDATA_METADATA_RDS", unset = "")
  if (!nzchar(source_path)) {
    source_path <- tempfile(fileext = ".rds")
    on.exit(unlink(source_path), add = TRUE)
    utils::download.file(SOURCE_URL, source_path, mode = "wb", quiet = TRUE)
  }
  observed_sha256 <- digest::digest(
    source_path,
    algo = "sha256",
    file = TRUE
  )
  if (!identical(observed_sha256, SOURCE_SHA256)) {
    stop(sprintf(
      "haemdata metadata checksum mismatch: expected %s, observed %s",
      SOURCE_SHA256,
      observed_sha256
    ))
  }
  readRDS(source_path)
}
source_metadata <- load_source_metadata()

read_expression_names <- function(path) {
  con <- gzfile(path, open = "rt")
  on.exit(close(con))
  names(utils::read.delim(
    con,
    nrows = 1L,
    check.names = FALSE
  ))[-1L]
}

make_mapping <- function(sample_names, source_cohort, prepared_layer) {
  library_id <- extract_gse133642_library_id(sample_names)
  source_rows <- source_metadata[
    source_metadata$cohort == source_cohort &
      source_metadata$assay == "mRNA",
    c("library_id", "cohort", "mouse_id", "sample_weeks")
  ]
  if (anyDuplicated(source_rows$library_id) > 0L) {
    stop(sprintf("source cohort %s has duplicate library_id values", source_cohort))
  }
  idx <- match(library_id, source_rows$library_id)
  if (anyNA(idx)) {
    stop(sprintf("source cohort %s is missing expression libraries", source_cohort))
  }
  parsed_mouse <- vapply(
    strsplit(sample_names, "_", fixed = TRUE),
    `[`,
    character(1L),
    2L
  )
  if (!identical(parsed_mouse, as.character(source_rows$mouse_id[idx]))) {
    stop(sprintf("source cohort %s has inconsistent mouse identifiers", source_cohort))
  }
  data.frame(
    expression_name = sample_names,
    library_id = library_id,
    source_cohort = source_rows$cohort[idx],
    prepared_layer = prepared_layer,
    mouse_id = as.character(source_rows$mouse_id[idx]),
    sample_weeks = as.numeric(source_rows$sample_weeks[idx]),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

training_2018_names <- read_expression_names(file.path(
  GEO,
  "GSE133642_merged_gene_counts_log2cpm_0.5CPMin2samples.txt.gz"
))
validation_2016_names <- read_expression_names(file.path(
  GEO,
  "GSE133642_validation_merged_gene_counts__log2cpm_5CPMin2samples.tsv.gz"
))
validation_2016_names <- validation_2016_names[
  !grepl("^WK[0-9]", validation_2016_names)
]

mapping <- rbind(
  make_mapping(
    training_2018_names,
    "AML.mRNA.2018.all_samples",
    "mrna_primary_2018"
  ),
  make_mapping(
    validation_2016_names,
    "AML.mRNA.2016",
    "mrna_supp_2016"
  )
)
mapping <- validate_gse133642_sample_weeks(mapping)
layer_order <- match(
  mapping$prepared_layer,
  c("mrna_primary_2018", "mrna_supp_2016")
)
mapping <- mapping[
  order(layer_order, mapping$mouse_id, mapping$sample_weeks),
  ,
  drop = FALSE
]
rownames(mapping) <- NULL
if (nrow(mapping) != 233L ||
    sum(mapping$prepared_layer == "mrna_primary_2018") != 132L ||
    sum(mapping$prepared_layer == "mrna_supp_2016") != 101L) {
  stop("GSE133642 retained-observation counts do not match the preparation contract")
}

utils::write.csv(mapping, OUTPUT, row.names = FALSE, quote = TRUE)
cat(sprintf("Wrote %d authoritative mappings to %s\n", nrow(mapping), OUTPUT))
