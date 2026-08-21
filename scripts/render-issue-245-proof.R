#!/usr/bin/env Rscript

# Reproducible family-level classification for the #245 palette contract.
inventory_path <- file.path(
    ".github", "landing-proof", "issue-226", "public-plot-inventory.tsv"
)
output_dir <- file.path(".github", "landing-proof", "issue-245")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

inventory <- utils::read.delim(
    inventory_path,
    stringsAsFactors = FALSE,
    check.names = FALSE
)
included <- inventory[inventory$included == "TRUE", , drop = FALSE]
if (anyDuplicated(included$id)) {
    stop("Issue 245 inventory contains duplicate included plot IDs")
}

classification <- c(
    `cross-sectional-atlas` = "compliant",
    `component-proposal` = "compliant",
    `permutation-evidence` = "compliant",
    `association-abstention` = "compliant",
    `component-abstention` = "compliant",
    `independent-time-course` = "compliant",
    `repeated-subject-time-course` = "compliant",
    `stage1-components-categorical` = "intentional-exception",
    `stage1-components-continuous` = "intentional-exception",
    `stage1-decomposition` = "intentional-exception",
    `stage1-spectrum` = "compliant",
    `stage2-potential` = "intentional-exception",
    `stage2-potential-critical-points` = "intentional-exception",
    `k1-operating-domain` = "compliant",
    `identifiability-primary` = "compliant",
    `identifiability-diagnostic` = "compliant",
    `identifiability-audit` = "compliant"
)
if (!setequal(included$id, names(classification))) {
    stop("Issue 245 classification does not cover exactly the included inventory")
}

rule <- c(
    compliant = "canonical semantic roles or signed diverging roles are explicit",
    `intentional-exception` = "data-role scale is permitted when named and captioned"
)
out <- included[, c("id", "function_name", "source_file", "source_sha256", "purpose")]
out$classification <- unname(classification[out$id])
out$palette_rule <- unname(rule[out$classification])
out$claim_status <- included$evidence_state
utils::write.table(
    out,
    file.path(output_dir, "palette-classification.tsv"),
    sep = "\t",
    quote = FALSE,
    row.names = FALSE
)

writeLines(
    c(
        "# Issue #245 semantic palette proof",
        "",
        "This packet classifies every included public family in the immutable",
        "issue-226 inventory against ADR 0020's semantic palette contract.",
        "It does not recolour figures or change scientific evidence.",
        "",
        "`compliant` means the existing renderer already uses canonical semantic",
        "roles. `intentional-exception` means a categorical, molecular-layer,",
        "continuous, or quasi-potential data-role scale is permitted when its",
        "legend, caption, and non-colour interpretation remain explicit.",
        "",
        "Regenerate with `Rscript scripts/render-issue-245-proof.R`."
    ),
    file.path(output_dir, "README.md")
)
