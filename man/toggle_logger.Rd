% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/toggle_logger.R
\name{toggle_logger}
\alias{toggle_logger}
\title{Updates the logging level for functions. Default is set to WARN}
\usage{
toggle_logger(quiet = FALSE)
}
\arguments{
\item{quiet}{suppresses messaging about log level.}
}
\description{
Updates the logging level for functions. Default is set to WARN
}
\examples{
\dontrun{
Sys.setenv("RPFY_VERBOSE" = "DEBUG")
toggle_logger()
}
}
