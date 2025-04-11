#' Inserts Figures in appropriate places in a Microsoft Word file
#'
#' @description Reads in a `.docx` file and returns a new version with figures placed at appropriate places in the document.
#' @param docx_in The file path to the input `.docx` file.
#' @param docx_out The file path to the output `.docx` file to save to.
#' @param figures_path The file path to the figures directory.
#' @param config_yaml The path to config.yaml file that controls figure dimensions
#' @param fig_width A global controller. The figure width in inches. Default is `NULL`. If `NULL`, the width is determined by the figure's pixel dimensions.
#' @param fig_height A global controller. The figure height in inches. Default is `NULL`. If `NULL`, the height is determined by the figure's pixel dimensions.
#' @param debug Debug.
#'
#' @export
#'
#' @examples \dontrun{
#'
#' # ---------------------------------------------------------------------------
#' # Load all dependencies
#' # ---------------------------------------------------------------------------
#' docx_in <- here::here("report", "shell", "template.docx")
#' doc_dirs <- make_doc_dirs(docx_in = docx_in)
#' figures_path <- here::here("OUTPUTS", "figures")
#' tables_path <- here::here("OUTPUTS", "tables")
#' standard_footnotes_yaml <- here::here("report", "standard_footnotes.yaml")
#'
#' # ---------------------------------------------------------------------------
#' # Step 1.
#' # `add_tables()` will format and insert tables into the `.docx` file.
#' # ---------------------------------------------------------------------------
#' add_tables(
#'   docx_in = doc_dirs$doc_in,
#'   docx_out = doc_dirs$doc_tables,
#'   tables_path = tables_path
#' )
#'
#' # ---------------------------------------------------------------------------
#' # Step 2.
#' # Next we insert the plots using the `add_plots()` function.
#' # ---------------------------------------------------------------------------
#' add_plots(
#'   docx_in = doc_dirs$doc_tables,
#'   docx_out = doc_dirs$doc_tabs_figs,
#'   figures_path = figures_path
#' )
#' }
add_plots <- function(
    docx_in,
    docx_out,
    figures_path,
    config_yaml = NULL,
    fig_width = NULL,
    fig_height = NULL,
    debug = FALSE) {
  log4r::debug(.le$logger, "Starting add_plots function")
  tictoc::tic()

  validate_docx(docx_in, config_yaml)

  if (!(tools::file_ext(docx_out) == "docx")) {
    log4r::error(
      .le$logger,
      paste(
        "The output file must be a docx file, not:",
        tools::file_ext(docx_out)
      )
    )
    stop(paste("The file must be a docx file not:", tools::file_ext(docx_out)))
  }

  if (debug) {
    log4r::debug(.le$logger, "Debug mode enabled")
    browser()
  }
  script <- system.file("scripts/add_figure.py", package = "reportifyr")
  args <- c("run", script, "-i", docx_in, "-o", docx_out, "-d", figures_path)

  if (!is.null(config_yaml)) {
    args <- c(args, "-c", config_yaml)
    log4r::info(.le$logger, paste0("config yaml set: ", config_yaml))
  }

  if (!is.null(fig_width)) {
    args <- c(args, "-w", fig_width)
    log4r::info(.le$logger, paste0("Figure width set: ", fig_width))
  }

  if (!is.null(fig_height)) {
    args <- c(args, "-g", fig_height)
    log4r::info(.le$logger, paste0("Figure height set: ", fig_height))
  }

  if (is.null(getOption("venv_dir"))) {
    log4r::info(.le$logger, "Setting options('venv_dir') to project root.")

    message("Setting options('venv_dir') to project root.")
    options("venv_dir" = here::here())
  }

  venv_path <- file.path(getOption("venv_dir"), ".venv")

  if (!dir.exists(venv_path)) {
    log4r::error(
      .le$logger,
      "Virtual environment not found. Please initialize with initialize_python."
    )
    stop("Create virtual environment with initialize_python")
  }

  uv_path <- get_uv_path()
  if (is.null(uv_path)) {
    log4r::error(
      .le$logger,
      "uv not found. Please install with initialize_python"
    )
    stop("Please install uv with initialize_python")
  }
  log4r::debug(.le$logger, "Running add plots script")
  result <- tryCatch(
    {
      processx::run(
        command = uv_path,
        args = args,
        env = c("current", VIRTUAL_ENV = venv_path),
        error_on_status = TRUE
      )
    },
    error = function(e) {
      log4r::error(
        .le$logger,
        paste0("Add plots script failed. Status: ", e$status)
      )
      log4r::error(
        .le$logger,
        paste0("Add plots script failed. Stderr: ", e$stderr)
      )
      log4r::info(
        .le$logger,
        paste0("Add plots script failed. Stdout: ", e$stdout)
      )
      stop(paste(
        "Add plots script failed. Status: ",
        e$status,
        "Stderr: ",
        e$stderr
      ))
    }
  )
  if (grepl("Duplicate figure names found in the document", result$stdout)) {
    log4r::warn(
      .le$logger,
      "Duplicate figures found in magic strings of document."
    )
  }

  if (grepl("Unsupported", result$stdout)) {
    stdout_lines <- strsplit(result$stdout, "\n")[[1]]
    matching_lines <- stdout_lines[grepl("Unsupported", stdout_lines)]
    log4r::warn(.le$logger, matching_lines)
  }

  log4r::info(.le$logger, paste0("Returning status: ", result$status))
  log4r::info(.le$logger, paste0("Returning stdout: ", result$stdout))
  log4r::info(.le$logger, paste0("Returning stderr: ", result$stderr))

  tictoc::toc()

  log4r::debug(.le$logger, "Exiting add_plots function")
}
