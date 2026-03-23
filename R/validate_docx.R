#' Validates input Microsoft Word file to ensure proper functionality with reportifyr
#'
#' @param docx_in The file path to the input `.docx` file.
#' @param config_yaml The file path to the `config.yaml`.
#'
#' @export
#'
#' @examples \dontrun{
#' validate_docx(
#'   here::here("report/shell/template.docx"),
#'   here::here("report/config.yaml")
#' )
#' }
validate_docx <- function(docx_in, config_yaml) {
  log4r::debug(.le$logger, "Starting validate_docx function")

  if (!file.exists(docx_in)) {
    log4r::error(
      .le$logger,
      paste("The input document does not exist:", docx_in)
    )
    stop(paste("The input document does not exist:", docx_in))
  }
  log4r::info(.le$logger, paste0("Input document found: ", docx_in))

  if (!(tools::file_ext(docx_in) == "docx")) {
    log4r::error(
      .le$logger,
      paste("The file must be a docx file, not:", tools::file_ext(docx_in))
    )
    stop(paste("The file must be a docx file not:", tools::file_ext(docx_in)))
  }

  strict_mode <- TRUE
  if (!is.null(config_yaml)) {
    config <- yaml::read_yaml(config_yaml)
    if (!is.null(config$strict)) {
      strict_mode <- config$strict
    }
  } else {
    log4r::info(.le$logger, "config.yaml not supplied, using strict mode")
  }

  paths <- get_venv_uv_paths()

  args <- c(
    "run",
    "-m",
    "reportipyr.cli",
    "validate-docx",
    "-i",
    docx_in
  )
  if (!strict_mode) {
    args <- c(args, "--no-strict")
  }

  python_path <- system.file("python", package = "reportifyr")
  env_vars <- c("current", VIRTUAL_ENV = paths$venv)
  if (nzchar(python_path)) {
    env_vars <- c(env_vars, PYTHONPATH = python_path)
  }

  result <- processx::run(
    command = paths$uv,
    args = args,
    env = env_vars,
    error_on_status = FALSE
  )

  if (!nzchar(trimws(result$stdout))) {
    log4r::error(.le$logger, "validate-docx returned no output")
    stop("validate-docx failed -- check log file for Python errors.")
  }

  validation <- jsonlite::fromJSON(result$stdout)

  # Log warnings
  for (warning_msg in validation$warnings) {
    log4r::warn(.le$logger, warning_msg)
  }

  # Handle errors
  if (!validation$success) {
    for (error_msg in validation$errors) {
      log4r::error(.le$logger, error_msg)
    }
    stop(validation$errors[[length(validation$errors)]])
  }
}
