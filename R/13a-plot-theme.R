# Canonical publication visual grammar

.landscapeR_scientific_caption_attribute <- "landscapeR_scientific_caption"

.with_scientific_caption <- function(plot, caption) {
    if (!inherits(plot, "ggplot")) {
        .stop_landscapeR_validation("plot must be a ggplot object")
    }
    if (!is.character(caption) || length(caption) != 1L ||
        is.na(caption) || !nzchar(caption)) {
        .stop_landscapeR_validation(
            "caption must be one non-empty string"
        )
    }
    attr(plot, .landscapeR_scientific_caption_attribute) <- caption
    plot
}

#' Retrieve a landscapeR scientific figure caption
#'
#' User-facing landscapeR plots carry their dynamically generated scientific
#' caption as metadata rather than drawing it inside the graphic. This accessor
#' returns that text for use as a true figure caption in Quarto, R Markdown,
#' manuscripts, or other publication systems.
#'
#' @param plot a ggplot object returned by a landscapeR plotting function.
#'
#' @return A single caption string, or `NULL` when the ggplot has no
#'   landscapeR scientific caption.
#' @export
scientific_caption <- function(plot) {
    if (!inherits(plot, "ggplot")) {
        .stop_landscapeR_validation("plot must be a ggplot object")
    }
    attr(plot, .landscapeR_scientific_caption_attribute, exact = TRUE)
}

#' Publication theme for landscapeR figures
#'
#' A restrained, publication-oriented theme built on
#' [ggplot2::theme_minimal()]. The default square aspect ratio is intended for
#' standalone scientific panels; set `square = FALSE` when composing a layout
#' that owns panel dimensions.
#'
#' @param base_size base font size in points. Defaults to 7 for final-size
#'   scientific figures.
#' @param base_family base font family. Defaults to Helvetica.
#' @param square logical; use a 1:1 panel aspect ratio.
#'
#' @return A ggplot2 theme.
#' @export
theme_landscapeR <- function(base_size = 7, base_family = "Helvetica",
                             square = TRUE) {
    if (!is.numeric(base_size) || length(base_size) != 1L ||
        !is.finite(base_size) || base_size <= 0) {
        .stop_landscapeR_validation("base_size must be one positive finite number")
    }
    if (!is.character(base_family) || length(base_family) != 1L ||
        is.na(base_family) || !nzchar(base_family)) {
        .stop_landscapeR_validation("base_family must be one non-empty string")
    }
    if (!is.logical(square) || length(square) != 1L || is.na(square)) {
        .stop_landscapeR_validation("square must be TRUE or FALSE")
    }

    ggplot2::theme_minimal(
        base_size = base_size,
        base_family = base_family
    ) +
        ggplot2::theme(
            text = ggplot2::element_text(
                family = base_family,
                colour = "#111111"
            ),
            plot.background = ggplot2::element_rect(
                fill = "white", colour = NA
            ),
            panel.background = ggplot2::element_rect(
                fill = "white", colour = NA
            ),
            panel.grid.major = ggplot2::element_blank(),
            panel.grid.minor = ggplot2::element_blank(),
            axis.line = ggplot2::element_line(
                colour = "#111111", linewidth = 0.3
            ),
            axis.ticks = ggplot2::element_line(
                colour = "#111111", linewidth = 0.3
            ),
            axis.ticks.length = grid::unit(1.5, "mm"),
            axis.title = ggplot2::element_text(
                colour = "#111111", size = base_size
            ),
            axis.text = ggplot2::element_text(
                colour = "#111111", size = base_size * 6 / 7
            ),
            strip.background = ggplot2::element_blank(),
            strip.text = ggplot2::element_text(
                colour = "#111111", face = "bold", size = base_size
            ),
            legend.position = "bottom",
            legend.justification = "left",
            legend.title = ggplot2::element_text(
                colour = "#111111", size = base_size
            ),
            legend.text = ggplot2::element_text(
                colour = "#111111", size = base_size * 6 / 7
            ),
            legend.key.height = grid::unit(3, "mm"),
            legend.key.width = grid::unit(5, "mm"),
            plot.margin = ggplot2::margin(4, 5, 4, 4),
            aspect.ratio = if (isTRUE(square)) 1 else NULL
        )
}

