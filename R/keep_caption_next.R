#' Keeps captions with magic strings
#'
#' @param docx_in The file path to the input `.docx` file.
#' @param docx_out The file path to the output `.docx` file to save to.
#' @keywords internal
#' @noRd
keep_caption_next <- function(docx_in, docx_out) {
  log4r::debug(.le$logger, "Starting keep_caption_next function")
  validate_input_args(docx_in, docx_out)

  paths <- pyro::get_venv_uv_paths()

  args <- c(
    "run",
    "-m",
    "reportipyr.cli",
    "keep-caption-next",
    "-i",
    docx_in,
    "-o",
    docx_out
  )

  log4r::debug(.le$logger, "Running keep caption next script")
  run_python_script(
    paths$uv,
    args,
    paths$venv,
    "Keep caption next script"
  )

  log4r::debug(.le$logger, "Exiting keep_caption_next function")
}
