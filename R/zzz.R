.onLoad <- function(libname, pkgname) {
  # Set up log file path (lazy — file created on first write)
  project_root <- find_project_root()
  if (is.null(project_root)) {
    project_root <- here::here()
  }
  log_dir <- file.path(project_root, ".rpfy-logs")
  prune_rpfy_logs(log_dir)
  session_timestamp <- format(Sys.time(), "%Y-%m-%d-%H-%M-%S")
  log_file <- file.path(log_dir, paste0(session_timestamp, "-rpfy.log"))
  toggle_logger(quiet = TRUE, log_file = log_file, lazy_file = TRUE)
}

.onAttach <- function(libname, pkgname) {
  msg <- reportifyr_options_message()
  packageStartupMessage(msg)
}

#' Generates a tidyverse-esque onAttach message
#'
#' @return a message to display on attach
#' @keywords internal
#' @noRd
#'
#' @examples \dontrun{
#' reportifyr_options_message()
#' }
reportifyr_options_message <- function() {
  set_options <- c()
  unset_options <- c()
  optional_options <- c()

  # Check for each used options
  root <- getOption("venv_dir")
  if (is.null(root)) {
    unset_options <- c(
      unset_options,
      "Using project root for venv (unless already present), set options('venv_dir') to change"
    )
  } else {
    set_options <- c(set_options, paste("venv_dir:", root))
  }

  # NICE TO HAVES
  uvversion <- getOption("uv.version")
  if (is.null(uvversion)) {
    uv_path <- pyro::get_uv_path(quiet = TRUE)
    if (is.null(uv_path)) {
      optional_options <- c(
        optional_options,
        "uv not installed; initialize_python() will install a default version"
      )
    } else {
      uv_version <- pyro::get_uv_version(uv_path)
      set_options <- c(
        set_options,
        paste0("Using installed uv version ", uv_version)
      )
    }
  } else {
    set_options <- c(set_options, paste("uv.version:", uvversion))
  }

  # format .onAttach message
  msg <- ""
  if (length(set_options)) {
    msg <- paste0(
      msg,
      cli::rule(
        left = cli::style_bold("Set reportifyr options")
      ),
      "\n",
      paste0(
        cli::col_green(cli::symbol$tick),
        " ",
        set_options,
        collapse = "\n"
      ),
      "\n"
    )
  }

  if (length(unset_options)) {
    msg <- paste0(
      msg,
      cli::rule(
        left = cli::style_bold("venv options")
      ),
      "\n",
      paste0(
        cli::col_yellow(cli::symbol$square),
        " ",
        unset_options,
        collapse = "\n"
      ),
      "\n"
    )
  }

  if (length(optional_options)) {
    msg <- paste0(
      msg,
      cli::rule(
        left = cli::style_bold("Version options")
      ),
      "\n",
      paste0(
        cli::col_yellow(cli::symbol$square),
        " ",
        optional_options,
        collapse = "\n"
      )
    )
  }

  msg
}
