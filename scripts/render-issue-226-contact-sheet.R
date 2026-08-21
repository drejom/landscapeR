#!/usr/bin/env Rscript

# Reproducible public plotting-surface audit for issue #226.
suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))
if (!requireNamespace("patchwork", quietly = TRUE)) {
    stop("issue #226 proof requires the patchwork package", call. = FALSE)
}
source(file.path("tests", "testthat", "helper-independent-time-course.R"))
source(file.path("tests", "testthat", "helper-repeated-time-course.R"))

output_dir <- Sys.getenv(
    "LANDSCAPER_CONTACT_SHEET_OUTPUT",
    unset = file.path(".github", "landing-proof", "issue-226")
)
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
cross_sectional_fixture <- function() {
    primary <- sprintf("sample_%02d", seq_len(10L))
    assay_ids <- sprintf("rna_%02d", seq_len(10L))
    se <- SummarizedExperiment::SummarizedExperiment(
        assays = list(logcounts = matrix(
            seq_len(50L), nrow = 5L,
            dimnames = list(sprintf("gene_%02d", 1:5), assay_ids)
        ))
    )
    data <- StateTransitionData(
        experiments = list(rna = se),
        colData = S4Vectors::DataFrame(
            condition = factor(
                rep(c("control", "treatment"), each = 5L),
                levels = c("control", "treatment")
            ),
            sample_id = primary,
            row.names = primary
        ),
        sampleMap = S4Vectors::DataFrame(
            assay = factor(rep("rna", 10L), levels = "rna"),
            primary = primary, colname = assay_ids
        )
    )
    data <- declare_sampling_design(data, cross_sectional())
    coords <- cbind(
        PC1 = c(-1.5, -1.2, -0.9, -0.5, -0.2, 0.3, 0.6, 1, 1.3, 1.6),
        PC2 = c(-0.8, 0.4, -0.3, 0.6, 0.1, -0.5, 0.5, -0.2, 0.7, -0.4)
    )
    md <- metadata(data)
    md$stage1 <- DecompositionResult(
        V_star = c(1, 0, 0, 0, 0), sigma = 1,
        coords = list(coords[, 1L]), V_k = diag(5)[, 1:2, drop = FALSE],
        sigma_k = matrix(c(2, 1), nrow = 1L), coords_k = list(coords), k = 2L
    )
    metadata(data) <- md
    data
}

cross_data <- cross_sectional_fixture()
cross_spec <- analysis_specification(
    id = "issue-226-cross-sectional", target_field = "condition",
    target_type = "binary", reference_level = "control",
    comparison_level = "treatment"
)
cross_atlas <- associate_metadata(
    cross_data, specification = cross_spec, non_analytical_fields = "sample_id",
    dataset_id = "Issue 226 cross-sectional fixture"
)
cross_proposal <- propose_component(cross_atlas, n_permutations = 9L, seed = 22601L)
cross_permutation <- proposal_permutation_evidence(cross_proposal)
cross_association_abstention <- associate_metadata(
    cross_data,
    specification = analysis_specification(
        id = "issue-226-invalid-target", target_field = "condition",
        target_type = "continuous", continuous_direction = "increasing"
    ),
    non_analytical_fields = "sample_id",
    dataset_id = "Issue 226 cross-sectional fixture"
)
cross_component_abstention <- propose_component(
    associate_metadata(
        cross_data, non_analytical_fields = "sample_id",
        dataset_id = "Issue 226 cross-sectional fixture"
    ),
    target = "condition", n_permutations = 9L, seed = 22602L
)

time_atlases <- list(
    independent_time_course = associate_metadata(
        independent_time_course_fixture(),
        specification = independent_time_course_specification("batch"),
        non_analytical_fields = "sample_id",
        dataset_id = "Issue 226 independent-time-course fixture",
        n_resamples = 3L, seed = 22603L, sequential_internal = TRUE
    ),
    repeated_subject = associate_metadata(
        repeated_time_course_fixture(),
        specification = repeated_time_course_specification("batch"),
        non_analytical_fields = "mouse_id",
        dataset_id = "Issue 226 repeated-subject fixture",
        n_resamples = 3L, seed = 22604L, sequential_internal = TRUE
    )
)

