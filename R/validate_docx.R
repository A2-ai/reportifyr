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

  validator <- system.file(
    "scripts/validate_docx.py",
    package = "reportifyr"
  )

  args <- c("run", validator, "-i", docx_in)
  if (!strict_mode) {
    args <- c(args, "--no-strict")
  }

  result <- processx::run(
    command = uv_path,
    args = args,
    env = c("current", VIRTUAL_ENV = venv_path),
    error_on_status = FALSE
  )

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
