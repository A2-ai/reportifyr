.onLoad <- function(libname, pkgname) {
  toggle_logger()
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
      "options('venv_dir') is not set. venv will be created in Project root"
    )
  } else {
    set_options <- c(set_options, paste("venv_dir:", root))
  }
  # NICE TO HAVES
  uvversion <- getOption("uv.version")
  if (is.null(uvversion)) {
    optional_options <- c(
      optional_options,
      "options('uv.version') is not set. Default is 0.5.1"
    )
  } else {
    set_options <- c(set_options, paste("uv.version:", uvversion))
  }

  pyversion <- getOption("python.version")
  if (is.null(pyversion)) {
    optional_options <- c(
      optional_options,
      "options('python.version') is not set. Default is system version"
    )
  } else {
    set_options <- c(set_options, paste("python.version:", pyversion))
  }

  docx_vers <- getOption("python-docx.version")
  if (is.null(docx_vers)) {
    optional_options <- c(
      optional_options,
      "options('python-docx.version') is not set. Default is 1.1.2"
    )
  } else {
    set_options <- c(set_options, paste("python-docx.version:", docx_vers))
  }

  pyyaml_vers <- getOption("pyyaml.version")
  if (is.null(pyyaml_vers)) {
    optional_options <- c(
      optional_options,
      "options('pyyaml.version') is not set. Default is 6.0.2"
    )
  } else {
    set_options <- c(set_options, paste("pyyaml.version:", pyyaml_vers))
  }

  pillow_vers <- getOption("Pillow.version")
  if (is.null(pillow_vers)) {
    optional_options <- c(
      optional_options,
      "options('Pillow.version') is not set. Default is 11.1"
    )
  } else {
    set_options <- c(set_options, paste("Pillow.version:", pillow_vers))
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
        left = cli::style_bold("Needed reportifyr options")
      ),
      "\n",
      paste0(
        cli::col_red(cli::symbol$cross),
        " ",
        unset_options,
        collapse = "\n"
      ),
      "\n",
      paste0(
        cli::col_cyan(cli::symbol$info),
        " ",
        cli::format_inline("Please set all options for package to work."),
        "\n"
      )
    )
  }

  if (length(optional_options)) {
    msg <- paste0(
      msg,
      cli::rule(
        left = cli::style_bold("Optional version options")
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
