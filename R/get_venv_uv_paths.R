#' get_venv_uv_paths (deprecated)
#'
#' Deprecated; forwards to `fyrstartr::get_venv_uv_paths()`. Prefer
#' `fyrstartr::get_venv_uv_paths()` in new code.
#'
#' @return list of paths to uv and venv directory for calling py scripts
#' @export
#'
#' @examples \dontrun{
#' get_venv_uv_paths()
#' }
get_venv_uv_paths <- function() {
  .Deprecated("fyrstartr::get_venv_uv_paths")
  fyrstartr::get_venv_uv_paths()
}