state_data <- synthetic_control(
    n = 40L, p = 500L, K = 2L, signal = 30, seed = 22605L
)
state_cd <- colData(state_data)
state_cd$observed_time <- seq_len(nrow(state_cd))
colData(state_data) <- state_cd
state_stage1 <- suppressWarnings(
    decompose(get_strategy("Decomposer", "hogsvd_averaged")(), state_data)
)@value
state_stage2 <- estimate_dynamics(
    get_strategy("DynamicsEstimator", "kde_logdensity")(), state_stage1
)@value

operating_fixture <- local({
    independent <- run_k1_independent_time_course_calibration(
        template_ids = c("balanced_1", "balanced_3"), replicates = 1L,
        p = 20L, seed = 22607L, sequential_internal = TRUE
    )
    signal <- run_k1_high_dimensional_calibration(
        regime_ids = "fixed_sparse", feature_counts = c(20L, 40L),
        signal_ratios = c(0.75, 1.25), replicates = 1L, n = 24L,
        informative_features = 8L, axis_resamples = 1L, seed = 22608L,
        sequential_internal = TRUE
    )
    diagnostics <- k1_experiment_diagnostics(
        feature_count = 20L,
        spectral_signal = signal$cells$signal_strength[[1L]],
        noise_reference = signal$cells$recovery_boundary[[1L]],
        covariance_regime = "independent-gaussian", signal_regime = "fixed_sparse",
        design = list(
            n_retained = 8L, minimum_cell_size = 1L,
            maximum_cell_size = 1L, mean_retained_per_declared_cell = 1
        )
    )
    locate_k1_operating_domain(
        independent_time_course("collection_time", "days"),
        independent, signal, diagnostics
    )
})

identifiability_spec <- analysis_specification(
    id = "Issue 226 identifiability fixture", target_field = "condition",
    target_type = "binary", reference_level = "control",
    comparison_level = "treatment"
)
identifiability_config <- new(
    "PipelineConfig",
    strategies = list(Decomposer = "svd"),
    params = list(svd = list(center = TRUE, k_components = 2L)),
    dataset = "Issue 226 identifiability fixture",
    analysis = identifiability_spec
)
identifiability_discovery <- decompose(
    get_strategy("Decomposer", "svd")(identifiability_config@params$svd),
    cross_data
)
stopifnot(identical(identifiability_discovery@status, "success"))
identifiability_atlas <- associate_metadata(
    identifiability_discovery@value, specification = identifiability_spec,
    non_analytical_fields = "sample_id",
    dataset_id = "Issue 226 identifiability fixture"
)
identifiability_assessed <- assess_component_identifiability(
    data = cross_data, proposal = propose_component(identifiability_atlas),
    config = identifiability_config, non_analytical_fields = "sample_id",
    n_resamples = 9L, seed = 22606L, sequential_internal = TRUE
)

