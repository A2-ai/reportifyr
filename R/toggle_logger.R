.le <- new.env() # parent = emptyenv()

#' Updates the logging level for functions. Default is set to WARN
#'
#' @export
#'
#' @examples \dontrun{
#' Sys.setenv("RPFY_VERBOSE" = "DEBUG")
#' toggle_logger()
#' }
toggle_logger <- function() {
  LEVEL_NAMES <- c("DEBUG", "INFO", "WARN", "ERROR", "FATAL")
  verbosity <- Sys.getenv("RPFY_VERBOSE", unset = "WARN")
  if (!(verbosity %in% LEVEL_NAMES)) {
    cat(
      "Invalid verbosity level. Available options are:",
      paste(LEVEL_NAMES, collapse = ", "),
      "\n"
    )
  }

  logger <- log4r::logger(
    verbosity,
    appenders = log4r::console_appender(my_layout)
  )
  assign("logger", logger, envir = .le)
  message(paste("logging now at", verbosity, "level"))
}

my_layout <- function(level, ...) {
  paste0(format(Sys.time()), " [", level, "] ", ..., "\n", collapse = "")
}
