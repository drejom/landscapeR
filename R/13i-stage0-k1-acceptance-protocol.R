# Stage 0 K=1 acceptance protocol
#
# Phase A of issue #51 freezes the complete protocol without executing any
# acceptance replicate. Acceptance execution and immutable evidence publication
# are deliberately separate later phases.

.k1_acceptance_protocol_abort <- function(message) {
    stop(structure(
        list(message = message, call = NULL),
        class = c("k1_acceptance_protocol_error", "error", "condition")
    ))
}

.k1_acceptance_seed_plan <- function(version = "1") {
    plan <- data.frame(
        control = c("generic_double_well", "pure_noise", "single_well",
                    "aml_synchronized"),
        replicates_per_grid_cell = c(100L, 200L, 200L, 100L),
        stringsAsFactors = FALSE
    )
    if (identical(version, "2")) {
        plan <- rbind(
            plan,
            data.frame(
                control = "shared_baseline_missing_cells",
                replicates_per_grid_cell = 100L,
                stringsAsFactors = FALSE
            )
        )
    } else if (version %in% c("3", "4")) {
        plan <- data.frame(
            control = c(
                "independent_time_course", "repeated_subject",
                "high_dimensional_signal", "high_dimensional_null"
            ),
            replicates_per_grid_cell = rep(100L, 4L),
            stringsAsFactors = FALSE
        )
    }
    plan
}

.k1_calibration_manifest_payload <- function(issue) {
    specification <- switch(as.character(issue),
        `189` = list(
            run_seed = 18900L,
            task_id = unlist(lapply(c(
                "balanced_1", "balanced_2", "balanced_3", "unequal_1_2_3",
                "isolated_library_failure", "missing_internal_cell"
            ), function(id) sprintf("template=%s;replicate=%04d", id, 1:5))),
            child_scheme = paste(
                "generator and association seeds are task-stream state",
                "element 2 plus 0:1"
            ),
            source_sha256 =
                "4f7cd7fcb598fd7e637015f8eed068df68be61a6cc594cb42531f72fd3b7cdb8"
        ),
        `190` = list(
            run_seed = 19000L,
            task_id = unlist(lapply(c(
                "complete", "isolated_observation_loss", "terminal_dropout",
                "condition_dependent_loss"
            ), function(id) sprintf("template=%s;replicate=%04d", id, 1:5))),
            child_scheme = paste(
                "generator, association, proposal, and resampling seeds are",
                "task-stream state element 2 plus 0:3"
            ),
            source_sha256 =
                "5b14bc7854cb60028a6c69950ecb455adb632b01f74166b32d62447d4c760ea7"
        ),
        `191` = {
            grid <- expand.grid(
                regime_id = c(
                    "fixed_total_spike", "fixed_sparse", "growing_coherent",
                    "correlated_modules", "null_near_null"
                ),
                p = c(100L, 500L), signal_ratio = c(0, 0.75, 1.25),
                replicate_index = 1:3,
                KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
            )
            grid <- grid[
                grid$regime_id != "null_near_null" |
                    grid$signal_ratio <= 0.75, , drop = FALSE
            ]
            list(
                run_seed = 19100L,
                task_id = sprintf(
                    "regime=%s;p=%d;ratio=%g;replicate=%04d",
                    grid$regime_id, grid$p, grid$signal_ratio,
                    grid$replicate_index
                ),
                child_scheme = paste(
                    "sha256 task-stream plus task-id and each of generator,",
                    "association, proposal, and resampling"
                ),
                source_sha256 =
                    "ff3719eca4c9105c6419869bdf2b05dabafcab10cda7e71c772af219a3b29163"
            )
        },
        .k1_acceptance_protocol_abort("unknown calibration manifest issue")
    )
    streams <- lapply(
        specification$task_id,
        function(id) .derive_task_stream(specification$run_seed, id)
    )
    child_seeds <- switch(as.character(issue),
        `189` = lapply(streams, function(stream) {
            stats::setNames(
                as.integer(stream[[2L]] + 0:1),
                c("generator", "association")
            )
        }),
        `190` = lapply(streams, function(stream) {
            stats::setNames(
                as.integer(stream[[2L]] + 0:3),
                c("generator", "association", "proposal", "resampling")
            )
        }),
        `191` = Map(function(stream, id) {
            children <- c("generator", "association", "proposal", "resampling")
            stats::setNames(vapply(children, function(child) {
                .k1_high_dimensional_child_seed(
                    stream, paste0(id, ":", child)
                )
            }, integer(1L)), children)
        }, streams, specification$task_id)
    )
    payload <- list(
        schema_version = "k1-calibration-rng-manifest-v1",
        issue = as.integer(issue),
        run_seed = specification$run_seed,
        task_count = length(specification$task_id),
        task_seed_scheme = "sha256-lecuyer-rejection-state-v2",
        task_id = specification$task_id,
        task_stream = streams,
        child_seed_scheme = specification$child_scheme,
        child_seeds = child_seeds,
        source_script_sha256_assertion = specification$source_sha256,
        digest_contract = "sha256 of this ordered R list before manifest_digest"
    )
    c(payload, list(manifest_digest = digest::digest(payload, algo = "sha256")))
}

