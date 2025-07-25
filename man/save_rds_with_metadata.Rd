% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/save_rds_with_metadata.R
\name{save_rds_with_metadata}
\alias{save_rds_with_metadata}
\title{Wrapper around the saveRDS function. Saves an object as .RDS and .RTF and captures analysis relevant metadata in a .json file}
\usage{
save_rds_with_metadata(
  object,
  file = "",
  config_yaml = NULL,
  meta_type = "NA",
  meta_equations = NULL,
  meta_notes = NULL,
  meta_abbrevs = NULL,
  table1_format = FALSE,
  ...
)
}
\arguments{
\item{object}{The \code{R} object to serialize.}

\item{file}{The connection or name of the file where the \code{R} object is saved.}

\item{config_yaml}{The file path to the \code{config.yaml}. Default is \code{NULL}. If \code{NULL}, a default value of \code{TRUE} for \code{save_rtf()} is used.}

\item{meta_type}{A string to specify the type of object. Default is \code{"NA"}.}

\item{meta_equations}{A string or vector of strings representing equations to include in the metadata. Default is \code{NULL}.}

\item{meta_notes}{A string or vector of strings representing notes to include in the metadata. Default is \code{NULL}.}

\item{meta_abbrevs}{A string or vector of strings representing abbreviations to include in the metadata. Default is \code{NULL}.}

\item{table1_format}{A boolean indicating whether to apply table1-style formatting. Default is \code{FALSE}.}

\item{...}{Additional arguments passed to the \code{saveRDS()} function.}
}
\description{
Extension to the \code{saveRDS()} function that allows capturing object metadata as a separate \code{.json} file.
}
\examples{
\dontrun{

# ---------------------------------------------------------------------------
# Save a simple table
# ---------------------------------------------------------------------------
tables_path <- here::here("OUTPUTS", "tables")
outfile_name <- "01-12345-pk-theoph.RDS"

save_rds_with_metadata(
  object = Theoph,
  file = file.path(tables_path, outfile_name)
)
}
}
