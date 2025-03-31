#' Validate config file
#'
#' @param path_to_config_yaml path to config.yaml file
#'
#' @returns bool TRUE if config is valid, FALSE otherwise
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

  if (valid) {
    log4r::debug(.le$logger, "No issues found")
  }

  valid
}
