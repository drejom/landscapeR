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

.k1_acceptance_seed_plan <- function() {
    data.frame(
        control = c("generic_double_well", "pure_noise", "single_well",
                    "aml_synchronized"),
        replicates_per_grid_cell = c(100L, 200L, 200L, 100L),
        stringsAsFactors = FALSE
    )
}

.k1_acceptance_protocol_payload <- function() {
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
                "smallest n passing every declared p cell for the generic",
                "positive and both negative controls"
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
                "1 + (first 13 hexadecimal digest digits modulo 2147483645)"
            ),
            collision_rule =
                "collision is a protocol failure; do not redraw or perturb"
        ),
        separation = list(
            disclosed_calibration_seeds = c(42L, 6701L, 6702L, 6703L),
            rule = paste(
                "acceptance seeds are unknowable until the phase-A merge",
                "commit exists and may not be derived or executed before then"
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

#' Return the frozen K=1 Stage 0 acceptance protocol
#'
#' This function exposes the complete phase-A protocol required by ADR 0016.
#' Constructing or validating it does not execute any acceptance replicate.
#'
#' @return A digest-bound `K1AcceptanceProtocol` list containing the frozen
#'   grids, metrics, thresholds, pass rules, and delayed seed-derivation plan.
#' @export
k1_acceptance_protocol <- function() {
    payload <- .k1_acceptance_protocol_payload()
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
    frozen <- .k1_acceptance_protocol_payload()
    observed <- unclass(protocol)
    digest_value <- observed$digest
    observed$digest <- NULL
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
