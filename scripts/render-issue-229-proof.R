#!/usr/bin/env Rscript

# Reproducible native and reduced-size proof for issue #229.
suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))

output_dir <- file.path(".github", "landing-proof", "issue-229")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

cross_sectional_fixture <- function() {
    primary <- sprintf("sample_%02d", seq_len(10L))
    assay_ids <- sprintf("rna_%02d", seq_len(10L))
    data <- StateTransitionData(
        experiments = list(rna = SummarizedExperiment::SummarizedExperiment(
            assays = list(logcounts = matrix(
                seq_len(50L), nrow = 5L,
                dimnames = list(sprintf("gene_%02d", 1:5), assay_ids)
            ))
        )),
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
    md <- metadata(data)
    md$stage1 <- DecompositionResult(
        V_star = c(1, 0, 0, 0, 0), sigma = 1,
        coords = list(matrix(seq(-1.5, 1.5, length.out = 10L), ncol = 1L)),
        V_k = diag(5)[, 1:2, drop = FALSE],
        sigma_k = matrix(c(2, 1), nrow = 1L),
        coords_k = list(cbind(
            PC1 = seq(-1.5, 1.5, length.out = 10L),
            PC2 = c(-0.8, 0.4, -0.3, 0.6, 0.1, -0.5, 0.5, -0.2, 0.7, -0.4)
        )),
        k = 2L
    )
    metadata(data) <- md
    data
}

cross_data <- cross_sectional_fixture()
specification <- analysis_specification(
    id = "Issue 229 identifiability fixture", target_field = "condition",
    target_type = "binary", reference_level = "control",
    comparison_level = "treatment"
)
config <- new(
    "PipelineConfig",
    strategies = list(Decomposer = "svd"),
    params = list(svd = list(center = TRUE, k_components = 2L)),
    dataset = "Issue 229 identifiability fixture",
    analysis = specification
)
discovery <- decompose(
    get_strategy("Decomposer", "svd")(config@params$svd), cross_data
)
atlas <- associate_metadata(
    discovery@value, specification = specification,
    non_analytical_fields = "sample_id",
    dataset_id = "Issue 229 identifiability fixture"
)
assessed <- assess_component_identifiability(
    data = cross_data, proposal = propose_component(atlas),
    config = config, non_analytical_fields = "sample_id",
    n_resamples = 9L, seed = 22901L, sequential_internal = TRUE
)

identifiability <- plot_component_identifiability(
    assessed, view = "diagnostic"
)
identifiability_caption <- scientific_caption(identifiability)

state_data <- synthetic_control(
    n = 40L, p = 500L, K = 2L, signal = 30, seed = 22902L
)
stage1 <- suppressWarnings(
    decompose(get_strategy("Decomposer", "hogsvd_averaged")(), state_data)
)@value
stage2 <- estimate_dynamics(
    get_strategy("DynamicsEstimator", "kde_logdensity")(), stage1
)@value
stage2_metadata <- metadata(stage2)
stage2_metadata$stage2$wells <- c(-1, 1)
stage2_metadata$stage2$barriers <- 0
metadata(stage2) <- stage2_metadata
stage2 <- prepare_plot_evidence(stage2, stage = "stage2")
potential <- plot_potential(
    stage2, colour_by = "planted_group", show_critical_points = TRUE
)
potential_caption <- scientific_caption(potential)

before_identifiability <- file.path(
    ".github", "landing-proof", "issue-226", "identifiability-diagnostic.png"
)
before_potential <- file.path(
    ".github", "landing-proof", "issue-226",
    "stage2-potential-critical-points.png"
)
stopifnot(file.exists(before_identifiability), file.exists(before_potential))
file.copy(
    before_identifiability,
    file.path(output_dir, "identifiability-before.png"), overwrite = TRUE
)
file.copy(
    before_potential,
    file.path(output_dir, "stage2-potential-before.png"), overwrite = TRUE
)

save_landscapeR_plot(
    identifiability, file.path(output_dir, "identifiability.png"),
    width_mm = 100, height_mm = 100
)
save_landscapeR_plot(
    identifiability, file.path(output_dir, "identifiability-reduced.png"),
    width_mm = 80, height_mm = 80
)
save_landscapeR_plot(
    potential, file.path(output_dir, "stage2-potential.png"),
    width_mm = 100, height_mm = 100
)
save_landscapeR_plot(
    potential, file.path(output_dir, "stage2-potential-reduced.png"),
    width_mm = 80, height_mm = 80
)
writeLines(
    identifiability_caption,
    file.path(output_dir, "identifiability-caption.txt")
)
writeLines(
    potential_caption,
    file.path(output_dir, "stage2-potential-caption.txt")
)
writeLines(
    c(
        "Issue #229 visual proof", "",
        "The before images are retained issue #226 native artifacts, copied",
        "verbatim to preserve the observed overplotting failure.", "",
        "The after images use the same scientific evidence. Identifiability",
        "comparison series are separated at shared evidence positions. Stage 2",
        "critical-point symbols are offset only for display and connected by",
        "dashed stems to their exact stored coordinates. Native 100 mm and",
        "reduced 80 mm renderings are both retained for inspection.", "",
        "Regenerate with: Rscript scripts/render-issue-229-proof.R"
    ),
    file.path(output_dir, "README.md")
)
