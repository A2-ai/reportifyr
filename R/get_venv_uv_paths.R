#' get_venv_uv_paths (deprecated)
#'
#' Deprecated; forwards to `pyro::get_venv_uv_paths()`. Prefer
#' `pyro::get_venv_uv_paths()` in new code.
#'
#' @return list of paths to uv and venv directory for calling py scripts
#' @export
#'
#' @examples \dontrun{
#' get_venv_uv_paths()
#' }
get_venv_uv_paths <- function() {
  .Deprecated("pyro::get_venv_uv_paths")
  pyro::get_venv_uv_paths()
}
