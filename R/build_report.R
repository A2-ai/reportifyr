#' Updates a Word file to include formatted plots, tables, and footnotes
#'
#' @description Reads in a .docx file and returns an updated version with plots, tables, and footnotes replaced.
#' @param docx_in Path to input .docx to update
#' @param docx_out Path to output .docx to save to
#' @param figures_path Path to images file directory
#' @param tables_path Path to tables file directory
#' @param standard_footnotes_yaml Path to standard_footnotes.yaml in report
#' @param add_footnotes boolean for including footnotes in the document or not
#' @param include_object_path boolean for including object path in footnotes
#' @param footnotes_fail_on_missing_metadata Boolean for allowing objects to lack metadata and thus have no footnotes
#'
#' @export
#'
#' @examples \dontrun{
#'
#' # ---------------------------------------------------------------------------
#' # Load all dependencies
#' # ---------------------------------------------------------------------------
#' docx_in <- file.path(here::here(), "report", "shell", "template.docx")
#' figures_path <- file.path(here::here(), "OUTPUTS", "figures")
#' tables_path <- file.path(here::here(), "OUTPUTS", "tables")
#' footnotes <- file.path(here::here(), "report", "standard_footnotes.yaml")
#'
#' # ---------------------------------------------------------------------------
#' # Step 1.
#' # Run the wrapper function to replace figures, tables, and footnotes in a
#' # .docx file.
#' # ---------------------------------------------------------------------------
#' build_report(
#'   docx_in = docx_in,
#'   docx_out = doc_dirs$doc_draft,
#'   figures_path = figures_path,
#'   tables_path = tables_path,
#'   standard_footnotes_yaml = footnotes
#' )
#' }
build_report <- function(docx_in,
                         docx_out,
                         figures_path,
                         tables_path,
                         standard_footnotes_yaml = NULL,
                         add_footnotes = TRUE,
                         include_object_path = FALSE,
                         footnotes_fail_on_missing_metadata = TRUE) {
  log4r::debug(.le$logger, "Starting build_report function")

  if (!file.exists(docx_in)) {
    log4r::error(.le$logger, paste("The input document does not exist:", docx_in))
    stop(paste("The input document does not exist:", docx_in))
  }
  log4r::info(.le$logger, paste0("Input document found: ", docx_in))

  if (docx_in == docx_out) {
    log4r::error(.le$logger, "Input and output files cannot be the same")
    stop("You must save the output document as a new file.")
  }
  log4r::info(.le$logger, paste0("Output document path set: ", docx_out))

  if (!(tools::file_ext(docx_in) == "docx")) {
    log4r::error(.le$logger, paste("The input file must be a .docx file, not:", tools::file_ext(docx_in)))
    stop(paste("The file must be a docx file not:", tools::file_ext(docx_in)))
  }

  if (!(tools::file_ext(docx_out) == "docx")) {
    log4r::error(.le$logger, paste("The output file must be a .docx file, not:", tools::file_ext(docx_out)))
    stop(paste("The file must be a docx file not:", tools::file_ext(docx_out)))
  }

  doc_dirs <- make_doc_dirs(docx_in = docx_in)
  # Save over input docx without tfls
  remove_tables_figures_footnotes(docx_in = docx_in, docx_out = doc_dirs$doc_clean)

  add_tables(
    docx_in = doc_dirs$doc_clean,
    docx_out = doc_dirs$doc_tables,
    tables_path = tables_path
  )

  if (add_footnotes) {
    docx_out_figs = doc_dirs$doc_tabs_figs
  } else {
    docx_out_figs = docx_out
  }

  add_plots(
    docx_in = doc_dirs$doc_tables,
    docx_out = docx_out_figs,
    figures_path = figures_path
  )

  if (add_footnotes) {
    tryCatch({
      suppressWarnings({
        add_footnotes(
          docx_in = doc_dirs$doc_tabs_figs,
          docx_out = docx_out,
          figures_path = figures_path,
          tables_path = tables_path,
          footnotes = standard_footnotes_yaml,
          include_object_path = include_object_path,
          footnotes_fail_on_missing_metadata = footnotes_fail_on_missing_metadata
        )
      })
    }, error = function(e) {
      log4r::error(.le$logger, paste("Footnotes scripts failed:", e$message))
      stop("build_report stopped: Failed to add footnotes due to an error in add_footnotes.", call. = FALSE)
    })
  }


  output_dir <- dirname(docx_out)
  intermediate_dir <- file.path(output_dir, "intermediate_files")

  if (!dir.exists(intermediate_dir)) {
    log4r::info(.le$logger, paste0("Creating intermediate files directory: ", intermediate_dir))
    dir.create(intermediate_dir)
  }

  files_and_dirs <- list.files(output_dir, full.names = TRUE)

  for (item in files_and_dirs) {
    log4r::info(.le$logger, paste0("Moving file: ", item))
    if (item != docx_out && item != docx_in && item != intermediate_dir && basename(item) != "readme.txt") {
      file.rename(item, file.path(intermediate_dir, basename(item)))
    }
  }
  log4r::debug(.le$logger, "Exiting build_report function")
}
