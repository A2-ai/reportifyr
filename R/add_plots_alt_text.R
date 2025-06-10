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
  tictoc::tic()

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
  args <- c("run", script, "-i", docx_in, "-o", docx_out)

  paths <- get_venv_uv_paths()

  log4r::debug(.le$logger, "Running add plots alt text script")
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
        paste0("Add plots alt text script failed. Status: ", e$status)
      )
      log4r::error(
        .le$logger,
        paste0("Add plots alt text script failed. Stderr: ", e$stderr)
      )
      log4r::info(
        .le$logger,
        paste0("Add plots alt text script failed. Stdout: ", e$stdout)
      )
      stop(paste(
        "Add table plots text script failed. Status: ",
        e$status,
        "Stderr: ",
        e$stderr
      ))
    }
  )

  if (grepl("Duplicate figure names found in the document", result$stdout)) {
    log4r::warn(
      .le$logger,
      "Duplicate figures found in magic strings of document."
    )
  }

  if (grepl("Unsupported", result$stdout)) {
    stdout_lines <- strsplit(result$stdout, "\n")[[1]]
    matching_lines <- stdout_lines[grepl("Unsupported", stdout_lines)]
    log4r::warn(.le$logger, matching_lines)
  }

  log4r::info(.le$logger, paste0("Returning status: ", result$status))
  log4r::info(.le$logger, paste0("Returning stdout: ", result$stdout))
  log4r::info(.le$logger, paste0("Returning stderr: ", result$stderr))

  tictoc::toc()

  log4r::debug(.le$logger, "Exiting add_plot_alt_text function")
}
