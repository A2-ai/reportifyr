#' Wrapper around the write.csv function. Saves data as .RDS and .RTF and captures analysis relevant metadata in a .json file
#'
#' @description Extension to the write.csv function that allows capturing object metadata as a separate .json file.
#' @param object The object to be written, preferably a matrix or data frame. If not, it is attempted to coerce object to a data frame
#' @param file Either a character string naming a file or a connection open for writing. "" indicates output to the console.
#' @param meta_type The analysis meta type. Defaults to "NA"
#' @param meta_equations Additional equations for metadata
#' @param meta_notes Additional notes for metadata
#' @param meta_abbrevs Additional abbrevs for metadata
#' @param table1_format Boolean for declaring table is table1 format
#' @param ... Additional arguments that can be passed to write.csv
#'
#' @export
#'
#' @examples \dontrun{
#'
#' # Path to the analysis tables (.csv) and metadata (.json files)
#' tables.path <- "OUTPUTS/tables"
#'
#' # ---------------------------------------------------------------------------------
#' # Save a simple table
#' # ---------------------------------------------------------------------------------
#'
#' out_name <- "01-12345-pk-theoph.csv"
#' write_csv_with_metadata(
#'   object = Theoph,
#'   file = file.path(tables.path, out_name), row_names = F
#' )
#' }
write_csv_with_metadata <- function(object,
                                    file,
                                    meta_type = "NA",
                                    meta_equations = NULL,
                                    meta_notes = NULL,
                                    meta_abbrevs = NULL,
                                    table1_format = F,
                                    ...) {
  log4r::debug(.le$logger, "Starting write_csv_with_metadata function")

  utils::write.csv(x = object, file = file, ...)
  log4r::info(.le$logger, paste0("CSV written to file: ", file))

  write_object_metadata(
    file,
    meta_type = meta_type,
    equations = meta_equations,
    notes = meta_notes,
    abbrevs = meta_abbrevs
  )

  save_rtf(object = object, file = file, table1_format = table1_format)

  log4r::debug(.le$logger, "Exiting write_csv_with_metadata function")
}