#' Canonical landscapeR colour palettes
#'
#' The default visual grammar is black, white, and grey. Red is reserved for a
#' declared focal target or nominated result. Blue appears as the negative end
#' of a signed diverging scale. General categorical and continuous palettes are
#' introduced only when the data require them.
#'
#' @param palette one of `"semantic"`, `"binary"`, or `"categorical"`.
#' @param n optional number of categorical colours requested. The categorical
#'   palette is generated from the same discrete Viridis policy used by the
#'   scale helpers and is not capped at eight levels.
#'
#' @return A character vector of hexadecimal colours.
#' @export
landscapeR_palette <- function(
    palette = c("semantic", "binary", "categorical"),
    n = NULL
) {
    palette <- .with_landscapeR_validation(match.arg(palette))
    semantic <- c(
        ink = "#111111",
        focal = "#C43C39",
        nuisance = "#8A8A8A",
        missing = "#EFEFEF",
        negative = "#356A88"
    )

    if (!identical(palette, "categorical") && !is.null(n)) {
        .stop_landscapeR_validation(
            "n is supported only for the categorical palette"
        )
    }
    if (identical(palette, "semantic")) return(semantic)
    if (identical(palette, "binary")) {
        values <- c(
            reference = unname(semantic[["ink"]]),
            focal = unname(semantic[["focal"]])
        )
    } else {
        if (is.null(n)) n <- 8L
        if (!is.numeric(n) || length(n) != 1L || !is.finite(n) ||
            n != as.integer(n) || n < 1L) {
            .stop_landscapeR_validation("n must be one positive integer")
        }
        return(
            viridisLite::viridis(
                as.integer(n),
                option = "D",
                end = 0.9
            )
        )
    }

    if (is.null(n)) return(values)
    if (!is.numeric(n) || length(n) != 1L || !is.finite(n) ||
        n != as.integer(n) || n < 1L) {
        .stop_landscapeR_validation("n must be one positive integer")
    }
    n <- as.integer(n)
    values[seq_len(n)]
}

.landscapeR_call_scale <- function(scale_fun, defaults, dots) {
    do.call(
        scale_fun,
        utils::modifyList(defaults, dots, keep.null = TRUE)
    )
}

.landscapeR_scale <- function(aesthetic, palette, reference_level = NULL,
                              focal_level = NULL, ...) {
    palette <- .with_landscapeR_validation(match.arg(
        palette,
        c("binary", "categorical", "continuous", "diverging")
    ))
    semantic <- landscapeR_palette("semantic")

    if (identical(palette, "binary")) {
        levels <- c(
            reference_level = reference_level,
            focal_level = focal_level
        )
        if (!is.character(levels) || anyNA(levels) ||
            any(!nzchar(levels)) || identical(levels[[1L]], levels[[2L]])) {
            .stop_landscapeR_validation(
                paste0(
                    "binary scales require distinct non-empty ",
                    "reference_level and focal_level"
                )
            )
        }
        scale_fun <- if (identical(aesthetic, "colour")) {
            ggplot2::scale_colour_manual
        } else {
            ggplot2::scale_fill_manual
        }
        values <- landscapeR_palette("binary")
        names(values) <- unname(levels)
        return(.landscapeR_call_scale(
            scale_fun,
            list(
                values = values,
                na.value = unname(semantic[["missing"]])
            ),
            list(...)
        ))
    }

    if (identical(palette, "categorical")) {
        scale_fun <- if (identical(aesthetic, "colour")) {
            ggplot2::scale_colour_viridis_d
        } else {
            ggplot2::scale_fill_viridis_d
        }
        return(.landscapeR_call_scale(
            scale_fun,
            list(
                option = "D",
                end = 0.9,
                na.value = unname(semantic[["missing"]])
            ),
            list(...)
        ))
    }

    if (identical(palette, "continuous")) {
        scale_fun <- if (identical(aesthetic, "colour")) {
            ggplot2::scale_colour_viridis_c
        } else {
            ggplot2::scale_fill_viridis_c
        }
        return(.landscapeR_call_scale(
            scale_fun,
            list(
                option = "E",
                direction = -1,
                na.value = unname(semantic[["missing"]])
            ),
            list(...)
        ))
    }

    scale_fun <- if (identical(aesthetic, "colour")) {
        ggplot2::scale_colour_gradient2
    } else {
        ggplot2::scale_fill_gradient2
    }
    .landscapeR_call_scale(
        scale_fun,
        list(
            low = unname(semantic[["negative"]]),
            mid = "white",
            high = unname(semantic[["focal"]]),
            midpoint = 0,
            na.value = unname(semantic[["missing"]])
        ),
        list(...)
    )
}

