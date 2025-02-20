#' Helper function that defines document output paths
#'
#' @param docx_in The file path to the input `.docx` file.
#'
#' @return A list of document paths
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
#' }
make_doc_dirs <- function(docx_in){
  log4r::debug(.le$logger, "Starting make_doc_dirs function")

  if (!file.exists(docx_in)) {
    log4r::error(.le$logger, paste("The input document does not exist:", docx_in))
    stop(paste("The input document does not exist:", docx_in))
  }
  log4r::info(.le$logger, paste0("Input document exists: ", docx_in))

  if (!(tools::file_ext(docx_in) == "docx")) {
    log4r::error(.le$logger, paste("The file must be a docx file, not:", tools::file_ext(docx_in)))
    stop(paste("The file must be a docx file not:", tools::file_ext(docx_in)))
  }
  log4r::info(.le$logger, "File type is valid (.docx)")

  base_path <- paste0(gsub("/[^/]+$", "", docx_in), "/")
  base_path <- sub("shell", "draft", base_path)

  log4r::debug(.le$logger, "Base path determined")

  if(base_path == docx_in) base_path <- ""
  log4r::debug(.le$logger, "Base path is equal to input document path, resetting base_path to empty string")

  doc_name  <- gsub(".*/(.*)\\.docx", "\\1", docx_in)
  log4r::info(.le$logger, paste0("Document name determined: ", doc_name))

  doc_clean <- paste0(base_path, doc_name, '-clean.docx')
  doc_tables <- paste0(base_path, doc_name, '-tabs.docx')
  doc_tabs_figs <- paste0(base_path, doc_name, '-tabsfigs.docx')
  doc_draft <- paste0(base_path, doc_name, '-draft.docx')

  base_path <- sub("draft", "final", base_path)
  doc_final <- paste0(base_path, doc_name, '-final.docx')

  doc_dirs <- list(
    'doc_in' = docx_in,
    'doc_clean' = doc_clean,
    'doc_tables' = doc_tables,
    'doc_tabs_figs' = doc_tabs_figs,
    'doc_draft' = doc_draft,
    'doc_final' = doc_final)

  log4r::info(.le$logger, paste0("Document paths created: ", toString(names(doc_dirs))))
  log4r::debug(.le$logger, "Exiting make_doc_dirs function")

  return(doc_dirs)
}
