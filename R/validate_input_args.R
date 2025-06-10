#' validate_input_args
#'
#' @param docx_in input docx to work on
#' @param docx_out output docx to save to
#'
#' @return ()
#' @internal
#'
#' @examples \dontrun{
#' validate_input_args(
#'   "template.docx",
#'   "template-figs.docx"
#' )
#' }
validate_input_args <- function(docx_in, docx_out) {
  log4r::debug(.le$logger, "Starting validate_input_args function")

  if (!file.exists(docx_in)) {
    log4r::error(
      .le$logger,
      paste("The input document does not exist:", docx_in)
    )
    stop(paste("The input document does not exist:", docx_in))
  }

  if (docx_in == docx_out) {
    log4r::error(.le$logger, "Input and output files cannot be the same")
    stop("You must save the output document as a new file.")
  }

  if (!(tools::file_ext(docx_in) == "docx")) {
    log4r::error(
      .le$logger,
      paste(
        "The input file must be a .docx file, not:",
        tools::file_ext(docx_in)
      )
    )
    stop(paste("The file must be a docx file not:", tools::file_ext(docx_in)))
  }

  if (!(tools::file_ext(docx_out) == "docx")) {
    log4r::error(
      .le$logger,
      paste(
        "The output file must be a .docx file, not:",
        tools::file_ext(docx_out)
      )
    )
    stop(paste("The file must be a docx file not:", tools::file_ext(docx_out)))
  }
}
