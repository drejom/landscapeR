.assoc_exec_normalize <- function(value) {
    if (is.data.frame(value)) {
        value[] <- lapply(value, .assoc_exec_normalize)
        rownames(value) <- NULL
        return(value)
    }
    if (is.factor(value)) return(as.character(value))
    if (is.numeric(value) && !is.integer(value)) return(round(value, 5L))
    if (is.list(value)) {
        return(lapply(value, .assoc_exec_normalize))
    }
    value
}

.assoc_exec_fingerprint <- function(atlas) {
    provenance <- atlas_provenance(atlas)
    provenance$model_engine_version <- NULL
    if (is.list(provenance$evidence_contract)) {
        provenance$evidence_contract$digests <- NULL
    }
    provenance$time_course_models <- lapply(
        provenance$time_course_models,
        function(model) {
            for (variant in c(
                "unadjusted_uncertainty",
                "adjusted_uncertainty"
            )) {
                if (
                    is.list(model[[variant]]) &&
                        is.list(model[[variant]]$execution)
                ) {
                    model[[variant]]$execution$digest <- NULL
                }
            }
            model
        }
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
        provenance = provenance
    )
    digest::digest(
        .assoc_exec_normalize(evidence),
        algo = "sha256",
        serialize = TRUE
    )
}