.k1_validate_calibration_manifest_payload <- function(payload) {
    required <- c(
        "schema_version", "issue", "run_seed", "task_count",
        "task_seed_scheme", "task_id", "task_stream", "child_seed_scheme",
        "child_seeds", "source_script_sha256_assertion", "digest_contract",
        "manifest_digest"
    )
    if (!is.list(payload) || !identical(names(payload), required) ||
            !identical(payload$schema_version,
                "k1-calibration-rng-manifest-v1") ||
            !payload$issue %in% c(189L, 190L, 191L) ||
            !identical(payload$task_count, length(payload$task_id)) ||
            !identical(payload$task_count, length(payload$task_stream)) ||
            !identical(payload$task_count, length(payload$child_seeds)) ||
            anyDuplicated(payload$task_id)) {
        .k1_acceptance_protocol_abort(
            "calibration RNG manifest structure is invalid"
        )
    }
    expected <- .k1_calibration_manifest_payload(payload$issue)
    if (!identical(payload, expected)) {
        .k1_acceptance_protocol_abort(
            "calibration RNG manifest does not reproduce from its contract"
        )
    }
    unsigned <- payload
    observed_digest <- unsigned$manifest_digest
    unsigned$manifest_digest <- NULL
    if (!identical(
            digest::digest(unsigned, algo = "sha256"), observed_digest
        )) {
        .k1_acceptance_protocol_abort(
            "calibration RNG manifest digest does not verify"
        )
    }
    invisible(TRUE)
}

