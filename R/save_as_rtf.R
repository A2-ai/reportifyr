#' Formats and saves a flextable object as .RTF
#'
#' @param object R object to serialize
#' @param file A connection or the name of the file where the R object is saved to or read from
#' @param table1_format Boolean for declaring if object is table1 format, passed to format_flextable
#'
#' @keywords internal
#' @noRd
save_rtf <- function(object,
                     file,
                     table1_format) {
  log4r::debug(.le$logger, "Starting save_rtf function")
  rtf_file <- paste0(tools::file_path_sans_ext(file), "_", tools::file_ext(file), ".RTF")
  log4r::info(.le$logger, paste0("RTF file path set: ", rtf_file))

  if (!inherits(object, "flextable")) {
    log4r::info(.le$logger, "Object is not a flextable, applying format_flextable")

    object <- tryCatch(
      {
        format_flextable(object, table1_format = table1_format)
      },
      error = function(e) {
        log4r::error(.le$logger, paste("Failed to convert object to flextable:", e$message))
      }
    )
  }

  flextable::save_as_rtf(object, path = rtf_file)

  log4r::info(.le$logger, paste0("RTF file saved: ", rtf_file))
  log4r::debug(.le$logger, "Exiting save_rtf function")
}
