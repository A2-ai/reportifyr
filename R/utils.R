#' Gets the git information for a file
#'
#' @param file_path Path to file to retrieve git information from
#'
#' @keywords internal
#' @noRd
get_git_info <- function(file_path) {
  # If git doesn't work return NA for everything.
  tryCatch(
    {
      log <- processx::run("git", c("log", "--follow", "--", file_path))$stdout

      if (log == "") {
        log4r::warn(
          .le$logger,
          paste0("Source file path not tracked by git: ", file_path)
        )
        return(list(
          creation_author = "FILE NOT TRACKED BY GIT",
          latest_author = "FILE NOT TRACKED BY GIT",
          creation_time = "FILE NOT TRACKED BY GIT",
          latest_time = format(Sys.time(), "%Y-%m-%d %H:%M:%S")
        ))
      }

      author_lines <- regmatches(log, gregexpr("Author: [^\n]+", log))[[1]]
      date_lines <- regmatches(log, gregexpr("Date: [^\n]+", log))[[1]]

      authors <- sub("Author: ", "", author_lines)
      dates <- sub("Date: ", "", date_lines)

      dates <- trimws(dates)
      parsed_dates <- strptime(dates, "%a %b %d %H:%M:%S %Y %z", tz = "UTC")

      creation_author <- authors[length(authors)]
      latest_author <- authors[1]
      creation_time <- format(
        parsed_dates[length(parsed_dates)],
        "%Y-%m-%d %H:%M:%S"
      )
      latest_time <- format(parsed_dates[1], "%Y-%m-%d %H:%M:%S")

      return(list(
        creation_author = creation_author,
        latest_author = latest_author,
        creation_time = creation_time,
        latest_time = latest_time
      ))
    },
    error = function(e) {
      # Return the specified list in case of an error
      list(
        creation_author = "COULD NOT ACCESS GIT",
        latest_author = "COULD NOT ACCESS GIT",
        creation_time = "COULD NOT ACCESS GIT",
        latest_time = "COULD NOT ACCESS GIT"
      )
    }
  )
}

#' Gets the author information
#'
#' @param settings Git settings, default gert::git_config_global()
#'
#' @keywords internal
#' @noRd
get_git_config_author <- function(settings = gert::git_config_global()) {
  global_settings <- settings[settings$level == "global", ]

  email <- subset(global_settings, name == "user.email")$value
  name <- subset(global_settings, name == "user.name")$value

  if (length(email) > 1 || length(name) > 1) {
    stop(
      "Multiple user names or emails found in global git config.
			Please check the .gitconfig file before running again."
    )
  } else if (length(email) == 0 || length(name) == 0) {
    stop(
      "Please set git global configs
			git config --global user.name \"user name\",
			git config --global user.email user\\@emai.com"
    )
  }

  if (!nzchar(email) || !nzchar(name)) {
    warning(
      "No default git user or email configuration set up.
			Empty values set for object meta author. \n"
    )
  }

  author <- paste(name, " <", email, ">", sep = "")
  author
}

#' Gets the R packages loaded explicitly or via namespace
#'
#' @keywords internal
#' @noRd
get_packages <- function() {
  # Pkgs via library() calls
  attached_pkgs <- utils::sessionInfo()$otherPkgs

  # Pkgs via namespace
  namespaced_pkgs <- loadedNamespaces()

  attached_pkgs_metadata <- sapply(attached_pkgs, function(pkg) {
    list(version = pkg$Version)
  })

  # Filter namespaced packages to exclude those already loaded
  namespaced_only <- setdiff(namespaced_pkgs, names(attached_pkgs))

  namespaced_pkgs_metadata <- sapply(namespaced_only, function(pkg) {
    version <- tryCatch(
      as.character(utils::packageVersion(pkg)),
      error = function(e) NA
    )
    list(version = version)
  })

  # Combine both metadatas
  pkgs_metadata <- c(attached_pkgs_metadata, namespaced_pkgs_metadata)

  pkgs_metadata
}


