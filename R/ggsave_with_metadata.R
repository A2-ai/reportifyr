#' Wrapper around the ggplot2 ggsave function. Saves a ggplot (or other grid object) and captures analysis relevant metadata in a .json file
#'
#' @description Extension to the ggsave function that allows capturing object metadata as a separate .json file.
#' @param filename The filename for the plot to save to.
#' @param plot The plot object to save. Default is the last displayed plot (ggplot2::last_plot()).
#' @param meta_type A string to specify the type of object. Default is "NA".
#' @param meta_equations A string or vector of strings representing equations to include in the metadata. Default is NULL.
#' @param meta_notes A string or vector of strings representing notes to include in the metadata. Default is NULL.
#' @param meta_abbrevs A string or vector of strings representing abbreviations to include in the metadata. Default is NULL.
#' @param ... Additional arguments passed to the ggplot2::ggsave() function.
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
