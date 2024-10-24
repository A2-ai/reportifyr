% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/build_report.R
\name{build_report}
\alias{build_report}
\title{Updates a Word file to include formatted plots, tables, and footnotes}
\usage{
build_report(
  docx_in,
  docx_out,
  figures_path,
  tables_path,
  standard_footnotes_yaml = NULL
)
}
\arguments{
\item{docx_in}{Path to input .docx to update}

\item{docx_out}{Path to output .docx to save to}

\item{figures_path}{Path to images file directory}

\item{tables_path}{Path to tables file directory}

\item{standard_footnotes_yaml}{Path to standard_footnotes.yaml in report/}
}
\description{
Reads in a .docx file and returns an updated version with plots, tables, and footnotes replaced.
}
\examples{
\dontrun{

# ---------------------------------------------------------------------------
# Load all dependencies
# ---------------------------------------------------------------------------
docx_in <- file.path(here::here(), "report", "shell", "template.docx")
figures_path <- file.path(here::here(), "OUTPUTS", "figures")
tables_path <- file.path(here::here(), "OUTPUTS", "tables")
footnotes <- file.path(here::here(), "report", "standard_footnotes.yaml")

# ---------------------------------------------------------------------------
# Step 1.
# Run the wrapper function to replace figures, tables, and footnotes in a
# .docx file.
# ---------------------------------------------------------------------------
build_report(
  docx_in = docx_in,
  docx_out = doc_dirs$doc_draft,
  figures_path = figures_path,
  tables_path = tables_path,
  standard_footnotes_yaml = footnotes
)
}
}