.k1_acceptance_protocol_v3_payload <- function() {
    independent_templates <- c(
        "balanced_1", "balanced_2", "balanced_3", "unequal_1_2_3",
        "isolated_library_failure", "missing_internal_cell"
    )
    repeated_templates <- c(
        "complete", "isolated_observation_loss", "terminal_dropout",
        "condition_dependent_loss"
    )
    signal_regimes <- c(
        "fixed_total_spike", "fixed_sparse", "growing_coherent",
        "correlated_modules"
    )
    feature_counts <- c(100L, 1000L, 10000L)
    signal_ratios <- c(0.75, 1, 1.25)
    null_ratios <- c(0, 0.75)
    replicate_count <- 100L
    workload <- c(
        independent_time_course = length(independent_templates) *
            length(feature_counts),
        repeated_subject = length(repeated_templates) *
            length(feature_counts),
        high_dimensional_signal = length(signal_regimes) *
            length(feature_counts) * length(signal_ratios),
        high_dimensional_null = length(feature_counts) * length(null_ratios)
    ) * replicate_count
    reserved <- sort(unique(c(
        42:45, 50:51, 6701:6705,
        18900:18909, 19000:19009, 19100:19109,
        867530900:867530907
    )))
    list(
        artifact_version = "3",
        protocol_id = "k1-stage0-acceptance-v3",
        protocol_status = "frozen_before_acceptance",
        claim_status = "predeclared_acceptance_protocol_only",
        governing_decisions = c("ADR-0002", "ADR-0016", "ADR-0020"),
        calibration_evidence = list(
            reviewed_issues = c(189L, 190L, 191L),
            historical_negative_acceptance_issue = 67L,
            historical_artifact =
                "k1-stage0-acceptance-v2-780f4b10ea21923a",
            review_conclusion = paste(
                "sampling design, high-dimensional signal regime, target-axis",
                "recovery, and downstream estimability require separate",
                "evidence; historical version 2 remains unchanged"
            )
        ),
        strategies = list(
            decomposer = "svd",
            component_interpretation =
                "registered_sampling_design_strategy"
        ),
        execution_contracts = list(
            version = "k1-stage0-revised-acceptance-runner-v1",
            parameter_resolution = paste(
                "use these normalized values exactly; package defaults and",
                "caller overrides are forbidden"
            ),
            svd = list(center = TRUE, k_components = 2L),
            backend = paste(
                "backend-independent targets graph with future, crew, hprcc,",
                "and Slurm; one outer task per independent replicate"
            ),
            internal_parallelism = "sequential within each outer task"
        ),
        grids = list(
            independent_time_course = list(
                template_ids = independent_templates,
                feature_counts = feature_counts,
                fixed = list(
                    noise_sd = 0.15, time_signal = 8,
                    condition_time_signal = 3
                )
            ),
            repeated_subject = list(
                template_ids = repeated_templates,
                feature_counts = feature_counts,
                fixed = list(
                    noise_sd = 0.03, time_signal = 8,
                    condition_time_signal = 3
                )
            ),
            high_dimensional_signal = list(
                regime_ids = signal_regimes,
                feature_counts = feature_counts,
                signal_ratios = signal_ratios,
                signal_parameterization = list(
                    reference_p = 100L,
                    coefficient = paste(
                        "signal_strength = signal_ratio times the",
                        "regime-specific covariance-adjusted noise reference",
                        "evaluated at n=24 and reference_p=100"
                    ),
                    effective_ratio = paste(
                        "signal_strength times planted loading norm divided by",
                        "the regime-specific recovery boundary at the executed p"
                    )
                ),
                fixed = list(
                    n = 24L, informative_features = 10L, noise_sd = 1,
                    module_correlation = 0.6
                )
            ),
            high_dimensional_null = list(
                regime_ids = "null_near_null",
                feature_counts = feature_counts,
                signal_ratios = null_ratios,
                signal_parameterization = list(
                    reference_p = 100L,
                    coefficient = paste(
                        "signal_strength = signal_ratio times the independent",
                        "Gaussian noise reference at n=24 and reference_p=100"
                    ),
                    effective_ratio = paste(
                        "signal_strength divided by the independent-Gaussian",
                        "recovery boundary at the executed p"
                    )
                ),
                fixed = list(
                    n = 24L, informative_features = 10L, noise_sd = 1,
                    module_correlation = 0.6
                )
            )
        ),
        thresholds = list(
            target_axis_recovery = list(
                canonical_metric = "absolute_loading_cosine",
                minimum = 0.90,
                principal_angle_role = "descriptive_equivalent_only"
            ),
            supported_cell = list(
                minimum_recovery_probability = 0.90,
                minimum_wilson_95_lower_bound = 0.80
            ),
            null_control = list(
                maximum_recovery_probability = 0.05,
                maximum_wilson_95_upper_bound = 0.10
            )
        ),
        outcome_states = c(
            "recovered_and_estimable",
            "recovered_downstream_nonestimable",
            "recovery_below_threshold",
            "recovery_not_evaluable",
            "execution_failure"
        ),
        pass_rules = list(
            execution = paste(
                "every requested replicate remains in immutable accounting;",
                "support requires completion and recovery evaluability rates",
                "of 1.00; an execution failure is never excluded or scientific",
                "evidence"
            ),
            recovery = paste(
                "classify each declared cell using absolute loading cosine",
                "alone; a principal angle may describe the same one-dimensional",
                "property but cannot impose a second gate; recovery probability",
                "and its Wilson interval use all requested replicates as the",
                "denominator, with unevaluable or failed tasks not recovered"
            ),
            downstream_nonestimability = paste(
                "report a typed downstream non-estimability rate separately",
                "and only among replicates whose planted axis was recovered;",
                "it is not decomposition failure"
            ),
            operating_region = paste(
                "a supported cell meets both supported-cell recovery bounds;",
                "a null cell must meet both null-control bounds; all other",
                "executed cells are unsupported or indeterminate as stated"
            ),
            design_expectations = list(
                repeated_estimable = c(
                    "complete", "isolated_observation_loss"
                ),
                repeated_typed_nonestimable = c(
                    "terminal_dropout", "condition_dependent_loss"
                ),
                independent = paste(
                    "estimability is empirical and conditional on recovery;",
                    "no thin or damaged template is presumed supported"
                )
            ),
            advancement = paste(
                "exploratory real-data K=1 advances only for an experiment",
                "inside at least one supported, design-compatible cell after",
                "all null controls and artifact verification pass"
            ),
            out_of_domain = paste(
                "designs, feature counts, signal regimes, covariance regimes,",
                "or missingness patterns outside the declared grid remain",
                "out of domain; no universal sample-size rule is inferred"
            ),
            negative_result = paste(
                "no supported compatible cell is a valid structured negative",
                "result and cannot trigger changes on these seeds"
            )
        ),
        resampling = list(
            repeated_axis_resamples = 19L,
            high_dimensional_axis_resamples = 19L,
            independent_biological_unit =
                "one independently collected synthetic animal",
            repeated_biological_unit =
                "one repeatedly observed synthetic mouse",
            repeated_resampling_unit = "complete subject trajectory"
        ),
        seed_plan = .k1_acceptance_seed_plan("3"),
        seed_derivation = list(
            reveal_value = "reviewed version 3 protocol merge commit SHA-1",
            hidden_until = "version 3 protocol merge",
            algorithm = "sha256-merge-commit-indexed-block-v3",
            task_order = paste(
                "frozen control order; template or regime order; feature-count",
                "order; signal-ratio order; ascending replicate index"
            ),
            block_stride = 8L,
            minimum_seed_root = 200000L,
            collision_rule = paste(
                "each task receives one disjoint eight-integer block; every",
                "derived task stream and child seed must avoid every stream in",
                "the digest-bound calibration manifests and every historical",
                "acceptance stream or validation fails"
            )
        ),
        separation = list(
            reserved_calibration_rng_streams = as.integer(reserved),
            calibration_stream_manifests = data.frame(
                issue = c(189L, 190L, 191L),
                run_seed = c(18900L, 19000L, 19100L),
                task_count = c(30L, 20L, 84L),
                task_seed_scheme = rep(
                    "sha256-lecuyer-rejection-state-v2", 3L
                ),
                child_seed_derivation = c(
                    "generator seed is task-stream state element 2",
                    "generator/association/proposal/resampling are task-stream state element 2 plus 0:3",
                    "sha256 task-stream plus task-id and child-name"
                ),
                stream_manifest_digest = c(
                    "df1f0b0fc79d1fb2f7df9a272b85f5c45e3bd3946daccd554b13298df29cf610",
                    "ac136b9e0cab29f7a24b797910a4771cfe8129dde12d9a0e33c6aeb18a8b834b",
                    "ea41582cda89d34cc3a301f7f0a0f4d510b8794a868b87bef964f190678ac5b8"
                ),
                source_script_sha256 = c(
                    "4f7cd7fcb598fd7e637015f8eed068df68be61a6cc594cb42531f72fd3b7cdb8",
                    "5b14bc7854cb60028a6c69950ecb455adb632b01f74166b32d62447d4c760ea7",
                    "ff3719eca4c9105c6419869bdf2b05dabafcab10cda7e71c772af219a3b29163"
                ),
                stringsAsFactors = FALSE
            ),
            reserved_historical_acceptance_ranges = data.frame(
                protocol_id = "k1-stage0-acceptance-v2",
                first_stream = 1505953920L,
                last_stream = 1506021917L,
                manifest_digest = paste0(
                    "ce5b129f09cdc7c0e4a50ad929f0b640b7db8ae6b6d406293",
                    "b5e7b81a247417c"
                ),
                stringsAsFactors = FALSE
            ),
            historical_acceptance_protocols = c(
                "k1-stage0-acceptance-v1", "k1-stage0-acceptance-v2"
            ),
            rule = paste(
                "version 3 roots are unknowable before its reviewed merge;",
                "#67 and versions 1-2 remain immutable historical evidence;",
                "derived blocks must not overlap the recorded historical range"
            )
        ),
        workload = list(
            replicates_by_control = stats::setNames(
                as.list(as.integer(workload)), names(workload)
            ),
            total_replicates = as.integer(sum(workload))
        ),
        evidence_requirements = c(
            "replicate evidence", "typed cell summaries", "operating maps",
            "separate scientific captions", "runtime environment",
            "worker and collector provenance", "content hashes"
        ),
        provenance = list(
            stage = "freeze_protocol",
            contract = "K1AcceptanceProtocol",
            implementation = "k1_stage0_acceptance_v3",
            source_issue = 193L,
            source_specification =
                "docs/specs/k1-stage0-acceptance-protocol-v3.md",
            evidence_inputs = c(
                "issue-189 disclosed destructive-time-course calibration",
                "issue-190 disclosed repeated-subject calibration",
                "issue-191 disclosed high-dimensional calibration",
                "issue-67 immutable historical negative acceptance"
            ),
            acceptance_results_inspected = FALSE
        ),
        execution = list(
            phase = "definition_only",
            acceptance_execution_available = FALSE,
            publication = "post-merge immutable content-addressed artifact"
        )
    )
}

