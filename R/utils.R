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


#' /.cargo/bin post v0.5.0 to /.local/bin
#'
#' @param quite boolean to suppress log message
#'
#' @return path to uv
#'
#' @keywords internal
#' @noRd
get_uv_path <- function(quiet = FALSE) {
  # First check if uv is available in PATH (cross-platform)
  # Only check PATH if it's not empty (for test isolation)
  path_env <- Sys.getenv("PATH")
  uv_in_path <- if (nzchar(path_env)) Sys.which("uv") else ""

  # Get home directory - respect HOME env var for test isolation
  home_env <- Sys.getenv("HOME")
  if (nzchar(home_env)) {
    # Use HOME env var (for tests or Unix)
    home_dir <- home_env
  } else {
    # Use default expansion
    home_dir <- path.expand("~")
  }

  if (.Platform$OS.type == "windows") {
    # Windows paths
    uv_paths <- c(
      file.path(home_dir, ".local", "bin", "uv.exe"),
      file.path(home_dir, ".local", "bin", "uv"),      # for tests without .exe
      file.path(home_dir, ".cargo", "bin", "uv.exe"),
      file.path(home_dir, ".cargo", "bin", "uv")       # for tests without .exe
    )
  } else {
    # Unix paths
    uv_paths <- c(
      file.path(home_dir, ".local", "bin", "uv"),
      file.path(home_dir, ".cargo", "bin", "uv")
    )
  }

  # Combine PATH result with known locations (prefer PATH version)
  if (nzchar(uv_in_path)) {
    uv_paths <- c(uv_in_path, uv_paths)
  }

  # Find the first existing path
  uv_paths <- uv_paths[nzchar(uv_paths) & file.exists(uv_paths)]

  uv_path <- if (length(uv_paths)) normalizePath(uv_paths[[1]]) else NULL

  if (!quiet) {
    if (is.null(uv_path)) {
      log4r::warn(
        .le$logger,
        "uv not found. Please install with initialize_python"
      )
    }
  }
  uv_path
}

#' Gets the version of uv
#'
#' @param uv_path path to uv
#' @keywords internal
#' @noRd
get_uv_version <- function(uv_path) {
  result <- processx::run(uv_path, "--version")
  # output should be "uv version (commit date)"
  uv_version <- trimws(strsplit(result$stdout, " ")[[1]][2])

  uv_version
}

#' Find the project root directory by looking for *_init.json files
#'
#' @param start_path Path to start searching from. Defaults to current directory.
#'
#' @return Path to project root directory, or NULL if not found
#'
#' @keywords internal
#' @noRd
find_project_root <- function(start_path = getwd()) {
  current_path <- normalizePath(start_path)

  while (TRUE) {
    # Look for any .*_init.json file (e.g., .report_init.json, .custom_init.json)
    init_files <- list.files(current_path, pattern = "^\\.[^.]*_init\\.json$", full.names = TRUE, all.files = TRUE)
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

detect_quarto_render <- function() {
  log4r::debug(.le$logger, "Starting detect_quarto_render()")

  # --- Detect Quarto context ---
  quarto_vars <- Sys.getenv(c("QUARTO_PROJECT_ROOT", "QUARTO_BIN_PATH", "QUARTO_RENDER_TOKEN"))
  is_quarto <- any(quarto_vars != "")
  log4r::debug(.le$logger, paste0(
    "Quarto vars: ",
    paste(names(quarto_vars), quarto_vars, sep = "=", collapse = "; "),
    " | is_quarto = ", is_quarto
  ))

  if (!is_quarto) {
    log4r::debug(.le$logger, "Not running in a Quarto context — returning NULL")
    return(NULL)
  }

  # --- Get current input ---
  current <- tryCatch(knitr::current_input(), error = function(e) NULL)
  log4r::debug(.le$logger, paste0("knitr::current_input() returned: ", ifelse(is.null(current), "NULL", current)))

  # --- Validate current file pattern ---
  if (is.null(current) || !grepl("\\.(Rmd|rmarkdown)$", current, ignore.case = TRUE)) {
    log4r::debug(.le$logger, "Current input is NULL or not an .Rmd/.rmarkdown file — returning NULL")
    return(NULL)
  }

  # --- Attempt to resolve .qmd equivalent ---
  qmd_candidate <- sub("\\.(rmd|rmarkdown)$", ".qmd", basename(current))
  project_root <- Sys.getenv("QUARTO_PROJECT_ROOT", unset = getwd())
  qmd_path <- file.path(project_root, qmd_candidate)
  log4r::debug(.le$logger, paste0("Candidate .qmd path: ", qmd_path))

  if (file.exists(qmd_path)) {
    log4r::info(.le$logger, paste0(
      "Detected Quarto render: .Rmd intermediate '", current,
      "' mapped to existing .qmd: ", qmd_path
    ))
    return(normalizePath(qmd_path))
  } else {
    log4r::warn(.le$logger, paste0(
      "Quarto environment detected, but .qmd not found at: ", qmd_path,
      " — returning NULL"
    ))
    return(NULL)
  }
}

