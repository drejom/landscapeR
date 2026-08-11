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
    }
    plan
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
            !version %in% c("1", "2")) {
        .k1_acceptance_protocol_abort(
            "version must identify readable K=1 acceptance protocol 1 or 2"
        )
    }
    if (identical(version, "1")) {
        .k1_acceptance_protocol_v1_payload()
    } else {
        .k1_acceptance_protocol_v2_payload()
    }
}

#' Return the frozen K=1 Stage 0 acceptance protocol
#'
#' This function exposes a complete reviewed protocol required by ADR 0016.
#' Constructing or validating it does not execute any acceptance replicate.
#'
#' @param version readable protocol version. Version 2 is the current protocol;
#'   version 1 remains available as superseded historical evidence.
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
