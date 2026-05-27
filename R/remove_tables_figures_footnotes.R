#' Removes Tables, Figures, and Footnotes from a Word file
#'
#' @description Reads in a `.docx` file and returns a new version with tables, figures, and footnotes removed from the document.
#' @param docx_in The file path to the input `.docx` file.
#' @param docx_out The file path to the output `.docx` file to save to.
#' @param config_yaml The file path to the `config.yaml`. Default is `NULL`, a default `config.yaml` bundled with the `reportifyr` package is used.
#' @param figures_path The file path to the figures directory. Used for hash-based skip of unchanged artifacts. Default is `NULL`.
#' @param tables_path The file path to the tables directory. Used for hash-based skip of unchanged artifacts. Default is `NULL`.
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
  config_yaml = NULL,
  figures_path = NULL,
  tables_path = NULL
) {
  tictoc::tic("remove tables, figures, and footnotes")
  log4r::debug(
    .le$logger,
    "Starting remove_tables_figures_footnotes function"
  )

  validate_input_args(docx_in, docx_out)
  validate_alt_text_magic_strings(docx_in)

  if (is.null(config_yaml)) {
    config_yaml <- system.file(
      "extdata", "config.yaml", package = "reportifyr"
    )
  }
  log4r::info(.le$logger, paste0("config yaml set: ", config_yaml))

  notes_args <- c(
    "run",
    "-m",
    "reportipyr.cli",
    "remove-footnotes",
    "-i",
    docx_in,
    "-o",
    docx_out,
    "-c",
    config_yaml
  )
  if (!is.null(figures_path)) {
    notes_args <- c(notes_args, "--figures-dir", figures_path)
  }
  if (!is.null(tables_path)) {
    notes_args <- c(notes_args, "--tables-dir", tables_path)
  }

  log4r::debug(.le$logger, "Running remove footnotes script")
  run_python_script(
    notes_args,
    "Remove footnotes script"
  )

  tab_args <- c(
    "run",
    "-m",
    "reportipyr.cli",
    "remove-tables",
    "-i",
    docx_out,
    "-o",
    docx_out,
    "-c",
    config_yaml
  )
  if (!is.null(tables_path)) {
    tab_args <- c(tab_args, "-d", tables_path)
  }

  log4r::debug(.le$logger, "Running remove tables script")
  run_python_script(
    tab_args,
    "Remove tables script"
  )

  fig_args <- c(
    "run",
    "-m",
    "reportipyr.cli",
    "remove-figures",
    "-i",
    docx_out,
    "-o",
    docx_out,
    "-c",
    config_yaml
  )
  if (!is.null(figures_path)) {
    fig_args <- c(fig_args, "-d", figures_path)
  }

  log4r::debug(.le$logger, "Running remove figures script")
  run_python_script(
    fig_args,
    "Remove figures script"
  )

  log4r::debug(
    .le$logger,
    "Exiting remove_tables_figures_footnotes function"
  )
  tictoc::toc()
}
