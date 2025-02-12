#' Validates a file's hash against a stored hash in the associated _metadata.json file
#'
#' @param file The connection or name of the file where the R object is saved.
#'
#' @return A boolean declaring if the hashes are equal or not
#'
#' @export
#'
#' @examples \dontrun{
#' tables.path  <- "OUTPUTS/tables"
#' out_name <- "01-12345-pk-theoph.csv"
#'
#' validate_object(file = file.path(tables.path, out_name))
#' }
validate_object <- function(file) {
  log4r::debug(.le$logger, "Starting validate_object function")
  if (!file.exists(file)) {
    log4r::error(.le$logger, paste0("File does not exist: ", file))
    stop("The specified file does not exist.")
  }
  log4r::info(.le$logger, paste0("File exists: ", file))

  file_dir <- dirname(file)

  file_basename <- tools::file_path_sans_ext(basename(file))

  file_ext <- tools::file_ext(file)

  metadata_path <- file.path(file_dir, paste0(file_basename, "_", file_ext, "_metadata.json"))

  if (!file.exists(metadata_path)) {
    log4r::error(.le$logger, paste0("Metadata file does not exist: ", metadata_path))
    stop("The associated metadata JSON file does not exist.")
  }
  log4r::info(.le$logger, paste0("Metadata file exists: ", metadata_path))

  metadata <- jsonlite::fromJSON(metadata_path)

  if (!"hash" %in% names(metadata$object_meta)) {
    log4r::error(.le$logger, paste0("No hash found in metadata: ", metadata_path))
    stop("The metadata JSON file does not contain a hash value.")
  }
  log4r::info(.le$logger, paste0("Hash found in metadata:", metadata$object_meta$hash))

  file_hash <- digest::digest(file = file, algo = "blake3")
  log4r::info(.le$logger, paste0("Generated file hash: ", file_hash))

  if (file_hash == metadata$object_meta$hash) {
    log4r::info(.le$logger, "File hash matches metadata hash")
    message("The file hash matches the hash in the metadata.")
    log4r::debug(.le$logger, "Exiting validate_object function")
    return(TRUE)
  } else {
    log4r::warn(.le$logger, "File hash does NOT match metadata hash")
    message("The file hash does NOT match the hash in the metadata.")
    log4r::debug(.le$logger, "Exiting validate_object function")
    return(FALSE)
  }
}
