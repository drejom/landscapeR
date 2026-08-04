test_that("hogsvd_averaged and hogsvd_prereduced are registered", {
    strats <- list_strategies("Decomposer")
    expect_true("Decomposer:hogsvd_averaged"   %in% strats)
    expect_true("Decomposer:hogsvd_prereduced" %in% strats)
})

test_that("synthetic_control produces valid StateTransitionData", {
    std <- synthetic_control(n = 10L, p = 20L, K = 2L, signal = 30, seed = 1L)
    expect_s4_class(std, "StateTransitionData")
    expect_s4_class(std@ground_truth, "SubspaceGroundTruth")
    expect_equal(ncol(std@ground_truth@shared), 1L)
    expect_equal(length(std@ground_truth@exclusive), 2L)
    expect_equal(length(experiments(std)), 2L)
    expect_false(is.null(metadata(std)$control))
})

test_that("hogsvd_averaged recovers v_true exactly in noiseless rank-1 case", {
    # Noiseless: signal >> noise (noise_sd=0 would give NaN in BBP check; use tiny noise)
    std <- synthetic_control(n = 10L, p = 30L, K = 2L,
                              signal = 100, signal_spec = 5,
                              noise_sd = 0.001, seed = 7L)
    bm <- suppressWarnings(recovery_benchmark(std, "hogsvd_averaged"))
    expect_lt(bm$angle_deg, 1)   # < 1 degree
})

test_that("hogsvd_averaged returns stage_success with stage1 metadata", {
    std <- synthetic_control(n = 15L, p = 50L, K = 2L, signal = 40, seed = 2L)
    ctor <- get_strategy("Decomposer", "hogsvd_averaged")
    result <- suppressWarnings(decompose(ctor(), std))
    expect_s4_class(result, "StageResult")
    expect_equal(result@status, "success")
    s1 <- metadata(result@value)$stage1
    expect_false(is.null(s1))
    expect_s4_class(s1, "DecompositionResult")
    expect_equal(length(dr_V_star(s1)), 50L)
})

test_that("hogsvd_prereduced returns stage_success", {
    std <- synthetic_control(n = 15L, p = 50L, K = 2L, signal = 40, seed = 3L)
    ctor <- get_strategy("Decomposer", "hogsvd_prereduced")
    result <- suppressWarnings(decompose(ctor(), std))
    expect_equal(result@status, "success")
})

make_hogsvd_test_data <- function(feature_counts = c(8L, 8L),
                                  non_finite = FALSE,
                                  second_feature_ids = NULL,
                                  scale_factor = 1) {
    set.seed(121L)
    sample_ids <- paste0("s", seq_len(6L))
    experiments <- lapply(seq_along(feature_counts), function(i) {
        values <- matrix(
            scale_factor * stats::rnorm(
                feature_counts[[i]] * length(sample_ids)
            ),
            nrow = feature_counts[[i]],
            dimnames = list(
                paste0("g", seq_len(feature_counts[[i]])), sample_ids
            )
        )
        if (i == 2L && !is.null(second_feature_ids))
            rownames(values) <- second_feature_ids
        if (non_finite && i == 2L) values[[1L]] <- NA_real_
        SummarizedExperiment::SummarizedExperiment(
            assays = list(counts = values)
        )
    })
    names(experiments) <- paste0("layer", seq_along(experiments))
    mae <- MultiAssayExperiment::MultiAssayExperiment(
        experiments = MultiAssayExperiment::ExperimentList(experiments),
        colData = S4Vectors::DataFrame(row.names = sample_ids)
    )
    as(mae, "StateTransitionData")
}

test_that("legacy HO-GSVD adapters expose supported and unsupported outcomes", {
    cases <- list(
        supported = make_hogsvd_test_data(),
        heterogeneous_features = make_hogsvd_test_data(c(8L, 7L)),
        non_finite = make_hogsvd_test_data(non_finite = TRUE)
    )

    for (strategy_name in c("hogsvd_averaged", "hogsvd_prereduced")) {
        ctor <- get_strategy("Decomposer", strategy_name)
        supported <- suppressWarnings(decompose(ctor(), cases$supported))
        heterogeneous <- decompose(ctor(), cases$heterogeneous_features)
        non_finite <- decompose(ctor(), cases$non_finite)

        expect_equal(supported@status, "success", info = strategy_name)
        expect_equal(heterogeneous@status, "failure", info = strategy_name)
        expect_match(heterogeneous@reason, "heterogeneous feature spaces")
        expect_equal(non_finite@status, "failure", info = strategy_name)
        expect_match(non_finite@reason, "finite numeric")
    }
})

