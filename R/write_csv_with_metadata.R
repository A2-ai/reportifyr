#' Wrapper around the write.csv function. Saves data as .RDS and .RTF and captures analysis relevant metadata in a .json file
#'
#' @description Extension to the `write.csv()` function that allows capturing object metadata as a separate `.json` file.
#' @param object The `R` object to serialize.
#' @param file The connection or name of the file where the `R` object is saved.
#' @param config_yaml The path to the config.yaml, default is NULL and defaults will be used.
#' @param meta_type A string to specify the type of object. Default is `"NA"`.
#' @param meta_equations A string or vector of strings representing equations to include in the metadata. Default is `NULL`.
#' @param meta_notes A string or vector of strings representing notes to include in the metadata. Default is `NULL`.
#' @param meta_abbrevs A string or vector of strings representing abbreviations to include in the metadata. Default is `NULL`.
#' @param table1_format A boolean indicating whether to apply table1-style formatting. Default is `FALSE`.
#' @param ... Additional arguments passed to the `utils::write.csv()` function.
#'
#' @export
#'
#' @examples \dontrun{
#'
#' # ---------------------------------------------------------------------------------
#' # Save a simple table
#' # ---------------------------------------------------------------------------------
#' tables_path <- here::here("OUTPUTS", "tables")
#' outfile_name <- "01-12345-pk-theoph.csv"
#'
#' write_csv_with_metadata(
#'   object = Theoph,
#'   file = file.path(tables_path, out_name),
#'   row_names = FALSE
#' )
#' }
write_csv_with_metadata <- function(
  object,
  file,
  config_yaml = NULL,
  meta_type = "NA",
  meta_equations = NULL,
  meta_notes = NULL,
  meta_abbrevs = NULL,
  table1_format = FALSE,
  ...
) {
  log4r::debug(.le$logger, "Starting write_csv_with_metadata function")

  utils::write.csv(x = object, file = file, ...)
  log4r::info(.le$logger, paste0("CSV written to file: ", file))

  write_object_metadata(
    file,
    meta_type = meta_type,
    meta_equations = meta_equations,
    meta_notes = meta_notes,
    meta_abbrevs = meta_abbrevs,
    table1_format = table1_format
  )

  log4r::debug(.le$logger, "Reading config for RTF saving now")
  if (!is.null(config_yaml)) {
    log4r::debug(.le$logger, paste0("Reading config.yaml: ", config_yaml))
    config <- yaml::read_yaml(config_yaml)
    if (config$save_table_rtf) {
      save_rtf(object = object, file = file, table1_format = table1_format)
    }
  } else {
    save_rtf(object = object, file = file, table1_format = table1_format)
  }

  log4r::debug(.le$logger, "Exiting write_csv_with_metadata function")
}
