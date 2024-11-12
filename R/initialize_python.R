#' Initializes python virtual environment
#'
#' @export
#'
#' @examples \dontrun{
#' initialize_python()
#' }
initialize_python <- function() {
  log4r::debug(.le$logger, "Starting initialize_python function")

  cmd <- system.file("scripts/uv_setup.sh", package = "reportifyr")
  log4r::info(.le$logger, paste0("Command for setting up virtual environment: ", cmd))

  if (is.null(getOption("venv_dir"))) {
    options("venv_dir" = here::here())
    log4r::info(.le$logger, "venv_dir option set to project root")
  }

  args <- c(getOption("venv_dir"))
  log4r::info(.le$logger, paste0("Virtual environment directory: ", args[[1]]))


  if (!is.null(getOption("python-docx.version"))) {
    args <- c(args, getOption("python-docx.version"))
  } else {
    args <- c(args, "1.1.2")
    log4r::info(.le$logger, "Using default python-docx version: 1.1.2")
  }

  if (!is.null(getOption("pyyaml.version"))) {
    args <- c(args, getOption("pyyaml.version"))
  } else {
    args <- c(args, "6.0.2")
    log4r::info(.le$logger, "Using default pyyaml version: 6.0.2")
  }

  if (!is.null(getOption("uv.version"))) {
    args <- c(args, getOption("uv.version"))
  } else {
    args <- c(args, "0.5.1")
    log4r::info(.le$logger, "Using default uv version: 0.5.1")
  }

  if (!is.null(getOption("python.version"))) {
    args <- c(args, getOption("python.version"))
    log4r::info(.le$logger, paste0("Using specified python version: ", getOption("python.version")))
  }

  uv_path <- get_uv_path()

  if (!dir.exists(file.path(args[[1]], ".venv"))) {
    log4r::debug(.le$logger, "Creating new virtual environment")

    result <- processx::run(
      command = cmd,
      args = args
    )
    log4r::info(.le$logger, paste("Virtual environment created at: ", file.path(args[[1]], ".venv")))

    args_name <- c("venv_dir", "python-docx.version", "pyyaml.version", "uv.version", "python.version")
    pyvers <- get_py_version(getOption("venv_dir"))
    if (!is.null(pyvers)) {
      args <- c(args, pyvers)
      log4r::info(.le$logger, paste0("Python version detected: ", pyvers))
    } else {
      args <- c(args, "")
      log4r::warn(.le$logger, "Python version could not be detected")
    }

    message(paste(
      "Creating python virtual environment with the following settings:\n",
      paste0("\t", args_name, ": ", args, collapse = "\n")
    ))
    log4r::debug(.le$logger, ".venv created")

  } else if (!file.exists(uv_path)) {
    message("installing uv")
    result <- processx::run(
      command = cmd,
      args = args
    )
  } else {
    log4r::info(.le$logger, paste(".venv already exists at:", file.path(args[[1]], ".venv")))
    message(paste(
      ".venv already exists at:",
      file.path(args[[1]], ".venv")
    ))
  }
  log4r::debug(.le$logger, "Exiting initialize_python function")
}


#' Grabs python version for .venv
#'
#' @param venv_dir Path to .venv directory
#'
#' @return string of python version or NULL
#' @keywords internal
get_py_version <- function(venv_dir) {
  log4r::debug(.le$logger, "Fetching Python version")
  # Read the file into R
  file_path <- file.path(venv_dir, ".venv", "pyvenv.cfg")
  log4r::debug(.le$logger, paste0("Reading file: ", file_path))

  file_content <- readLines(file_path)

  # Search for the line containing "version_info = "
  version_info_line <- grep("version_info = ", file_content, value = TRUE)

  # Extract everything after "version_info = "
  if (length(version_info_line) > 0) {
    version_info <- sub(".*version_info =\\s*", "", version_info_line)
    log4r::info(.le$logger, paste0("Python version detected: ", version_info))
    return(version_info)
  } else {
    log4r::warn(.le$logger, "Python version info not found in pyvenv.cfg")
    return(NULL)
  }
}
