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

#' Build canonical python-versions schema
#'
#' Pkg versions are read from `.venv/.python_dependency_versions.json`;
#' `fyrstartr.version`, `uv.version`, `python.version`, and `venv_dir`
#' are derived live.
#'
#' @param project_dir Project root; `venv_dir` is recorded relative to it.
#'
#' @return 1:1 `versions` and `package_names` character vectors. Keys in
#'   order: `fyrstartr.version`, `venv_dir`, `python-docx.version`,
#'   `pyyaml.version`, `pillow.version`, `uv.version`, `python.version`.
#'
#' @keywords internal
#' @noRd
build_python_version_data <- function(project_dir) {
  paths <- fyrstartr::get_venv_uv_paths()

  venv_json_path <- file.path(paths$venv, ".python_dependency_versions.json")
  venv_json <- if (file.exists(venv_json_path)) {
    jsonlite::read_json(venv_json_path)
  } else {
    list()
  }

  venv_json_lower <- stats::setNames(venv_json, tolower(names(venv_json)))
  pkg_version <- function(key) {
    val <- venv_json_lower[[tolower(key)]]
    if (is.null(val)) NA_character_ else as.character(val)
  }

  venv_parent <- getOption("venv_dir") %||% project_dir
  venv_dir_rel <- as.character(fs::path_rel(venv_parent, project_dir))

  package_names <- c(
    "fyrstartr.version",
    "venv_dir",
    "python-docx.version",
    "pyyaml.version",
    "pillow.version",
    "uv.version",
    "python.version"
  )
  versions <- c(
    as.character(utils::packageVersion("fyrstartr")),
    venv_dir_rel,
    pkg_version("python-docx.version"),
    pkg_version("pyyaml.version"),
    pkg_version("pillow.version"),
    fyrstartr::get_uv_version(paths$uv),
    fyrstartr::get_py_version(getOption("venv_dir"))
  )

  list(versions = versions, package_names = package_names)
}

