#' Removes Tables, Figures, and Footnotes from a Word file
#'
#' @description Reads in a `.docx` file and returns a new version with tables, figures, and footnotes removed from the document.
#' @param docx_in The file path to the input `.docx` file.
#' @param docx_out The file path to the output `.docx` file to save to.
#'
#' @export
#'
#' @examples \dontrun{
#'
#' # ---------------------------------------------------------------------------
#' # Load all dependencies
#' # ---------------------------------------------------------------------------
#' docx_in <- here::here("report", "shell", "template.docx")
#' doc_dirs <- make_doc_dirs(docx_in = docx_in)
#'
#' # ---------------------------------------------------------------------------
#' # Removing tables, figures, and footnotes
#' # ---------------------------------------------------------------------------
#' remove_tables_figures_footnotes(
#'   docx_in = doc_dirs$doc_in,
#'   docx_out = doc_dirs$doc_clean
#' )
#' }
remove_tables_figures_footnotes <- function(docx_in,
                                            docx_out) {
  log4r::debug(.le$logger, "Starting remove_tables_figures_footnotes function")

  if (!file.exists(docx_in)) {
    log4r::error(.le$logger, paste("The input document does not exist:", docx_in))
    stop(paste("The input document does not exist:", docx_in))
  }

  log4r::info(.le$logger, paste("Input document found: ", docx_in))

  if (!(tools::file_ext(docx_in) == "docx")) {
    stop(paste("The file must be a docx file not:", tools::file_ext(docx_in)))
  }

  if (!(tools::file_ext(docx_out) == "docx")) {
    stop(paste("The file must be a docx file not:", tools::file_ext(docx_out)))
  }

  if (is.null(getOption("venv_dir"))) {
    log4r::info(.le$logger, "Setting options('venv_dir') to project root.")
    message("Setting options('venv_dir') to project root.")
    options("venv_dir" = here::here())
  }

  venv_path <- file.path(getOption("venv_dir"), ".venv")

  if (!dir.exists(venv_path)) {
    log4r::error(.le$logger, "Virtual environment not found. Please initialize with initialize_python.")
    stop("Create virtual environment with initialize_python")
  }

  uv_path <- get_uv_path()

  notes_script <- system.file("scripts/remove_footnotes.py", package = "reportifyr")
  notes_args <- c("run", notes_script, "-i", docx_in, "-o", docx_out)

  log4r::debug(.le$logger, "Running remove footnotes script")
  notes_result <- tryCatch({
    processx::run(
      command = uv_path, args = notes_args, env = c("current", VIRTUAL_ENV = venv_path), error_on_status = TRUE
    )
  }, error = function(e) {
    log4r::error(.le$logger, paste0("Remove footnotes script failed. Status: ", e$status))
    log4r::error(.le$logger, paste0("Remove footnotes script failed. Stderr: ", e$stderr))
    log4r::info(.le$logger, paste0("Remove footnotes script failed. Stdout: ", e$stdout))
    stop(paste("Remove footnotes script failed. Status: ", e$status, "Stderr: ", e$stderr))
  })

  log4r::info(.le$logger, paste0("Returning status: ", notes_result$status))
  log4r::info(.le$logger, paste0("Returning stdout: ", notes_result$stdout))
  log4r::info(.le$logger, paste0("Returning stderr: ", notes_result$stderr))

  tab_script <- system.file("scripts/remove_tables.py", package = "reportifyr")
  tab_args <- c("run", tab_script, "-i", docx_out, "-o", docx_out)

  log4r::debug(.le$logger, "Running remove tables script")
  tab_result <- tryCatch({
    processx::run(
      command = uv_path, args = tab_args, env = c("current", VIRTUAL_ENV = venv_path), error_on_status = TRUE
      )
  }, error = function(e) {
    log4r::error(.le$logger, paste0("Remove tables script failed. Status: ", e$status))
    log4r::error(.le$logger, paste0("Remove tables strings script failed. Stderr: ", e$stderr))
    log4r::info(.le$logger, paste0("Remove tables strings script failed. Stdout: ", e$stdout))
    stop(paste("Remove tables strings script failed. Status: ", e$status, "Stderr: ", e$stderr))
  })

  log4r::info(.le$logger, paste0("Returning status: ", tab_result$status))
  log4r::info(.le$logger, paste0("Returning stdout: ", tab_result$stdout))
  log4r::info(.le$logger, paste0("Returning stderr: ", tab_result$stderr))

  # input file is output of previous step
  fig_script <- system.file("scripts/remove_figures.py", package = "reportifyr")
  fig_args <- c("run", fig_script, "-i", docx_out, "-o", docx_out)

  log4r::debug(.le$logger, "Running remove figures script")
  fig_result <- tryCatch({
    processx::run(
      command = uv_path, args = fig_args, env = c("current", VIRTUAL_ENV = venv_path), error_on_status = TRUE
    )
  }, error = function(e) {
    log4r::error(.le$logger, paste0("Remove figures script failed. Status: ", e$status))
    log4r::error(.le$logger, paste0("Remove figures strings script failed. Stderr: ", e$stderr))
    log4r::info(.le$logger, paste0("Remove figures strings script failed. Stdout: ", e$stdout))
    stop(paste("Remove figures strings script failed. Status: ", e$status, "Stderr: ", e$stderr))
  })

  log4r::info(.le$logger, paste0("Returning status: ", fig_result$status))
  log4r::info(.le$logger, paste0("Returning stdout: ", fig_result$stdout))
  log4r::info(.le$logger, paste0("Returning stderr: ", fig_result$stderr))

  log4r::debug(.le$logger, "Exiting remove_tables_figures_footnotes function")
}
