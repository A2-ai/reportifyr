#' Validates input docx to ensure proper functionality with reportiryf
#'
#' @param docx_in path to input docx
#' @param config_yaml path to config.yaml file
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
  strict_mode <- TRUE # Default value
  if (!is.null(config_yaml)) {
    config <- yaml::read_yaml(config_yaml)
    if (!is.null(config$strict)) {
      strict_mode <- config$strict
    }
  } else {
    log4r::info(.le$logger, "config.yaml not supplied, using strict mode")
  }

  start_pattern <- "\\{rpfy\\}:" # matches "{rpfy}:"
  end_pattern <- "\\.[^.]+$" # matches the file extension (e.g., ".csv", ".rds")
  magic_pattern <- paste0(start_pattern, ".*?", end_pattern)


  doc <- officer::read_docx(docx_in)
  doc_summary <- officer::docx_summary(doc)
  magic_indices <- grep(magic_pattern, doc_summary$text)

  if (length(magic_indices) == 0) {
    log4r::error(
      .le$logger,
      "The file does not contain magic strings."
    )
    stop("The file does not contain magic strings.")
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
  file_names <- c()
  for (i in magic_indices) {
    magic_string <- doc_summary$text[[i]]
    parser <- system.file(
      "scripts/parse_magic_string.py",
      package = "reportifyr"
    )
    args <- c("run", parser, "-i", magic_string)

    result <- processx::run(
      command = uv_path,
      args = args,
      env = c("current", VIRTUAL_ENV = venv_path),
    )

    j <- jsonlite::fromJSON(result$stdout)
    file_names <- c(file_names, names(j))
  }

  duplicated_files <- file_names[duplicated(file_names)]
  if (length(duplicated_files) > 0) {
    if (strict_mode) {
      log4r::error(
        .le$logger,
        paste0(
          "Found duplicate files, please fix: ",
          paste0(duplicated_files, collapse = ", ")
        )
      )
      stop("Using strict mode. Fix duplicate artifacts to continue.")
    } else {
      log4r::warn(
        .le$logger,
        paste0(
          "Found duplicate files, artifact addition might not work properly: ",
          paste0(duplicated_files, collapse = ", ")
        )
      )
    }
  }
}
