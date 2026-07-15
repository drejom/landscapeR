#!/usr/bin/env Rscript

# Audit generated GSE133642 StateTransitionData objects against the packaged
# authoritative mapping. Run after data-raw/load-aml-cml.R from repo root.

suppressPackageStartupMessages({
  devtools::load_all(".", quiet = TRUE)
  library(MultiAssayExperiment)
  library(SummarizedExperiment)
})
source("inst/scripts/gse133642-metadata.R", local = TRUE)

mapping <- read_gse133642_sample_weeks(
  "inst/extdata/gse133642-sample-weeks.csv"
)
aml <- readRDS("data-raw/aml_mrna_std.rds")
expected_counts <- c(mrna_primary_2018 = 132L, mrna_supp_2016 = 101L)

if (!identical(names(experiments(aml)), names(expected_counts))) {
  stop("prepared AML layer names or order do not match the contract")
}
for (layer in names(expected_counts)) {
  se <- experiments(aml)[[layer]]
  cd <- as.data.frame(colData(se))
  expected <- mapping[mapping$prepared_layer == layer, , drop = FALSE]
  idx <- match(colnames(se), expected$expression_name)
  if (ncol(se) != expected_counts[[layer]] ||
      anyNA(idx) ||
      nrow(expected) != ncol(se) ||
      !identical(as.numeric(cd$sample_weeks), expected$sample_weeks[idx]) ||
      !identical(as.character(cd$mouse_id), expected$mouse_id[idx])) {
    stop(sprintf("prepared layer %s disagrees with its source mapping", layer))
  }
  cat(sprintf(
    "%s: %d genes x %d observations; %d mice; weeks %s; 0 missing\n",
    layer,
    nrow(se),
    ncol(se),
    length(unique(cd$mouse_id)),
    paste(range(cd$sample_weeks), collapse = "..")
  ))
}

cd <- as.data.frame(colData(aml))
design <- aml@sampling_design
strict_order <- tapply(cd$sample_weeks, cd$mouse_id, function(weeks) {
  !anyDuplicated(weeks) && all(diff(sort(weeks)) > 0)
})
provenance <- metadata(aml)$data_source$sample_weeks
if (nrow(cd) != 233L ||
    length(unique(cd$mouse_id)) != 30L ||
    anyNA(cd$sample_weeks) ||
    any(grepl("endpoint|event", names(cd))) ||
    !all(strict_order) ||
    !identical(design@kind, "longitudinal") ||
    !identical(design@subject_id_col, "mouse_id") ||
    !identical(design@time_col, "sample_weeks") ||
    !identical(design@time_unit, "weeks") ||
    !identical(provenance$source_file, "data-raw/metadata_mmu.rds") ||
    !identical(provenance$source_column, "sample_weeks") ||
    !identical(provenance$units, "weeks") ||
    !grepl("library_id", provenance$join_key, fixed = TRUE) ||
    !nzchar(provenance$procedure) ||
    !identical(
      provenance$source_revision,
      "38176c1192989bbd5ec0f278d05aaaba06833567"
    ) ||
    !identical(
      provenance$source_sha256,
      "73977189d4979279b3fb7127dd28d29e7c2d7fe447844f05090c2aee78773f5f"
    )) {
  stop("combined AML object fails its longitudinal preparation contract")
}

multimodal <- readRDS("data-raw/aml_multimodal_std.rds")
multimodal_counts <- vapply(experiments(multimodal), ncol, integer(1L))
if (!identical(multimodal_counts, c(mrna = 129L, mirna = 129L)) ||
    nrow(colData(multimodal)) != 129L ||
    !identical(multimodal@sampling_design@time_col, "sample_weeks")) {
  stop("corrected 2018 multi-modal pairing fails its preparation contract")
}

cat(sprintf(
  "Combined: %d observations; %d mice; strict within-mouse ordering: TRUE\n",
  nrow(cd),
  length(unique(cd$mouse_id))
))
cat("SamplingDesign: longitudinal(mouse_id, sample_weeks, weeks)\n")
cat("No endpoint/event field or inference present.\n")
cat("Multi-modal 2018 pairing: 129 mRNA / 129 miRNA observations.\n")
