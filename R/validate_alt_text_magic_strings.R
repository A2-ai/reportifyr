#' Validate alt text of figures/tables against their magic strings in a Microsoft Word file
#'
#' @param docx_in The file path to the input `.docx` file.
#' @param debug Debug.
#'
#' @export
#'
#' @examples \dontrun{
#' validate_alt_text_magic_strings("template.docx")
#' }
validate_alt_text_magic_strings <- function(
  docx_in,
  debug = FALSE
) {
  log4r::debug(.le$logger, "Starting validate_alt_text_magic_strings function")
  tictoc::tic("validate alt text magic strings")

  if (debug) {
    log4r::debug(.le$logger, "Debug mode enabled")
    browser()
  }

  args <- c(
    "run",
    "-m",
    "reportipyr.cli",
    "check-alt-text-magic",
    "-i",
    docx_in
  )

  paths <- fyrstartr::get_venv_uv_paths()

  log4r::debug(.le$logger, "Running check_alt_text_magic_strings script")
  run_python_script(
    paths$uv,
    args,
    paths$venv,
    "Check alt text magic string script"
  )

  tictoc::toc()

  log4r::debug(.le$logger, "Exiting validate_alt_text_magic_strings function")
}
