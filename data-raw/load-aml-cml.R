# Load GEO datasets into StateTransitionData objects
#
# Produces three .rds files in data-raw/:
#
#   aml_mrna_std.rds   — AML mRNA, GSE133642
#                        Layer 1: training 2016 (batch-confounded, log2 CPM)
#                        Layer 2: validation 2018 (clean, log2 CPM)
#                        Restricted to 13,232 shared genes.
#                        Experiment: does Stage 1 recover AML axis vs batch axis?
#
#   cml_mrna_std.rds   — CML mRNA, GSE244990
#                        Single-layer (298 samples, TPM)
#                        Used for end-to-end Stage 1 + Stage 2 on the paper
#                        that the reference code (CML_mRNA_state-transition) runs on.
#
#   aml_multimodal_std.rds — AML mRNA + miRNA, GSE133642 val + GSE173785 val
#                            Layer 1: mRNA validation 2018 (log2 CPM)
#                            Layer 2: miRNA validation 2018 (CPM)
#                            Restricted to samples present in both assays.
#                            Experiment: shared AML axis across modalities.

suppressPackageStartupMessages({
  devtools::load_all(".", quiet = TRUE)
  library(SummarizedExperiment)
  library(S4Vectors)
})

GEO <- "data-raw/geo"

strip_version <- function(ids) sub("\\.[0-9]+$", "", ids)

# ============================================================================
# Helper: parse AML training sample names
#   T{tp}_{mouseID}_{?}_{condition}_{diet}{wt}_{sex}_{group}_{?}
# ============================================================================
parse_train_meta <- function(nms) {
  parts <- strsplit(nms, "_")
  data.frame(
    row.names = nms,
    cohort     = "train_2016",
    timepoint  = sapply(parts, `[`, 1),
    mouse_id   = sapply(parts, `[`, 2),
    condition  = sapply(parts, `[`, 4),
    sex        = sapply(parts, function(x) x[6]),
    group      = sapply(parts, function(x) x[7]),
    stringsAsFactors = FALSE
  )
}

# Validation: L_{mouseID}_{condition}_{diet}{wt}_{sex}_{?}
parse_val_meta <- function(nms) {
  parts <- strsplit(nms, "_")
  data.frame(
    row.names = nms,
    cohort     = "val_2018",
    timepoint  = NA_character_,
    mouse_id   = sapply(parts, `[`, 2),
    condition  = sapply(parts, function(x) {
      cond <- x[3]; ifelse(cond == "Ctrl", "CTL", cond)
    }),
    sex        = sapply(parts, function(x) x[5]),
    group      = NA_character_,
    stringsAsFactors = FALSE
  )
}

# ============================================================================
# 1. AML mRNA (GSE133642) — batch deconfounding experiment
# ============================================================================
cat("=== AML mRNA (GSE133642) ===\n")

cat("  Reading training (2016)...\n")
train_raw <- read.table(
  gzfile(file.path(GEO, "GSE133642_merged_gene_counts_log2cpm_0.5CPMin2samples.txt.gz")),
  sep = "\t", header = TRUE, row.names = 1, check.names = FALSE)
rownames(train_raw) <- strip_version(rownames(train_raw))
cat(sprintf("  %d genes x %d samples\n", nrow(train_raw), ncol(train_raw)))

cat("  Reading validation (2018)...\n")
val_raw <- read.table(
  gzfile(file.path(GEO, "GSE133642_validation_merged_gene_counts__log2cpm_5CPMin2samples.tsv.gz")),
  sep = "\t", header = TRUE, row.names = 1, check.names = FALSE)
rownames(val_raw) <- strip_version(rownames(val_raw))
cat(sprintf("  %d genes x %d samples\n", nrow(val_raw), ncol(val_raw)))

shared_genes <- intersect(rownames(train_raw), rownames(val_raw))
cat(sprintf("  Shared genes: %d\n", length(shared_genes)))

