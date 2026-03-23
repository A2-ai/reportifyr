#' Inserts alt text for tables within a Microsoft Word file.
#'
#' @param docx_in The file path to the input `.docx` file.
#' @param docx_out The file path to the output `.docx` file to save to.
#' @param debug Debug.
#'
#' @export
#'
#' @examples \dontrun{
#' add_tables_alt_text("document-tabs.docx", "document-tabs_at.docx")
#' }
add_tables_alt_text <- function(
  docx_in,
  docx_out,
  debug = FALSE
) {
  log4r::debug(.le$logger, "Starting add_tables_alt_text function")
  tictoc::tic("add tables alt text")

  if (debug) {
    log4r::debug(.le$logger, "Debug mode enabled")
    browser()
  }

  validate_input_args(docx_in, docx_out)

  log4r::info(.le$logger, paste0("Output document path set: ", docx_out))

  args <- c(
    "run",
    "-m",
    "reportipyr.cli",
    "add-table-alt-text",
    "-i",
    docx_in,
    "-o",
    docx_out
  )

  paths <- get_venv_uv_paths()

  log4r::debug(.le$logger, "Running add table alt text script")
  run_python_script(
    paths$uv,
    args,
    paths$venv,
    "Add table alt text script"
  )

  tictoc::toc()

  log4r::debug(.le$logger, "Exiting add_tables_alt_text function")
}
