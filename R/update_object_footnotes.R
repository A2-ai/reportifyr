#' Updates an object's footnote metadata - equations, notes, or abbreviations
#'
#' @param file_path The file path to the object or its metadata file.
#' @param overwrite A boolean indicating whether to overwrite existing metadata entries. Default is `FALSE` (appends to existing entries).
#' @param meta_equations A string or vector of strings representing equations to include or overwrite in the metadata.
#' @param meta_notes A string or vector of strings representing notes to include or overwrite in the metadata.
#' @param meta_abbrevs A string or vector of strings representing abbreviations to include or overwrite in the metadata.
#'
#' @export
#'
#' @examples \dontrun{
#' update_object_footnotes("example_metadata.json", equations = c("K10 = CL/VC", "K12 = Q/VC"))
#' }
update_object_footnotes <- function(
  file_path,
  overwrite = FALSE,
  meta_equations = NULL,
  meta_notes = NULL,
  meta_abbrevs = NULL
) {
  log4r::debug(.le$logger, "Starting update_object_footnotes function")

  if (tools::file_ext(file_path) != "json") {
    log4r::info(.le$logger, "File extension is not .json, adjusting file path")
    # assumes object is passed instead of metadata -- so grabbing metadata.
    file_path <- paste0(
      tools::file_path_sans_ext(file_path),
      "_",
      tools::file_ext(file_path),
      "_metadata.json"
    )
  }

  if (!file.exists(file_path)) {
    log4r::error(
      .le$logger,
      paste0("Metadata file does not exist: ", file_path)
    )
    stop(
      "The metadata associated with the specified file does not exist: ",
      file_path
    )
  }
  log4r::info(.le$logger, paste0("Metadata file found: ", file_path))

  metadata <- jsonlite::fromJSON(file_path, simplifyVector = TRUE)
  log4r::debug(.le$logger, "Metadata file loaded successfully")
  if (overwrite) {
    log4r::info(.le$logger, "Overwrite is TRUE, replacing existing footnotes")
    metadata$object_meta$footnotes$equations <- as.list(unique(c(
      meta_equations
    )))
    metadata$object_meta$footnotes$notes <- as.list(unique(c(meta_notes)))
    metadata$object_meta$footnotes$abbreviations <- as.list(unique(c(
      meta_abbrevs
    )))
  } else {
    log4r::info(
      .le$logger,
      "Overwrite is FALSE, appending to existing footnotes"
    )
    metadata$object_meta$footnotes$equations <- as.list(unique(c(
      metadata$object_meta$footnotes$equations,
      meta_equations
    )))
    metadata$object_meta$footnotes$notes <- as.list(unique(c(
      metadata$object_meta$footnotes$notes,
      meta_notes
    )))
    metadata$object_meta$footnotes$abbreviations <- as.list(unique(c(
      metadata$object_meta$footnotes$abbreviations,
      meta_abbrevs
    )))
  }

  json_data <- jsonlite::toJSON(metadata, pretty = TRUE, auto_unbox = TRUE)
  write(json_data, file = file_path)

  log4r::info(
    .le$logger,
    paste0("Footnotes updated in metadata file: ", file_path)
  )

  message("Footnotes successfully updated in ", file_path)
  log4r::debug(.le$logger, "Exiting update_object_footnotes function")
}
