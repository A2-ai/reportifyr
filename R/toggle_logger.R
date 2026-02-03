.le <- new.env() # parent = emptyenv()

#' Updates the logging level for console output. Default is set to WARN.
#' File logging is always at DEBUG level when log_file is provided.
#'
#' @param quiet suppresses messaging about log level.
#' @param log_file path to log file. If NULL, only console logging is enabled.
#'
#' @export
#'
#' @examples \dontrun{
#' Sys.setenv("RPFY_VERBOSE" = "DEBUG")
#' toggle_logger()
#' }
toggle_logger <- function(quiet = FALSE, log_file = NULL) {
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
  paste0(format(Sys.time()), " [", level, "] ", ..., "\n", collapse = "")
}
