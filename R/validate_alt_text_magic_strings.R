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

  script <- system.file(
    "scripts/check_alt_text_magic.py",
    package = "reportifyr"
  )
  args <- c(
    "run",
    script,
    "-i",
    docx_in
  )

  paths <- get_venv_uv_paths()

  log4r::debug(.le$logger, "Running check_alt_text_magic_strings script")
  result <- run_python_script(
    paths$uv,
    args,
    paths$venv,
    "Check alt text magic string script"
  )

  if (grepl("Magic mismatch!", result$stdout)) {
    log4r::warn(
      .le$logger,
      "Mismatching magic strings found!"
    )
  }

  if (grepl("Magic mismatch", result$stdout)) {
    stdout_lines <- strsplit(result$stdout, "\n")[[1]]
    matching_lines <- stdout_lines[grepl("Magic mismatch", stdout_lines)]
    log4r::warn(.le$logger, matching_lines)
  }

  tictoc::toc()

  log4r::debug(.le$logger, "Exiting validate_alt_text_magic_strings function")
}
