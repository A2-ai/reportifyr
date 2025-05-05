#' Finalizes the Microsoft Word file by removing magic strings and bookmarks
#'
#' @description Reads in a `.docx` file and returns a finalized version with magic strings and bookmarks removed.
#' @param docx_in The file path to the input `.docx` file.
#' @param docx_out The file path to the output `.docx` file to save to. Default is `NULL`. If `NULL`, `docx_out` is assigned `doc_dirs$doc_final` using `make_doc_dirs(docx_in = docx_in)`.
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
#'   standard_footnotes_yaml = standard_footnote_yaml
#' )
#'
#' # ---------------------------------------------------------------------------
#' # Step 2.
#' # If you are ready to finalize the `.docx` file, run the `finalize_document()`
#' # function. This will remove the ties between reportifyr and the document, so
#' # please be mindful!
#' # ---------------------------------------------------------------------------
#' finalize_document(
#'   docx_in = doc_dirs$doc_draft,
#'   docx_out = doc_dirs$doc_final
#' )
#' }
finalize_document <- function(docx_in, docx_out = NULL) {
  log4r::debug(.le$logger, "Starting finalize_document function")

  if (is.null(docx_out)) {
    doc_dirs <- make_doc_dirs(docx_in = docx_in)
    docx_out <- doc_dirs$doc_final
    log4r::info(
      .le$logger,
      paste0("Docx_out is null, setting docx_out to: ", docx_out)
    )
  }

  validate_input_args(docx_in, docx_out)
  validate_docx(docx_in)
  log4r::info(.le$logger, paste0("Output document path set: ", docx_out))

  intermediate_docx <- gsub(".docx", "-int.docx", docx_out)
  log4r::info(
    .le$logger,
    paste0("Intermediate document path set: ", intermediate_docx)
  )

  remove_bookmarks(docx_in, intermediate_docx)

  # remove magic strings on output of previous doc
  remove_magic_strings(intermediate_docx, docx_out)

  unlink(intermediate_docx)
  log4r::debug(.le$logger, "Deleting intermediate document")

  write_object_metadata(object_file = docx_out)

  log4r::debug(.le$logger, "Exiting finalize_document function")
}
