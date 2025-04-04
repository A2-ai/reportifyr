#' Initializes python virtual environment
#'
#' @export
#'
#' @param continue Optional argument to bypass asking user for
#' confirmation to install python deps
#'
#' @return invisibly the metadata_file path
#'
#' @examples \dontrun{
#' initialize_python()
#' }
initialize_python <- function(continue = NULL) {
  log4r::debug(.le$logger, "Starting initialize_python function")
  # ask user to continue
  if (is.null(continue)) {
    continue <- continue()
  }

  if (tolower(continue) != "y") {
    if (continue == "n") {
      log4r::info(.le$logger, "User declined installation. No changes made.")
      message(
        "User declined installation of uv, Python, and Python dependencies.\n
        Full functionality of reportifyr will not be available."
      )
    } else {
      log4r::error(.le$logger, "Invalid response from user. Must enter Y or n.")
      stop("Must enter Y or n.")
    }
    log4r::debug(.le$logger, "Exiting initialize_python function")
    return(invisible(NULL))
  }

  log4r::info(.le$logger, "Installation confirmed.")

  cmd <- system.file("scripts/uv_setup.sh", package = "reportifyr")
  log4r::info(
    .le$logger,
    paste0("Command for setting up virtual environment: ", cmd)
  )

  uv_path <- get_uv_path()
  log4r::info(.le$logger, paste0("uv path: ", uv_path))

  args <- get_args(uv_path)
  args_name <- c(
    "venv_dir",
    "python-docx.version",
    "pyyaml.version",
    "pillow.version",
    "uv.version",
    "python.version"
  )
  log4r::info(.le$logger, paste0("args: ", paste0(args, collapse = ", ")))

  venv_dir <- file.path(args[[1]], ".venv")
  is_new_env <- !dir.exists(venv_dir)

  # Run the setup script for both new and existing environments
  result <- processx::run(
    command = cmd,
    args = args
  )
  # Get Python version AFTER environment exists
  pyvers <- get_py_version(getOption("venv_dir"))
  if (!is.null(pyvers)) {
    log4r::info(.le$logger, paste0("Python version detected: ", pyvers))
    # Add Python version to args for metadata
    args <- c(args, pyvers)
  } else {
    log4r::warn(.le$logger, "Python version could not be detected")
    args <- c(args, "")
  }

  if (is_new_env) {
    log4r::debug(.le$logger, "Creating new virtual environment")
    message(paste(
      "Creating python virtual environment with the following settings:\n",
      paste0("\t", args_name, ": ", args, collapse = "\n")
    ))
  } else if (!file.exists(uv_path)) {
    message("installing uv")
  } else {
    log4r::info(
      .le$logger,
      paste(".venv already exists at:", venv_dir)
    )
  }

  message(result$stdout)
  # Log appropriate message based on whether we created or used existing environment
  if (is_new_env) {
    log4r::info(
      .le$logger,
      paste("Virtual environment created at: ", venv_dir)
    )
    log4r::debug(.le$logger, ".venv created")
  } else if (file.exists(uv_path)) {
    log4r::info(
      .le$logger,
      paste("Virtual environment already present at: ", venv_dir)
    )
  }

  # Add the write_package_metadata call with updated args (including Python version)
  metadata_file <- write_package_version_metadata(args, args_name, venv_dir)

  log4r::debug(.le$logger, "Exiting initialize_python function")
  invisible(metadata_file)
} #' Grabs python version for .venv
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

    version_info
  } else {
    log4r::warn(.le$logger, "Python version info not found in pyvenv.cfg")

    NULL
  }
}

#' Asks a user to continue
#'
#' @return y/n string
#' @keywords internal
#' @noRd
continue <- function() {
  if (interactive()) {
    log4r::info(
      .le$logger,
      "Prompting user for confirmation to install uv, Python,
			and Python dependencies to your local files."
    )
    continue <- readline(
      "If uv, Python, and Python dependencies (python-docx, PyYAML, Pillow)
			\nare not installed, this will install them.
			\nOtherwise, the installed versions will be used.
			\nAre you sure you want to continue? [Y/n]\n"
    )
  } else {
    continue <- "Y" # Automatically proceed in non-interactive environments
    log4r::info(
      .le$logger,
      "Non-interactive session detected, proceeding with installation."
    )
  }
  continue
}

#' Gets args for us_setup.sh
#'
#' @param uv_path path to uv
#'
#' @return list of args
#' @keywords internal
#' @noRd
get_args <- function(uv_path) {
  if (is.null(getOption("venv_dir"))) {
    options("venv_dir" = here::here())
    log4r::info(.le$logger, "venv_dir option set to project root")
  }

  args <- c(getOption("venv_dir"))
  log4r::info(
    .le$logger,
    paste0("Virtual environment directory: ", args[[1]])
  )

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

  if (!is.null(getOption("pillow.version"))) {
    args <- c(args, getOption("pillow.version"))
  } else {
    args <- c(args, "11.1.0")
    log4r::info(.le$logger, "Using default pillow version: 11.1.0")
  }

  if (!is.null(getOption("uv.version"))) {
    args <- c(args, getOption("uv.version"))
  } else {
    if (is.null(uv_path)) {
      args <- c(args, "0.5.1")
      log4r::info(.le$logger, "Using default uv version: 0.5.1")
    } else {
      uv_version <- get_uv_version(uv_path)
      args <- c(args, uv_version)
      log4r::info(.le$logger, paste0("Using uv version: ", uv_version))
    }
  }

  if (!is.null(getOption("python.version"))) {
    args <- c(args, getOption("python.version"))
    log4r::info(
      .le$logger,
      paste0("Using specified python version: ", getOption("python.version"))
    )
  }
  args
}

#' Writes python package versions and venv directory metadata
#' to json file for reference.
#'
#' @param versions vector of package versions
#' @param package_names vector of package names, 1:1 to versions
#' @param dir directory to save metadata.json
#'
#' @return invisibly the metadata_file path
#'
#' @keywords internal
#' @noRd
write_package_version_metadata <- function(versions, package_names, dir) {
  log4r::info(.le$logger, "Writing python dependency versions metadata")

  data_to_save <- stats::setNames(as.list(versions), package_names)
  log4r::debug(.le$logger, "Assembled data for saving as JSON")

  json_data <- jsonlite::toJSON(data_to_save, pretty = TRUE, auto_unbox = TRUE)
  log4r::debug(.le$logger, "Data converted to json string")

  json_with_comment <- paste(
    "// WARNING: This file is automatically generated on initialization. Do not edit by hand!",
    json_data,
    sep = "\n"
  )
  metadata_file <- file.path(dir, "python_dependency_versions.json")
  write(json_with_comment, file = metadata_file)

  log4r::info(.le$logger, paste0("metadata written to file: ", metadata_file))

  log4r::debug(.le$logger, "Exiting write_package_version_metadata function")
  metadata_file
}
