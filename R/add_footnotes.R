#' Inserts Footnotes in appropriate places in a Microsoft Word file
#'
#' @description Reads in a `.docx` file and returns a new version with footnotes placed at appropriate places in the document.
#' @param docx_in The file path to the input `.docx` file.
#' @param docx_out The file path to the output `.docx` file to save to.
#' @param figures_path The file path to the figures and associated metadata directory.
#' @param tables_path The file path to the tables and associated metadata directory.
#' @param standard_footnotes_yaml The file path to the `standard_footnotes.yaml`. Default is `NULL`. If `NULL`, a default `standard_footnotes.yaml` bundled with the `reportifyr` package is used.
#' @param config_yaml The file path to the `config.yaml`. Default is `NULL`, a default `config.yaml` bundled with the `reportifyr` package is used.
#' @param include_object_path A boolean indicating whether to include the file path of the figure or table in the footnotes. Default is `FALSE`.
#' @param footnotes_fail_on_missing_metadata A boolean indicating whether to stop execution if the metadata `.json` file for a figure or table is missing. Default is `TRUE`.
#' @param debug Debug.
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
#' figures_path <- here::here("OUTPUTS", "figures")
#' tables_path <- here::here("OUTPUTS", "tables")
#' standard_footnotes_yaml <- here::here("report", "standard_footnotes.yaml")
#'
#' # ---------------------------------------------------------------------------
#' # Step 1.
#' # `add_tables()` will format and insert tables into the `.docx` file.
#' # ---------------------------------------------------------------------------
#' add_tables(
#'   docx_in = doc_dirs$doc_in,
#'   docx_out = doc_dirs$doc_tables,
#'   tables_path = tables_path
#' )
#'
#' # ---------------------------------------------------------------------------
#' # Step 2.
#' # Next we insert the plots using the `add_plots()` function.
#' # ---------------------------------------------------------------------------
#' add_plots(
#'   docx_in = doc_dirs$doc_tables,
#'   docx_out = doc_dirs$doc_tabs_figs,
#'   figures_path = figures_path
#' )
#'
#' # ---------------------------------------------------------------------------
#' # Step 3.
#' # Now we can add the footnotes with the `add_footnotes` function.
#' # ---------------------------------------------------------------------------
#' add_footnotes(
#'   docx_in = doc_dirs$doc_tabs_figs,
#'   docx_out = doc_dirs$doc_draft,
#'   figures_path = figures_path,
#'   tables_path = tables_path,
#'   standard_footnotes_yaml = standard_footnotes_yaml,
#'   include_object_path = FALSE,
#'   footnotes_fail_on_missing_metadata = TRUE
#' )
#' }
add_footnotes <- function(
  docx_in,
  docx_out,
  figures_path,
  tables_path,
  standard_footnotes_yaml = NULL,
  config_yaml = NULL,
  include_object_path = FALSE,
  footnotes_fail_on_missing_metadata = TRUE,
  debug = FALSE
) {
  log4r::debug(.le$logger, "Starting add_footnotes function")

  tictoc::tic("add footnotes")

  if (debug) {
    log4r::debug(.le$logger, "Debug mode enabled")
    browser()
  }

  validate_input_args(docx_in, docx_out)
  validate_docx(docx_in, config_yaml)
  log4r::info(.le$logger, paste0("Output document path set: ", docx_out))

  fig_args <- c(
    "run",
    "-m",
    "reportipyr.cli",
    "add-figure-footnotes",
    "-i",
    docx_in,
    "-o",
    docx_out,
    "-d",
    figures_path,
    "-b",
    include_object_path,
    "-m",
    footnotes_fail_on_missing_metadata
  )

  # input file should be output file from call above
  tab_args <- c(
    "run",
    "-m",
    "reportipyr.cli",
    "add-table-footnotes",
    "-i",
    docx_out,
    "-o",
    docx_out,
    "-d",
    tables_path,
    "-b",
    include_object_path,
    "-m",
    footnotes_fail_on_missing_metadata
  )

  if (!is.null(standard_footnotes_yaml)) {
    log4r::info(
      .le$logger,
      paste0("Using provided footnotes file: ", standard_footnotes_yaml)
    )
  } else {
    standard_footnotes_yaml <- system.file(
      "extdata/standard_footnotes.yaml",
      package = "reportifyr"
    )
    log4r::info(
      .le$logger,
      paste0("Using default footnotes file: ", standard_footnotes_yaml)
    )
  }
  # add footnotes yaml to args
  fig_args <- c(fig_args, "-f", standard_footnotes_yaml)
  tab_args <- c(tab_args, "-f", standard_footnotes_yaml)

  if (!is.null(config_yaml)) {
    if (!validate_config(config_yaml)) {
      stop("Invalid config yaml. Please fix")
    }
    log4r::info(
      .le$logger,
      paste0("Using provided config file: ", config_yaml)
    )
  } else {
    config_yaml <- system.file(
      "extdata/config.yaml",
      package = "reportifyr"
    )
    log4r::info(
      .le$logger,
      paste0("Using default config file: ", config_yaml)
    )
  }
  log4r::info(.le$logger, "Adding config.yaml to args")
  fig_args <- c(fig_args, "-c", config_yaml)
  tab_args <- c(tab_args, "-c", config_yaml)

  paths <- pyro::get_venv_uv_paths()
  log4r::debug(.le$logger, "Running figure footnotes script")
  run_python_script(
    paths$uv,
    fig_args,
    paths$venv,
    "Figure footnotes script"
  )

  log4r::debug(.le$logger, "Running table footnotes script")
  run_python_script(
    paths$uv,
    tab_args,
    paths$venv,
    "Table footnotes script"
  )

  tictoc::toc()

  log4r::debug(.le$logger, "Exiting add_footnotes function")
}
