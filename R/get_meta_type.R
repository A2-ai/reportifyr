#' Get meta types from standard_footnotes.yaml
#'
#' @param path_to_footnotes_yaml The file path to the `standard_footnotes.yaml` file.
#'
#' @return A list of `meta_type` to be called while performing an analysis
#'
#' @export
#'
#' @examples \dontrun{
#' standard_footnotes_yaml <- here::here("report", "standard_footnotes.yaml")
#' meta_type <- get_meta_type(path_to_footnotes_yaml = standard_footnotes_yaml)
#' }
get_meta_type <- function(path_to_footnotes_yaml) {
  log4r::debug(.le$logger, "Starting get_meta_type function")

  if (!file.exists(path_to_footnotes_yaml)) {
    log4r::error(
      .le$logger,
      paste("footnotes yaml file does not exist at:", path_to_footnotes_yaml)
    )
    stop("footnotes yaml file does not exist. Please check the provided path")
  }

  if (tools::file_ext(path_to_footnotes_yaml) != 'yaml') {
    stop("Supplied file is not yaml. Please point to footnotes yaml file.")
  }

  yaml_content <- yaml::read_yaml(path_to_footnotes_yaml)
  log4r::debug(.le$logger, "YAML content successfully read")

  tryCatch(
    {
      if (!("figure_footnotes" %in% names(yaml_content))) {
        log4r::error(
          .le$logger,
          "'figure_footnotes' is missing or misspelled in standard_footnotes.yaml"
        )
        stop(
          "Error: 'figure_footnotes' is missing or misspelled in standard_footnotes.yaml"
        )
      }
      if (!("table_footnotes" %in% names(yaml_content))) {
        log4r::error(
          .le$logger,
          "'table_footnotes' is missing or misspelled in standard_footnotes.yaml"
        )
        stop(
          "Error: 'table_footnotes' is missing or misspelled in standard_footnotes.yaml"
        )
      }

      meta_type <- c(
        lapply(names(yaml_content$figure_footnotes), function(name) name),
        lapply(names(yaml_content$table_footnotes), function(name) name)
      )

      names(meta_type) <- c(
        names(yaml_content$figure_footnotes),
        names(yaml_content$table_footnotes)
      )
      log4r::debug(
        .le$logger,
        "Meta types successfully retrieved from YAML content"
      )
      log4r::debug(.le$logger, "Exiting get_meta_type function")

      return(meta_type)
    },
    error = function(e) {
      log4r::error(
        .le$logger,
        paste("An error occurred while retrieving meta_types:", e$message)
      )
      message("An error occurred while retrieving meta_types: ", e$message)
      return(NULL)
    }
  )
}
