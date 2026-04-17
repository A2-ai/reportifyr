#' Wrapper around the ggplot2 ggsave function. Saves a ggplot (or other grid object) and captures analysis relevant metadata in a .json file
#'
#' @description Extension to the `ggsave()` function that allows capturing object metadata as a separate `.json` file.
#' @param filename The filename for the plot to save to.
#' @param plot The plot object to save. Default is the last displayed plot (`ggplot2::last_plot()`).
#' @param meta_type A string to specify the type of object. Default is `"NA"`.
#' @param meta_equations A string or vector of strings representing equations to include in the metadata. Default is `NULL`.
#' @param meta_notes A string or vector of strings representing notes to include in the metadata. Default is `NULL`.
#' @param meta_abbrevs A string or vector of strings representing abbreviations
#'   to include in the metadata. Default is `NULL`.
#' @param config_yaml The file path to the `config.yaml`.
#'   Default is `NULL`. If provided and `add_path_overlay` is
#'   `TRUE` in the config, the source script path is stamped
#'   onto the saved image.
#' @param context An `rpfy_context` built via [rpfy_context()]. When
#'   `NULL` (default) an ephemeral context is constructed with all
#'   defaults. Passing an existing context avoids recomputing
#'   session-level fields on every artifact.
#' @param ... Additional arguments passed to the
#'   `ggplot2::ggsave()` function.
#' @export
#'
#' @examples \dontrun{
#'
#' # ---------------------------------------------------------------------------
#' # Construct and save a simple ggplot
#' # ---------------------------------------------------------------------------
#' g <- ggplot2::ggplot(
#'   data = Theoph,
#'   ggplot2::aes(x = Time, y = conc, group = Subject)
#' ) +
#'   ggplot2::geom_point() +
#'   ggplot2::geom_line() +
#'   ggplot2::theme_bw()
#'
#' # Save a png using the wrapper function
#' figures_path <- here::here("OUTPUTS", "figures")
#' plot_file_name <- "01-12345-pk-timecourse1.png"
#' ggsave_with_metadata(filename = file.path(figures_path, plot_file_name))
#' }
ggsave_with_metadata <- function(
  filename,
  plot = ggplot2::last_plot(),
  meta_type = "NA",
  meta_equations = NULL,
  meta_notes = NULL,
  meta_abbrevs = NULL,
  config_yaml = NULL,
  context = NULL,
  ...
) {
  log4r::debug(.le$logger, "Starting ggsave_with_metadata function")

  if (is.null(context)) {
    context <- rpfy_context()
  } else if (!inherits(context, "rpfy_context")) {
    stop(
      "`context` must be NULL or inherit from class \"rpfy_context\".",
      call. = FALSE
    )
  }

  ggplot2::ggsave(
    filename = filename,
    plot = plot,
    ...
  )
  log4r::info(.le$logger, paste0("Plot saved to file: ", filename))

  # Overlay runs before metadata so the hash reflects the final image
  if (!is.null(config_yaml)) {
    config <- yaml::read_yaml(config_yaml)
    if (
      isTRUE(config$add_path_overlay) &&
        grepl("\\.png$", filename, ignore.case = TRUE)
    ) {
      source_rel <- context$source_meta$path
      if (!is.null(source_rel)) {
        paths <- get_venv_uv_paths()
        args <- c(
          "run",
          "-m",
          "reportipyr.cli",
          "add-path-overlay",
          "-i", normalizePath(filename),
          "-s", source_rel
        )
        run_python_script(
          paths$uv,
          args,
          paths$venv,
          "Add path overlay script"
        )
        log4r::info(
          .le$logger,
          paste0("Path overlay added to: ", filename)
        )
      } else {
        log4r::warn(
          .le$logger,
          paste0(
            "Skipping path overlay: could not determine",
            " source path or project root"
          )
        )
      }
    }
  }

  write_object_metadata(
    filename,
    meta_type = meta_type,
    meta_equations = meta_equations,
    meta_notes = meta_notes,
    meta_abbrevs = meta_abbrevs,
    context = context
  )
  log4r::debug(.le$logger, "Exiting ggsave_with_metadata function")
}