.k1_acceptance_protocol_v4_payload <- function() {
    payload <- .k1_acceptance_protocol_v3_payload()
    calibration_payloads <- lapply(
        c(189L, 190L, 191L), .k1_calibration_manifest_payload
    )
    invisible(lapply(
        calibration_payloads, .k1_validate_calibration_manifest_payload
    ))
    payload$artifact_version <- "4"
    payload$protocol_id <- "k1-stage0-acceptance-v4"
    payload$calibration_evidence$review_conclusion <- paste(
        "version 4 retains every version 3 scientific setting unchanged;",
        "only the retired acceptance seed set and historical RNG manifest",
        "authentication contract change"
    )
    payload$seed_derivation$reveal_value <-
        "reviewed version 4 protocol merge commit SHA-1"
    payload$seed_derivation$hidden_until <- "version 4 protocol merge"
    payload$seed_derivation$algorithm <-
        "sha256-merge-commit-indexed-block-v4"
    payload$separation$calibration_stream_manifests <- data.frame(
        issue = c(189L, 190L, 191L),
        run_seed = vapply(calibration_payloads, `[[`, integer(1L), "run_seed"),
        task_count = vapply(
            calibration_payloads, `[[`, integer(1L), "task_count"
        ),
        task_seed_scheme = vapply(
            calibration_payloads, `[[`, character(1L), "task_seed_scheme"
        ),
        stream_manifest_digest = vapply(
            calibration_payloads, `[[`, character(1L), "manifest_digest"
        ),
        source_script_sha256_assertion = vapply(
            calibration_payloads, `[[`, character(1L),
            "source_script_sha256_assertion"
        ),
        stringsAsFactors = FALSE
    )
    payload$separation$calibration_stream_manifests$manifest_payload <-
        I(calibration_payloads)
    payload$separation$historical_stream_authentication <- paste(
        "task IDs, L'Ecuyer states, and named child seeds reproduce from the",
        "self-describing payload before v4 seed reveal; source-script hashes",
        "are pinned historical assertions, not independent runtime identity"
    )
    payload$separation$retired_version3_seed_block <- list(
        protocol_merge_commit =
            "4d2ee67653c7de2f7caf2e52da4a8f7fa05ab111",
        protocol_digest = digest::digest(
            .k1_acceptance_protocol_v3_payload(), algo = "sha256"
        ),
        derivation_algorithm = "sha256-merge-commit-indexed-block-v3",
        first_seed_root = 664979464L,
        last_reserved_scalar_seed = 665037063L,
        task_count = 7200L,
        block_stride = 8L,
        status = "retired_after_early_task_execution"
    )
    payload$separation$rule <- paste(
        "version 4 roots are unknowable before its reviewed merge; version 3",
        "is retired in full and its disclosed scalar block, task identities,",
        "and derived streams remain reserved alongside #67 and calibrations"
    )
    payload$provenance$implementation <- "k1_stage0_acceptance_v4"
    payload$provenance$source_specification <-
        "docs/specs/k1-stage0-acceptance-protocol-v4.md"
    payload$provenance$evidence_inputs <- c(
        payload$provenance$evidence_inputs,
        "version 3 runner incident; no scientific outcomes used"
    )
    payload
}

