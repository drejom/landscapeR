#!/usr/bin/env Rscript

devtools::load_all(".", quiet = TRUE)
sys.source(
    file.path("tests", "testthat", "helper-independent-time-course.R"),
    envir = environment()
)
sys.source(
    file.path(
        "tests", "testthat",
        "helper-association-execution-fingerprint.R"
    ),
    envir = environment()
)

cross_fixture <- function() {
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
            mouse_id = sprintf("mouse_%02d", seq_len(n)),
            row.names = primary
        ),
        sampleMap = S4Vectors::DataFrame(
            assay = factor(rep("rna", n), levels = "rna"),
            primary = primary,
            colname = assay_ids
        )
    )
    std <- declare_sampling_design(std, cross_sectional())
    coordinates <- cbind(
        PC1 = seq_len(n),
        PC2 = rep(c(-1, 1), times = n / 2L)
    )
    md <- metadata(std)
    md$stage1 <- DecompositionResult(
        V_star = c(1, 0, 0, 0),
        sigma = 1,
        coords = list(coordinates[, 1L]),
        V_k = diag(4)[, 1:2, drop = FALSE],
        sigma_k = matrix(c(2, 1), nrow = 1L),
        coords_k = list(coordinates),
        k = 2L
    )
    metadata(std) <- md
    std
}

cross <- associate_metadata(
    cross_fixture(),
    non_analytical_fields = "mouse_id",
    dataset_id = "kernel-cross",
    n_resamples = 3L,
    seed = 17L,
    sequential_internal = TRUE
)
independent <- associate_metadata(
    independent_time_course_fixture(),
    specification = independent_time_course_specification("batch"),
    non_analytical_fields = "sample_id",
    dataset_id = "kernel-independent",
    n_resamples = 3L,
    seed = 17L,
    sequential_internal = TRUE
)
cross_partial_fixture <- cross_fixture()
colData(cross_partial_fixture)$condition[[2L]] <- NA
cross_partial <- associate_metadata(
    cross_partial_fixture,
    non_analytical_fields = "mouse_id",
    dataset_id = "kernel-cross-partial",
    n_resamples = 3L,
    seed = 17L,
    sequential_internal = TRUE
)
independent_partial_fixture <- independent_time_course_fixture()
colData(independent_partial_fixture)$batch[[2L]] <- NA
independent_partial <- associate_metadata(
    independent_partial_fixture,
    specification = independent_time_course_specification("batch"),
    non_analytical_fields = "sample_id",
    dataset_id = "kernel-independent-partial",
    n_resamples = 3L,
    seed = 17L,
    sequential_internal = TRUE
)
abstention_fixture <- independent_time_course_fixture()
colData(abstention_fixture)$day <- 0
abstention <- associate_metadata(
    abstention_fixture,
    specification = independent_time_course_specification("batch"),
    non_analytical_fields = "sample_id",
    dataset_id = "kernel-independent-abstain",
    n_resamples = 3L,
    seed = 17L,
    sequential_internal = TRUE
)

evidence <- data.frame(
    design = c(
        "cross-sectional", "independent-time-course",
        "cross-sectional", "independent-time-course",
        "independent-time-course"
    ),
    case = c("successful", "successful", "partial", "partial", "abstention"),
    identity_type = c(
        "exact-atlas-digest", "portable-scientific-fingerprint",
        "exact-atlas-digest", "portable-scientific-fingerprint",
        "typed-reason"
    ),
    observed = c(
        atlas_digest(cross),
        .assoc_exec_fingerprint(independent),
        atlas_digest(cross_partial),
        .assoc_exec_fingerprint(independent_partial),
        abstention@reason
    ),
    expected = c(
        "e9a80c9b4a59b685a78827a4affcb3288200df4f38008ac5333f10abb1081862",
        "2926e00771749c145c84b5a9a78a1e4c77a3c4eb4a706cb125c002156bc7e4c9",
        "44bc45c654ca7761513643ca2992af8c6382668014960a5ea43e8f11e33a9d04",
        "d1f6d0db0019a7df5badaddd02ba28eddde969d306db2be41e0a2646c0b1107d",
        "non-identifiable-design"
    ),
    stringsAsFactors = FALSE
)
if (!all(evidence$observed == evidence$expected)) {
    stop("Issue 210 evidence identity changed", call. = FALSE)
}

output_dir <- file.path(".github", "landing-proof", "issue-210")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
utils::write.table(
    evidence,
    file.path(output_dir, "evidence-equivalence.tsv"),
    sep = "\t",
    quote = FALSE,
    row.names = FALSE
)

nodes <- data.frame(
    x = c(0.9, 0.9, 3.3, 5.7, 5.7),
    y = c(2.0, 0.0, 1.0, 2.0, 0.0),
    width = c(1.65, 1.65, 2.0, 1.45, 1.45),
    height = c(0.78, 0.78, 1.4, 0.78, 0.78),
    label = c(
        "Cross-sectional\nrank association\nobservation bootstrap",
        "Independent time course\ncondition × time\ncell bootstrap",
        "Shared execution kernel\nstrategy validation\ncomponent traversal\naccounting and assembly",
        "Rank association\nevidence",
        "Trajectory interaction\nevidence"
    ),
    shared = c(FALSE, FALSE, TRUE, FALSE, FALSE),
    stringsAsFactors = FALSE
)
arrows <- data.frame(
    x = c(1.74, 1.74, 4.31, 4.31),
    y = c(2.0, 0.0, 1.35, 0.65),
    xend = c(2.29, 2.29, 4.96, 4.96),
    yend = c(1.35, 0.65, 2.0, 0.0)
)
plot <- ggplot2::ggplot() +
    ggplot2::geom_curve(
        data = arrows,
        ggplot2::aes(x = x, y = y, xend = xend, yend = yend),
        curvature = 0.08,
        linewidth = 0.55,
        colour = "#303030",
        arrow = grid::arrow(length = grid::unit(2.4, "mm"), type = "closed")
    ) +
    ggplot2::geom_rect(
        data = nodes,
        ggplot2::aes(
            xmin = x - width / 2,
            xmax = x + width / 2,
            ymin = y - height / 2,
            ymax = y + height / 2,
            colour = shared
        ),
        fill = "white",
        linewidth = 0.75,
        show.legend = FALSE
    ) +
    ggplot2::geom_text(
        data = nodes,
        ggplot2::aes(x = x, y = y, label = label),
        family = "sans",
        size = 2.65,
        lineheight = 1.0,
        colour = "#171717"
    ) +
    ggplot2::scale_colour_manual(values = c(`FALSE` = "#303030", `TRUE` = "#B2182B")) +
    ggplot2::coord_cartesian(
        xlim = c(-0.05, 6.45),
        ylim = c(-0.7, 2.7),
        clip = "off"
    ) +
    ggplot2::theme_void(base_family = "sans") +
    ggplot2::theme(
        plot.background = ggplot2::element_rect(fill = "white", colour = NA),
        panel.background = ggplot2::element_rect(fill = "white", colour = NA),
        plot.margin = ggplot2::margin(8, 8, 8, 8)
    )
ggplot2::ggsave(
    filename = file.path(output_dir, "association-execution-kernel.png"),
    plot = plot,
    device = ragg::agg_png,
    width = 140,
    height = 140,
    units = "mm",
    dpi = 300,
    background = "white"
)
cat("Verified and wrote issue 210 landing proof\n")
