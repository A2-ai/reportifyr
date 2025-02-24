#' Inserts Tables in appropriate places in a Microsoft Word file
#'
#' @description Reads in a `.docx` file and returns a new version with tables placed at appropriate places in the document.
#' @param docx_in The file path to the input `.docx` file.
#' @param docx_out The file path to the output `.docx` file to save to.
#' @param tables_path The file path to the tables and associated metadata directory.
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
add_tables <- function(docx_in,
                       docx_out,
                       tables_path,
                       debug = FALSE) {
  log4r::debug(.le$logger, "Starting add_tables function")
  tictoc::tic()

  if (!file.exists(docx_in)) {
    log4r::error(.le$logger, paste("The input document does not exist:", docx_in))
    stop(paste("The input document does not exist:", docx_in))
  }
  log4r::info(.le$logger, paste0("Input document found: ", docx_in))

  if (!(tools::file_ext(docx_in) == "docx") || !(tools::file_ext(docx_out) == "docx")) {
    log4r::error(.le$logger, "Both input and output files must be .docx")
    stop("Both input and output files must be .docx")
  }

  if (debug) {
    log4r::debug(.le$logger, "Debug mode enabled")
    browser()
  }

  # Define magic string pattern
  start_pattern <- "\\{rpfy\\}:" # Matches "{rpfy}:"
  end_pattern <- "\\.[^.]+$"     # Matches the file extension (e.g., ".csv", ".RDS")
  magic_pattern <- paste0(start_pattern, ".*?", end_pattern)

  document <- officer::read_docx(docx_in)

  # Extract the document summary, which includes text for paragraphs
  doc_summary <- officer::docx_summary(document)
  paragraphs <- doc_summary[doc_summary$content_type == "paragraph", "text"]

  found_matches <- FALSE  # Track if we find any matches

  # Loop through paragraphs
  for (i in seq_along(paragraphs)) {
    par_text <- paragraphs[i]

    # Find matches for the magic string pattern
    matches <- regmatches(par_text, regexec(magic_pattern, par_text))[[1]]

    if (length(matches) > 0) {
      log4r::info(.le$logger, paste0("Found magic string: ", matches[1], " in paragraph ", i))
      table_name <- gsub("\\{rpfy\\}:", "", matches[1]) |> trimws() # Remove "{rpfy}:"
      table_file <- file.path(tables_path, table_name)

      # Check if the file exists
      if (file.exists(table_file)) {
        found_matches <- TRUE
        log4r::info(.le$logger, paste0("Found matching table file: ", table_file))

        # Load the table data
        data_in <- switch(tools::file_ext(table_file),
                          "csv" = utils::read.csv(table_file),
                          "RDS" = readRDS(table_file),
                          stop("Unsupported file type"))

        # Correct metadata file naming
        metadata_file <- paste0(tools::file_path_sans_ext(table_file), "_", tools::file_ext(table_file), "_metadata.json")
        if (!file.exists(metadata_file)) {
          log4r::warn(.le$logger, paste0("Metadata file missing for table: ", table_file))
          if (!inherits(data_in, "flextable")) {
            log4r::warn(.le$logger, paste0("Default formatting will be applied for ", table_file, "."))
            flextable <- format_flextable(data_in)
          } else {
            log4r::warn(.le$logger, paste0("Data is already a flextable so no formatting will be applied for ", table_file, "."))
            flextable <- data_in
          }
        } else {
          # Format the table using flextable
          metadata <- jsonlite::fromJSON(metadata_file)
          flextable <- format_flextable(data_in, metadata$object_meta$table1)
        }

        # Insert the table right after the paragraph containing the magic string, but keep the magic string
        magic_file_pattern <- paste0("\\{rpfy\\}:", table_name)

        officer::cursor_reach(document, magic_file_pattern) |>
          flextable::body_add_flextable(
            value = flextable,
            pos = "after",
            align = "center",
            split = F,
            keepnext = F
          )

        log4r::info(.le$logger, paste0("Inserted table for: ", table_file))
      } else {
        if (tools::file_ext(table_file) %in% c("RDS", "csv")) {
          log4r::warn(.le$logger, paste0("Table file not found: ", table_file))
        }
      }
    }
  }

  # If no matches found, output warning
  if (!found_matches) {
    log4r::warn(.le$logger, "No magic strings were found in the document.")
  }

  # Save the final document
  print(document, target = docx_out)
  log4r::info(.le$logger, paste0("Final document saved to: ", docx_out))
  tictoc::toc()
}
