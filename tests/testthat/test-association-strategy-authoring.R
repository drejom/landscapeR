association_author_fixture <- function() {
    n <- 8L
    primary <- sprintf("sample_%02d", seq_len(n))
    assay_ids <- sprintf("rna_%02d", seq_len(n))
    target <- structure(
        rep(c("low", "middle", "high", "peak"), each = 2L),
        class = c("AssociationAuthorTarget", "character")
    )
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
            author_target = target,
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

if (!methods::isClass("AssociationAuthorFixtureStrategy")) {
    methods::setClass(
        "AssociationAuthorFixtureStrategy",
        contains = "AssociationStrategy"
    )
    methods::setMethod(
        "association_applicable",
        signature(
            strategy = "AssociationAuthorFixtureStrategy",
            data = "StateTransitionData",
            values = "ANY"
        ),
        function(strategy, data, values) {
            identical(data@sampling_design@kind, "cross_sectional") &&
                setequal(
                    unique(as.character(values[!is.na(values)])),
                    c("low", "middle", "high", "peak")
                )
        }
    )
    methods::setMethod(
        "association_contract",
        signature(strategy = "AssociationAuthorFixtureStrategy"),
        function(strategy) {
            structure(
                list(
                    version = "1.0.0",
                    sampling_designs = "cross_sectional",
                    target_types = "unsupported",
                    estimand = "fixture-ordinal-score",
                    cohort_policy = "available-independent-observations",
                    diagnostic_prefix = "author-fixture",
                    abstention_statuses = "not-estimable",
                    refit_policy = "biological-observation-index",
                    evidence_version = "cross-sectional-v1"
                ),
                class = "landscapeR_association_contract"
            )
        }
    )
    methods::setMethod(
        "associate_component",
        signature(
            strategy = "AssociationAuthorFixtureStrategy",
            scores = "numeric",
            values = "ANY"
        ),
        function(strategy, scores, values) {
            complete <- is.finite(scores) & !is.na(values)
            estimate <- suppressWarnings(stats::cor(
                scores[complete],
                match(values[complete], c("low", "middle", "high", "peak")),
                method = "spearman"
            ))
            list(
                estimand = "fixture-ordinal-score",
                estimate = unname(estimate),
                reference_level = NA_character_,
                comparison_level = NA_character_,
                n_available = sum(complete),
                n_score_ties = 0L,
                n_target_ties = 4L,
                p_value = NA_real_
            )
        }
    )
    methods::setMethod(
        "association_strategy_id",
        signature(strategy = "AssociationAuthorFixtureStrategy"),
        function(strategy) "author-fixture-v1"
    )
}

test_that("a narrow registered adapter works through associate_metadata", {
    key <- "AssociationStrategy:_author_fixture"
    provenance_key <- key
    on.exit({
        if (exists(key, landscapeR:::.registry, inherits = FALSE)) {
            rm(list = key, envir = landscapeR:::.registry)
        }
        if (exists(
            provenance_key,
            landscapeR:::.registry_provenance,
            inherits = FALSE
        )) {
            rm(list = provenance_key, envir = landscapeR:::.registry_provenance)
        }
    }, add = TRUE)
    register_strategy(
        "AssociationStrategy",
        "_author_fixture",
        function(params = list()) new("AssociationAuthorFixtureStrategy")
    )

    atlas <- associate_metadata(
        association_author_fixture(),
        non_analytical_fields = "sample_id",
        dataset_id = "author-contract-fixture",
        n_resamples = 3L,
        seed = 17L,
        sequential_internal = TRUE
    )

    expect_s4_class(atlas, "MetadataAssociationAtlas")
    expect_identical(
        atlas_provenance(atlas)$association_strategy,
        "author-fixture-v1"
    )
    contract <- atlas_provenance(atlas)$association_contracts[[
        "author-fixture-v1"
    ]]
    expect_identical(contract$estimand, "fixture-ordinal-score")
    expect_identical(
        contract$cohort_policy,
        "available-independent-observations"
    )
    expect_identical(contract$refit_policy, "biological-observation-index")
    evidence <- atlas_associations(atlas)
    expect_true(all(evidence$estimand == "fixture-ordinal-score"))
    expect_true(all(evidence$n_resamples == 3L))
    restored <- unserialize(serialize(atlas, NULL))
    expect_identical(
        atlas_provenance(restored)$association_contracts,
        atlas_provenance(atlas)$association_contracts
    )
})

if (!methods::isClass("MalformedAssociationAuthorStrategy")) {
    methods::setClass(
        "MalformedAssociationAuthorStrategy",
        contains = "AssociationStrategy"
    )
    methods::setMethod(
        "association_applicable",
        signature(
            strategy = "MalformedAssociationAuthorStrategy",
            data = "StateTransitionData",
            values = "ANY"
        ),
        function(strategy, data, values) {
            setequal(
                unique(as.character(values[!is.na(values)])),
                c("low", "middle", "high", "peak")
            )
        }
    )
    methods::setMethod(
        "association_contract",
        signature(strategy = "MalformedAssociationAuthorStrategy"),
        function(strategy) list(estimand = "incomplete")
    )
    methods::setMethod(
        "associate_component",
        signature(
            strategy = "MalformedAssociationAuthorStrategy",
            scores = "numeric",
            values = "ANY"
        ),
        function(strategy, scores, values) NULL
    )
    methods::setMethod(
        "association_strategy_id",
        signature(strategy = "MalformedAssociationAuthorStrategy"),
        function(strategy) "malformed-author-fixture"
    )
}

test_that("malformed registered contracts fail at the public workflow seam", {
    key <- "AssociationStrategy:_malformed_author_fixture"
    on.exit({
        if (exists(key, landscapeR:::.registry, inherits = FALSE)) {
            rm(list = key, envir = landscapeR:::.registry)
        }
        if (exists(key, landscapeR:::.registry_provenance, inherits = FALSE)) {
            rm(list = key, envir = landscapeR:::.registry_provenance)
        }
    }, add = TRUE)
    register_strategy(
        "AssociationStrategy",
        "_malformed_author_fixture",
        function(params = list()) new("MalformedAssociationAuthorStrategy")
    )

    expect_error(
        associate_metadata(
            association_author_fixture(),
            non_analytical_fields = "sample_id"
        ),
        "invalid contract.*must contain exactly",
        class = "landscapeR_validation_error"
    )
})