included <- list(
    list("cross-sectional-atlas", "plot.MetadataAssociationAtlas",
         "R/13b-component-interpretation.R", "cross-sectional metadata association atlas",
         "Raw component-score distributions and descriptive fits", "scientific user",
         "MetadataAssociationAtlas", "public scientific evidence", plot(cross_atlas)),
    list("component-proposal", "plot.ComponentProposal",
         "R/13b-component-interpretation.R", "effect-first component proposal",
         "Ranked component evidence before explicit confirmation", "scientific user",
         "ComponentProposal", "public scientific evidence", plot(cross_proposal)),
    list("permutation-evidence", "plot.PermutationEvidence",
         "R/13b-component-interpretation.R", "search-aware maximum-effect null",
         "Search-aware descriptive permutation evidence", "scientific user",
         "PermutationEvidence", "public scientific evidence", plot(cross_permutation)),
    list("association-abstention", "plot.AssociationAbstention",
         "R/13b-component-interpretation.R", "typed association abstention",
         "Visible explanation when an association cannot be estimated", "scientific user",
         "AssociationAbstention", "public scientific evidence",
         plot(cross_association_abstention)),
    list("component-abstention", "plot.ComponentAbstention",
         "R/13b-component-interpretation.R", "typed component-nomination abstention",
         "Visible explanation when no component can be nominated", "scientific user",
         "ComponentAbstention", "public scientific evidence",
         plot(cross_component_abstention)),
    list("independent-time-course", "plot.MetadataAssociationAtlas",
         "R/13c-independent-time-course-interpretation.R",
         "independent destructive time-course atlas",
         "Destructive-time-course trajectory evidence", "scientific user",
         "MetadataAssociationAtlas", "public scientific evidence",
         plot(time_atlases$independent_time_course)),
    list("repeated-subject-time-course", "plot.MetadataAssociationAtlas",
         "R/13d-repeated-time-course-interpretation.R",
         "repeated-subject trajectory atlas",
         "Subject-preserving repeated-measures evidence", "scientific user",
         "MetadataAssociationAtlas", "public scientific evidence",
         plot(time_atlases$repeated_subject)),
    list("stage1-components-categorical", "plot_components", "R/14-stage1-plots.R",
         "categorical metadata", "Descriptive component distributions by category",
         "scientific user", "StateTransitionData with Stage 1",
         "public scientific evidence",
         plot_components(
             state_stage1, colour_by = "planted_group", n_components = 2L,
             reference_level = "low", focal_level = "high"
         )),
    list("stage1-components-continuous", "plot_components", "R/14-stage1-plots.R",
         "continuous observed-time metadata",
         "Descriptive component distributions by continuous metadata", "scientific user",
         "StateTransitionData with Stage 1", "public scientific evidence",
         plot_components(state_stage1, colour_by = "observed_time", n_components = 2L)),
    list("stage1-decomposition", "plot_decomposition", "R/14-stage1-plots.R",
         "sample coordinates on component 1",
         "Sample-level state-space coordinates by molecular layer", "scientific user",
         "StateTransitionData with Stage 1", "public scientific evidence",
         plot_decomposition(
             state_stage1, colour_by = "planted_group", component = 1L,
             reference_level = "low", focal_level = "high"
         )),
    list("stage1-spectrum", "plot_spectrum", "R/14-stage1-plots.R",
         "singular-value spectrum",
         "Spectral structure and model-based detectability reference", "scientific user",
         "StateTransitionData with Stage 1", "public scientific evidence",
         plot_spectrum(state_stage1)),
    list("stage2-potential", "plot_potential", "R/16-stage2-plots.R",
         "quasi-potential without critical-point overlay",
         "Exploratory one-dimensional state-transition landscape", "scientific user",
         "StateTransitionData with Stage 2", "public exploratory evidence",
         plot_potential(
             state_stage2, colour_by = "planted_group",
             reference_level = "low", focal_level = "high"
         )),
    list("stage2-potential-critical-points", "plot_potential", "R/16-stage2-plots.R",
         "quasi-potential with explicit critical-point overlay",
         "Optional stored-well and barrier-point display", "scientific user",
         "StateTransitionData with Stage 2", "public exploratory evidence",
         plot_potential(
             state_stage2, colour_by = "planted_group",
             reference_level = "low", focal_level = "high",
             show_critical_points = TRUE
         )),
    list("k1-operating-domain", "plot_k1_operating_domain",
         "R/13o-stage0-k1-operating-domain-locator.R",
         "calibrated operating-domain location",
         "Diagnostic comparison of an experiment with calibrated operating support",
         "scientific user", "K1OperatingDomainLocation",
         "public diagnostic evidence", plot_k1_operating_domain(operating_fixture)),
    list("identifiability-primary", "plot_component_identifiability",
         "R/13e-axis-identifiability.R", "primary axis/subspace summary",
         "Primary numerical-identifiability summary", "scientific user",
         "ComponentProposal with identifiability evidence", "public diagnostic evidence",
         plot_component_identifiability(identifiability_assessed, view = "primary")),
    list("identifiability-diagnostic", "plot_component_identifiability",
         "R/13e-axis-identifiability.R", "replicate-level recovery diagnostic",
         "Focused diagnostic for loading agreement and effect magnitude", "scientific user",
         "ComponentProposal with identifiability evidence", "public diagnostic evidence",
         plot_component_identifiability(identifiability_assessed, view = "diagnostic")),
    list("identifiability-audit", "plot_component_identifiability",
         "R/13e-axis-identifiability.R", "complete identifiability audit surface",
         "Full evidence surface for axis and subspace instability", "scientific user",
         "ComponentProposal with identifiability evidence", "public diagnostic evidence",
         plot_component_identifiability(identifiability_assessed, view = "audit"))
)

