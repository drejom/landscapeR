# Internal contract for the public-plot contact-sheet audit surface.

.contact_sheet_tile_labels <- function() {
    c(
        "cross-sectional-atlas" = "Association atlas",
        "component-proposal" = "Component proposal",
        "permutation-evidence" = "Permutation null",
        "association-abstention" = "Association abstention",
        "component-abstention" = "Component abstention",
        "independent-time-course" = "Independent time course",
        "repeated-subject-time-course" = "Repeated time course",
        "stage1-components-categorical" = "Stage 1: category",
        "stage1-components-continuous" = "Stage 1: time",
        "stage1-decomposition" = "Stage 1 coordinates",
        "stage1-spectrum" = "Stage 1 spectrum",
        "stage2-potential" = "Stage 2 potential",
        "stage2-potential-critical-points" = "Critical points",
        "k1-operating-domain" = "K=1 operating",
        "identifiability-primary" = "ID: primary",
        "identifiability-diagnostic" = "ID: diagnostic",
        "identifiability-audit" = "ID: audit"
    )
}

.contact_sheet_tile <- function(plot_object, tile_id) {
    labels <- .contact_sheet_tile_labels()
    if (!is.character(tile_id) || length(tile_id) != 1L ||
        is.na(tile_id) || !tile_id %in% names(labels)) {
        stop(sprintf("no contact-sheet label is defined for %s", tile_id),
             call. = FALSE)
    }
    label <- unname(labels[[tile_id]])
    if (!nzchar(label) || nchar(label, type = "chars") > 25L) {
        stop(sprintf("contact-sheet label is too long for %s", tile_id),
             call. = FALSE)
    }
    plot_object +
        ggplot2::labs(title = label, subtitle = NULL, caption = NULL) +
        ggplot2::theme(
            plot.title = ggplot2::element_text(
                face = "bold", size = 7, margin = ggplot2::margin(b = 2)
            ),
            plot.subtitle = ggplot2::element_blank(),
            plot.caption = ggplot2::element_blank(),
            plot.margin = ggplot2::margin(3, 3, 3, 3)
        )
}
