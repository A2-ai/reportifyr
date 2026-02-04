#' Inserts alt text for figures within a Microsoft Word file.
#'
#' @param docx_in The file path to the input `.docx` file.
#' @param docx_out The file path to the output `.docx` file to save to.
#' @param debug Debug.
#'
#' @export
#'
#' @examples \dontrun{
#' add_plots_alt_text("doc-figs.docx", "doc-draft.docx")
#' }
add_plots_alt_text <- function(
  docx_in,
  docx_out,
  debug = FALSE
) {
  log4r::debug(.le$logger, "Starting add_plots_alt_text function")
  tictoc::tic("add plots alt text")

  if (debug) {
    log4r::debug(.le$logger, "Debug mode enabled")
    browser()
  }

  validate_input_args(docx_in, docx_out)

  log4r::info(.le$logger, paste0("Output document path set: ", docx_out))

  script <- system.file(
    "scripts/add_figure_alt_text.py",
    package = "reportifyr"
  )
  args <- c("run", script, "-i", docx_in, "-o", docx_out, "-l", .le$log_file)

  paths <- get_venv_uv_paths()

  log4r::debug(.le$logger, "Running add plots alt text script")
  run_python_script(
    paths$uv,
    args,
    paths$venv,
    "Add plots alt text script"
  )

  tictoc::toc()

  log4r::debug(.le$logger, "Exiting add_plots_alt_text function")
}
