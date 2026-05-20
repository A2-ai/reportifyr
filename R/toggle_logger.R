.le <- new.env() # parent = emptyenv()

#' Get the current log file path
#'
#' @return path to the log file, or NULL if not set
#'
#' @export
get_log_file <- function() {
  if (exists("log_file", envir = .le)) {
    .le$log_file
  } else {
    message("No log file set. Log file is created on package load.")
    NULL
  }
}

#' Updates the logging level for console output. Default is set to WARN.
#' File logging is always at DEBUG level when log_file is provided.
#'
#' @param quiet suppresses messaging about log level.
#' @param log_file path to log file. Defaults to the current session log file
#'   set on package load. Use \code{get_log_file()} to retrieve the current
#'   path. Pass a custom path to write to a different file.
#' @param lazy_file if TRUE, delay log file creation until first log write.
#'
#' @export
#'
#' @examples \dontrun{
#' Sys.setenv("RPFY_VERBOSE" = "DEBUG")
#' toggle_logger()
#' }
toggle_logger <- function(quiet = FALSE, log_file = get_log_file(), lazy_file = FALSE) {
  LEVEL_NAMES <- c("DEBUG", "INFO", "WARN", "ERROR", "FATAL")
  verbosity <- Sys.getenv("RPFY_VERBOSE", unset = "WARN")
  if (!(verbosity %in% LEVEL_NAMES)) {
    cat(
      "Invalid verbosity level. Available options are:",
      paste(LEVEL_NAMES, collapse = ", "),
      "\n"
    )
  }

  # Custom console appender that filters by verbosity
  level_order <- c(
    "DEBUG" = 1,
    "INFO" = 2,
    "WARN" = 3,
    "ERROR" = 4,
    "FATAL" = 5
  )
  filtered_console <- function(level, ...) {
    if (level_order[level] >= level_order[verbosity]) {
      cat(my_layout(level, ...))
    }
  }

  # Build appenders list
  appenders <- list(filtered_console)

  if (!is.null(log_file)) {
    if (lazy_file) {
      lazy_appender <- local({
        initialized <- FALSE
        disabled <- FALSE
        delegate <- NULL
        function(level, ...) {
          if (disabled) return(invisible(NULL))
          if (!initialized) {
            if (getOption("rpfy.no_log", FALSE)) {
              disabled <<- TRUE
              return(invisible(NULL))
            }
            log_dir <- dirname(log_file)
            if (!dir.exists(log_dir)) {
              dir.create(log_dir, recursive = TRUE)
            }
            if (!file.exists(log_file)) {
              file.create(log_file)
            }
            delegate <<- log4r::file_appender(
              log_file,
              layout = my_layout
            )
            initialized <<- TRUE
          }
          delegate(level, ...)
        }
      })
      appenders <- c(appenders, list(lazy_appender))
    } else {
      # Ensure directory exists
      log_dir <- dirname(log_file)
      if (!dir.exists(log_dir)) {
        dir.create(log_dir, recursive = TRUE)
      }
      # Create file if it doesn't exist
      if (!file.exists(log_file)) {
        file.create(log_file)
      }
      appenders <- c(
        appenders,
        list(log4r::file_appender(log_file, layout = my_layout))
      )
    }
    assign("log_file", log_file, envir = .le)
  }

  logger <- log4r::logger(
    "DEBUG",
    appenders = appenders
  )
  assign("logger", logger, envir = .le)

  if (!quiet) {
    message(paste("Console logging at", verbosity, "level"))
    if (!is.null(log_file)) {
      message(paste("File logging at DEBUG level:", log_file))
    }
  }
}

my_layout <- function(level, ...) {
  paste0(format(Sys.time()), " [R] [", level, "] ", ..., "\n", collapse = "")
}

#' Prune `.rpfy-logs` entries
#'
#' Deletes session log files older than `max_age_days`, and trims to at
#' most `max_files` if more remain. Silent: pruning failures must never
#' block package load.
#'
#' @param log_dir Directory containing `*-rpfy.log` files.
#' @param max_age_days Maximum age in days.
#' @param max_files Safety ceiling on file count.
#'
#' @keywords internal
#' @noRd
prune_rpfy_logs <- function(
  log_dir,
  max_age_days = 30,
  max_files = 500
) {
  if (!dir.exists(log_dir)) {
    return(invisible(NULL))
  }
  files <- list.files(
    log_dir,
    pattern = "-rpfy\\.log$",
    full.names = TRUE
  )
  if (!length(files)) {
    return(invisible(NULL))
  }
  info <- file.info(files)
  cutoff <- Sys.time() - (max_age_days * 86400)
  too_old <- !is.na(info$mtime) & info$mtime < cutoff
  to_delete <- files[too_old]
  remaining <- files[!too_old]
  if (length(remaining) > max_files) {
    rem_info <- info[!too_old, , drop = FALSE]
    ord <- order(rem_info$mtime, decreasing = TRUE)
    overflow <- remaining[ord][(max_files + 1):length(remaining)]
    to_delete <- c(to_delete, overflow)
  }
  if (length(to_delete)) {
    try(file.remove(to_delete), silent = TRUE)
  }
  invisible(NULL)
}