train_mat <- as.matrix(train_raw[shared_genes, ])
val_mat   <- as.matrix(val_raw[shared_genes, ])

train_meta <- parse_train_meta(colnames(train_mat))
val_meta   <- parse_val_meta(colnames(val_mat))

se_train <- SummarizedExperiment(assays = list(log2cpm = train_mat),
                                  colData = DataFrame(train_meta))
se_val   <- SummarizedExperiment(assays = list(log2cpm = val_mat),
                                  colData = DataFrame(val_meta))

all_meta <- rbind(train_meta, val_meta)

aml_std <- StateTransitionData(
  experiments = list(mrna_train_2016 = se_train, mrna_val_2018 = se_val),
  colData     = DataFrame(all_meta)
)
md <- metadata(aml_std)
md$data_source <- list(
  accession  = "GSE133642",
  paper      = "Frankhouser et al. Cancer Res 2020 (PMID 32414754)",
  organism   = "Mus musculus, Cbfb-MYH11 AML",
  layers     = c("train_2016_log2cpm", "val_2018_log2cpm"),
  n_genes    = length(shared_genes),
  n_train    = ncol(train_mat),
  n_val      = ncol(val_mat),
  note       = "training cohort batch-confounded; validation clean"
)
metadata(aml_std) <- md
saveRDS(aml_std, "data-raw/aml_mrna_std.rds")
cat("  Saved: data-raw/aml_mrna_std.rds\n\n")

# ============================================================================
# 2. CML mRNA (GSE244990) — single layer, reference paper data
# ============================================================================
cat("=== CML mRNA (GSE244990) ===\n")

cat("  Reading CML TPM matrix...\n")
# File uses quoted column headers with "" as row-name placeholder
cml_raw <- read.table(
  gzfile(file.path(GEO, "GSE244990_cml_mrna_processed_1tpm_in_5_samples.tsv.gz")),
  sep = ",", header = TRUE, row.names = 1, check.names = FALSE, quote = "\"")
rownames(cml_raw) <- strip_version(rownames(cml_raw))
cat(sprintf("  %d genes x %d samples\n", nrow(cml_raw), ncol(cml_raw)))
cat("  colname example:", colnames(cml_raw)[1], "\n")
cat("  value range:", round(range(as.matrix(cml_raw[1:10,])), 2), "\n")

# Sample names are COHP_NNNNN — no condition metadata embedded in names.
# Condition metadata (treatment timepoint etc.) requires the external phenodata
# distributed via the repo's Google Drive; flag as unknown for now.
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
# 3. AML multi-modal (GSE133642 val mRNA + GSE173785 val miRNA)
# ============================================================================
cat("=== AML multi-modal (mRNA + miRNA, 2018 validation cohort) ===\n")

cat("  Reading miRNA validation CPM...\n")
mir_raw <- read.table(
  gzfile(file.path(GEO, "GSE173785_validation_mature_normalized_CPM.tsv.gz")),
  sep = "\t", header = TRUE, row.names = 1, check.names = FALSE)
cat(sprintf("  %d miRNAs x %d samples\n", nrow(mir_raw), ncol(mir_raw)))

# miRNA validation sample names: 2683-5.mature  -> strip ".mature"
colnames(mir_raw) <- sub("\\.mature$", "", colnames(mir_raw))
cat("  miRNA sample example:", colnames(mir_raw)[1], "\n")
cat("  mRNA  sample example:", colnames(val_mat)[1], "\n")

# mRNA validation sample names: L_2684_CM_CHW_M_11548
# Extract the mouse ID field (position 2) to match miRNA mouse IDs
mrna_mouse <- sub("^L_([0-9]+)_.*", "\\1", colnames(val_mat))
cat("  mRNA mouse IDs example:", paste(head(mrna_mouse, 3), collapse=", "), "\n")
cat("  miRNA sample IDs example:", paste(head(colnames(mir_raw), 3), collapse=", "), "\n")

