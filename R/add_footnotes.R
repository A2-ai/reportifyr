#' Inserts Footnotes in appropriate places in Word files
#'
#' @description Reads in a .docx file and returns a new version with footnotes placed at appropriate places in the document.
#' @param docx_in Path to the input .docx file
#' @param docx_out Path to output .docx to save to
#' @param figures_path Path to images and associated metadata directory
#' @param tables_path Path to tables and associated metadata directory
#' @param standard_footnotes_yaml Path to standard_footnotes.yaml
#' @param include_object_path Boolean for including object path path in footnotes
#' @param footnotes_fail_on_missing_metadata Boolean for allowing objects to lack metadata and thus have no footnotes
#' @param debug Debug
#'
#' @export
#'
#' @examples \dontrun{
#'
#' # ---------------------------------------------------------------------------
#' # Load all dependencies
#' # ---------------------------------------------------------------------------
#' docx_in <- file.path(here::here(), "report", "shell", "template.docx")
#' doc_dirs <- make_doc_dirs(docx_in = docx_in)
#' figures_path <- file.path(here::here(), "OUTPUTS", "figures")
#' tables_path <- file.path(here::here(), "OUTPUTS", "tables")
#' standard_footnotes_yaml <- file.path(here::here(), "report", "standard_footnotes.yaml")
#'
#' # ---------------------------------------------------------------------------
#' # Step 1.
#' # Table addition running add_tables will format and insert tables into the doc.
#' # ---------------------------------------------------------------------------
#' add_tables(
#'   docx_in = docx_in,
#'   docx_out = doc_dirs$doc_tables,
#'   tables_path = tables_path
#' )
#'
#' # ---------------------------------------------------------------------------
#' # Step 2.
#' # Next we place in the plots using the add_plots function.
#' # ---------------------------------------------------------------------------
#' add_plots(
#'   docx_in = doc_dirs$doc_tables,
#'   docx_out = doc_dirs$doc_tabs_figs,
#'   figures_path = figures_path
#' )
#'
#' # ---------------------------------------------------------------------------
#' # Step 3.
#' # Now we can add the footnotes to all the inserted figures and tables.
#' # ---------------------------------------------------------------------------
#' add_footnotes(
#'   docx_in = doc_dirs$doc_tabs_figs,
#'   docx_out = doc_dirs$doc_draft,
#'   figures_path = figures_path,
#'   tables_path = tables_path,
#'   standard_footnotes_yaml = standard_footnotes_yaml,
#'   include_object_path = TRUE
#'   footnotes_fail_on_missing_metadata
#' )
#' }
add_footnotes <- function(docx_in,
                          docx_out,
                          figures_path,
                          tables_path,
                          standard_footnotes_yaml = NULL,
                          include_object_path = FALSE,
                          footnotes_fail_on_missing_metadata = TRUE,
                          debug = F) {
  log4r::debug(.le$logger, "Starting add_footnotes function")

  tictoc::tic()

  if (!file.exists(docx_in)) {
    log4r::error(.le$logger, paste("The input document does not exist:", docx_in))
    stop(paste("The input document does not exist:", docx_in))
  }
  log4r::info(.le$logger, paste0("Input document found: ", docx_in))

  if (!(tools::file_ext(docx_in) == "docx")) {
    log4r::error(.le$logger, paste("The file must be a docx file, not:", tools::file_ext(docx_in)))
    stop(paste("The file must be a docx file not:", tools::file_ext(docx_in)))
  }

  if (!(tools::file_ext(docx_out) == "docx")) {
    log4r::error(.le$logger, paste("The output file must be a docx file, not:", tools::file_ext(docx_out)))
    stop(paste("The file must be a docx file not:", tools::file_ext(docx_out)))
  }

  if (debug) {
    log4r::debug(.le$logger, "Debug mode enabled")
    browser()
  }

  fig_script <- system.file("scripts/add_figure_footnotes.py", package = "reportifyr")
  fig_args <- c("run", fig_script, "-i", docx_in, "-o", docx_out, "-d", figures_path, "-b", include_object_path, "-m", footnotes_fail_on_missing_metadata)

  # input file should be output file from call above
  tab_script <- system.file("scripts/add_table_footnotes.py", package = "reportifyr")
  tab_args <- c("run", tab_script, "-i", docx_out, "-o", docx_out, "-d", tables_path, "-b", include_object_path, "-m", footnotes_fail_on_missing_metadata)

  if (!is.null(standard_footnotes_yaml)) {
    log4r::info(.le$logger, paste0("Using provided footnotes file: ", standard_footnotes_yaml))
    fig_args <- c(fig_args, "-f", standard_footnotes_yaml)
    tab_args <- c(tab_args, "-f", standard_footnotes_yaml)
  } else {
    footnotes_file <- system.file("extdata/standard_footnotes.yaml", package = "reportifyr")
    log4r::info(.le$logger, paste0("Using default footnotes file: ", footnotes_file))
    fig_args <- c(fig_args, "-f", footnotes_file)
    tab_args <- c(tab_args, "-f", footnotes_file)
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

  log4r::debug(.le$logger, "Running figure footnotes script")
  fig_results <- tryCatch({
    result <- processx::run(
      command = uv_path, args = fig_args, env = c("current", VIRTUAL_ENV = venv_path), error_on_status = TRUE
      )
    if (nzchar(result$stderr)) {
      log4r::warn(.le$logger, paste0("Figure footnotes script stderr: ", result$stderr))
    }
  }, error = function(e) {
    log4r::error(.le$logger, paste0("Figure footnotes script failed. Status: ", e$status))
    log4r::error(.le$logger, paste0("Figure footnotes script failed. Stderr: ", e$stderr))
    log4r::info(.le$logger, paste0("Figure footnotes script failed. Stdout: ", e$stdout))
    stop(paste("Figure footnotes script failed. Status: ", e$status, "Stderr: ", e$stderr), call. = FALSE)
  })

  log4r::info(.le$logger, paste0("Returning status: ", fig_results$status))
  log4r::info(.le$logger, paste0("Returning stderr: ", fig_results$stderr))
  log4r::info(.le$logger, paste0("Returning stdout: ", fig_results$stdout))

  log4r::debug(.le$logger, "Running table footnotes script")
  tab_results <- tryCatch({
    result <- processx::run(
      command = uv_path, args = tab_args, env = c("current", VIRTUAL_ENV = venv_path), error_on_status = TRUE
    )
    if (nzchar(result$stderr)) {
      log4r::warn(.le$logger, paste0("Table footnotes script stderr: ", result$stderr))
    }
  }, error = function(e) {
    log4r::error(.le$logger, paste0("Table footnotes script failed. Status: ", e$status))
    log4r::error(.le$logger, paste0("Table footnotes script failed. Stderr: ", e$stderr))
    log4r::info(.le$logger, paste0("Table footnotes script failed. Stdout: ", e$stdout))
    stop(paste("Table footnotes script failed. Status: ", e$status, "Stderr: ", e$stderr), call. = FALSE)
  })

  log4r::info(.le$logger, paste0("Returning status: ", tab_results$status))
  log4r::info(.le$logger, paste0("Returning stderr: ", tab_results$stderr))
  log4r::info(.le$logger, paste0("Returning stdout: ", tab_results$stdout))

  tictoc::toc()
  log4r::debug(.le$logger, "Exiting add_footnotes function")
}
