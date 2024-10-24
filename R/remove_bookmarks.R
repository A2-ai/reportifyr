#' Removes Bookmarks from a Word file
#'
#' @description Reads in a .docx file and returns a new version with bookmarks removed from the document.
#' @param docx_in Path to the input .docx file
#' @param docx_out Path to output .docx to save to
#'
#' @keywords internal
#'
#' @examples \dontrun{
#'
#' # ---------------------------------------------------------------------------
#' # Load all dependencies
#' # ---------------------------------------------------------------------------
#' docx_in <- file.path(here::here(), "report", "shell", "template.docx")
#' doc_dirs <- make_doc_dirs(docx_in = docx_in)
#' figures_path <- file.path(here::here(), "OUTPUTS", "figures")
#' tables_path <- file.path(here::here(), "OUTPUTS", "tables")
#' footnotes <- file.path(here::here(), "report", "standard_footnotes.yaml")
#'
#' # ---------------------------------------------------------------------------
#' # Step 1.
#' # Table addition running add_tables will format and insert tables into the doc.
#' # ---------------------------------------------------------------------------
#' add_tables(
#'   docx_in = docx_in,
#'   docx_out = doc_dirs$doc_tables,
#'   tables_path = tables_path
#' )
#'
#' # ---------------------------------------------------------------------------
#' # Step 3.
#' # Next we place in the plots using the add_plots function.
#' # ---------------------------------------------------------------------------
#' add_plots(
#'   docx_in = doc_dirs$doc_tables,
#'   docx_out = doc_dirs$doc_tabs_figs,
#'   figures_path = figures_path
#' )
#'
#' # ---------------------------------------------------------------------------
#' # Step 4.
#' # Now we can add the footnotes to all the inserted figures and tables.
#' # ---------------------------------------------------------------------------
#' add_footnotes(
#'   docx_in = doc_dirs$doc_tabs_figs,
#'   docx_out = doc_dirs$doc_draft,
#'   figures_path = figures_path,
#'   tables_path = tables_path,
#'   footnotes = footnotes
#' )
#'
#' # ---------------------------------------------------------------------------
#' # Step 5.
#' # Clean the output for a final document creation. This will remove the ties
#' # between reportifyr and the document so be careful!
#' # ---------------------------------------------------------------------------
#' remove_bookmarks(
#'   docx_in = doc_dirs$doc_draft,
#'   docx_out = doc_dirs$doc_final
#' )
#' }
remove_bookmarks <- function(docx_in,
                             docx_out) {
  log4r::debug(.le$logger, "Starting remove_bookmarks function")

  if (docx_in == docx_out) {
    log4r::error(.le$logger, "Input and output file paths cannot be the same.")
    stop("You must save the output document as a new file.")
  }

  if (!(tools::file_ext(docx_in) == "docx")) {
    log4r::error(.le$logger, paste("The input file must be a docx file, not:", tools::file_ext(docx_in)))
    stop(paste("The file must be a docx file not:", tools::file_ext(docx_in)))
  }

  if (!(tools::file_ext(docx_out) == "docx")) {
    log4r::error(.le$logger, paste("The output file must be a docx file, not:", tools::file_ext(docx_out)))
    stop(paste("The file must be a docx file not:", tools::file_ext(docx_out)))
  }


  if (interactive()) {
    log4r::info(.le$logger, "Prompting user for confirmation to remove bookmarks.")
    continue <- readline("This will remove the bookmarks in the document. This severs the link between the document and reportifyr. Are you sure you want to continue? [Y/n]\n")
  } else {
    continue <- "Y"  # Automatically proceed in non-interactive environments
    log4r::info(.le$logger, "Non-interactive session detected, proceeding with bookmark removal.")
  }

  if (continue == "Y") {
    log4r::info(.le$logger, "User confirmed bookmark removal.")

    if (!file.exists(docx_in)) {
      log4r::error(.le$logger, paste("The input document does not exist:", docx_in))
      stop(paste("The input document does not exist:", docx_in))
    }

    if (is.null(getOption("venv_dir"))) {
      log4r::info(.le$logger, "Setting options('venv_dir') to project root.")
      message("Setting options('venv_dir') to project root.")
      options("venv_dir" = here::here())
    }

    venv_path <- file.path(getOption("venv_dir"), ".venv")

    if (!dir.exists(venv_path)) {
      log4r::error(.le$logger, "Virtual environment not found. Please initialize with initialize_python.")
      stop("Create virtual environment with initialize_python")
    }

    uv_path <- normalizePath("~/.cargo/bin/uv", mustWork = FALSE)
    if (!file.exists(uv_path)) {
      log4r::error(.le$logger, "uv not found. Please install with initialize_python")
      stop("Please install uv with initialize_python")
    }

    script <- system.file("scripts/remove_bookmarks.py", package = "reportifyr")
    args <- c("run", script, "-i", docx_in, "-o", docx_out)

    log4r::debug(.le$logger, "Running remove bookmarks script")
    result <- tryCatch({
      processx::run(
        command = uv_path, args = args, env = c("current", VIRTUAL_ENV = venv_path), error_on_status = TRUE
      )
    }, error = function(e) {
      log4r::error(.le$logger, paste0("Remove bookmarks script failed. Status: ", e$status))
      log4r::error(.le$logger, paste0("Remove bookmarks script failed. Stderr: ", e$stderr))
      log4r::info(.le$logger, paste0("Remove bookmarks script failed. Stdout: ", e$stdout))
      stop(paste("Remove bookmarks script failed. Status: ", e$status, "Stderr: ", e$stderr))
    })

    log4r::info(.le$logger, paste0("Returning status: ", result$status))
    log4r::info(.le$logger, paste0("Returning stdout: ", result$stdout))
    log4r::info(.le$logger, paste0("Returning stderr: ", result$stderr))

  } else if (continue == "n") {
    log4r::info(.le$logger, "User declined to remove bookmarks. No changes made.")
    message("Not updating document")
  } else {
    log4r::error(.le$logger, "Invalid response from user. Must enter Y or n.")
    stop("Must enter Y or n")
  }
  log4r::debug(.le$logger, "Exiting remove_bookmarks function")
}
