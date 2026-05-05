#' Initializes python virtual environment (deprecated)
#'
#' This function is deprecated; it forwards to
#' `fyrstartr::initialize_python()`. The Python environment (uv, Python
#' interpreter, pinned dependencies) is owned by the `fyrstartr` package;
#' call `fyrstartr::initialize_python()` directly in new code.
#'
#' @param continue Optional argument to bypass asking user for
#' confirmation to install python deps.
#'
#' @return invisibly the metadata_file path
#'
#' @export
#'
#' @examples \dontrun{
#' initialize_python()
#' }
initialize_python <- function(continue = NULL) {
  .Deprecated("fyrstartr::initialize_python")
  fyrstartr::initialize_python(continue = continue, groups = "reportifyr")
}