.k1_acceptance_protocol_v5_payload <- function() {
    payload <- .k1_acceptance_protocol_v4_payload()
    payload$artifact_version <- "5"
    payload$protocol_id <- "k1-stage0-acceptance-v5"
    payload$calibration_evidence$review_conclusion <- paste(
        "version 5 retains every version 4 scientific setting unchanged;",
        "only the retired acceptance seed set and delayed seed-reveal",
        "identity change"
    )
    payload$seed_derivation$reveal_value <-
        "reviewed version 5 protocol merge commit SHA-1"
    payload$seed_derivation$hidden_until <- "version 5 protocol merge"
    payload$seed_derivation$algorithm <-
        "sha256-merge-commit-indexed-block-v5"
    payload$separation$retired_version4_seed_block <- list(
        protocol_merge_commit =
            "92db509aa1724cbeac62ac79d4e4858c94e5aa20",
        protocol_digest = digest::digest(
            .k1_acceptance_protocol_v4_payload(), algo = "sha256"
        ),
        derivation_algorithm = "sha256-merge-commit-indexed-block-v4",
        first_seed_root = 990320213L,
        last_reserved_scalar_seed = 990377812L,
        task_count = 7200L,
        block_stride = 8L,
        status = "retired_after_premerge_acceptance_execution"
    )
    payload$separation$development_fixture_seed_blocks <- list(
        repeated_subject_validator = list(
            task_id = "development-fixture=repeated-subject-validator",
            first_scalar_seed = 4242L,
            last_scalar_seed = 4249L,
            status = "reserved_non_acceptance_fixture"
        )
    )
    payload$separation$rule <- paste(
        "version 5 roots are unknowable before its reviewed merge; versions",
        "3 and 4 are retired in full, and their scalar blocks, task",
        "identities, and derived streams remain reserved alongside #67",
        "and calibration evidence"
    )
    payload$provenance$implementation <- "k1_stage0_acceptance_v5"
    payload$provenance$source_specification <-
        "docs/specs/k1-stage0-acceptance-protocol-v5.md"
    payload$provenance$acceptance_results_inspected <- TRUE
    payload$provenance$acceptance_outcomes_changed_science <- FALSE
    payload$provenance$evidence_inputs <- c(
        payload$provenance$evidence_inputs,
        paste(
            "version 4 premerge execution incident; result structure",
            "inspected, no scientific setting changed in response"
        )
    )
    payload
}

