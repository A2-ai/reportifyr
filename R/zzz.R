.onLoad <- function(libname, pkgname) {
  toggle_logger(quiet = TRUE)
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
    uv_path <- get_uv_path()
    if (is.null(uv_path)) {
      optional_options <- c(
        optional_options,
        "Using uv version 0.5.1, set options('uv.version') to change"
      )
    } else {
      uv_version <- get_uv_version(uv_path)
      set_options <- c(
        set_options,
        paste0("Using installed uv version ", uv_version)
      )
    }
  } else {
    set_options <- c(set_options, paste("uv.version:", uvversion))
  }

  pyversion <- getOption("python.version")
  if (is.null(pyversion)) {
    optional_options <- c(
      optional_options,
      "Using system python version, set options('python.version') to change"
    )
  } else {
    set_options <- c(set_options, paste("python.version:", pyversion))
  }

  docx_vers <- getOption("python-docx.version")
  if (is.null(docx_vers)) {
    optional_options <- c(
      optional_options,
      "Using python-docx version 1.1.2, set options('python-docx.version') to change"
    )
  } else {
    set_options <- c(set_options, paste("python-docx.version:", docx_vers))
  }

  pyyaml_vers <- getOption("pyyaml.version")
  if (is.null(pyyaml_vers)) {
    optional_options <- c(
      optional_options,
      "Using pyyaml version 6.0.2, set options('pyyaml.version') to change"
    )
  } else {
    set_options <- c(set_options, paste("pyyaml.version:", pyyaml_vers))
  }

  pillow_vers <- getOption("pillow.version")
  if (is.null(pillow_vers)) {
    optional_options <- c(
      optional_options,
      "Using default v11.1.0, set options('pillow.version') to change"
    )
  } else {
    set_options <- c(set_options, paste("pillow.version:", pillow_vers))
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
