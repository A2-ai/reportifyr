#' Wrapper around the saveRDS function. Saves an object as .RDS and .RTF and captures analysis relevant metadata in a .json file
#'
#' @description Extension to the saveRDS function that allows capturing object metadata as a separate .json file.
#' @param object The R object to serialize.
#' @param file The connection or name of the file where the R object is saved.
#' @param meta_type A string to specify the type of object. Default is "NA".
#' @param meta_equations A string or vector of strings representing equations to include in the metadata. Default is NULL.
#' @param meta_notes A string or vector of strings representing notes to include in the metadata. Default is NULL.
#' @param meta_abbrevs A string or vector of strings representing abbreviations to include in the metadata. Default is NULL.
#' @param table1_format A boolean indicating whether to apply table1-style formatting. Defaults to FALSE.
#' @param ... Additional arguments passed to the base saveRDS() function.
#'
#' @export
#'
#' @examples \dontrun{
#' # Path to the analysis tables (.RDS) and metadata (.json files)
#' tables.path <- file.path(tempdir(), "tables")
#'
#' # ---------------------------------------------------------------------------
#' # Save a simple table
#' # ---------------------------------------------------------------------------
#'
#' out_name <- "01-12345-pk-theoph.csv"
#' save_rds_with_metadata(
#'   object = Theoph,
#'   file = file.path(tables.path, out_name)
#' )
#' }
save_rds_with_metadata <- function(object,
                                   file = "",
                                   meta_type = "NA",
                                   meta_equations = NULL,
                                   meta_notes = NULL,
                                   meta_abbrevs = NULL,
                                   table1_format = F,
                                   ...) {
  log4r::debug(.le$logger, "Starting save_rds_with_metadata function")

  base::saveRDS(object = object, file = file, ...)
  log4r::info(.le$logger, paste0("RDS written to file: ", file))

  write_object_metadata(
    file,
    meta_type = meta_type,
    meta_equations = meta_equations,
    meta_notes = meta_notes,
    meta_abbrevs = meta_abbrevs,
    table1_format = table1_format
  )

  save_rtf(object = object, file = file, table1_format = table1_format)

  log4r::debug(.le$logger, "Exiting save_rds_with_metadata function")
}