excluded <- list(
    list("k1-acceptance-summary", "plot_k1_acceptance_summary",
         "R/13k-stage0-k1-acceptance-summary.R", "Stage 0 K=1 acceptance summary",
         "Frozen acceptance validation output", "developer/reviewer", "K1AcceptanceSummary",
         "Acceptance calibration and runner proof, not a package user result"),
    list("k1-aml-acceptance-summary", "plot_k1_aml_acceptance_summary",
         "R/13k-stage0-k1-acceptance-summary.R", "AML-shaped acceptance summary",
         "Frozen acceptance validation output", "developer/reviewer", "K1AcceptanceSummary",
         "Acceptance calibration and runner proof, not a package user result"),
    list("k1-calibration-outcomes", "plot_k1_calibration_outcomes",
         "R/13l-stage0-k1-calibration-outcomes.R", "calibration outcome map",
         "Known-truth calibration diagnostic", "developer/reviewer",
         "K1CalibrationOutcomeAssessment", "Simulation calibration output"),
    list("k1-high-dimensional-calibration", "plot_k1_high_dimensional_calibration",
         "R/13o-stage0-k1-high-dimensional-calibration.R", "high-dimensional operating map",
         "Known-truth operating-domain diagnostic", "developer/reviewer",
         "K1HighDimensionalCalibrationAssessment", "Simulation operating map"),
    list("k1-independent-time-course-calibration",
         "plot_k1_independent_time_course_calibration",
         "R/13m-stage0-k1-independent-time-course-calibration.R",
         "independent-time-course calibration map", "Known-truth calibration diagnostic",
         "developer/reviewer", "K1IndependentTimeCourseAssessment",
         "Simulation calibration output"),
    list("k1-repeated-subject-calibration", "plot_k1_repeated_subject_calibration",
         "R/13n-stage0-k1-repeated-subject-calibration.R", "repeated-subject calibration map",
         "Known-truth calibration diagnostic", "developer/reviewer",
         "K1RepeatedSubjectAssessment", "Simulation calibration output"),
    list("k1-revised-acceptance", "plot_k1_revised_acceptance",
         "R/13p-stage0-k1-revised-acceptance.R", "reviewed K=1 acceptance operating map",
         "Frozen acceptance-runner proof", "developer/reviewer",
         "K1RevisedAcceptanceSummary", "Acceptance runner proof")
)

contact_sheet_tile_labels <- .contact_sheet_tile_labels()

source_files <- unique(c(
    vapply(included, function(x) x[[3L]], character(1L)),
    vapply(excluded, function(x) x[[3L]], character(1L))
))
stopifnot(all(file.exists(source_files)))
source_digest <- vapply(
    source_files,
    function(path) digest::digest(file = path, algo = "sha256"),
    character(1L)
)
names(source_digest) <- source_files

public_plot_symbols <- unique(c(
    getNamespaceExports("landscapeR")[
        grepl("^plot_", getNamespaceExports("landscapeR"))
    ],
    unique(getNamespaceInfo(asNamespace("landscapeR"), "S3methods"))[
        grepl("^plot\\.", unique(getNamespaceInfo(asNamespace("landscapeR"),
            "S3methods")))
    ]
))
catalog_plot_symbols <- unique(c(
    vapply(included, function(x) x[[2L]], character(1L)),
    vapply(excluded, function(x) x[[2L]], character(1L))
))
missing_plot_symbols <- setdiff(public_plot_symbols, catalog_plot_symbols)
unexpected_plot_symbols <- setdiff(catalog_plot_symbols, public_plot_symbols)
if (length(missing_plot_symbols) || length(unexpected_plot_symbols)) {
    stop(
        paste(
            "public plot inventory is out of sync with package symbols:",
            paste(c(
                paste("missing", missing_plot_symbols),
                paste("unexpected", unexpected_plot_symbols)
            ), collapse = "; ")
        ), call. = FALSE
    )
}
if (!setequal(names(contact_sheet_tile_labels), vapply(included, `[[`, character(1L), 1L))) {
    stop("contact-sheet tile labels are out of sync with included plots", call. = FALSE)
}
if (any(nchar(contact_sheet_tile_labels, type = "chars") > 25L)) {
    stop("contact-sheet tile labels exceed the 25-character isolation budget", call. = FALSE)
}
utils::write.table(
    data.frame(
        panel = LETTERS[seq_along(contact_sheet_tile_labels)],
        id = names(contact_sheet_tile_labels),
        label = unname(contact_sheet_tile_labels),
        characters = nchar(contact_sheet_tile_labels, type = "chars"),
        stringsAsFactors = FALSE
    ),
    file.path(output_dir, "public-plot-contact-sheet-labels.tsv"),
    sep = "\t", quote = FALSE, row.names = FALSE
)

