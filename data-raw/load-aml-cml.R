# Load GEO datasets into StateTransitionData objects
#
# Produces three .rds files in data-raw/:
#
#   aml_mrna_std.rds   — AML mRNA, GSE133642
#                        Layer 1: mrna_primary_2018 — 132-observation source-paper
#                                 training cohort; clean randomized batches and
#                                 the discovery state-space for landscapeR.
#                        Layer 2: mrna_supp_2016 — 101-observation source-paper
#                                 validation cohort 1; batch/time-confounded and
#                                 retained as a hostile projection stress test.
#                        Restricted to 13,232 shared genes.
#
#   cml_mrna_std.rds   — CML mRNA, GSE244990
#                        Single-layer (298 samples, TPM)
#                        Used for end-to-end Stage 1 + Stage 2 on the paper
#                        that the reference code (CML_mRNA_state-transition) runs on.
#
#   aml_multimodal_std.rds — AML mRNA + miRNA, GSE133642 + GSE173785
#                            source-paper training cohort only
#                            Layer 1: mRNA 2018 (log2 CPM)
#                            Layer 2: miRNA 2018 (CPM)
#                            Restricted to samples present in both assays.
#
# The AML matrices together are a real biological validation dataset for
# landscapeR. "Training" and "validation" below describe their roles in the
# source study, not scientific acceptance of landscapeR.

suppressPackageStartupMessages({
  devtools::load_all(".", quiet = TRUE)
  library(SummarizedExperiment)
  library(S4Vectors)
})

GEO <- "data-raw/geo"
AML_SAMPLE_WEEKS <- "inst/extdata/gse133642-sample-weeks.csv"
source("inst/scripts/gse133642-metadata.R", local = TRUE)

strip_version <- function(ids) sub("\\.[0-9]+$", "", ids)

# Source-paper training cohort (2018):
#   T{tp}_{mouseID}_{?}_{condition}_{genotype}_{sex}_{batch}_{libraryID}
parse_training_2018_meta <- function(nms) {
  parts <- strsplit(nms, "_")
  data.frame(
    row.names = nms,
    cohort     = "primary_2018",
    timepoint  = vapply(parts, `[`, character(1L), 1L),
    mouse_id   = vapply(parts, `[`, character(1L), 2L),
    condition  = vapply(parts, `[`, character(1L), 4L),
    sex        = vapply(parts, `[`, character(1L), 6L),
    group      = vapply(parts, `[`, character(1L), 7L),
    stringsAsFactors = FALSE
  )
}

# Source-paper validation cohort 1 (2016):
#   T{tp}_{mouseID}_{condition}_{genotype}_{sex}_{libraryID}
#   L_{mouseID}_{condition}_{genotype}_{sex}_{libraryID}
parse_validation_2016_meta <- function(nms) {
  parts <- strsplit(nms, "_")
  data.frame(
    row.names = nms,
    cohort     = "supp_2016",
    timepoint  = vapply(parts, `[`, character(1L), 1L),
    mouse_id   = vapply(parts, `[`, character(1L), 2L),
    condition  = vapply(parts, function(x) {
      if (identical(x[3L], "Ctrl")) "CTL" else x[3L]
    }, character(1L)),
    sex        = vapply(parts, `[`, character(1L), 5L),
    group      = NA_character_,
    stringsAsFactors = FALSE
  )
}

# ============================================================================
# 1. AML mRNA (GSE133642)
# ============================================================================
cat("=== AML mRNA (GSE133642) ===\n")

cat("  Reading source-paper training cohort (2018)...\n")
training_2018_raw <- read.table(
  gzfile(file.path(GEO, "GSE133642_merged_gene_counts_log2cpm_0.5CPMin2samples.txt.gz")),
  sep = "\t", header = TRUE, row.names = 1, check.names = FALSE)
rownames(training_2018_raw) <- strip_version(rownames(training_2018_raw))
cat(sprintf("  %d genes x %d samples\n",
            nrow(training_2018_raw), ncol(training_2018_raw)))

cat("  Reading source-paper validation cohort 1 (2016)...\n")
validation_2016_raw <- read.table(
  gzfile(file.path(GEO, "GSE133642_validation_merged_gene_counts__log2cpm_5CPMin2samples.tsv.gz")),
  sep = "\t", header = TRUE, row.names = 1, check.names = FALSE)
rownames(validation_2016_raw) <- strip_version(rownames(validation_2016_raw))
cat(sprintf("  %d genes x %d samples (before WK filter)\n",
            nrow(validation_2016_raw), ncol(validation_2016_raw)))

# Exclude source-paper validation cohort 2: 15 sparse WK10-WK28 samples from
# mice 3127/3130/3131/3200/3202. They have no T0 observation and are outside
# the current complete longitudinal validation-cohort contract.
wk_mask <- grepl("^WK[0-9]", colnames(validation_2016_raw))
if (any(wk_mask)) {
  cat(sprintf("  Dropping %d sparse WK validation-cohort-2 samples\n",
              sum(wk_mask)))
  validation_2016_raw <- validation_2016_raw[, !wk_mask, drop = FALSE]
}
cat(sprintf("  %d genes x %d samples\n",
            nrow(validation_2016_raw), ncol(validation_2016_raw)))

