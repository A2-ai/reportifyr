#' Removes Tables, Figures, and Footnotes from a Word file
#'
#' @description Reads in a `.docx` file and returns a new version with tables, figures, and footnotes removed from the document.
#' @param docx_in The file path to the input `.docx` file.
#' @param docx_out The file path to the output `.docx` file to save to.
#' @param config_yaml The file path to the `config.yaml`. Default is `NULL`, a default `config.yaml` bundled with the `reportifyr` package is used.
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
remove_tables_figures_footnotes <- function(
  docx_in,
  docx_out,
  config_yaml = NULL
) {
  tictoc::tic("remove tables, figures, and footnotes")
  log4r::debug(.le$logger, "Starting remove_tables_figures_footnotes function")

  validate_input_args(docx_in, docx_out)
  validate_alt_text_magic_strings(docx_in)

  paths <- get_venv_uv_paths()
  notes_script <- system.file(
    "scripts/remove_footnotes.py",
    package = "reportifyr"
  )
  notes_args <- c("run", notes_script, "-i", docx_in, "-o", docx_out)

  log4r::debug(.le$logger, "Running remove footnotes script")
  run_python_script(
    paths$uv,
    notes_args,
    paths$venv,
    "Remove footnotes script"
  )

  tab_script <- system.file("scripts/remove_tables.py", package = "reportifyr")
  tab_args <- c("run", tab_script, "-i", docx_out, "-o", docx_out)

  log4r::debug(.le$logger, "Running remove tables script")
  run_python_script(
    paths$uv,
    tab_args,
    paths$venv,
    "Remove tables script"
  )

  # input file is output of previous step
  fig_script <- system.file("scripts/remove_figures.py", package = "reportifyr")
  fig_args <- c("run", fig_script, "-i", docx_out, "-o", docx_out)

  if (is.null(config_yaml)) {
    config_yaml <- system.file("extdata", "config.yaml", package = "reportifyr")
  }
  fig_args <- c(fig_args, "-c", config_yaml)
  log4r::info(.le$logger, paste0("config yaml set: ", config_yaml))

  log4r::debug(.le$logger, "Running remove figures script")
  run_python_script(
    paths$uv,
    fig_args,
    paths$venv,
    "Remove figures script"
  )

  log4r::debug(.le$logger, "Exiting remove_tables_figures_footnotes function")
  tictoc::toc()
}