included_rows <- lapply(seq_along(included), function(i) {
    record <- included[[i]]
    id <- record[[1L]]
    plot_object <- record[[9L]]
    figure <- paste0(id, ".png")
    caption_file <- paste0(id, "-caption.txt")
    save_landscapeR_plot(plot_object, file.path(output_dir, figure),
                         width_mm = 100, height_mm = 100)
    caption <- scientific_caption(plot_object)
    if (!is.character(caption) || length(caption) != 1L ||
        is.na(caption) || !nzchar(caption)) {
        stop(sprintf("%s has no separate scientific caption", id), call. = FALSE)
    }
    writeLines(caption, file.path(output_dir, caption_file))
    data.frame(
        panel = LETTERS[[i]], id = id, included = TRUE,
        function_name = record[[2L]], source_file = record[[3L]],
        source_sha256 = unname(source_digest[[record[[3L]]]]),
        variant = record[[4L]], purpose = record[[5L]], audience = record[[6L]],
        input_class = record[[7L]], classification = record[[8L]],
        figure = figure, caption = caption_file, width_mm = 100L,
        height_mm = 100L, caption_separate = is.null(plot_object$labels$caption),
        exclusion_reason = "", stringsAsFactors = FALSE
    )
})
excluded_rows <- lapply(excluded, function(record) {
    data.frame(
        panel = "", id = record[[1L]], included = FALSE,
        function_name = record[[2L]], source_file = record[[3L]],
        source_sha256 = unname(source_digest[[record[[3L]]]]),
        variant = record[[4L]], purpose = record[[5L]], audience = record[[6L]],
        input_class = record[[7L]], classification = "excluded development/validation surface",
        figure = "", caption = "", width_mm = NA_integer_, height_mm = NA_integer_,
        caption_separate = NA, exclusion_reason = record[[8L]],
        stringsAsFactors = FALSE
    )
})
inventory <- do.call(rbind, c(included_rows, excluded_rows))
sampling_design_by_id <- c(
    "cross-sectional-atlas" = "cross-sectional",
    "component-proposal" = "cross-sectional",
    "permutation-evidence" = "cross-sectional",
    "association-abstention" = "cross-sectional",
    "component-abstention" = "cross-sectional",
    "independent-time-course" = "independent destructive time-course",
    "repeated-subject-time-course" = "repeated-subject time course",
    "stage1-components-categorical" = "design declared by input",
    "stage1-components-continuous" = "design declared by input",
    "stage1-decomposition" = "design declared by input",
    "stage1-spectrum" = "design declared by input",
    "stage2-potential" = "design declared by input",
    "stage2-potential-critical-points" = "design declared by input",
    "k1-operating-domain" = "independent destructive time-course calibration",
    "identifiability-primary" = "cross-sectional resampling",
    "identifiability-diagnostic" = "cross-sectional resampling",
    "identifiability-audit" = "cross-sectional resampling"
)
evidence_state_by_id <- c(
    "cross-sectional-atlas" = "exploratory scientific evidence",
    "component-proposal" = "exploratory scientific evidence",
    "permutation-evidence" = "descriptive search-aware evidence",
    "association-abstention" = "typed abstention evidence",
    "component-abstention" = "typed abstention evidence",
    "independent-time-course" = "exploratory scientific evidence",
    "repeated-subject-time-course" = "exploratory scientific evidence",
    "stage1-components-categorical" = "descriptive state-space evidence",
    "stage1-components-continuous" = "descriptive state-space evidence",
    "stage1-decomposition" = "descriptive state-space evidence",
    "stage1-spectrum" = "descriptive state-space evidence",
    "stage2-potential" = "exploratory state-transition evidence",
    "stage2-potential-critical-points" = "exploratory state-transition evidence",
    "k1-operating-domain" = "diagnostic operating-domain evidence",
    "identifiability-primary" = "diagnostic identifiability evidence",
    "identifiability-diagnostic" = "diagnostic identifiability evidence",
    "identifiability-audit" = "diagnostic identifiability evidence"
)
inventory$sampling_design <- unname(sampling_design_by_id[inventory$id])
inventory$evidence_state <- unname(evidence_state_by_id[inventory$id])
inventory$sampling_design[is.na(inventory$sampling_design)] <-
    "calibration/acceptance design not a user result"
inventory$evidence_state[is.na(inventory$evidence_state)] <-
    "development/validation output"
