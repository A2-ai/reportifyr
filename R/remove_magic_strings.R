#' Removes Magic Strings from a Word file
#'
#' @description Reads in a `.docx` file and returns a new version with magic strings removed from the document.
#' @param docx_in The file path to the input `.docx` file.
#' @param docx_out The file path to the output `.docx` file to save to.
#'
#' @keywords internal
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
#' # Run the `build_report()` wrapper function to replace figures, tables, and
#' # footnotes in a `.docx` file.
#' # ---------------------------------------------------------------------------
#' build_report(
#'   docx_in = doc_dirs$doc_in,
#'   docx_out = doc_dirs$doc_draft,
#'   figures_path = figures_path,
#'   tables_path = tables_path,
#'   standard_footnotes_yaml = standard_footnotes_yaml
#' )
#'
#' # ---------------------------------------------------------------------------
#' # Step 2.
#' # Clean the output for final document creation. This will remove the ties
#' # between reportifyr and the document, so please be mindful!
#' # ---------------------------------------------------------------------------
#' remove_magic_strings(
#'   docx_in = doc_dirs$doc_draft,
#'   docx_out = doc_dirs$doc_final
#' )
#' }
remove_magic_strings <- function(docx_in, docx_out) {
  tictoc::tic()
  log4r::debug(.le$logger, "Starting remove_magic_strings function")
  validate_input_args(docx_in, docx_out, NULL)

  if (interactive()) {
    log4r::info(
      .le$logger,
      "Prompting user for confirmation to remove bookmarks."
    )
    continue <- readline(
      "This will remove magic strings from the document. This severs link between the document and reportifyr. Are you sure you want to continue? [Y/n]\n"
    )
  } else {
    continue <- "Y"
    log4r::info(
      .le$logger,
      "Non-interactive session detected, proceeding with bookmark removal."
    )
  }

  if (tolower(continue) == "y") {
    log4r::info(.le$logger, "User confirmed bookmark removal.")

    if (!file.exists(docx_in)) {
      log4r::error(
        .le$logger,
        paste("The input document does not exist:", docx_in)
      )
      stop(paste("The input document does not exist:", docx_in))
    }

    paths <- get_venv_uv_paths()

    script <- system.file(
      "scripts/remove_magic_strings.py",
      package = "reportifyr"
    )
    args <- c("run", script, "-i", docx_in, "-o", docx_out)

    log4r::debug(.le$logger, "Running remove magic strings script")
    result <- tryCatch(
      {
        processx::run(
          command = paths$uv,
          args = args,
          env = c("current", VIRTUAL_ENV = paths$venv),
          error_on_status = TRUE
        )
      },
      error = function(e) {
        log4r::error(
          .le$logger,
          paste0("Remove magic strings script failed. Status: ", e$status)
        )
        log4r::error(
          .le$logger,
          paste0("Remove magic strings script failed. Stderr: ", e$stderr)
        )
        log4r::info(
          .le$logger,
          paste0("Remove magic strings script failed. Stdout: ", e$stdout)
        )
        stop(paste(
          "Remove magic strings script failed. Status: ",
          e$status,
          "Stderr: ",
          e$stderr
        ))
      }
    )

    log4r::info(.le$logger, paste0("Returning status: ", result$status))
    log4r::info(.le$logger, paste0("Returning stdout: ", result$stdout))
    log4r::info(.le$logger, paste0("Returning stderr: ", result$stderr))
  } else if (tolower(continue) == "n") {
    log4r::info(
      .le$logger,
      "User declined to remove bookmarks. No changes made."
    )
    message("Not updating docx_in")
  } else {
    log4r::error(.le$logger, "Invalid response from user. Must enter Y or n.")
    stop("You must enter Y or n")
  }
  log4r::debug(.le$logger, "Exiting remove_bookmarks function")
  tictoc::toc()
}
