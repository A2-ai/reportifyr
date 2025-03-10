% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/format_flextable.R
\name{format_flextable}
\alias{format_flextable}
\title{Formats data frames to a flextable specification}
\usage{
format_flextable(data_in, table1_format = FALSE)
}
\arguments{
\item{data_in}{The input data to be formatted. Must be either a data frame or a flextable object.}

\item{table1_format}{A boolean indicating whether to apply table1-style formatting. Default is \code{FALSE}.}
}
\value{
A formatted flextable
}
\description{
Formats data frames to a flextable specification
}
\examples{
\dontrun{
dt <- head(iris, 10)
format_flextable(
  data_in = dt
)
}
}
