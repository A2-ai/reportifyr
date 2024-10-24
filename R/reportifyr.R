#' reportifyr: An R package to aid in the drafting of reports.
#'
#' This pacakge aims to ease table, figure, and footnote insertion and formatting
#' into reports.
#'
#' @section reportifyr setup functions:
#' \itemize{
#'   \item \code{\link{initialize_report_project}}: Creates `report` directory
#'   with shell, draft, scripts, final subdirectories and adds
#'   standard_footnotes.yaml to /report directory.
#'   Initializes python virtual environment through a subcall to
#'   [initialize_python]
#'   creates OUTPUTS/figures, OUTPUTS/tables, OUTPUTS/listings directories
#'   \item \code{\link{initialize_python}}: Creates virtual environment in
#'   options("venv_dir") if set or project root otherwise.
#'   Also installs python-docx and pyyaml packages.
#' }
#'
#' @section Analysis output saving functions:
#' \itemize{
#'   \item \code{\link{ggsave_with_metadata}}: Wrapper for saving ggplot that
#'    also creates metadata for plot object
#'   \item \code{\link{save_rds_with_metadata}}: Wrapper for saveRDS that also
#'   creates metadata for tabular object and saves as rtf
#'   \item \code{\link{write_csv_with_metadata}}: Wrapper for write.csv that
#'   also creates metadata for tabular object and saves as rtf
#'   \item \code{\link{save_as_rtf}}: Saves tabular object (.csv or flextable)
#'    as rtf.
#'    This is called within [save_rds_with_metadata] and [write_csv_with_metadata]
#'   \item \code{\link{format_flextable}}: Formats a tabular data object as a
#'   flextable with simple formatting.
#' }
#'
#' @section metadata interaction functions:
#' \itemize{
#'   \item \code{\link{write_object_metadata}}: Creates a metadata.json file for
#'   the input object path. Called within all analysis output saving functions.
#'   \item \code{\link{update_object_footnotes}}: Used to update footnotes fields
#'   within object metadata json files.
#'   \item \code{\link{preview_metadata_files}}: Generates a data frame of all
#'   object metadata within input directory and displays object, meta type, equations
#'   notes, abbreviations.
#'   \item \code{\link{preview_metadata}}: Generates the metadata data frame of the
#'   singular input file.
#'   \item \code{\link{get_meta_type}}: Generates meta_type object to allow user to
#'   see available meta_types in standard_footnotes.yaml within report directory
#'   \item \code{\link{get_meta_abbrevs}}: Generates meta_abbrev object to allow user
#'   to see available abbreviations in standard_footnotes.yaml within report directory.
#' }
#'
#'
#' @section Document interaction functions:
#' \itemize{
#'   \item \code{\link{add_tables}}: Adds tables into the word document
#'   \item \code{\link{add_footnotes}}: Adds footnotes for figures and tables
#'   \item \code{\link{add_plots}}: Adds plots into the word document
#'   \item \code{\link{remove_tables_figures_footnotes}}: Removes all tables,
#'   figures, and footnotes associated with a magic string \{rpfy\}:object.ext
#'   \item \code{\link{remove_magic_strings}}: Removes all magic strings from a
#'   document cutting its tie to reportifyr but producing a final document.
#'   \item \code{\link{remove_bookmarks}}: Removes all bookmarks from document
#' }
#'
#' @section Report building function:
#' \itemize{
#'   \item \code{\link{build_report}}: Wrapper function to remove old tables,
#'    figures, and footnotes and adds new ones. Calls
#'    [remove_tables_figures_footnotes], [make_doc_dirs],
#'    [add_plots], [add_tables], [add_footnotes]
#'   \item \code{\link{finalize_document}}: Wrapper function to remove magic
#'   strings and bookmarks from document.
#' }
#'
#' @section Utility functions:
#' \itemize{
#'   \item \code{\link{make_doc_dirs}}: FILL IN
#'   \item \code{\link{validate_object}}: FILL IN
#' }
#'
#'
#' @name reportifyr
"_PACKAGE"
