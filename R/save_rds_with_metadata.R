#' Wrapper around the saveRDS function. Saves an object as .RDS and .RTF and captures analysis relevant metadata in a .json file
#'
#' @description Extension to the saveRDS function that allows capturing object metadata as a separate .json file.
#' @param object R object to serialize
#' @param file A connection or the name of the file where the R object is saved to or read from
#' @param meta_type The analysis meta type. Defaults to "NA"
#' @param meta_equations Additional equations to add to metadata
#' @param meta_notes Additional notes to add to metadata
#' @param meta_abbrevs Additional abbrevs to add to metadata
#' @param table1_format Boolean for declaring object is table1 format
#' @param ... Additional args to be used in saveRDS
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
    equations = meta_equations,
    notes = meta_notes,
    abbrevs = meta_abbrevs,
    table1_format = table1_format
  )

  save_rtf(object = object, file = file, table1_format = table1_format)

  log4r::debug(.le$logger, "Exiting save_rds_with_metadata function")
}
