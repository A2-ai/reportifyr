#' Validate config.yaml file
#'
#' @param path_to_config_yaml The file path to the `config.yaml`.
#'
#' @returns bool `TRUE` if config is valid, `FALSE` otherwise.
#' @export
#'
#' @examples \dontrun{
#' validate_config(here::here("report/config.yaml"))
#' }
validate_config <- function(path_to_config_yaml) {
  log4r::debug(.le$logger, "Starting validate_config function")
  valid <- TRUE

  log4r::debug(.le$logger, paste0("Reading in config:", path_to_config_yaml))
  config <- yaml::read_yaml(path_to_config_yaml)

  log4r::debug(.le$logger, "Checking footnotes_font")
  if (!is.null(config$footnotes_font)) {
    if (typeof(config$footnotes_font) != "character") {
      log4r::error(
        .le$logger,
        paste0(
          "footnotes_font should be character, not: ",
          typeof(config$footnotes_font)
        )
      )
      valid <- FALSE
    }
  }

  log4r::debug(.le$logger, "Checking footnotes_font_size")
  if (!is.null(config$footnotes_font_size)) {
    if (!(typeof(config$footnotes_font_size) %in% c("integer", "double"))) {
      log4r::error(
        .le$logger,
        paste0(
          "footnotes_font_size should be integer/double, not: ",
          typeof(config$footnotes_font_size)
        )
      )
      valid <- FALSE
    }
  }

  log4r::debug(.le$logger, "Checking use_object_path_as_source")
  if (!is.null(config$use_object_path_as_source)) {
    if (typeof(config$use_object_path_as_source) != "logical") {
      log4r::error(
        .le$logger,
        paste0(
          "use_object_path_as_source should be logical, not: ",
          typeof(config$use_object_path_as_source)
        )
      )
      valid <- FALSE
    }
  }

  log4r::debug(.le$logger, "Checking wrap_path_in_[]")
  if (!is.null(config$`wrap_path_in_[]`)) {
    if (typeof(config$`wrap_path_in_[]`) != "logical") {
      log4r::error(
        .le$logger,
        paste0(
          "wrap_path_in_[] should be logical, not: ",
          typeof(config$`wrap_path_in_[]`)
        )
      )
      valid <- FALSE
    }
  }

  log4r::debug(.le$logger, "Checking combine_duplicate_footnotes")
  if (!is.null(config$combine_duplicate_footnotes)) {
    if (typeof(config$combine_duplicate_footnotes) != "logical") {
      log4r::error(
        .le$logger,
        paste0(
          "combine_duplicate_footnotes should be logical, not: ",
          typeof(config$combine_duplicate_footnotes)
        )
      )
      valid <- FALSE
    }
  }

  log4r::debug(.le$logger, "Checking footnote_order now")
  if (!is.null(config$footnote_order)) {
    footnotes <- c("Object", "Source", "Notes", "Abbreviations")
    if (
      !identical(
        intersect(config$footnote_order, footnotes),
        config$footnote_order
      )
    ) {
      log4r::error(
        .le$logger,
        paste0(
          "Unexpected footnote field: ",
          paste0(setdiff(config$footnote_order, footnotes), collapse = ", "),
          ". Acceptable fields are: ",
          paste0(footnotes, collapse = ", ")
        )
      )
      valid <- FALSE
    }
  }

  log4r::debug(.le$logger, "Checking keep_caption_next now")
  if (!is.null(config$keep_caption_next)) {
    if (typeof(config$keep_caption_next) != "logical") {
      log4r::error(
        .le$logger,
        paste0(
          "keep_caption_next should be logical, not: ",
          typeof(config$keep_caption_next)
        )
      )
      valid <- FALSE
    }
  }

  log4r::debug(.le$logger, "Checking add_alt_text now")
  if (!is.null(config$add_alt_text)) {
    if (typeof(config$add_alt_text) != "logical") {
      log4r::error(
        .le$logger,
        paste0(
          "add_alt_text should be logical, not: ",
          typeof(config$add_alt_text)
        )
      )
      valid <- FALSE
    }
  }

  log4r::debug(.le$logger, "Checking save_table_rtf now")
  if (!is.null(config$save_table_rtf)) {
    if (typeof(config$save_table_rtf) != "logical") {
      log4r::error(
        .le$logger,
        paste0(
          "save_table_rtf should be logical, not: ",
          typeof(config$save_table_rtf)
        )
      )
      valid <- FALSE
    }
  }

  log4r::debug(.le$logger, "Checking fig_alignment now")
  if (!is.null(config$fig_alignment)) {
    alignment <- c("center", "left", "right")
    if (
      !identical(
        intersect(config$fig_alignment, alignment),
        config$fig_alignment
      )
    ) {
      log4r::error(
        .le$logger,
        paste0(
          "Unexpected figure alignment option: ",
          paste0(setdiff(config$fig_alignment, alignment), collapse = "', '"),
          ". Acceptable alignments are: ",
          paste0(alignment, collapse = ", ")
        )
      )
      valid <- FALSE
    }
  }

  log4r::debug(.le$logger, "Checking use_artifact_size now")
  if (!is.null(config$use_artifact_size)) {
    if (typeof(config$use_artifact_size) != "logical") {
      log4r::error(
        .le$logger,
        paste0(
          "use_artifact_size should be logical, not: ",
          typeof(config$use_artifact_size)
        )
      )
      valid <- FALSE
    }
  }

  log4r::debug(.le$logger, "Checking default_fig_width now")
  if (!is.null(config$default_fig_width)) {
    if (!(typeof(config$default_fig_width) %in% c("integer", "double"))) {
      log4r::error(
        .le$logger,
        paste0(
          "default_fig_width should be integer/double, not: ",
          typeof(config$default_fig_width)
        )
      )
      valid <- FALSE
    }
  }

  log4r::debug(.le$logger, "Checking use_embedded_dimensions now")
  if (!is.null(config$use_embedded_dimensions)) {
    if (typeof(config$use_embedded_dimensions) != "logical") {
      log4r::error(
        .le$logger,
        paste0(
          "use_embedded_dimensions should be logical, not: ",
          typeof(config$use_embedded_dimensions)
        )
      )
      valid <- FALSE
    }
  }

  log4r::debug(.le$logger, "Checking label_multi_figures now")
  if (!is.null(config$label_multi_figures)) {
    if (typeof(config$label_multi_figures) != "logical") {
      log4r::error(
        .le$logger,
        paste0(
          "label_multi_figures should be logical, not: ",
          typeof(config$label_multi_figures)
        )
      )
      valid <- FALSE
    }
  }

  log4r::debug(.le$logger, "Checking add_path_overlay now")
  if (!is.null(config$add_path_overlay)) {
    if (typeof(config$add_path_overlay) != "logical") {
      log4r::error(
        .le$logger,
        paste0(
          "add_path_overlay should be logical, not: ",
          typeof(config$add_path_overlay)
        )
      )
      valid <- FALSE
    }
  }

  log4r::debug(.le$logger, "Checking strict now")
  if (!is.null(config$strict)) {
    if (typeof(config$strict) != "logical") {
      log4r::error(
        .le$logger,
        paste0(
          "strict should be logical, not: ",
          typeof(config$strict)
        )
      )
      valid <- FALSE
    }
  }

  if (valid) {
    log4r::debug(.le$logger, "No issues found")
  }

  valid
}