shared_genes <- intersect(
  rownames(training_2018_raw),
  rownames(validation_2016_raw)
)
cat(sprintf("  Shared genes: %d\n", length(shared_genes)))

primary_mat <- as.matrix(training_2018_raw[shared_genes, , drop = FALSE])
supp_mat <- as.matrix(validation_2016_raw[shared_genes, , drop = FALSE])

sample_weeks_mapping <- read_gse133642_sample_weeks(AML_SAMPLE_WEEKS)
primary_meta <- attach_gse133642_sample_weeks(
  parse_training_2018_meta(colnames(primary_mat)),
  prepared_layer = "mrna_primary_2018",
  source_cohort = "AML.mRNA.2018.all_samples",
  mapping = sample_weeks_mapping
)
supp_meta <- attach_gse133642_sample_weeks(
  parse_validation_2016_meta(colnames(supp_mat)),
  prepared_layer = "mrna_supp_2016",
  source_cohort = "AML.mRNA.2016",
  mapping = sample_weeks_mapping
)

se_primary <- SummarizedExperiment(
  assays = list(log2cpm = primary_mat),
  colData = DataFrame(primary_meta)
)
se_supp <- SummarizedExperiment(
  assays = list(log2cpm = supp_mat),
  colData = DataFrame(supp_meta)
)

all_meta <- rbind(primary_meta, supp_meta)
aml_std <- StateTransitionData(
  experiments = list(mrna_primary_2018 = se_primary, mrna_supp_2016 = se_supp),
  colData = DataFrame(all_meta)
)
aml_std <- declare_sampling_design(
  aml_std,
  longitudinal("mouse_id", "sample_weeks", "weeks")
)
md <- metadata(aml_std)
md$data_source <- list(
  accession = "GSE133642",
  paper = "Frankhouser et al. Cancer Res 2020 (PMID 32414754)",
  organism = "Mus musculus, Cbfb-MYH11 AML",
  layers = c("mrna_primary_2018_log2cpm", "mrna_supp_2016_log2cpm"),
  n_genes = length(shared_genes),
  n_primary = ncol(primary_mat),
  n_supp = ncol(supp_mat),
  cohort_roles = list(
    mrna_primary_2018 = paste(
      "AML.mRNA.2018.all_samples; 132-observation source-paper training",
      "cohort and landscapeR discovery state-space"
    ),
    mrna_supp_2016 = paste(
      "AML.mRNA.2016; 101-observation source-paper validation cohort 1",
      "and landscapeR hostile projection stress test"
    )
  ),
  sample_weeks = list(
    source_repository = "https://github.com/cohmathonc/haemdata",
    source_file = "data-raw/metadata_mmu.rds",
    source_revision = "38176c1192989bbd5ec0f278d05aaaba06833567",
    source_sha256 = "73977189d4979279b3fb7127dd28d29e7c2d7fe447844f05090c2aee78773f5f",
    source_column = "sample_weeks",
    units = "weeks",
    join_key = paste(
      "library_id: COHP_ plus the terminal numeric token of the GEO",
      "expression sample name"
    ),
    packaged_mapping = "inst/extdata/gse133642-sample-weeks.csv",
    procedure = paste(
      "Exact numeric values copied from the immutable source snapshot;",
      "categorical sample labels are not parsed, interpolated, rounded,",
      "or used for longitudinal ordering"
    )
  ),
  note = paste(
    "Both matrices are real biological validation data for landscapeR.",
    "Source-study training/validation roles describe the original paper and",
    "do not constitute scientific acceptance of landscapeR."
  )
)
metadata(aml_std) <- md
saveRDS(aml_std, "data-raw/aml_mrna_std.rds")
cat("  Saved: data-raw/aml_mrna_std.rds\n\n")

# ============================================================================
# 2. CML mRNA (GSE244990) — single layer, reference paper data
# ============================================================================
cat("=== CML mRNA (GSE244990) ===\n")

cat("  Reading CML TPM matrix...\n")
cml_raw <- read.table(
  gzfile(file.path(GEO, "GSE244990_cml_mrna_processed_1tpm_in_5_samples.tsv.gz")),
  sep = ",", header = TRUE, row.names = 1, check.names = FALSE, quote = "\"")
rownames(cml_raw) <- strip_version(rownames(cml_raw))
cat(sprintf("  %d genes x %d samples\n", nrow(cml_raw), ncol(cml_raw)))
cat("  colname example:", colnames(cml_raw)[1], "\n")
cat("  value range:", round(range(as.matrix(cml_raw[1:10,])), 2), "\n")

