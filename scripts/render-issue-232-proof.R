#!/usr/bin/env Rscript

# Reproducible before/after proof for issue #232.
output_dir <- file.path(".github", "landing-proof", "issue-232")
scratch_dir <- file.path(".scratch", "issue-232-contact-sheet")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(scratch_dir, recursive = TRUE, showWarnings = FALSE)
file.copy(
    file.path(".github", "landing-proof", "issue-226", "adversarial-review.md"),
    file.path(scratch_dir, "adversarial-review.md"), overwrite = TRUE
)
Sys.setenv(LANDSCAPER_CONTACT_SHEET_OUTPUT = scratch_dir)
source(file.path("scripts", "render-issue-226-contact-sheet.R"), local = new.env())

required <- c(
    "public-plot-contact-sheet.png",
    "public-plot-contact-sheet-reduced.png",
    "public-plot-contact-sheet-caption.txt",
    "public-plot-contact-sheet-labels.tsv"
)
stopifnot(all(file.exists(file.path(scratch_dir, required))))
stopifnot(file.exists(file.path(output_dir, "contact-sheet-before.png")))
file.copy(
    file.path(scratch_dir, "public-plot-contact-sheet.png"),
    file.path(output_dir, "contact-sheet-after.png"), overwrite = TRUE
)
file.copy(
    file.path(scratch_dir, "public-plot-contact-sheet-reduced.png"),
    file.path(output_dir, "contact-sheet-after-reduced.png"), overwrite = TRUE
)
file.copy(
    file.path(scratch_dir, "public-plot-contact-sheet-caption.txt"),
    file.path(output_dir, "contact-sheet-after-caption.txt"), overwrite = TRUE
)
file.copy(
    file.path(scratch_dir, "public-plot-contact-sheet-labels.tsv"),
    file.path(output_dir, "contact-sheet-after-labels.tsv"), overwrite = TRUE
)
writeLines(c(
    "# Issue #232 contact-sheet tile-isolation proof", "",
    "The before image is the issue #226 contact sheet whose full plot subtitles",
    "collided across tile boundaries at reduced reading size.", "",
    "The after image uses concise tile-local labels and suppresses only the",
    "underlying plot subtitles in the audit sheet. Full scientific captions remain",
    "in the issue #226 inventory and separate caption files.", "",
    "The reduced after image is the required smaller-dimension QA render. The",
    "label manifest records the bounded text budget checked by the renderer and",
    "contract checker. Inspect both after images for tile isolation, label",
    "legibility, clipping, and legend collisions.", "",
    "Reproduce with:", "", "Rscript scripts/render-issue-232-proof.R", "",
    "Claim status: implementation proof; no biological claim."
), file.path(output_dir, "README.md"))
