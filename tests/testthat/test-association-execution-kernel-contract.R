.kernel_contract_adapter <- function(execute_component = NULL) {
    contract <- landscapeR:::.new_association_contract(
        sampling_designs = "cross_sectional",
        target_types = "binary",
        estimand = "fixture-effect",
        cohort_policy = "complete-fixture-observations",
        diagnostic_prefix = "fixture",
        abstention_statuses = "not-estimable",
        refit_policy = "none",
        evidence_version = "cross-sectional-v1"
    )
    if (is.null(execute_component)) {
        execute_component <- function(
            context,
            plan,
            work_item,
            component,
            component_label,
            scores
        ) {
            included <- rep(TRUE, length(scores))
            members <- data.frame(
                primary_sample = names(scores),
                included = included,
                stringsAsFactors = FALSE
            )
            association <- data.frame(
                metadata_field = work_item$metadata_field,
                component = component,
                component_label = component_label,
                estimand = "fixture-effect",
                estimate = as.numeric(component),
                effect_magnitude = as.numeric(component),
                reference_level = "control",
                comparison_level = "treatment",
                n_available = as.integer(length(scores)),
                n_missing = 0L,
                n_score_ties = 0L,
                n_target_ties = 2L,
                evidence_variant = "unadjusted",
                proposal_eligible = TRUE,
                nuisance_fields = "",
                cohort_digest = landscapeR:::.association_cohort_digest(
                    names(scores),
                    included
                ),
                design_digest = NA_character_,
                diagnostic = "fixture-estimable",
                p_value = component / 10,
                q_value = NA_real_,
                effect_conf_low = as.numeric(component),
                effect_conf_high = as.numeric(component),
                n_resamples = 0L,
                resample_failures = 0L,
                resampling_method = "none-requested",
                resampling_plan_digest = digest::digest(
                    list(
                        method = "none-requested",
                        component = component
                    ),
                    algo = "sha256",
                    serialize = TRUE
                ),
                evidence_status = "estimable-exploratory-only",
                .cohort_members = I(list(members)),
                stringsAsFactors = FALSE
            )
            observation <- data.frame(
                metadata_field = work_item$metadata_field,
                component = component,
                component_label = component_label,
                sample_index = seq_along(scores),
                primary_sample = names(scores),
                metadata_type = "categorical",
                metadata_value = rep(c("control", "treatment"), each = 2L),
                metadata_numeric = NA_real_,
                score = as.numeric(scores),
                atom_count = 1L,
                available = included,
                stringsAsFactors = FALSE
            )
            list(
                association_rows = association,
                observation_rows = observation,
                execution_records = list(),
                scientific_records = list(),
                display_records = list()
            )
        }
    }
    landscapeR:::.new_assoc_execution_adapter(
        id = "fixture-kernel-v1",
        sampling_design = "cross_sectional",
        prepare = function(context) {
            coordinates <- cbind(
                PC1 = setNames(1:4, sprintf("sample_%02d", 1:4)),
                PC2 = setNames(4:1, sprintf("sample_%02d", 1:4))
            )
            list(
                coordinate_matrix = coordinates,
                component_labels = colnames(coordinates),
                work_items = list(list(
                    id = "condition",
                    metadata_field = "condition"
                )),
                state = list(),
                strategy_contracts = list(fixture = contract),
                exclusion_rows = list(data.frame(
                    metadata_field = "sample_id",
                    reason = "identifier-field",
                    stringsAsFactors = FALSE
                ))
            )
        },
        execute_component = execute_component
    )
}

