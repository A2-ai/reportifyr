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

  script <- system.file("scripts/add_table_alt_text.py", package = "reportifyr")
  args <- c("run", script, "-i", docx_in, "-o", docx_out, "-l", .le$log_file)

  paths <- get_venv_uv_paths()

  log4r::debug(.le$logger, "Running add table alt text script")
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
        paste0("Add table alt text script failed. Status: ", e$status)
      )
      log4r::error(
        .le$logger,
        paste0("Add table alt text script failed. Stderr: ", e$stderr)
      )
      log4r::info(
        .le$logger,
        paste0("Add table alt text script failed. Stdout: ", e$stdout)
      )
      stop(paste(
        "Add table alt text script failed. Status: ",
        e$status,
        "Stderr: ",
        e$stderr
      ))
    }
  )

  tictoc::toc()

  log4r::debug(.le$logger, "Exiting add_tables_alt_text function")
}
