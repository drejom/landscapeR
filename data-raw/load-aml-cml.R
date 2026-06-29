# Load GEO datasets into StateTransitionData objects
#
# Produces three .rds files in data-raw/:
#
#   aml_mrna_std.rds   — AML mRNA, GSE133642
#                        Layer 1: mrna_primary_2018 — primary experiment
#                                 Clean randomised batches, reported in paper.
#                                 GEO filename: "validation_merged_gene_counts"
#                                 (GEO depositor naming; this IS the primary cohort)
#                        Layer 2: mrna_supp_2016 — supplementary stress-test
#                                 Batch-confounded, earlier experiment.
#                                 Projected into primary state-space via project_into().
#                        Restricted to 13,232 shared genes.
#
#   cml_mrna_std.rds   — CML mRNA, GSE244990
#                        Single-layer (298 samples, TPM)
#                        Used for end-to-end Stage 1 + Stage 2 on the paper
#                        that the reference code (CML_mRNA_state-transition) runs on.
#
#   aml_multimodal_std.rds — AML mRNA + miRNA, GSE133642 primary + GSE173785 primary
#                            Layer 1: mRNA primary 2018 (log2 CPM)
#                            Layer 2: miRNA primary 2018 (CPM)
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
# Helper: parse AML supplementary (2016) sample names
#   T{tp}_{mouseID}_{?}_{condition}_{diet}{wt}_{sex}_{group}_{?}
# ============================================================================
parse_supp_meta <- function(nms) {
  parts <- strsplit(nms, "_")
  data.frame(
    row.names = nms,
    cohort     = "supp_2016",
    timepoint  = sapply(parts, `[`, 1),
    mouse_id   = sapply(parts, `[`, 2),
    condition  = sapply(parts, `[`, 4),
    sex        = sapply(parts, function(x) x[6]),
    group      = sapply(parts, function(x) x[7]),
    stringsAsFactors = FALSE
  )
}

