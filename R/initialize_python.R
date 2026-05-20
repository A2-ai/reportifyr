#' Initializes python virtual environment (deprecated)
#'
#' This function is deprecated; it forwards to
#' `pyro::initialize_python()`. The Python environment (uv, Python
#' interpreter, pinned dependencies) is owned by the `pyro` package;
#' call `pyro::initialize_python()` directly in new code.
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
  .Deprecated("pyro::initialize_python")
  pyro::write_group_to_pyproject("reportifyr")
  pyro::initialize_python(continue = continue, groups = "reportifyr")
}
