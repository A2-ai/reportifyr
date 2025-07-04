#' Build a reviewer's guide of file names and source paths
#'
#' @description Reads in a `.docx` file and returns a `.docx` table of file names and source paths.
#' @param docx_in The file path to the input `.docx` file.
#' @param docx_out The file path to the output `.docx` file to save to. Default is `NULL`.
#' @param figures_path The file path to the figures and associated metadata directory.
#' @param tables_path The file path to the tables and associated metadata directory.
#'
#' @export
#'
#' @examples \dontrun{
#' reviewer_guide(
#'   docx_in = docx_in,
#'   docx_out = docx_out,
#'   figures_path = figures_path,
#'   tables_path = tables_path
#' )
build_reviewer_guide <- function(
    docx_in,
    docx_out = NULL,
    figures_path,
    tables_path
) {
  log4r::debug(.le$logger, "Starting build_reviewer_guide function")

  if (is.null(docx_out)) {
    dir <- dirname(docx_in)
    docx_out <- file.path(dir, "reviewer_guide.docx")
    log4r::info(
      .le$logger,
      paste0("Docx_out is null, setting docx_out to: ", docx_out)
    )
  }

  start_pattern <- "\\{rpfy\\}:" # matches "{rpfy}:"
  end_pattern <- "\\.[^.]+$" # matches the file extension (e.g., ".csv", ".rds")
  magic_pattern <- paste0(start_pattern, ".*?", end_pattern)

  doc <- officer::read_docx(docx_in)
  doc_summary <- officer::docx_summary(doc)
  magic_indices <- grep(magic_pattern, doc_summary$text)

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
  file_names <- c()
  for (i in magic_indices) {
    magic_string <- doc_summary$text[[i]]
    parser <- system.file(
      "scripts/parse_magic_string.py",
      package = "reportifyr"
    )
    args <- c("run", parser, "-i", magic_string)

    result <- processx::run(
      command = uv_path,
      args = args,
      env = c("current", VIRTUAL_ENV = venv_path),
    )

    j <- jsonlite::fromJSON(result$stdout)
    file_names <- c(file_names, names(j))
  }

  # map extensions to candidate directories ------------
  ext2dir <- list(
    csv = tables_path,
    rds = tables_path,
    png = figures_path
  )

  index_tbl <- purrr::map_dfr(file_names, function(f) {
    stem <- tools::file_path_sans_ext(f)
    ext  <- tolower(tools::file_ext(f))
    meta_basename <- sprintf("%s_%s_metadata.json", stem, ext)

    # candidate directories for this extension
    cand_dirs <- rlang::`%||%`(ext2dir[[ext]], character(0))

    # try each candidate until one exists
    meta_file <- purrr::detect(
      cand_dirs,
      ~ file.exists(file.path(.x, meta_basename)),
      .default = NA_character_
    )
    meta_file <- if (!is.na(meta_file)) file.path(meta_file, meta_basename) else NA_character_

    src_path <- if (!is.na(meta_file)) {
      purrr::pluck(jsonlite::read_json(meta_file, simplifyVector = TRUE),
                   "source_meta", "path", .default = NA_character_)
    } else {
      NA_character_
    }

    tibble::tibble(filename = f, source_path = src_path)
  })

  ft <- flextable::flextable(index_tbl) |> flextable::autofit()

  flextable::save_as_docx(
    ft, path = docx_out,
    pr_section = officer::prop_section(
      page_size = officer::page_size(orient = "landscape"))
  )

  log4r::info(.le$logger, paste("Artifact index saved to:", docx_out))
  invisible(index_tbl)
}
