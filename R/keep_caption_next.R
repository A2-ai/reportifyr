#' Keeps captions with magic strings
#'
#' @param docx_in The file path to the input `.docx` file.
#' @param docx_out The file path to the output `.docx` file to save to.
#' @keywords internal
#' @noRd
keep_caption_next <- function(docx_in, docx_out) {
  log4r::debug(.le$logger, "Starting keep_caption_next function")
  validate_input_args(docx_in, docx_out)

  paths <- get_venv_uv_paths()

  script <- system.file(
    "scripts/keep_caption_next.py",
    package = "reportifyr"
  )
  args <- c("run", script, "-i", docx_in, "-o", docx_out)

  log4r::debug(.le$logger, "Running keep caption next script")
  result <- tryCatch(
    {
      processx::run(
        command = paths$uv,
        args = args,
        env = c("current", VIRTUAL_ENV = paths$venv),
        error_on_status = TRUE
      )
    },
    error = function(e) {
      log4r::error(
        .le$logger,
        paste0("Keep caption next script failed. Status: ", e$status)
      )
      log4r::error(
        .le$logger,
        paste0("Keep caption next script failed. Stderr: ", e$stderr)
      )
      log4r::info(
        .le$logger,
        paste0("Remove magic strings script failed. Stdout: ", e$stdout)
      )
      stop(paste(
        "Keep caption next script failed. Status: ",
        e$status,
        "Stderr: ",
        e$stderr
      ))
    }
  )

  log4r::info(.le$logger, paste0("Returning status: ", result$status))
  log4r::info(.le$logger, paste0("Returning stdout: ", result$stdout))
  log4r::info(.le$logger, paste0("Returning stderr: ", result$stderr))

  log4r::debug(.le$logger, "Exiting keep_caption_next function")
}
