#' Finalizes the document by removing magic strings and bookmarks
#'
#' @description Reads in a .docx file and returns a finalized version with magic strings and bookmarks removed.
#' @param docx_in Path to input .docx to finalize
#' @param docx_out Path to output .docx to save to
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
#' # Run the wrapper function build_report() to replace figures, tables, and
#' # footnotes in a .docx file.
#' # ---------------------------------------------------------------------------
#' build_report(
#'   docx_in = docx_in,
#'   docx_out = doc_dirs$doc_draft,
#'   figures_path = figures_path,
#'   tables_path = tables_path,
#'   standard_footnotes_yaml = footnotes
#' )
#'
#' # ---------------------------------------------------------------------------
#' # Step 2.
#' # If you are happy with the report and are ready to finalize the document.
#' # ---------------------------------------------------------------------------
#' finalize_document(
#'   docx_in = doc_dirs$doc_draft,
#'   docx_out = doc_dirs$doc_final
#' )
#' }
finalize_document <- function(docx_in,
                              docx_out = NULL) {
  log4r::debug(.le$logger, "Starting finalize_document function")

  if (!file.exists(docx_in)) {
    log4r::error(.le$logger, paste("Input file does not exist:", docx_in))
    stop("Input file does not exist.")
  }
  log4r::info(.le$logger, paste0("Input document found: ", docx_in))

  if (is.null(docx_out)) {
    doc_dirs <- make_doc_dirs(docx_in = docx_in)
    docx_out <- doc_dirs$doc_final
    log4r::info(.le$logger, paste0("Docx_out is null, setting docx_out to: ", docx_out))
  }

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

  intermediate_docx <- gsub(".docx", "-int.docx", docx_out)
  log4r::info(.le$logger, paste0("Intermediate document path set: ", intermediate_docx))

  remove_bookmarks(docx_in, intermediate_docx)

  # remove magic strings on output of previous doc
  remove_magic_strings(intermediate_docx, docx_out)

  unlink(intermediate_docx)
  log4r::debug(.le$logger, "Deleting intermediate document")


  write_object_metadata(object_file = docx_out)

  log4r::debug(.le$logger, "Exiting finalize_document function")
}
