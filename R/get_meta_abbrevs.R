#' Get meta abbreviations from standard_footnotes.yaml
#'
#' @param path_to_footnotes_yaml The file path to the `standard_footnotes.yaml` file.
#'
#' @return A list of `meta_abbrevs` to be called while performing an analysis
#'
#' @export
#'
#' @examples \dontrun{
#' standard_footnotes_yaml <- here::here("report", "standard_footnotes.yaml")
#' meta_abbrevs <- get_meta_abbrevs(path_to_footnotes_yaml = standard_footnotes_yaml)
#' }
get_meta_abbrevs <- function(path_to_footnotes_yaml) {
  log4r::debug(.le$logger, "Starting get_meta_abbrevs function")

  if (!file.exists(path_to_footnotes_yaml)) {
    log4r::error(
      .le$logger,
      paste("footnotes yaml file does not exist at:", path_to_footnotes_yaml)
    )
    stop("footnotes yaml file does not exist. Please check the provided path")
  }

  if (tools::file_ext(path_to_footnotes_yaml) != "yaml") {
    stop("Entered file is not yaml. Please input footnotes.yaml path.")
  }

  yaml_content <- yaml::read_yaml(path_to_footnotes_yaml)
  log4r::debug(.le$logger, "YAML content successfully read")

  tryCatch(
    {
      if (!("abbreviations" %in% names(yaml_content))) {
        log4r::error(
          .le$logger,
          "'abbreviations' is missing or misspelled in standard_footnotes.yaml"
        )
        stop(
          "Error: 'abbreviations' is missing or misspelled in standard_footnotes.yaml"
        )
      }
      meta_abbrevs <- lapply(
        names(yaml_content$abbreviations),
        function(name) name
      )

      names(meta_abbrevs) <- names(yaml_content$abbreviations)

      log4r::debug(
        .le$logger,
        "Meta abbreviations successfully retrieved from YAML content"
      )
      log4r::debug(.le$logger, "Exiting get_meta_abbbrevs function")

      return(meta_abbrevs)
    },
    error = function(e) {
      log4r::error(
        .le$logger,
        paste("An error occurred while retrieving meta_abbrevs:", e$message)
      )
      message("An error occurred while retrieving meta_abbrevs: ", e$message)
      return(NULL)
    }
  )
}