utils::write.table(
    inventory, file.path(output_dir, "public-plot-inventory.tsv"),
    sep = "\t", quote = FALSE, row.names = FALSE, na = ""
)

findings <- data.frame(
    finding = c("F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8"),
    severity = c(
        "follow-up issue", "pre-existing queued issue", "follow-up issue",
        "follow-up issue", "follow-up issue", "resolved",
        "follow-up issue", "follow-up issue"
    ),
    observation = c(
        "Independent-time-course interaction headings are clipped at the default 100 mm output.",
        "Independent-time-course facets do not yet carry the visible A/B panel labels required by the publication policy.",
        "Identifiability comparison markers and Stage 2 critical-point annotations can occlude one another or the landscape evidence.",
        "Stage 1 and Stage 2 group/time rugs rely on thin colour-only marks that weaken at reduced size and under colour-vision deficiency.",
        "Cross-sectional, abstention, and operating-domain captions need reconciliation with the rendered encodings and public analysis-unit wording.",
        "Concise tile labels replace long plot subtitles; full scientific captions remain separate.",
        "Continuous component plots emit an unknown fill-scale warning for a valid continuous metadata field.",
        "The abstention empty state and cross-figure layout tokens need a consistency pass after the higher-severity fixes."
    ),
    evidence = c(
        "independent-time-course.png; public-plot-contact-sheet.png",
        "independent-time-course.png; issue #220",
        "identifiability-diagnostic.png; identifiability-audit.png; stage2-potential-critical-points.png",
        "stage1-components-categorical.png; stage1-components-continuous.png; stage1-decomposition.png; stage2-potential*.png",
        "cross-sectional-atlas.png; cross-sectional-atlas-caption.txt; association-abstention.png; association-abstention-caption.txt; k1-operating-domain-caption.txt",
        "public-plot-contact-sheet.png",
        "script regeneration output: Ignoring unknown labels: fill",
        "association-abstention.png; public-plot-contact-sheet.png"
    ),
    follow_up = c(
        "issue #227",
        "issue #220",
        "issue #229",
        "issue #230",
        "issue #231",
        "issue #232 (resolved in this proof)",
        "issue #228",
        "issue #233"
    ),
    stringsAsFactors = FALSE
)
utils::write.table(
    findings, file.path(output_dir, "audit-findings.tsv"),
    sep = "\t", quote = FALSE, row.names = FALSE
)

contact_sheet <- patchwork::wrap_plots(
    lapply(included, function(x) .contact_sheet_tile(x[[9L]], x[[1L]])),
    ncol = 4L, guides = "collect"
) + patchwork::plot_annotation(
    title = "landscapeR public-facing plot contact sheet",
    subtitle = paste(
        "Representative outputs generated from package source;",
        "panels are keyed to public-plot-inventory.tsv"
    ),
    tag_levels = "A",
    theme = ggplot2::theme(
        plot.title = ggplot2::element_text(face = "bold", size = 14),
        plot.subtitle = ggplot2::element_text(size = 9),
        plot.tag = ggplot2::element_text(face = "bold", size = 9),
        plot.margin = ggplot2::margin(5, 5, 5, 5)
    )
)
native_sheet <- file.path(output_dir, "public-plot-contact-sheet.png")
reduced_sheet <- file.path(output_dir, "public-plot-contact-sheet-reduced.png")
ggplot2::ggsave(
    native_sheet, contact_sheet, width = 360, height = 330,
    units = "mm", dpi = 300, bg = "white"
)
ggplot2::ggsave(
    reduced_sheet, contact_sheet, width = 270, height = 247.5,
    units = "mm", dpi = 300, bg = "white"
)

writeLines(c(
    "Figure 1. Public-facing landscapeR plot contact sheet.",
    "Panels A--Q show representative outputs from the current package source,",
    "with panel identity, concise tile labels, plotting function, input class,",
    "purpose, and separate",
    "scientific caption recorded in public-plot-inventory.tsv.",
    "Panels A--G cover component-association evidence across cross-sectional,",
    "independent-time-course, and repeated-subject designs. Panels H--M cover",
    "Stage 1 and Stage 2 state-space displays. Panel N covers the calibrated",
    "operating-domain diagnostic; panels O--Q cover the primary, diagnostic,",
    "and audit identifiability views.",
    "Excluded exported K=1 calibration and acceptance renderers are listed in the",
    "inventory with their development/validation boundary; they are not package",
    "user result figures.",
    "All included figures use the package scientific-caption accessor; the contact",
    "sheet is retained at native and reduced dimensions for tile-isolation QA; the",
    "sheet itself is an audit artifact and carries no scientific claim.",
    "The adversarial review found follow-up work rather than silently declaring the",
    "current visual language complete. Findings and issue links are recorded in",
    "audit-findings.tsv; the governing objective is scientific accuracy and usefulness",
    "through a coherent visual language that elevates scientific interpretation."
), file.path(output_dir, "public-plot-contact-sheet-caption.txt"))

