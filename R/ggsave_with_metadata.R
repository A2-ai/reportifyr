#' Wrapper around the ggplot2 ggsave function. Saves a ggplot (or other grid object) and captures analysis relevant metadata in a .json file
#'
#' @description Extension to the ggsave function that allows capturing object metadata as a separate .json file.
#' @param filename File name to create on disk
#' @param plot Plot to save, defaults to last plot displayed
#' @param meta_type Parameter for specifying meta_type for write_object_metadata
#' @param meta_equations Parameter for specifying additional equations
#' @param meta_notes Parameter for specifying additional notes
#' @param meta_abbrevs Parameter for specifying additional abbreviations
#' @param ... Additional args to be used in ggsave
#' @export
#'
#' @examples \dontrun{
#' # Path to the analysis figures (.png) and metadata (.json files)
#' figures_path <- file.path(tempdir(), "figures")
#'
#' # ---------------------------------------------------------------------------
#' # Construct a simple ggplot
#' # ---------------------------------------------------------------------------
#' g <- ggplot2::ggplot(
#'   data = Theoph,
#'   ggplot2::aes(x = Time, y = conc, group = Subject)
#' ) +
#'   ggplot2::geom_point() +
#'   ggplot2::geom_line() +
#'   ggplot2::theme_bw()
#'
#' # Save a png using the helper function
#' out_name <- "01-12345-pk-timecourse1.png"
#' ggsave_with_metadata(
#'   filename = file.path(figures_path, out_name),
#' )
#' }
ggsave_with_metadata <- function(
    filename,
    plot = ggplot2::last_plot(),
    meta_type = "NA",
    meta_equations = NULL,
    meta_notes = NULL,
    meta_abbrevs = NULL,
    ...) {

  log4r::debug(.le$logger, "Starting ggsave_with_metadata function")

  ggplot2::ggsave(
    filename = filename,
    plot = plot,
    ...
  )
  log4r::info(.le$logger, paste0("Plot saved to file: ", filename))

  write_object_metadata(
    filename,
    meta_type = meta_type,
    equations = meta_equations,
    notes = meta_notes,
    abbrevs = meta_abbrevs
  )
  log4r::debug(.le$logger, "Exiting ggsave_with_metadata function")
}
