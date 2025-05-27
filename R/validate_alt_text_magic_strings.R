#' validate_alt_text_magic_strings
#'
#' @param docx_in path to docx in file
#' @param config_yaml path to config.yaml file
#' @param debug boolean, whether to open browser
#'
#' @export
#'
#' @examples \dontrun{
#' validate_alt_text_magic_strings("template.docx")
#' }
validate_alt_text_magic_strings <- function(
    docx_in,
    config_yaml = NULL,
    debug = FALSE) {
  log4r::debug(.le$logger, "Starting validate_alt_text_magic_strings function")
  tictoc::tic()

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
        paste0("Check alt text magic string script failed. Status: ", e$status)
      )
      log4r::error(
        .le$logger,
        paste0("Check alt text magic string script failed. Stderr: ", e$stderr)
      )
      log4r::info(
        .le$logger,
        paste0("Check alt text magic string script failed. Stdout: ", e$stdout)
      )
      stop(paste(
        "Check alt text magic string script failed. Status: ",
        e$status,
        "Stderr: ",
        e$stderr
      ))
    }
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

  log4r::info(.le$logger, paste0("Returning status: ", result$status))
  log4r::info(.le$logger, paste0("Returning stdout: ", result$stdout))
  log4r::info(.le$logger, paste0("Returning stderr: ", result$stderr))

  tictoc::toc()

  log4r::debug(.le$logger, "Exiting check_alt_text_magic function")
}