test_that("legacy HO-GSVD BBP warnings are stored and emitted on one line", {
    std <- make_hogsvd_test_data(scale_factor = 1e-6)
    for (strategy_name in c("hogsvd_averaged", "hogsvd_prereduced")) {
        ctor <- get_strategy("Decomposer", strategy_name)
        emitted <- NULL
        result <- withCallingHandlers(
            decompose(ctor(), std),
            warning = function(w) {
                emitted <<- c(emitted, conditionMessage(w))
                invokeRestart("muffleWarning")
            }
        )
        stored <- dr_warnings(metadata(result@value)$stage1)
        expect_length(stored, 1L)
        expect_identical(emitted, stored)
        expect_match(stored, "\\(n=6, p=8\\)")
        expect_false(any(grepl("\n", stored, fixed = TRUE)))
        expect_false(any(grepl("\r", stored, fixed = TRUE)))
    }
})

test_that("legacy HO-GSVD adapters require identical ordered feature identities", {
    cases <- list(
        different = paste0("other", seq_len(8L)),
        reordered = rev(paste0("g", seq_len(8L))),
        duplicated = rep("g", 8L)
    )
    for (strategy_name in c("hogsvd_averaged", "hogsvd_prereduced")) {
        ctor <- get_strategy("Decomposer", strategy_name)
        for (feature_ids in cases) {
            result <- decompose(
                ctor(), make_hogsvd_test_data(second_feature_ids = feature_ids)
            )
            expect_equal(result@status, "failure", info = strategy_name)
            expect_match(result@reason, "identical, unique, ordered")
        }
    }
})

test_that("legacy HO-GSVD adapters validate shared parameters consistently", {
    std <- make_hogsvd_test_data()
    bad_params <- list(
        list(center = NA),
        list(k_components = 0L),
        list(k_components = 1.5),
        list(k_components = Inf)
    )
    for (strategy_name in c("hogsvd_averaged", "hogsvd_prereduced")) {
        ctor <- get_strategy("Decomposer", strategy_name)
        for (params in bad_params) {
            result <- decompose(ctor(params), std)
            expect_equal(result@status, "failure", info = strategy_name)
        }
    }
})

test_that("legacy HO-GSVD adapters type external numerical failures", {
    testthat::local_mocked_bindings(
        .preReduce = function(...) stop("numerical backend unavailable")
    )
    std <- make_hogsvd_test_data()
    for (strategy_name in c("hogsvd_averaged", "hogsvd_prereduced")) {
        ctor <- get_strategy("Decomposer", strategy_name)
        result <- decompose(ctor(), std)
        expect_s4_class(result, "StageResult")
        expect_equal(result@status, "failure")
        expect_match(result@reason, "numerical backend unavailable")
    }
})

test_that("shared legacy execution preserves supported numerical results", {
    std <- make_hogsvd_test_data()
    matrices <- lapply(as.list(experiments(std)), function(e) t(assay(e)))
    svds <- .preReduce(matrices, center = TRUE)

    averaged <- suppressWarnings(decompose(
        get_strategy("Decomposer", "hogsvd_averaged")(list(k_components = 3L)),
        std
    ))
    sigma2 <- vapply(svds, function(s) s$d[[1L]]^2, numeric(1L))
    expected <- drop(vapply(svds, function(s) s$v[, 1L], numeric(8L)) %*% sigma2)
    expected <- expected / sqrt(sum(expected^2))
    expect_equal(dr_V_star(metadata(averaged@value)$stage1), expected)

    expected_V_k <- vapply(seq_len(3L), function(j) {
        weights <- vapply(svds, function(s) s$d[[j]]^2, numeric(1L))
        axis <- drop(vapply(svds, function(s) s$v[, j], numeric(8L)) %*% weights)
        axis / sqrt(sum(axis^2))
    }, numeric(8L))
    expect_equal(metadata(averaged@value)$stage1@V_k, expected_V_k)

    prereduced <- suppressWarnings(decompose(
        get_strategy("Decomposer", "hogsvd_prereduced")(list(k_components = 3L)),
        std
    ))
    best <- which.max(vapply(svds, function(s) s$d[[1L]], numeric(1L)))
    expect_equal(
        dr_V_star(metadata(prereduced@value)$stage1), svds[[best]]$v[, 1L]
    )
    expect_equal(
        metadata(prereduced@value)$stage1@V_k,
        svds[[best]]$v[, seq_len(3L), drop = FALSE]
    )
})

