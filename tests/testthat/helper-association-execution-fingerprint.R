.assoc_exec_normalize <- function(value) {
    if (is.data.frame(value)) {
        value[] <- lapply(value, .assoc_exec_normalize)
        rownames(value) <- NULL
        return(value)
    }
    if (is.factor(value)) return(as.character(value))
    if (is.numeric(value) && !is.integer(value)) return(round(value, 6L))
    if (is.list(value)) {
        return(lapply(value, .assoc_exec_normalize))
    }
    value
}

.assoc_exec_fingerprint <- function(atlas) {
    provenance <- atlas_provenance(atlas)
    stable_provenance <- intersect(
        c(
            "association_strategy", "association_contracts",
            "sampling_design", "exchangeability", "multiplicity",
            "interpretation_module", "primary_evidence_variant",
            "display_trajectory_variant", "analysis_cohort",
            "analysis_cohort_exclusions", "time_course_cells",
            "time_course_missing_cells", "time_course_missing_cell_count",
            "time_course_display_state"
        ),
        names(provenance)
    )
    evidence <- list(
        version = atlas@version,
        dataset_id = atlas@dataset_id,
        associations = atlas_associations(atlas),
        observations = atlas_observations(atlas),
        exclusions = atlas_exclusions(atlas),
        cohort_members = atlas_evidence_contract(atlas)$cohort_members,
        sampling_design = atlas@sampling_design@kind,
        input_digest = atlas@input_digest,
        state_space_digest = atlas@state_space_digest,
        compute_tier = atlas@compute_tier,
        evidence_status = atlas@evidence_status,
        provenance = provenance[stable_provenance]
    )
    digest::digest(
        .assoc_exec_normalize(evidence),
        algo = "sha256",
        serialize = TRUE
    )
}