.k1_acceptance_protocol_v1_payload <- function() {
    list(
        artifact_version = "1",
        protocol_id = "k1-stage0-acceptance-v1",
        protocol_status = "frozen_before_acceptance",
        claim_status = "predeclared_acceptance_protocol_only",
        governing_decisions = c("ADR-0002", "ADR-0016", "ADR-0020"),
        strategies = list(
            decomposer = "svd",
            dynamics_estimator = "kde_logdensity",
            component_interpretation = "registered_sampling_design_strategy"
        ),
        execution_contracts = list(
            version = "k1-stage0-acceptance-runner-v1",
            parameter_resolution = paste(
                "use these normalized values exactly; package defaults and",
                "caller overrides are forbidden"
            ),
            svd = list(center = TRUE, k_components = 6L),
            kde_logdensity = list(
                n_grid = 512L,
                poly_degree = 6L,
                layer = 1L,
                pool_layers = TRUE,
                component = 1L,
                bandwidth_method = "hpi",
                bandwidth_value = NULL
            ),
            generic_double_well_analysis = list(
                target_field = "x_coord",
                target_type = "continuous",
                continuous_direction = "increasing",
                lifecycle = "confirmed",
                selected_component = 1L,
                proposal_decision = "accepted",
                claim_intent = "exploratory"
            ),
            negative_control_analysis = list(
                target_field = "target",
                target_type = "binary",
                reference_level = "reference",
                comparison_level = "comparison",
                nuisance_fields = character(),
                non_analytical_fields = character(),
                claim_intent = "exploratory"
            ),
            aml_synchronized_analysis = list(
                target_field = "condition",
                target_type = "binary",
                reference_level = "CTL",
                comparison_level = "CM",
                nuisance_fields = "batch",
                non_analytical_fields = c("mouse_id", "batch"),
                dropout_subjects = character(),
                atlas_resamples = 0L,
                claim_intent = "exploratory"
            ),
            provenance_requirement = paste(
                "acceptance evidence records protocol digest, runner contract",
                "version, package version, and source revision; changing a",
                "named generator, strategy, or normalized value requires a",
                "new reviewed protocol version"
            )
        ),
        generators = list(
            generic_double_well = "exact_cauchy_rejection_v1",
            pure_noise = list(
                id = "isotropic_gaussian_expression_v1",
                expression = "p by n independent N(0,1) values",
                metadata = paste(
                    "balanced binary target independently permuted from",
                    "expression; no nuisance field"
                ),
                sampling_design = "cross_sectional"
            ),
            single_well = list(
                id = "gaussian_coordinate_expression_v1",
                coordinate = "n independent N(0,1) values",
                embedding = paste(
                    "outer product with one seeded random unit feature loading",
                    "plus independent N(0,0.05^2) expression noise"
                ),
                metadata = paste(
                    "balanced binary target independently permuted from",
                    "coordinate and expression; no nuisance field"
                ),
                sampling_design = "cross_sectional"
            ),
            aml_synchronized = "k1_aml_longitudinal_v1"
        ),
        grids = list(
            generic_double_well = list(
                varying = list(
                    n = c(24L, 48L, 96L, 132L, 192L),
                    p = c(100L, 1000L, 10000L, 20000L)
                ),
                fixed = list(beta = 2, noise_sd = 0.05)
            ),
            negative_controls = list(
                varying = list(
                    n = c(48L, 96L, 132L, 192L),
                    p = c(100L, 1000L, 10000L, 20000L)
                ),
                fixed = list()
            ),
            aml_synchronized = list(
                varying = list(
                    subjects_per_condition = c(4L, 7L, 12L),
                    p = c(100L, 1000L, 10000L)
                ),
                fixed = list(
                    noise_sd = 0.03,
                    time_signal = 8,
                    disease_signal = 3,
                    times = c(0, 6, 10, 14.6, 19, 23.4, 27.6, 31.6,
                              34.7, 38.7, 43.6)
                )
            )
        ),
        thresholds = list(
            generic_double_well = list(
                maximum_subspace_angle_degrees = 15,
                maximum_mean_well_location_error = 0.15,
                maximum_barrier_location_error = 0.20,
                maximum_barrier_height_error = 0.50,
                required_wells = 2L,
                required_barriers = 1L
            ),
            negative_controls = list(
                false_double_well_definition = paste(
                    "at least two recovered wells and at least one intervening",
                    "barrier"
                ),
                maximum_false_double_well_rate_per_control_cell = 0.05,
                false_target_selection_definition = paste(
                    "a proposal-eligible coordinate with search-aware",
                    "maximum-effect permutation p <= 0.05 and axis recurrence",
                    ">= 0.80 under metadata independent of expression"
                ),
                maximum_false_target_selection_rate_per_control_cell = 0.05
            ),
            aml_synchronized = list(
                minimum_target_loading_cosine = 0.90,
                maximum_target_subspace_angle_degrees = 15,
                required_target_component = 2L,
                required_nuisance_component = 1L,
                required_proposal_rank = 1L,
                minimum_target_index_recurrence = 0.80,
                minimum_mean_matched_loading_cosine = 0.85,
                minimum_resample_completion_rate = 0.90,
                required_stage2_ineligibility_rate = 1,
                separately_reported_not_gated = c(
                    "orientation_recurrence", "rank_one_fraction",
                    "matched_fraction"
                )
            )
        ),
        pass_rules = list(
            replicate_success = "all control-specific thresholds pass",
            minimum_cell_pass_rate = 0.90,
            minimum_cell_wilson_95_lower_bound = 0.80,
            barrier_height_error = paste(
                "absolute error in dimensionless quasi-potential units against",
                "beta times the physical barrier height; beta=2 gives truth=2"
            ),
            grid_execution = paste(
                "Cartesian product of each control's varying fields only;",
                "fixed vector-valued parameters are applied intact to every",
                "cell; every replicate is run independently in every cell"
            ),
            negative_rate_denominator = paste(
                "all requested replicates within each negative-control family",
                "and grid cell; execution failures remain in the denominator"
            ),
            failed_execution = "failed replicate, never silently excluded",
            supported_minimum_n = paste(
                "smallest n in the shared positive/negative candidate set",
                "48,96,132,192 that passes every declared p cell for the",
                "generic positive and both negative controls; n=24 remains a",
                "positive thinness cell and cannot establish support alone"
            ),
            aml_gate = paste(
                "every declared subjects-per-condition by p cell passes;",
                "typed abstention is retained as a failed recovery replicate"
            )
        ),
        resampling = list(
            aml_identifiability_resamples = 99L,
            aml_permutations = 99L,
            negative_identifiability_resamples = 99L,
            negative_permutations = 99L,
            unit = "complete synthetic mouse trajectory",
            negative_unit = "independent biological observation",
            backend = "future-backed package execution seam"
        ),
        seed_plan = .k1_acceptance_seed_plan(),
        seed_derivation = list(
            reveal_value = "phase-A pull-request merge commit SHA-1",
            hidden_until = "phase-A protocol merge",
            algorithm = "sha256-merge-commit-cell-v1",
            canonical_cell_schemas = list(
                generic_double_well = c("n", "p"),
                pure_noise = c("n", "p"),
                single_well = c("n", "p"),
                aml_synchronized = c("subjects_per_condition", "p")
            ),
            canonical_cell_format = paste(
                "control=<name>; then schema fields as field=<base-10 integer>",
                "joined by semicolons; fixed parameters are excluded because",
                "they are already bound by protocol_digest"
            ),
            input = paste0(
                "protocol_id|protocol_digest|merge_commit|canonical_cell|",
                "replicate_index"
            ),
            integer_mapping = paste(
                "1 + (first 13 hexadecimal digest digits modulo 2147483644);",
                "the maximum is reserved below the strictest downstream",
                "seed-plus-three limit"
            ),
            acceptance_stream_offsets = list(
                generic_double_well = c(
                    state_coordinates = 0L, expression = 1L
                ),
                pure_noise = c(
                    generator = 0L, metadata = 1L,
                    permutations = 2L, identifiability = 3L
                ),
                single_well = c(
                    generator = 0L, metadata = 1L,
                    permutations = 2L, identifiability = 3L
                ),
                aml_synchronized = c(
                    generator = 0L, association = 1L,
                    permutations = 2L, identifiability = 3L
                )
            ),
            collision_rule = paste(
                "a derived root plus every control-specific stream offset",
                "must be disjoint from all reserved calibration RNG streams",
                "and all previously derived acceptance streams; collision is",
                "a protocol failure, never redrawn or perturbed"
            )
        ),
        separation = list(
            disclosed_calibration_root_seeds = c(
                42L, 50L, 6701L, 6702L, 6703L
            ),
            reserved_calibration_rng_streams = c(
                42L, 43L, 44L, 45L, 50L, 51L,
                6701L, 6702L, 6703L, 6704L, 6705L
            ),
            calibration_sources = c(
                "public generator/calibration defaults",
                "issue-50 development-log calibration seed 50",
                "issue-67 AML calibration/development seeds 6701:6703"
            ),
            rule = paste(
                "acceptance seeds are unknowable until the phase-A merge",
                "commit exists and may not be derived or executed before then;",
                "the later runner rejects every reserved-stream collision"
            )
        ),
        provenance = list(
            stage = "freeze_protocol",
            contract = "K1AcceptanceProtocol",
            implementation = "k1_stage0_acceptance_v1",
            source_issue = 51L,
            source_specification =
                "docs/specs/k1-stage0-acceptance-protocol-v1.md",
            evidence_inputs = c("issue-50 disclosed calibration",
                                "issue-67 disclosed calibration"),
            acceptance_results_inspected = FALSE
        ),
        execution = list(
            phase = "definition_only",
            acceptance_execution_available = FALSE,
            publication = "later immutable content-addressed artifact"
        )
    )
}