# Primary (2018): T{tp}_{mouseID}_{condition}_{diet}{wt}_{sex}_{?}
#                 L_{mouseID}_{condition}_{diet}{wt}_{sex}_{?}   (leukemic endpoint)
# Field 1 is the timepoint token (T0-T6 or L); field 2 is mouse ID.
parse_primary_meta <- function(nms) {
  parts <- strsplit(nms, "_")
  data.frame(
    row.names = nms,
    cohort     = "primary_2018",
    timepoint  = sapply(parts, `[`, 1),   # T0, T1, ..., T6, or L
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
# 1. AML mRNA (GSE133642)
# ============================================================================
cat("=== AML mRNA (GSE133642) ===\n")

# GEO depositor named the 2016 file without "validation" and the 2018 file with
# "validation" — the opposite of scientific primacy. 2018 is the primary clean
# experiment reported in the paper; 2016 is supplementary batch-confounded data.

cat("  Reading supplementary 2016 cohort...\n")
supp_raw <- read.table(
  gzfile(file.path(GEO, "GSE133642_merged_gene_counts_log2cpm_0.5CPMin2samples.txt.gz")),
  sep = "\t", header = TRUE, row.names = 1, check.names = FALSE)
rownames(supp_raw) <- strip_version(rownames(supp_raw))
cat(sprintf("  %d genes x %d samples\n", nrow(supp_raw), ncol(supp_raw)))

cat("  Reading primary 2018 cohort...\n")
primary_raw <- read.table(
  gzfile(file.path(GEO, "GSE133642_validation_merged_gene_counts__log2cpm_5CPMin2samples.tsv.gz")),
  sep = "\t", header = TRUE, row.names = 1, check.names = FALSE)
rownames(primary_raw) <- strip_version(rownames(primary_raw))
cat(sprintf("  %d genes x %d samples (before WK filter)\n", nrow(primary_raw), ncol(primary_raw)))

# Drop WK10-WK28 samples: separate arm, different mice (3127/3130/3131/3200/3202),
# no T0 baseline, library prep confounded with timepoint. Keep L_ and T-prefix only.
wk_mask <- grepl("^WK[0-9]", colnames(primary_raw))
if (any(wk_mask)) {
  cat(sprintf("  Dropping %d WK-timepoint samples (no baseline, batch-confounded)\n",
              sum(wk_mask)))
  primary_raw <- primary_raw[, !wk_mask, drop = FALSE]
}
cat(sprintf("  %d genes x %d samples\n", nrow(primary_raw), ncol(primary_raw)))

shared_genes <- intersect(rownames(supp_raw), rownames(primary_raw))
cat(sprintf("  Shared genes: %d\n", length(shared_genes)))

supp_mat    <- as.matrix(supp_raw[shared_genes, ])
primary_mat <- as.matrix(primary_raw[shared_genes, ])

supp_meta    <- parse_supp_meta(colnames(supp_mat))
primary_meta <- parse_primary_meta(colnames(primary_mat))

se_supp    <- SummarizedExperiment(assays = list(log2cpm = supp_mat),
                                    colData = DataFrame(supp_meta))
se_primary <- SummarizedExperiment(assays = list(log2cpm = primary_mat),
                                    colData = DataFrame(primary_meta))

all_meta <- rbind(supp_meta, primary_meta)

aml_std <- StateTransitionData(
  experiments = list(mrna_primary_2018 = se_primary, mrna_supp_2016 = se_supp),
  colData     = DataFrame(all_meta)
)
md <- metadata(aml_std)
md$data_source <- list(
  accession  = "GSE133642",
  paper      = "Frankhouser et al. Cancer Res 2020 (PMID 32414754)",
  organism   = "Mus musculus, Cbfb-MYH11 AML",
  layers     = c("mrna_primary_2018_log2cpm", "mrna_supp_2016_log2cpm"),
  n_genes    = length(shared_genes),
  n_primary  = ncol(primary_mat),
  n_supp     = ncol(supp_mat),
  note       = paste(
    "Layer 1 (mrna_primary_2018) is the paper's training cohort — clean,",
    "randomised batches, used to build the SVD state-space.",
    "Layer 2 (mrna_supp_2016) is batch-confounded; project into layer 1",
    "state-space via project_into() for supplementary validation."
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
# 3. AML multi-modal (GSE133642 primary mRNA + GSE173785 primary miRNA)
# ============================================================================
cat("=== AML multi-modal (mRNA + miRNA, 2018 primary cohort) ===\n")

cat("  Reading miRNA primary CPM...\n")
mir_raw <- read.table(
  gzfile(file.path(GEO, "GSE173785_validation_mature_normalized_CPM.tsv.gz")),
  sep = "\t", header = TRUE, row.names = 1, check.names = FALSE)
cat(sprintf("  %d miRNAs x %d samples\n", nrow(mir_raw), ncol(mir_raw)))

colnames(mir_raw) <- sub("\\.mature$", "", colnames(mir_raw))
cat("  miRNA sample example:", colnames(mir_raw)[1], "\n")
cat("  mRNA  sample example:", colnames(primary_mat)[1], "\n")

mir_mouse <- sub("-.*$", "", colnames(mir_raw))
mir_tp    <- sub("^[0-9]+-", "", colnames(mir_raw))
mir_key   <- paste0(mir_mouse, "_T", mir_tp)

mrna_tp_raw <- sapply(strsplit(colnames(primary_mat), "_"), `[`, 1)
mrna_mouse  <- sapply(strsplit(colnames(primary_mat), "_"), `[`, 2)
mrna_key <- ifelse(
  grepl("^T", mrna_tp_raw),
  paste0(mrna_mouse, "_", mrna_tp_raw),
  paste0(mrna_mouse, "_L")
)

shared_keys <- intersect(mir_key, mrna_key)
cat(sprintf("  Matched sample pairs (mouse x timepoint): %d\n", length(shared_keys)))

if (length(shared_keys) >= 20) {
  mir_idx  <- match(shared_keys, mir_key)
  mrna_idx <- match(shared_keys, mrna_key)
  mrna_mm_mat <- primary_mat[, mrna_idx, drop = FALSE]
  mir_mm_mat  <- as.matrix(mir_raw)[, mir_idx, drop = FALSE]
  colnames(mrna_mm_mat) <- shared_keys
  colnames(mir_mm_mat)  <- shared_keys
} else {
  cat("  NOTE: few exact timepoint matches; using all samples unmatched.\n")
  mrna_mm_mat <- primary_mat
  mir_mm_mat  <- as.matrix(mir_raw)
}

cat(sprintf("  mRNA layer: %d genes x %d samples\n",
            nrow(mrna_mm_mat), ncol(mrna_mm_mat)))
cat(sprintf("  miRNA layer: %d miRNAs x %d samples\n",
            nrow(mir_mm_mat), ncol(mir_mm_mat)))

n_mm <- ncol(mrna_mm_mat)
mm_meta <- DataFrame(
  cohort    = rep("primary_2018", n_mm),
  row.names = colnames(mrna_mm_mat)
)

mir_meta <- DataFrame(
  cohort    = rep("primary_2018", ncol(mir_mm_mat)),
  row.names = colnames(mir_mm_mat)
)

se_mrna_mm <- SummarizedExperiment(assays = list(log2cpm = mrna_mm_mat),
                                    colData = mm_meta)
se_mirna   <- SummarizedExperiment(assays = list(cpm = mir_mm_mat),
                                    colData = mir_meta)

mm_std <- StateTransitionData(
  experiments = list(mrna = se_mrna_mm, mirna = se_mirna),
  colData     = mm_meta
)
md <- metadata(mm_std)
md$data_source <- list(
  accession  = c("GSE133642 (mRNA)", "GSE173785 (miRNA)"),
  paper      = c("Frankhouser Cancer Res 2020", "Frankhouser Sci Adv 2022"),
  organism   = "Mus musculus, Cbfb-MYH11 AML, 2018 primary cohort",
  layers     = c("mrna_log2cpm", "mirna_cpm"),
  n_shared   = ncol(mrna_mm_mat),
  note       = "different feature spaces; sample-space hogsvd needed for cross-modal fusion"
)
metadata(mm_std) <- md
saveRDS(mm_std, "data-raw/aml_multimodal_std.rds")
cat("  Saved: data-raw/aml_multimodal_std.rds\n\n")

cat("All datasets loaded.\n")