test_that("hogsvd_averaged angle improves with signal (above BBP)", {
    # p=50, n=20: BBP = (20*50)^0.25 = 5.6; use signals 10 and 50
    bm_lo <- suppressWarnings(
        recovery_benchmark(
            synthetic_control(n=20L, p=50L, K=2L, signal=10, seed=10L),
            "hogsvd_averaged"))
    bm_hi <- suppressWarnings(
        recovery_benchmark(
            synthetic_control(n=20L, p=50L, K=2L, signal=50, seed=10L),
            "hogsvd_averaged"))
    expect_lt(bm_hi$angle_deg, bm_lo$angle_deg)
})

test_that("decompose (hogsvd_averaged) fails with StageResult when schema_version is invalid", {
    std <- empty_std()
    std@schema_version <- "99.0.0"
    ctor <- get_strategy("Decomposer", "hogsvd_averaged")
    result <- decompose(ctor(), std)
    expect_s4_class(result, "StageResult")
    expect_equal(result@status, "failure")
})

test_that("decompose (hogsvd_prereduced) fails with StageResult when schema_version is invalid", {
    std <- empty_std()
    std@schema_version <- "99.0.0"
    ctor <- get_strategy("Decomposer", "hogsvd_prereduced")
    result <- decompose(ctor(), std)
    expect_s4_class(result, "StageResult")
    expect_equal(result@status, "failure")
})

test_that("decompose boundary failure fires without run_pipeline (direct call)", {
    std <- empty_std()
    std@schema_version <- "99.0.0"
    ctor <- get_strategy("Decomposer", "hogsvd_averaged")
    result <- decompose(ctor(), std)
    expect_s4_class(result, "StageResult")
    expect_equal(result@status, "failure")
    expect_match(result@reason, "schema mismatch|expected StateTransitionData", perl = FALSE)
})

test_that("multi-layer averaging: K=3 improves over K=2 at high signal", {
    # Reliable only when signal is clearly above BBP
    bm2 <- suppressWarnings(
        recovery_benchmark(
            synthetic_control(n=30L, p=50L, K=2L, signal=60, seed=20L),
            "hogsvd_averaged"))
    bm3 <- suppressWarnings(
        recovery_benchmark(
            synthetic_control(n=30L, p=50L, K=3L, signal=60, seed=20L),
            "hogsvd_averaged"))
    # K=3 should be at most a few degrees worse (seed variability), never much worse
    expect_lt(bm3$angle_deg, bm2$angle_deg + 5)
})

test_that("decompose returns DecompositionResult in metadata()$stage1", {
    std <- synthetic_control(n = 20L, p = 50L, K = 2L, signal = 30, seed = 1L)
    ctor <- get_strategy("Decomposer", "hogsvd_averaged")
    result <- suppressWarnings(decompose(ctor(), std))
    s1 <- metadata(result@value)$stage1
    expect_s4_class(s1, "DecompositionResult")
    expect_equal(length(dr_V_star(s1)), 50L)
})

# ---------------------------------------------------------------------------
# shared_axis() contract accessor tests
# ---------------------------------------------------------------------------

