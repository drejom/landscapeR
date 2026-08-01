expect_holm_multiplicity <- function(atlas) {
    contract <- atlas_provenance(atlas)$multiplicity
    expect_identical(contract, landscapeR:::.association_multiplicity_contract())
    associations <- atlas_associations(atlas)
    families <- interaction(
        associations$metadata_field,
        associations$evidence_variant,
        drop = TRUE,
        lex.order = TRUE
    )
    for (family_level in levels(families)) {
        index <- families == family_level
        expect_equal(
            associations$q_value[index],
            stats::p.adjust(associations$p_value[index], method = "holm")
        )
    }
    expect_match(
        gsub("\\s+", " ", scientific_caption(plot(atlas))),
        "Holm correction"
    )
    invisible(atlas)
}
