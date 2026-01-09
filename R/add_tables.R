#' Inserts Tables in appropriate places in a Microsoft Word file
#'
#' @description Reads in a `.docx` file and returns a new version with tables placed at appropriate places in the document.
#' @param docx_in The file path to the input `.docx` file.
#' @param docx_out The file path to the output `.docx` file to save to.
#' @param tables_path The file path to the tables and associated metadata directory.
#' @param config_yaml The file path to the `config.yaml`. Default is `NULL`, a default `config.yaml` bundled with the `reportifyr` package is used.
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
#' }
add_tables <- function(
  docx_in,
  docx_out,
  tables_path,
  config_yaml = NULL,
  debug = FALSE
) {
  log4r::debug(.le$logger, "Starting add_tables function")
  tictoc::tic()

  if (debug) {
    log4r::debug(.le$logger, "Debug mode enabled")
    browser()
  }

  if (is.null(config_yaml)) {
    config_yaml <- system.file("extdata", "config.yaml", package = "reportifyr")
    log4r::info(.le$logger, paste0("using built-in config.yaml: ", config_yaml))
  }

  validate_input_args(docx_in, docx_out)
  validate_docx(docx_in, config_yaml)
  log4r::info(.le$logger, paste0("Output document path set: ", docx_out))

  intermediate_docx <- gsub(".docx", "-int.docx", docx_out)
  log4r::info(
    .le$logger,
    paste0("Intermediate document path set: ", intermediate_docx)
  )

  keep_caption_next(docx_in, intermediate_docx)

  # define magic string pattern
  start_pattern <- "\\{rpfy\\}:" # matches "{rpfy}:"
  end_pattern <- "\\.[^.]+$" # matches the file extension (e.g., ".csv", ".rds")
  magic_pattern <- paste0(start_pattern, ".*?", end_pattern)

  document <- officer::read_docx(intermediate_docx)

  # Extract the document summary, which includes text for paragraphs
  doc_summary <- officer::docx_summary(document)
  magic_indices <- grep(magic_pattern, doc_summary$text)
  processed_files <- c()
  # find duplicated tables
  if (length(magic_indices) > 0) {
    log4r::info(
      .le$logger,
      paste0(
        "Found magic strings: in paragraph indices ",
        paste0(magic_indices, collapse = ",")
      )
    )
  } else {
    log4r::warn(.le$logger, "No magic strings were found in the document.")
    tictoc::toc()
    print(document, target = docx_out)
    return(invisible(NULL))
  }

  for (i in magic_indices) {
    # Remove "{rpfy}:"
    table_name <- gsub("\\{rpfy\\}:", "", doc_summary$text[[i]]) |> trimws()
    table_file <- file.path(tables_path, table_name)
    # check extension is valid
    if (tools::file_ext(table_file) %in% c("RDS", "csv")) {
      # Check if the file exists
      if (file.exists(table_file)) {
        if (!(table_file %in% processed_files)) {
          document <- process_table_file(
            table_file,
            document,
            table_name
          )
          processed_files <- c(processed_files, table_file)
        } else {
          # strict mode fail - config option, deafult FALSE
          # log4r::error
          # else
          log4r::warn(
            .le$logger,
            paste0("Duplicate table file fount: ", table_file)
          )
        }
      } else {
        log4r::warn(.le$logger, paste0("Table file not found: ", table_file))
      }
    }
  }
  intermediate_tabs_docx <- gsub(".docx", "-inttabs.docx", docx_out)

  print(document, target = intermediate_tabs_docx)

  add_tables_alt_text(
    intermediate_tabs_docx,
    docx_out
  )

  unlink(intermediate_docx)
  log4r::debug(.le$logger, "Deleting intermediate document")

  unlink(intermediate_tabs_docx)
  log4r::debug(.le$logger, "Deleting intermediate tabs document")

  log4r::info(.le$logger, paste0("Final document saved to: ", docx_out))
  tictoc::toc()
}

### New function for processing #####
process_table_file <- function(table_file, document, table_name) {
  log4r::info(
    .le$logger,
    paste0("Processing table file: ", table_file)
  )

  # Load the table data
  data_in <- switch(
    tools::file_ext(table_file),
    "csv" = utils::read.csv(table_file),
    "RDS" = readRDS(table_file),
    stop("Unsupported file type")
  )

  # Correct metadata file naming
  metadata_file <- paste0(
    tools::file_path_sans_ext(table_file),
    "_",
    tools::file_ext(table_file),
    "_metadata.json"
  )

  if (!file.exists(metadata_file)) {
    log4r::warn(
      .le$logger,
      paste0("Metadata file missing for table: ", table_file)
    )
    if (!inherits(data_in, "flextable")) {
      log4r::warn(
        .le$logger,
        paste0("Default formatting will be applied for ", table_file, ".")
      )
      flextable <- format_flextable(data_in)
    } else {
      log4r::warn(
        .le$logger,
        paste0(
          "Data is already a flextable so no formatting will be applied for ",
          table_file,
          "."
        )
      )
      flextable <- data_in
    }
  } else {
    # Format the table using flextable
    metadata <- jsonlite::fromJSON(metadata_file)
    flextable <- format_flextable(data_in, metadata$object_meta$table1)
  }

  document <- officer::cursor_reach(
    document,
    paste0("\\{rpfy\\}:", table_name)
  )

  flextable::body_add_flextable(
    document,
    value = flextable,
    pos = "after",
    align = "center",
    split = FALSE,
    keepnext = FALSE
  )

  log4r::info(.le$logger, paste0("Inserted table for: ", table_file))
  # save to tmp docx file for next iteration
  document
}