.kernel_contract_blueprint <- function(normalized) {
    contract <- landscapeR:::.new_association_contract(
        sampling_designs = "cross_sectional",
        target_types = "binary",
        estimand = "fixture-effect",
        cohort_policy = "complete-fixture-observations",
        diagnostic_prefix = "fixture",
        abstention_statuses = "not-estimable",
        refit_policy = "none",
        evidence_version = "cross-sectional-v1"
    )
    visual_evidence <- list(
        monotone_fit = landscapeR:::.monotone_fit_data(
            normalized$observations
        ),
        flexible_fit = landscapeR:::.flexible_fit_data(
            normalized$observations
        )
    )
    list(
        module = "cross-sectional-v1",
        contract_sampling_design = "cross_sectional",
        version = "1.0.0",
        dataset_id = "kernel-contract-fixture",
        associations = normalized$associations,
        observations = normalized$observations,
        exclusions = normalized$exclusions,
        cohort_members = normalized$cohort_members,
        sampling_design = cross_sectional(),
        input_digest = paste(rep("a", 64L), collapse = ""),
        state_space_digest = paste(rep("b", 64L), collapse = ""),
        compute_tier = "inspect",
        provenance = list(
            association_strategy = "fixture-strategy-v1",
            association_contracts = list(fixture = contract),
            package_version = as.character(
                utils::packageVersion("landscapeR")
            ),
            sampling_design = "cross_sectional",
            layer = "fixture",
            input_digest = paste(rep("a", 64L), collapse = ""),
            state_space_digest = paste(rep("b", 64L), collapse = ""),
            dataset_id = "kernel-contract-fixture",
            exchangeability = "independent",
            multiplicity = landscapeR:::.association_multiplicity_contract(),
            visual_evidence = visual_evidence,
            bootstrap_executions = list()
        ),
        evidence_status = "estimable-exploratory-only"
    )
}

test_that("the kernel owns traversal, accounting, and atlas assembly", {
    execution <- landscapeR:::.execute_assoc_components(
        .kernel_contract_adapter(),
        context = list()
    )
    atlas <- landscapeR:::.finalize_assoc_blueprint(
        .kernel_contract_blueprint(execution$normalized),
        "cross_sectional"
    )

    expect_s4_class(atlas, "MetadataAssociationAtlas")
    evidence <- atlas_associations(atlas)
    expect_identical(evidence$component, 1:2)
    expect_equal(evidence$q_value, c(0.2, 0.2))
    expect_identical(nrow(atlas_observations(atlas)), 8L)
    expect_identical(
        nrow(atlas_evidence_contract(atlas)$cohort_members),
        8L
    )
    expect_true(validObject(atlas))
})

test_that("invalid adapter output fails with a stable kernel condition", {
    adapter <- .kernel_contract_adapter(function(...) list())

    expect_error(
        landscapeR:::.execute_assoc_components(adapter, context = list()),
        "must return exactly",
        class = "association_execution_error"
    )
})

test_that("incidental adapter errors do not leak through the kernel", {
    adapter <- .kernel_contract_adapter(function(...) {
        stop("dependency detail")
    })

    expect_error(
        landscapeR:::.execute_assoc_components(adapter, context = list()),
        "adapter failed.*dependency detail",
        class = "association_execution_error"
    )
})

test_that("typed scientific abstention crosses the kernel unchanged", {
    std <- independent_time_course_fixture()
    stage1 <- stage_artifact(std, "stage1")
    specification <- independent_time_course_specification("batch")
    abstention <- landscapeR:::.new_association_abstention(
        std,
        stage1,
        specification,
        "fixture non-identifiable design",
        reason = "non-identifiable-design",
        interpretation_module = "independent-time-course-v1"
    )
    adapter <- .kernel_contract_adapter()
    adapter$prepare <- function(context) abstention

    result <- landscapeR:::.execute_assoc_components(
        adapter,
        context = list()
    )

    expect_identical(result, abstention)
    expect_s4_class(result, "AssociationAbstention")
})

test_that("malformed atlas blueprints fail with a stable kernel condition", {
    execution <- landscapeR:::.execute_assoc_components(
        .kernel_contract_adapter(),
        context = list()
    )
    blueprint <- .kernel_contract_blueprint(execution$normalized)
    blueprint$version <- "not-a-valid-atlas-version"

    expect_error(
        landscapeR:::.finalize_assoc_blueprint(
            blueprint,
            "cross_sectional"
        ),
        "adapter failed during atlas assembly",
        class = "association_execution_error"
    )
})

test_that("incompatible normalized rows fail with a stable kernel condition", {
    base_execute <- .kernel_contract_adapter()$execute_component
    adapter <- .kernel_contract_adapter(function(
        context,
        plan,
        work_item,
        component,
        component_label,
        scores
    ) {
        result <- base_execute(
            context,
            plan,
            work_item,
            component,
            component_label,
            scores
        )
        if (component == 2L) result$association_rows$unexpected <- "invalid"
        result
    })

    expect_error(
        landscapeR:::.execute_assoc_components(adapter, context = list()),
        "adapter failed during normalization",
        class = "association_execution_error"
    )
})
