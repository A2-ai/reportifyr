#' Keeps captions with magic strings
#'
#' @param docx_in The file path to the input `.docx` file.
#' @param docx_out The file path to the output `.docx` file to save to.
#' @keywords internal
#' @noRd
keep_caption_next <- function(docx_in, docx_out) {
  log4r::debug(.le$logger, "Starting keep_caption_next function")

  if (docx_in == docx_out) {
    log4r::error(.le$logger, "Input and output file paths cannot be the same.")
    stop("You must save the output document as a new file.")
  }

  if (!(tools::file_ext(docx_in) == "docx")) {
    log4r::error(
      .le$logger,
      paste(
        "The input file must be a docx file, not:",
        tools::file_ext(docx_in)
      )
    )
    stop(paste("The file must be a docx file not:", tools::file_ext(docx_in)))
  }

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

  if (!file.exists(docx_in)) {
    log4r::error(
      .le$logger,
      paste("The input document does not exist:", docx_in)
    )
    stop(paste("The input document does not exist:", docx_in))
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

  script <- system.file(
    "scripts/keep_caption_next.py",
    package = "reportifyr"
  )
  args <- c("run", script, "-i", docx_in, "-o", docx_out)

  log4r::debug(.le$logger, "Running keep caption next script")
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
        paste0("Keep caption next script failed. Status: ", e$status)
      )
      log4r::error(
        .le$logger,
        paste0("Keep caption next script failed. Stderr: ", e$stderr)
      )
      log4r::info(
        .le$logger,
        paste0("Remove magic strings script failed. Stdout: ", e$stdout)
      )
      stop(paste(
        "Keep caption next script failed. Status: ",
        e$status,
        "Stderr: ",
        e$stderr
      ))
    }
  )

  log4r::info(.le$logger, paste0("Returning status: ", result$status))
  log4r::info(.le$logger, paste0("Returning stdout: ", result$stdout))
  log4r::info(.le$logger, paste0("Returning stderr: ", result$stderr))

  log4r::debug(.le$logger, "Exiting keep_caption_next function")
}