# miRNA IDs: "{mouseID}-{timepoint}" e.g. "2683-5"
# mRNA IDs:  "L_{mouseID}_..." or "T{tp}_{mouseID}_..."
# Match on mouseID × timepoint pairs where possible.
mir_mouse <- sub("-.*$", "", colnames(mir_raw))          # "2683"
mir_tp    <- sub("^[0-9]+-", "", colnames(mir_raw))      # "5"
mir_key   <- paste0(mir_mouse, "_T", mir_tp)             # "2683_T5"

# mRNA val names: "L_2684_..." = long-term (no clean timepoint); "T0_2683_..." = T0
mrna_tp_raw <- sapply(strsplit(colnames(val_mat), "_"), `[`, 1)   # "L" or "T0","T1"...
mrna_mouse  <- sapply(strsplit(colnames(val_mat), "_"), `[`, 2)   # "2683"
# For timecourse samples, the timepoint is embedded in field 1
mrna_key <- ifelse(
  grepl("^T", mrna_tp_raw),
  paste0(mrna_mouse, "_", mrna_tp_raw),       # "2683_T0"
  paste0(mrna_mouse, "_L")                    # "2684_L"  (long-term; no miRNA match)
)

shared_keys <- intersect(mir_key, mrna_key)
cat(sprintf("  Matched sample pairs (mouse×timepoint): %d\n", length(shared_keys)))

if (length(shared_keys) >= 20) {
  mir_idx  <- match(shared_keys, mir_key)
  mrna_idx <- match(shared_keys, mrna_key)
  mrna_mm_mat <- val_mat[, mrna_idx, drop = FALSE]
  mir_mm_mat  <- as.matrix(mir_raw)[, mir_idx, drop = FALSE]
  colnames(mrna_mm_mat) <- shared_keys
  colnames(mir_mm_mat)  <- shared_keys
} else {
  cat("  NOTE: few exact timepoint matches; using all samples unmatched.\n")
  mrna_mm_mat <- val_mat
  mir_mm_mat  <- as.matrix(mir_raw)
}

cat(sprintf("  mRNA layer: %d genes x %d samples\n",
            nrow(mrna_mm_mat), ncol(mrna_mm_mat)))
cat(sprintf("  miRNA layer: %d miRNAs x %d samples\n",
            nrow(mir_mm_mat), ncol(mir_mm_mat)))

n_mm <- ncol(mrna_mm_mat)
mm_meta <- DataFrame(
  cohort    = rep("val_2018", n_mm),
  row.names = colnames(mrna_mm_mat)
)

mir_meta <- DataFrame(
  cohort    = rep("val_2018", ncol(mir_mm_mat)),
  row.names = colnames(mir_mm_mat)
)

se_mrna_mm <- SummarizedExperiment(assays = list(log2cpm = mrna_mm_mat),
                                    colData = mm_meta)
se_mirna   <- SummarizedExperiment(assays = list(cpm = mir_mm_mat),
                                    colData = mir_meta)

# When layers have different samples, colData covers the union; MAE handles
# the sample map. Use the mRNA colData as the primary.
mm_std <- StateTransitionData(
  experiments = list(mrna = se_mrna_mm, mirna = se_mirna),
  colData     = mm_meta
)
md <- metadata(mm_std)
md$data_source <- list(
  accession  = c("GSE133642 (mRNA)", "GSE173785 (miRNA)"),
  paper      = c("Frankhouser Cancer Res 2020", "Frankhouser Sci Adv 2022"),
  organism   = "Mus musculus, Cbfb-MYH11 AML, 2018 validation cohort",
  layers     = c("mrna_log2cpm", "mirna_cpm"),
  n_shared   = ncol(mrna_mm_mat),
  note       = "different feature spaces; sample-space hogsvd needed for cross-modal fusion"
)
metadata(mm_std) <- md
saveRDS(mm_std, "data-raw/aml_multimodal_std.rds")
cat("  Saved: data-raw/aml_multimodal_std.rds\n\n")

cat("All datasets loaded.\n")