manifest <- data.frame(
    artifact = c("public-plot-contact-sheet.png",
                 "public-plot-contact-sheet-reduced.png",
    "public-plot-contact-sheet-caption.txt",
                 "public-plot-contact-sheet-labels.tsv",
                 "public-plot-inventory.tsv",
                 "visual-review-framework.md",
                 "adversarial-review.md"),
    included_figures = length(included),
    excluded_exported_plotters = length(excluded),
    stringsAsFactors = FALSE
)
if (!file.exists(file.path(output_dir, "adversarial-review.md"))) {
    stop("adversarial-review.md must be present before rendering the proof", call. = FALSE)
}
utils::write.table(
    manifest, file.path(output_dir, "manifest.tsv"),
    sep = "\t", quote = FALSE, row.names = FALSE
)
writeLines(c(
    "# Issue #226 public-facing visual audit", "",
    "Generated from the current package source; source-file digests are recorded",
    "in public-plot-inventory.tsv.",
    "Tile-local labels and their bounded text budget are recorded in",
    "public-plot-contact-sheet-labels.tsv.",
    "",
    "The contact sheet is an audit surface, not a scientific result. Included",
    "figures are rendered by current package plotting functions from deterministic",
    "synthetic fixtures. Individual figures and captions are retained beside the",
    "sheet; the inventory records source-file digests and explicit exclusions.",
    "This is an audit gate, not a claim that every figure is publication-ready. The",
    "adversarial findings and queued follow-up issues are recorded in audit-findings.tsv.",
    "",
    "Review the native and reduced contact sheets. The checker enforces dimensions",
    "and the tile-label text budget; direct visual inspection remains mandatory.",
    "Tile-local labels are concise and isolated; full scientific captions remain",
    "in the inventory and separate files. Record inconsistent visual grammar, clipped labels, unreadable",
    "legends, caption mismatch, or public-language leaks as follow-up issues",
    "rather than silently changing them.",
    "",
    "Regenerate with:", "",
    "Rscript scripts/render-issue-226-contact-sheet.R"
), file.path(output_dir, "README.md"))

writeLines(c(
    "# Visual review framework",
    "",
    "The governing objective is scientific accuracy and usefulness, expressed",
    "through a coherent visual language that elevates scientific interpretation.",
    "Tufte and Wilke provide supporting design criteria; visual preference never",
    "overrides the evidence, estimand, uncertainty, or claim boundary:",
    "",
    "- **Scientific fidelity:** scales, positions, marks, annotations, and captions",
    "  must represent the retained evidence and its uncertainty without distortion.",
    "- **Interpretive usefulness:** the plot type and visual hierarchy must make the",
    "  declared scientific comparison legible and support the intended inference.",
    "- **Coherent visual grammar:** the same biological role should use the same",
    "  colour, shape, line, panel, and caption conventions across designs unless",
    "  a documented scientific distinction requires otherwise.",
    "- **Focused density:** remove decoration that does not support interpretation,",
    "  but retain data, uncertainty, and context needed to inspect the claim.",
    "- **Publication legibility:** inspect native 100 mm output and the reduced",
    "  contact sheet for clipping, overlap, unreadable legends, and inaccessible",
    "  encodings that could weaken interpretation.",
    "",
    "The framework is informed by:",
    "",
    "- Claus O. Wilke, *Fundamentals of Data Visualization*, Introduction:",
    "  https://clauswilke.com/dataviz/introduction.html",
    "- Edward R. Tufte, *The Visual Display of Quantitative Information*:",
    "  https://www.edwardtufte.com/book/the-visual-display-of-quantitative-information/",
    "- Edward R. Tufte, notes on data density and the shrink principle:",
    "  https://www.edwardtufte.com/notebook/"
), file.path(output_dir, "visual-review-framework.md"))