n_cml <- ncol(cml_raw)
cml_meta <- DataFrame(
  cohort    = rep("cml_leukemia2024", n_cml),
  condition = rep(NA_character_, n_cml),
  row.names = colnames(cml_raw)
)

se_cml <- SummarizedExperiment(
  assays  = list(tpm = as.matrix(cml_raw)),
  colData = cml_meta
)

cml_std <- StateTransitionData(
  experiments = list(cml_mrna = se_cml),
  colData     = cml_meta
)
md <- metadata(cml_std)
md$data_source <- list(
  accession = "GSE244990",
  paper     = "Frankhouser et al. Leukemia 2024 (PMID 38307941)",
  organism  = "Mus musculus, CML",
  layers    = "cml_mrna_tpm",
  n_genes   = nrow(cml_raw),
  n_samples = ncol(cml_raw),
  note      = "single-layer; condition metadata requires external phenodata"
)
metadata(cml_std) <- md
saveRDS(cml_std, "data-raw/cml_mrna_std.rds")
cat("  Saved: data-raw/cml_mrna_std.rds\n\n")

# ============================================================================
# 3. AML multi-modal (GSE133642 + GSE173785 source-paper training cohort)
# ============================================================================
cat("=== AML multi-modal (mRNA + miRNA, 2018 source-paper training cohort) ===\n")

cat("  Reading miRNA training-cohort CPM...\n")
mir_raw <- read.table(
  gzfile(file.path(GEO, "GSE173785_training_mature_normalized_CPM.tsv.gz")),
  sep = "\t", header = TRUE, row.names = 1, check.names = FALSE)
colnames(mir_raw) <- sub("\\.mature$", "", colnames(mir_raw))
cat(sprintf("  %d miRNAs x %d samples\n", nrow(mir_raw), ncol(mir_raw)))

mouse_time_key <- function(sample_names) {
  parts <- strsplit(sample_names, "_")
  paste(
    vapply(parts, `[`, character(1L), 2L),
    vapply(parts, `[`, character(1L), 1L),
    sep = "_"
  )
}

mrna_key <- mouse_time_key(colnames(primary_mat))
mir_key <- mouse_time_key(colnames(mir_raw))
if (anyDuplicated(mrna_key) > 0L || anyDuplicated(mir_key) > 0L) {
  stop("AML multi-modal mouse/time keys must be unique within each assay")
}
shared_keys <- mrna_key[mrna_key %in% mir_key]
if (!length(shared_keys)) {
  stop("AML multi-modal training cohorts have no matched observations")
}
cat(sprintf("  Matched sample pairs (mouse x timepoint): %d\n", length(shared_keys)))

mrna_idx <- match(shared_keys, mrna_key)
mir_idx <- match(shared_keys, mir_key)
mrna_mm_mat <- primary_mat[, mrna_idx, drop = FALSE]
mir_mm_mat <- as.matrix(mir_raw)[, mir_idx, drop = FALSE]
colnames(mrna_mm_mat) <- shared_keys
colnames(mir_mm_mat) <- shared_keys

cat(sprintf("  mRNA layer: %d genes x %d samples\n",
            nrow(mrna_mm_mat), ncol(mrna_mm_mat)))
cat(sprintf("  miRNA layer: %d miRNAs x %d samples\n",
            nrow(mir_mm_mat), ncol(mir_mm_mat)))

mm_meta <- primary_meta[mrna_idx, , drop = FALSE]
rownames(mm_meta) <- shared_keys
se_mrna_mm <- SummarizedExperiment(
  assays = list(log2cpm = mrna_mm_mat),
  colData = DataFrame(mm_meta)
)
se_mirna <- SummarizedExperiment(
  assays = list(cpm = mir_mm_mat),
  colData = DataFrame(mm_meta)
)

mm_std <- StateTransitionData(
  experiments = list(mrna = se_mrna_mm, mirna = se_mirna),
  colData = DataFrame(mm_meta)
)
mm_std <- declare_sampling_design(
  mm_std,
  longitudinal("mouse_id", "sample_weeks", "weeks")
)
md <- metadata(mm_std)
md$data_source <- list(
  accession = c("GSE133642 (mRNA)", "GSE173785 (miRNA)"),
  paper = c("Frankhouser Cancer Res 2020", "Frankhouser Sci Adv 2022"),
  organism = paste(
    "Mus musculus, Cbfb-MYH11 AML, 2018 source-paper training cohort;",
    "real biological validation data for landscapeR"
  ),
  layers = c("mrna_log2cpm", "mirna_cpm"),
  n_shared = ncol(mrna_mm_mat),
  sample_weeks = metadata(aml_std)$data_source$sample_weeks,
  note = paste(
    "Different feature spaces; sample-space hogsvd is needed for cross-modal",
    "fusion. Source-study training status does not imply landscapeR acceptance."
  )
)
metadata(mm_std) <- md
saveRDS(mm_std, "data-raw/aml_multimodal_std.rds")
cat("  Saved: data-raw/aml_multimodal_std.rds\n\n")

cat("All datasets loaded.\n")