.k1_acceptance_protocol_v2_payload <- function() {
    payload <- .k1_acceptance_protocol_v1_payload()
    lower_tail <- c(8L, 12L, 16L, 24L, 48L, 96L, 132L, 192L)
    payload$artifact_version <- "2"
    payload$protocol_id <- "k1-stage0-acceptance-v2"
    payload$execution_contracts$version <-
        "k1-stage0-acceptance-runner-v2"
    payload$execution_contracts$shared_baseline_missing_cells_analysis <- list(
        target_field = "condition",
        target_type = "binary",
        reference_level = "control",
        comparison_level = "treated",
        time_field = "observed_time",
        expected_outcome = "non-identifiable-design",
        claim_intent = "exploratory"
    )
    payload$generators$shared_baseline_missing_cells <- list(
        id = "shared_baseline_missing_cells_v1",
        design = paste(
            "two conditions and four times; three independent biological",
            "units per observed cell; control observed only at the first",
            "time and treated observed at all four times"
        ),
        expected_outcome = paste(
            "typed non-identifiable-design abstention without duplicated",
            "controls or fabricated condition-by-time cells"
        )
    )
    payload$grids$generic_double_well$varying$n <- lower_tail
    payload$grids$negative_controls$varying$n <- lower_tail
    payload$grids$shared_baseline_missing_cells <- list(
        varying = list(design_cell = 1L),
        fixed = list(
            conditions = 2L,
            time_points = 4L,
            replicates_per_observed_cell = 3L,
            p = 1000L
        )
    )
    payload$thresholds$shared_baseline_missing_cells <- list(
        required_abstention_reason = "non-identifiable-design",
        required_missing_control_time_cells = 3L,
        required_unique_control_observations = 3L,
        required_total_observations = 15L
    )
    payload$pass_rules$supported_minimum_n <- paste(
        "smallest n in the shared positive/negative candidate set",
        "8,12,16,24,48,96,132,192 that passes every declared p cell for",
        "the generic positive and both negative controls"
    )
    payload$pass_rules$shared_baseline_missing_cells <- paste(
        "every requested replicate returns typed non-identifiable-design,",
        "retains three unique baseline controls exactly once, and exposes",
        "the three unobserved later control cells"
    )
    payload$seed_plan <- .k1_acceptance_seed_plan("2")
    payload$seed_derivation$canonical_cell_schemas$
        shared_baseline_missing_cells <- "design_cell"
    payload$seed_derivation$acceptance_stream_offsets$
        shared_baseline_missing_cells <- c(generation = 0L, association = 1L)
    payload$seed_derivation$algorithm <-
        "sha256-merge-commit-indexed-block-v2"
    payload$seed_derivation$reveal_value <-
        "reviewed version 2 protocol pull-request merge commit SHA-1"
    payload$seed_derivation$hidden_until <-
        "version 2 protocol merge"
    payload$seed_derivation$input <- paste0(
        "protocol_id|protocol_digest|merge_commit|seed-block; canonical ",
        "task ordinal follows frozen control, grid, and replicate order"
    )
    payload$seed_derivation$task_order <- paste(
        "seed-plan control order, then expand.grid varying-field order,",
        "then ascending replicate index"
    )
    payload$seed_derivation$block_stride <- 4L
    payload$seed_derivation$minimum_seed_root <- 100000L
    payload$seed_derivation$integer_mapping <- paste(
        "derive one merge-specific block start from the first 13",
        "hexadecimal digest digits; assign each canonical task one",
        "four-integer block by task ordinal; every stream remains within",
        "1..2147483644 and above all reserved calibration streams"
    )
    payload$seed_derivation$collision_rule <- paste(
        "indexed blocks guarantee disjoint acceptance streams; any",
        "duplicate or reserved stream remains a protocol failure"
    )
    payload$provenance$implementation <- "k1_stage0_acceptance_v2"
    payload$provenance$source_issue <- 177L
    payload$provenance$source_specification <-
        "docs/specs/k1-stage0-acceptance-protocol-v2.md"
    payload$provenance$evidence_inputs <- c(
        payload$provenance$evidence_inputs,
        "pre-execution lower-tail and shared-baseline design review"
    )
    payload$separation$rule <- paste(
        "version 2 acceptance seeds are unknowable until its reviewed merge",
        "commit exists and may not be derived or executed before then;",
        "the runner rejects every reserved-stream collision"
    )
    payload
}