test_that("rank-deficient layer produces a warning stored in dr_warnings()", {
    # hogsvd_prereduced picks k from the best layer; give layer 2 fewer samples
    # so it has fewer singular values than layer 1.
    # Layer 1: n=10, p=50 -> thin SVD rank = min(9, 50) = 9
    # Layer 2: n=4,  p=50 -> thin SVD rank = min(3, 50) = 3
    # k_components = 6; prereduced picks best layer: k = min(6, 9) = 6
    # layer 2 has only 3 SVs -> k_eff=3 < k=6 -> rank-deficient warning fires.
    set.seed(42L)
    mat1 <- matrix(rnorm(10L * 50L), nrow = 50L, ncol = 10L)  # p x n
    mat2 <- matrix(rnorm(50L *  4L), nrow = 50L, ncol =  4L)
    feat_ids <- paste0("g", seq_len(50L))
    rownames(mat1) <- rownames(mat2) <- feat_ids
    samp1 <- paste0("s",  seq_len(10L))
    samp2 <- paste0("s2", seq_len( 4L))
    colnames(mat1) <- samp1
    colnames(mat2) <- samp2
    se1 <- SummarizedExperiment::SummarizedExperiment(assays = list(counts = mat1))
    se2 <- SummarizedExperiment::SummarizedExperiment(assays = list(counts = mat2))
    # Provide an explicit sampleMap so MAE can map disjoint sample sets
    all_samps <- c(samp1, samp2)
    smap <- S4Vectors::DataFrame(
        # MultiAssayExperiment requires assay as a factor -- passing character
        # triggers its own internal as.factor() coercion warning at construction.
        assay   = factor(c(rep("layer1", length(samp1)), rep("layer2", length(samp2)))),
        primary = all_samps,
        colname = all_samps
    )
    col_df <- S4Vectors::DataFrame(row.names = all_samps)
    mae <- MultiAssayExperiment::MultiAssayExperiment(
        experiments = MultiAssayExperiment::ExperimentList(layer1 = se1, layer2 = se2),
        colData     = col_df,
        sampleMap   = smap
    )
    std <- as(mae, "StateTransitionData")
    ctor   <- get_strategy("Decomposer", "hogsvd_prereduced")
    result <- suppressWarnings(decompose(ctor(list(k_components = 6L)), std))
    expect_equal(result@status, "success")
    s1 <- metadata(result@value)$stage1
    expect_s4_class(s1, "DecompositionResult")
    rd_warns <- dr_warnings(s1)
    expect_true(any(grepl("rank-deficient", rd_warns)),
        info = paste("Expected rank-deficient warning; got:", paste(rd_warns, collapse = "; ")))
    # The warning should name the shortfall
    expect_true(any(grepl("only.*of.*requested components available", rd_warns)))
})

# ---------------------------------------------------------------------------
# shared_axis() contract accessor tests
# ---------------------------------------------------------------------------

test_that("shared_axis(dr, j=1) returns V_k[,1]", {
    p <- 10L; k <- 3L; K <- 2L
    V_k     <- matrix(rnorm(p * k), nrow = p, ncol = k)
    sigma_k <- matrix(runif(K * k), nrow = K, ncol = k)
    coords_k <- lapply(seq_len(K), function(i) matrix(rnorm(5L * k), nrow = 5L, ncol = k))
    dr <- DecompositionResult(
        V_star   = V_k[, 1L],
        sigma    = sigma_k[, 1L],
        coords   = lapply(coords_k, function(m) m[, 1L]),
        warnings = character(0),
        V_k      = V_k,
        sigma_k  = sigma_k,
        coords_k = coords_k,
        k        = k
    )
    expect_equal(shared_axis(dr, j = 1L), V_k[, 1L])
})

test_that("shared_axis(dr, j=2) returns V_k[,2]", {
    p <- 10L; k <- 3L; K <- 2L
    V_k     <- matrix(rnorm(p * k), nrow = p, ncol = k)
    sigma_k <- matrix(runif(K * k), nrow = K, ncol = k)
    coords_k <- lapply(seq_len(K), function(i) matrix(rnorm(5L * k), nrow = 5L, ncol = k))
    dr <- DecompositionResult(
        V_star   = V_k[, 1L],
        sigma    = sigma_k[, 1L],
        coords   = lapply(coords_k, function(m) m[, 1L]),
        warnings = character(0),
        V_k      = V_k,
        sigma_k  = sigma_k,
        coords_k = coords_k,
        k        = k
    )
    expect_equal(shared_axis(dr, j = 2L), V_k[, 2L])
})

test_that("shared_axis() default (j=1) matches dr_V_star()", {
    p <- 8L; k <- 2L; K <- 2L
    V_k     <- matrix(rnorm(p * k), nrow = p, ncol = k)
    sigma_k <- matrix(runif(K * k), nrow = K, ncol = k)
    coords_k <- lapply(seq_len(K), function(i) matrix(rnorm(4L * k), nrow = 4L, ncol = k))
    dr <- DecompositionResult(
        V_star   = V_k[, 1L],
        sigma    = sigma_k[, 1L],
        coords   = lapply(coords_k, function(m) m[, 1L]),
        warnings = character(0),
        V_k      = V_k,
        sigma_k  = sigma_k,
        coords_k = coords_k,
        k        = k
    )
    expect_equal(shared_axis(dr), dr_V_star(dr))
})

