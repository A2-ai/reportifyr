#' get_venv_uv_paths
#'
#' @return list of paths to uv and venv directory for calling py scripts
#' @export
#'
#' @examples \dontrun{
#' get_venv_uv_paths()
#' }
get_venv_uv_paths <- function() {
  if (is.null(getOption("venv_dir"))) {
    log4r::info(.le$logger, "Setting options('venv_dir') to project root.")

    message("Setting options('venv_dir') to project root.")
    options("venv_dir" = here::here())
  }
  venv_path <- file.path(getOption("venv_dir"), ".venv")

  if (!dir.exists(venv_path)) {
    log4r::error(
      .le$logger,
      "Virtual environment not found. Please initialize with initialize_python."
    )
    stop("Create virtual environment with initialize_python")
  }

  uv_path <- get_uv_path()
  if (is.null(uv_path)) {
    log4r::error(
      .le$logger,
      "uv not found. Please install with initialize_python"
    )
    stop("Please install uv with initialize_python")
  }

  list(uv = uv_path, venv = venv_path)
}
