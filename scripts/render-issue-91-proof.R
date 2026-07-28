devtools::load_all(quiet = TRUE)

output_dir <- file.path(".github", "landing-proof", "issue-91")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

n <- 8L
primary <- sprintf("sample_%02d", seq_len(n))
assay_ids <- sprintf("rna_%02d", seq_len(n))
se <- SummarizedExperiment::SummarizedExperiment(
    assays = list(logcounts = matrix(
        seq_len(4L * n),
        nrow = 4L,
        dimnames = list(sprintf("gene_%02d", 1:4), assay_ids)
    ))
)
std <- StateTransitionData(
    experiments = list(rna = se),
    colData = S4Vectors::DataFrame(
        condition = factor(
            rep(c("control", "treatment"), each = n / 2L),
            levels = c("control", "treatment")
        ),
        sample_id = primary,
        row.names = primary
    ),
    sampleMap = S4Vectors::DataFrame(
        assay = factor(rep("rna", n), levels = "rna"),
        primary = primary,
        colname = assay_ids
    )
)
std <- declare_sampling_design(std, cross_sectional())
coords <- cbind(
    PC1 = c(-1.4, -1.1, -0.8, -0.4, 0.5, 0.8, 1.1, 1.4),
    PC2 = c(-0.6, 0.4, -0.2, 0.5, -0.4, 0.3, -0.5, 0.6)
)
md <- metadata(std)
md$stage1 <- DecompositionResult(
    V_star = c(1, 0, 0, 0),
    sigma = 1,
    coords = list(coords[, 1L]),
    V_k = diag(4)[, 1:2, drop = FALSE],
    sigma_k = matrix(c(2, 1), nrow = 1L),
    coords_k = list(coords),
    k = 2L
)
metadata(std) <- md

specification <- analysis_specification(
    id = "issue-91-proof",
    target_field = "condition",
    target_type = "binary",
    reference_level = "control",
    comparison_level = "treatment"
)
atlas <- associate_metadata(
    std,
    specification = specification,
    non_analytical_fields = "sample_id",
    dataset_id = "issue-91-synthetic",
    n_resamples = 19L,
    seed = 9101L
)
proposal <- propose_component(atlas, n_permutations = 19L, seed = 9102L)
save_landscapeR_plot(
    plot(atlas),
    file.path(output_dir, "cross-sectional-atlas.png")
)
save_landscapeR_plot(
    plot(proposal),
    file.path(output_dir, "component-proposal.png")
)

confounded <- std
colData(confounded)$batch <- colData(confounded)$condition
confounded_specification <- analysis_specification(
    id = "issue-91-confounded",
    target_field = "condition",
    target_type = "binary",
    reference_level = "control",
    comparison_level = "treatment",
    nuisance_fields = "batch"
)
abstention_atlas <- associate_metadata(
    confounded,
    specification = confounded_specification,
    non_analytical_fields = "sample_id",
    dataset_id = "issue-91-confounded"
)
abstention <- propose_component(abstention_atlas)
save_landscapeR_plot(
    plot(abstention),
    file.path(output_dir, "typed-abstention.png")
)

contract <- atlas_evidence_contract(atlas)
contract_lines <- c(
    paste("version:", contract$version),
    paste("sampling_design:", contract$sampling_design),
    paste(
        "row_counts:",
        paste(names(contract$row_counts), contract$row_counts, collapse = ", ")
    ),
    paste(
        "digests:",
        paste(
            names(contract$digests),
            substr(contract$digests, 1L, 16L),
            collapse = ", "
        )
    ),
    paste(
        "cohort_members:",
        nrow(contract$cohort_members),
        "normalized rows"
    ),
    "",
    paste(capture.output(print(contract$cohorts, row.names = FALSE)), collapse = "\n")
)
writeLines(contract_lines, file.path(output_dir, "evidence-contract.txt"))