# ---------------------------------------------------------------------------
# Issue #23: Provenance persistence
# ---------------------------------------------------------------------------

test_that("hogsvd_averaged: exactly one ProvenanceStep in StageResult@provenance", {
    std  <- synthetic_control(n = 15L, p = 50L, K = 2L, signal = 40, seed = 2L)
    ctor <- get_strategy("Decomposer", "hogsvd_averaged")
    result <- suppressWarnings(decompose(ctor(), std))
    expect_equal(result@status, "success")
    expect_length(result@provenance, 1L)
    expect_true(is(result@provenance[[1L]], "ProvenanceStep"))
})

test_that("hogsvd_averaged: ProvenanceStep is also persisted in returned StateTransitionData@provenance", {
    std  <- synthetic_control(n = 15L, p = 50L, K = 2L, signal = 40, seed = 2L)
    ctor <- get_strategy("Decomposer", "hogsvd_averaged")
    result <- suppressWarnings(decompose(ctor(), std))
    expect_equal(result@status, "success")
    prov <- result@value@provenance
    expect_length(prov, 2L)
    expect_true(is(prov[[2L]], "ProvenanceStep"))
    expect_equal(prov[[2L]]@stage, "decompose")
    expect_equal(prov[[2L]]@implementation, "hogsvd_averaged")
    expect_equal(prov[[2L]]@status, "success")
})

test_that("hogsvd_prereduced: exactly one ProvenanceStep in StageResult@provenance", {
    std  <- synthetic_control(n = 15L, p = 50L, K = 2L, signal = 40, seed = 3L)
    ctor <- get_strategy("Decomposer", "hogsvd_prereduced")
    result <- suppressWarnings(decompose(ctor(), std))
    expect_equal(result@status, "success")
    expect_length(result@provenance, 1L)
    expect_true(is(result@provenance[[1L]], "ProvenanceStep"))
})

test_that("hogsvd_prereduced: ProvenanceStep is also persisted in returned StateTransitionData@provenance", {
    std  <- synthetic_control(n = 15L, p = 50L, K = 2L, signal = 40, seed = 3L)
    ctor <- get_strategy("Decomposer", "hogsvd_prereduced")
    result <- suppressWarnings(decompose(ctor(), std))
    expect_equal(result@status, "success")
    prov <- result@value@provenance
    expect_length(prov, 2L)
    expect_true(is(prov[[2L]], "ProvenanceStep"))
    expect_equal(prov[[2L]]@stage, "decompose")
    expect_equal(prov[[2L]]@implementation, "hogsvd_prereduced")
    expect_equal(prov[[2L]]@status, "success")
})

test_that("hogsvd_averaged: StageResult@provenance is not a StateTransitionData", {
    std  <- synthetic_control(n = 15L, p = 50L, K = 2L, signal = 40, seed = 2L)
    ctor <- get_strategy("Decomposer", "hogsvd_averaged")
    result <- suppressWarnings(decompose(ctor(), std))
    expect_equal(result@status, "success")
    expect_false(is(result@provenance[[1L]], "StateTransitionData"))
})

test_that("hogsvd_averaged provenance hashes the pre-stage input deterministically", {
    std <- synthetic_control(n = 15L, p = 50L, K = 2L, signal = 40, seed = 4L)
    input_hashes <- c(
        omic_layers = digest::digest(experiments(std)),
        sample_map = digest::digest(sampleMap(std))
    )
    ctor <- get_strategy("Decomposer", "hogsvd_averaged")
    result <- suppressWarnings(decompose(ctor(), std))

    step <- result@provenance[[1L]]
    expect_identical(step@input_hashes, input_hashes)
    expect_true(is.na(step@timestamp))

    same_std <- synthetic_control(n = 15L, p = 50L, K = 2L, signal = 40, seed = 4L)
    same_result <- suppressWarnings(decompose(ctor(), same_std))
    expect_identical(result@value, same_result@value)
    expect_equal(step@params$sampling_design$kind, "cross_sectional")
})
