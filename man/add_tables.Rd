% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/add_tables.R
\name{add_tables}
\alias{add_tables}
\title{Inserts Tables in appropriate places in a Microsoft Word file}
\usage{
add_tables(docx_in, docx_out, tables_path, config_yaml = NULL, debug = FALSE)
}
\arguments{
\item{docx_in}{The file path to the input \code{.docx} file.}

\item{docx_out}{The file path to the output \code{.docx} file to save to.}

\item{tables_path}{The file path to the tables and associated metadata directory.}

\item{config_yaml}{The file path to the \code{config.yaml}. Default is \code{NULL}, a default \code{config.yaml} bundled with the \code{reportifyr} package is used.}

\item{debug}{Debug.}
}
\description{
Reads in a \code{.docx} file and returns a new version with tables placed at appropriate places in the document.
}
\examples{
\dontrun{

# ---------------------------------------------------------------------------
# Load all dependencies
# ---------------------------------------------------------------------------
docx_in <- here::here("report", "shell", "template.docx")
doc_dirs <- make_doc_dirs(docx_in = docx_in)
figures_path <- here::here("OUTPUTS", "figures")
tables_path <- here::here("OUTPUTS", "tables")
standard_footnotes_yaml <- here::here("report", "standard_footnotes.yaml")

# ---------------------------------------------------------------------------
# Step 1.
# `add_tables()` will format and insert tables into the `.docx` file.
# ---------------------------------------------------------------------------
add_tables(
  docx_in = doc_dirs$doc_in,
  docx_out = doc_dirs$doc_tables,
  tables_path = tables_path
)
}
}