#' Find the reportifyr project root directory
#'
#' Searches upward from `start_path` for a reportifyr init file
#' (e.g., `.report_init.json`). Returns the directory containing
#' the init file, or `NULL` if none is found.
#'
#' @param start_path Path to start searching from.
#'   Defaults to the current working directory.
#'
#' @return Absolute path to the project root directory,
#'   or `NULL` if no init file is found.
#'
#' @export
#'
#' @examples \dontrun{
#' find_project_root()
#' }
find_project_root <- function(start_path = getwd()) {
  current_path <- normalizePath(start_path)

  while (TRUE) {
    # Look for any .*_init.json file (e.g., .report_init.json, .custom_init.json)
    init_files <- list.files(
      current_path,
      pattern = "^\\.[^.]*_init\\.json$",
      full.names = TRUE,
      all.files = TRUE
    )
    if (length(init_files) > 0) {
      return(current_path)
    }

    # Move up one directory
    parent_path <- dirname(current_path)

    # If we've reached the root directory, stop
    if (parent_path == current_path) {
      break
    }

    current_path <- parent_path
  }

  # Return NULL if not found
  return(NULL)
}

#' Detect the source script path
#'
#' Checks for a Quarto render context first, then falls back
#' to \code{this.path::this.path()}.
#'
#' @return Absolute path to the source script,
#'   or \code{"SOURCE_PATH_NOT_DETECTED"} if detection fails.
#'
#' @keywords internal
#' @noRd
get_source_path <- function() {
  tryCatch(
    {
      qmd_path <- detect_quarto_render()
      if (!is.null(qmd_path)) {
        log4r::info(
          .le$logger,
          paste0("Detected Quarto render; using .qmd file: ", qmd_path)
        )
        qmd_path
      } else if (requireNamespace("this.path", quietly = TRUE)) {
        sp <- this.path::this.path()
        if (!is.null(sp) && nzchar(sp)) {
          sp <- normalizePath(sp)
          log4r::info(
            .le$logger,
            paste0("Source path detected via this.path: ", sp)
          )
          sp
        } else {
          log4r::warn(
            .le$logger,
            "this.path did not return a valid script path"
          )
          "SOURCE_PATH_NOT_DETECTED"
        }
      } else {
        log4r::warn(
          .le$logger,
          paste0(
            "Unable to detect source path via Quarto",
            " or this.path(); setting placeholder"
          )
        )
        "SOURCE_PATH_NOT_DETECTED"
      }
    },
    error = function(e) {
      log4r::warn(
        .le$logger,
        paste0("Error detecting source path: ", e$message)
      )
      "SOURCE_PATH_NOT_DETECTED"
    }
  )
}

#' Run a Python script via uv, forwarding to pyro with reportifyr's
#' py-log stderr callback
#'
#' Thin wrapper over `pyro::run_python_script()` that resolves the uv and
#' venv paths via `pyro::get_venv_uv_paths()` and supplies reportifyr's
#' `PYTHONPATH` (`inst/python/`) and a stderr callback that mirrors every
#' Python log line into the rpfy session log file while filtering console
#' output by `RPFY_VERBOSE`.
#'
#' @param args Arguments to pass to uv
#' @param script_name Name of the script for logging purposes
#'
#' @return The result from `pyro::run_python_script()`
#'
#' @keywords internal
#' @noRd
run_python_script <- function(args, script_name) {
  paths <- pyro::get_venv_uv_paths()
  log_file <- .le$log_file
  no_log <- getOption("rpfy.no_log", FALSE)

  py_levels <- c(
    "DEBUG" = 1, "INFO" = 2, "WARNING" = 3, "ERROR" = 4, "CRITICAL" = 5
  )
  r_levels <- c(
    "DEBUG" = 1, "INFO" = 2, "WARN" = 3, "ERROR" = 4, "FATAL" = 5
  )
  threshold <- r_levels[[Sys.getenv("RPFY_VERBOSE", unset = "WARN")]]

  py_callback <- function(chunk, proc) {
    lines <- strsplit(chunk, "\n")[[1]]
    for (line in lines) {
      line <- trimws(line)
      if (nchar(line) == 0) next

      if (!is.null(log_file) && !no_log) {
        cat(line, "\n", file = log_file, append = TRUE)
      }

      show <- TRUE
      level_match <- regmatches(
        line, regexpr("\\[(DEBUG|INFO|WARNING|ERROR|CRITICAL)\\]", line)
      )
      if (length(level_match) == 1) {
        level <- gsub("\\[|\\]", "", level_match)
        show <- py_levels[[level]] >= threshold
      }
      if (show) cat(line, "\n")
    }
  }

  pyro::run_python_script(
    uv_path = paths$uv,
    args = args,
    venv_path = paths$venv,
    script_name = script_name,
    pythonpath = system.file("python", package = "reportifyr"),
    stderr_callback = py_callback,
    verbose_env = "RPFY_VERBOSE"
  )
}

