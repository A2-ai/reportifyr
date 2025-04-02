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
      parsed_dates <- strptime(dates, "%a %b %d %H:%M:%S %Y %z")

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
#' @return path to uv
#'
#' @keywords internal
#' @noRd
get_uv_path <- function() {
  uv_paths <- c(
    normalizePath("~/.local/bin/uv", mustWork = FALSE),
    normalizePath("~/.cargo/bin/uv", mustWork = FALSE)
  )

  # Find the first existing path, preferring ~/.local/bin/uv
  uv_path <- uv_paths[file.exists(uv_paths)][1]

  if (is.null(uv_path)) {
    log4r::error(
      .le$logger,
      "uv not found. Please install with initialize_python"
    )
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
  # output should be "uv version (commit date)\n"
  uv_version <- strsplit(result$stdout, " ")[[1]][2]

  uv_version
}
