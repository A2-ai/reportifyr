#' Updates an object's footnote metadata - equations, notes, or abbreviations
#'
#' @param file_path Path to object or object's metadata file
#' @param overwrite Boolean to overwrite existing entries or append. Default is to append
#' @param equations String or vector of strings of equations to add
#' @param notes String or vector of strings of notes to add
#' @param abbrevs String or vector of strings of abbreviations to add
#'
#' @export
#'
#' @examples \dontrun{
#' update_object_footnotes("example_metadata.json", equations = c("K10 = CL/VC", "K12 = Q/VC"))
#' }
update_object_footnotes <- function(file_path,
                                    overwrite = FALSE,
                                    equations = NULL,
                                    notes = NULL,
                                    abbrevs = NULL) {
  log4r::debug(.le$logger, "Starting update_object_footnotes function")

  if (tools::file_ext(file_path) != "json") {
    log4r::info(.le$logger, "File extension is not .json, adjusting file path")
    # assumes object is passed instead of metadata -- so grabbing metadata.
    file_path <- paste0(tools::file_path_sans_ext(file_path), "_", tools::file_ext(file_path), "_metadata.json")
  }

  if (!file.exists(file_path)) {
    log4r::error(.le$logger, paste0("Metadata file does not exist: ", file_path))
    stop("The metadata associated with the specified file does not exist: ", file_path)
  }
  log4r::info(.le$logger, paste0("Metadata file found: ", file_path))

  metadata <- jsonlite::fromJSON(file_path, simplifyVector = TRUE)
  log4r::debug(.le$logger, "Metadata file loaded successfully")
  if (overwrite) {
    log4r::info(.le$logger, "Overwrite is TRUE, replacing existing footnotes")
    metadata$object_meta$footnotes$equations <- as.list(unique(c(equations)))
    metadata$object_meta$footnotes$notes <- as.list(unique(c(notes)))
    metadata$object_meta$footnotes$abbreviations <- as.list(unique(c(abbrevs)))
  } else {
    log4r::info(.le$logger, "Overwrite is FALSE, appending to existing footnotes")
    metadata$object_meta$footnotes$equations <- as.list(unique(c(metadata$object_meta$footnotes$equations, equations)))
    metadata$object_meta$footnotes$notes <- as.list(unique(c(metadata$object_meta$footnotes$notes, notes)))
    metadata$object_meta$footnotes$abbreviations <- as.list(unique(c(metadata$object_meta$footnotes$abbreviations, abbrevs)))
  }

  json_data <- jsonlite::toJSON(metadata, pretty = TRUE, auto_unbox = TRUE)
  write(json_data, file = file_path)

  log4r::info(.le$logger, paste0("Footnotes updated in metadata file: ", file_path))

  message("Footnotes successfully updated in ", file_path)
  log4r::debug(.le$logger, "Exiting update_object_footnotes function")
}