detect_quarto_render <- function() {
  log4r::debug(.le$logger, "Starting detect_quarto_render()")

  # --- Detect Quarto context ---
  quarto_vars <- Sys.getenv(c(
    "QUARTO_PROJECT_ROOT",
    "QUARTO_BIN_PATH",
    "QUARTO_RENDER_TOKEN"
  ))
  is_quarto <- any(quarto_vars != "")
  log4r::debug(
    .le$logger,
    paste0("Quarto environment vars detected: ", is_quarto)
  )

  if (!is_quarto) {
    log4r::debug(.le$logger, "Not running in a Quarto context, returning NULL")
    return(NULL)
  }

  # --- Get current input ---
  current <- tryCatch(knitr::current_input(), error = function(e) NULL)
  log4r::debug(
    .le$logger,
    paste0(
      "knitr::current_input() returned: ",
      ifelse(is.null(current), "NULL", current)
    )
  )

  # --- Validate current file pattern ---
  if (
    is.null(current) ||
      !grepl("\\.(Rmd|rmarkdown)$", current, ignore.case = TRUE)
  ) {
    log4r::debug(
      .le$logger,
      "Current input is NULL or not an .Rmd/.rmarkdown file, returning NULL"
    )
    return(NULL)
  }

  # --- Attempt to resolve .qmd equivalent ---
  qmd_candidate <- sub("\\.(rmd|rmarkdown)$", ".qmd", basename(current))
  project_root <- Sys.getenv("QUARTO_PROJECT_ROOT", unset = getwd())
  qmd_path <- file.path(project_root, qmd_candidate)
  log4r::debug(.le$logger, paste0("Candidate .qmd path: ", qmd_path))

  if (file.exists(qmd_path)) {
    log4r::info(
      .le$logger,
      paste0(
        "Detected Quarto render: .Rmd intermediate '",
        current,
        "' mapped to existing .qmd: ",
        qmd_path
      )
    )
    return(normalizePath(qmd_path))
  } else {
    log4r::warn(
      .le$logger,
      paste0(
        "Quarto environment detected, but .qmd not found at: ",
        qmd_path,
        ", returning NULL"
      )
    )
    return(NULL)
  }
}

#' Resolve a relative path within an artifact directory
#'
#' @param artifact_dir The artifact directory (figures/tables) to resolve within
#' @param relative_path The relative path to resolve
#' @return The resolved absolute path
#'
#' @keywords internal
#' @noRd
safe_resolve <- function(artifact_dir, relative_path) {
  boundary <- as.character(fs::path_norm(
    normalizePath(artifact_dir, mustWork = TRUE)
  ))
  resolved <- as.character(
    fs::path_norm(file.path(boundary, relative_path))
  )
  sep <- .Platform$file.sep
  outside <- resolved != boundary &&
    !startsWith(resolved, paste0(boundary, sep))
  if (outside) {
    log4r::error(
      .le$logger,
      paste0(
        "Path '", relative_path,
        "' resolves outside of '", artifact_dir, "'"
      )
    )
    stop(
      "Path '", relative_path,
      "' resolves outside of '", artifact_dir, "'"
    )
  }
  resolved
}
