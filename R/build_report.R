#' Updates a Microsoft Word file to include formatted plots, tables, and footnotes
#'
#' @description Reads in a `.docx` file and returns a new version with plots, tables, and footnotes replaced.
#' @param docx_in The file path to the input `.docx` file.
#' @param docx_out The file path to the output `.docx` file to save to. Default is `NULL`.
#' @param figures_path The file path to the figures and associated metadata directory.
#' @param tables_path The file path to the tables and associated metadata directory.
#' @param standard_footnotes_yaml The file path to the `standard_footnotes.yaml`. Default is `NULL`. If `NULL`, a default `standard_footnotes.yaml` bundled with the `reportifyr` package is used.
#' @param config_yaml The file path to the `config.yaml`. Default is `NULL`, a default `config.yaml` bundled with the `reportifyr` package is used.
#' @param add_footnotes A boolean indicating whether to insert footnotes into the `docx_in` or not. Default is `TRUE`.
#' @param include_object_path A boolean indicating whether to include the file path of the figure or table in the footnotes. Default is `FALSE`.
#' @param footnotes_fail_on_missing_metadata A boolean indicating whether to stop execution if the metadata `.json` file for a figure or table is missing. Default is `TRUE`.
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
#' # Run the `build_report()` wrapper function to replace figures, tables, and
#' # footnotes in a `.docx` file.
#' # ---------------------------------------------------------------------------
#' build_report(
#'   docx_in = doc_dirs$doc_in,
#'   docx_out = doc_dirs$doc_draft,
#'   figures_path = figures_path,
#'   tables_path = tables_path,
#'   standard_footnotes_yaml = standard_footnotes_yaml
#' )
#' }
build_report <- function(
    docx_in,
    docx_out = NULL,
    figures_path,
    tables_path,
    standard_footnotes_yaml = NULL,
    config_yaml = NULL,
    add_footnotes = TRUE,
    include_object_path = FALSE,
    footnotes_fail_on_missing_metadata = TRUE) {
  log4r::debug(.le$logger, "Starting build_report function")

  validate_input_args(docx_in, docx_out, config_yaml)
  validate_docx(docx_in, config_yaml)
  log4r::info(.le$logger, paste0("Output document path set: ", docx_out))

	doc_dirs <- make_doc_dirs(docx_in = docx_in)
  if (is.null(docx_out)) {
    docx_out <- doc_dirs$doc_draft
    log4r::info(
      .le$logger,
      paste0("Docx_out is null, setting docx_out to: ", docx_out)
    )
  }

  # Save over input docx without tfls
  remove_tables_figures_footnotes(
    docx_in = docx_in,
    docx_out = doc_dirs$doc_clean,
    config_yaml
  )

  add_tables(
    docx_in = doc_dirs$doc_clean,
    docx_out = doc_dirs$doc_tables,
    tables_path = tables_path,
    config_yaml
  )

  if (add_footnotes) {
    docx_out_figs <- doc_dirs$doc_tabs_figs
  } else {
    docx_out_figs <- docx_out
  }

  add_plots(
    docx_in = doc_dirs$doc_tables,
    docx_out = docx_out_figs,
    figures_path = figures_path,
    config_yaml
  )

  if (add_footnotes) {
    tryCatch(
      {
        suppressWarnings({
          add_footnotes(
            docx_in = doc_dirs$doc_tabs_figs,
            docx_out = docx_out,
            figures_path = figures_path,
            tables_path = tables_path,
            standard_footnotes_yaml = standard_footnotes_yaml,
            config_yaml = config_yaml,
            include_object_path = include_object_path,
            footnotes_fail_on_missing_metadata = footnotes_fail_on_missing_metadata
          )
        })
      },
      error = function(e) {
        log4r::error(.le$logger, paste("Footnotes scripts failed:", e$message))
        stop(
          "build_report stopped: Failed to add footnotes due to an error in add_footnotes.",
          call. = FALSE
        )
      }
    )
  }

  output_dir <- dirname(docx_out)
  intermediate_dir <- file.path(output_dir, "intermediate_files")

  if (!dir.exists(intermediate_dir)) {
    log4r::info(
      .le$logger,
      paste0("Creating intermediate files directory: ", intermediate_dir)
    )
    dir.create(intermediate_dir)
  }

  files_and_dirs <- list.files(output_dir, full.names = TRUE)

  for (item in files_and_dirs) {
    log4r::info(.le$logger, paste0("Moving file: ", item))
    if (
      item != docx_out &&
        item != docx_in &&
        item != intermediate_dir &&
        basename(item) != "readme.txt"
    ) {
      file.rename(item, file.path(intermediate_dir, basename(item)))
    }
  }
  log4r::debug(.le$logger, "Exiting build_report function")
}