.k1_acceptance_protocol_payload <- function(version = "2") {
    if (!is.character(version) || length(version) != 1L || is.na(version) ||
            !version %in% c("1", "2", "3", "4", "5")) {
        .k1_acceptance_protocol_abort(
            paste(
                "version must identify readable K=1 acceptance protocol",
                "1, 2, 3, 4, or 5"
            )
        )
    }
    if (identical(version, "1")) {
        .k1_acceptance_protocol_v1_payload()
    } else if (identical(version, "2")) {
        .k1_acceptance_protocol_v2_payload()
    } else if (identical(version, "3")) {
        .k1_acceptance_protocol_v3_payload()
    } else if (identical(version, "4")) {
        .k1_acceptance_protocol_v4_payload()
    } else {
        .k1_acceptance_protocol_v5_payload()
    }
}

#' Return the frozen K=1 Stage 0 acceptance protocol
#'
#' This function exposes a complete reviewed protocol required by ADR 0016.
#' Constructing or validating it does not execute any acceptance replicate.
#'
#' @param version readable protocol version. Version 2 remains the default for
#'   the historical runner; version 5 is the protocol-only refreeze of the
#'   revised acceptance science, versions 1 and 2 remain historical, and
#'   versions 3 and 4 are readable but their complete seed sets are retired.
#' @return A digest-bound `K1AcceptanceProtocol` list containing the frozen
#'   grids, metrics, thresholds, pass rules, and delayed seed-derivation plan.
#' @export
k1_acceptance_protocol <- function(version = "2") {
    payload <- .k1_acceptance_protocol_payload(version)
    out <- c(payload, list(
        digest = digest::digest(payload, algo = "sha256")
    ))
    class(out) <- c("K1AcceptanceProtocol", "list")
    out
}

#' Validate the frozen K=1 Stage 0 acceptance protocol
#'
#' @param protocol object returned by `k1_acceptance_protocol()`.
#' @return Invisibly `TRUE`, or throws `k1_acceptance_protocol_error`.
#' @export
validate_k1_acceptance_protocol <- function(
    protocol = k1_acceptance_protocol()
) {
    if (!inherits(protocol, "K1AcceptanceProtocol"))
        .k1_acceptance_protocol_abort(
            "protocol must inherit from K1AcceptanceProtocol"
        )
    observed <- unclass(protocol)
    digest_value <- observed$digest
    observed$digest <- NULL
    version <- switch(
        observed$protocol_id,
        `k1-stage0-acceptance-v1` = "1",
        `k1-stage0-acceptance-v2` = "2",
        `k1-stage0-acceptance-v3` = "3",
        `k1-stage0-acceptance-v4` = "4",
        `k1-stage0-acceptance-v5` = "5",
        .k1_acceptance_protocol_abort(
            "protocol does not identify a readable frozen definition"
        )
    )
    frozen <- .k1_acceptance_protocol_payload(version)
    if (!identical(observed, frozen))
        .k1_acceptance_protocol_abort(
            "protocol differs from the frozen K=1 acceptance definition"
        )
    expected_digest <- digest::digest(frozen, algo = "sha256")
    if (!is.character(digest_value) || length(digest_value) != 1L ||
            !identical(digest_value, expected_digest))
        .k1_acceptance_protocol_abort(
            "protocol digest does not match the frozen definition"
        )
    seed_plan <- frozen$seed_plan
    if (anyDuplicated(seed_plan$control) ||
            any(seed_plan$replicates_per_grid_cell < 1L))
        .k1_acceptance_protocol_abort(
            "seed plan must declare one positive replicate count per control"
        )
    invisible(TRUE)
}

#' @export
print.K1AcceptanceProtocol <- function(x, ...) {
    validate_k1_acceptance_protocol(x)
    cat("<K1AcceptanceProtocol>\n")
    cat("  id:", x$protocol_id, "\n")
    cat("  status:", x$protocol_status, "\n")
    cat("  acceptance execution:",
        if (isTRUE(x$execution$acceptance_execution_available))
            "available" else "not available", "\n")
    cat("  digest:", x$digest, "\n")
    invisible(x)
}