#' Canonical landscapeR colour scale
#'
#' @param palette data role: binary, categorical, continuous, or diverging.
#' @param reference_level declared binary reference level. Required for binary
#'   scales.
#' @param focal_level declared binary focal/comparison level. Required for
#'   binary scales and mapped to the focal red by default. A named `values`
#'   argument supplied through `...` can override that visual mapping.
#' @param ... named arguments passed to the corresponding ggplot2 scale
#'   constructor. Supplied arguments override landscapeR defaults.
#'
#' @return A ggplot2 colour scale.
#' @export
scale_colour_landscapeR <- function(
    palette = c("binary", "categorical", "continuous", "diverging"),
    reference_level = NULL,
    focal_level = NULL,
    ...
) {
    .landscapeR_scale(
        "colour",
        .with_landscapeR_validation(match.arg(palette)),
        reference_level = reference_level,
        focal_level = focal_level,
        ...
    )
}

#' Canonical landscapeR fill scale
#'
#' @param palette data role: binary, categorical, continuous, or diverging.
#' @param reference_level declared binary reference level. Required for binary
#'   scales.
#' @param focal_level declared binary focal/comparison level. Required for
#'   binary scales and mapped to the focal red by default. A named `values`
#'   argument supplied through `...` can override that visual mapping.
#' @param ... named arguments passed to the corresponding ggplot2 scale
#'   constructor. Supplied arguments override landscapeR defaults.
#'
#' @return A ggplot2 fill scale.
#' @export
scale_fill_landscapeR <- function(
    palette = c("binary", "categorical", "continuous", "diverging"),
    reference_level = NULL,
    focal_level = NULL,
    ...
) {
    .landscapeR_scale(
        "fill",
        .with_landscapeR_validation(match.arg(palette)),
        reference_level = reference_level,
        focal_level = focal_level,
        ...
    )
}

#' Save a landscapeR figure at publication scale
#'
#' Saves a ggplot with a default 100 mm square device. Raster output defaults
#' to 450 dpi; vector formats retain editable geometry through ggplot2.
#'
#' @param plot a ggplot object.
#' @param filename output path with a graphics extension understood by
#'   [ggplot2::ggsave()].
#' @param width_mm output width in millimetres.
#' @param height_mm output height in millimetres; defaults to `width_mm`.
#' @param dpi raster resolution.
#' @param bg device background.
#' @param ... additional arguments passed to [ggplot2::ggsave()].
#'
#' @return The normalized output path, invisibly.
#' @export
save_landscapeR_plot <- function(
    plot,
    filename,
    width_mm = 100,
    height_mm = width_mm,
    dpi = 450,
    bg = "white",
    ...
) {
    if (!inherits(plot, "ggplot")) {
        .stop_landscapeR_validation("plot must be a ggplot object")
    }
    if (!is.character(filename) || length(filename) != 1L ||
        is.na(filename) || !nzchar(filename)) {
        .stop_landscapeR_validation("filename must be one non-empty path")
    }
    dimensions <- c(width_mm = width_mm, height_mm = height_mm)
    if (!is.numeric(dimensions) || any(!is.finite(dimensions)) ||
        any(dimensions <= 0)) {
        .stop_landscapeR_validation(
            "width_mm and height_mm must be positive finite numbers"
        )
    }
    if (!is.numeric(dpi) || length(dpi) != 1L || !is.finite(dpi) ||
        dpi <= 0) {
        .stop_landscapeR_validation("dpi must be one positive finite number")
    }

    .with_landscapeR_validation(ggplot2::ggsave(
        filename = filename,
        plot = plot,
        width = width_mm,
        height = height_mm,
        units = "mm",
        dpi = dpi,
        bg = bg,
        ...
    ))
    invisible(normalizePath(filename))
}
