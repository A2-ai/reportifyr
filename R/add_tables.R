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
add_tables <- function(docx_in, docx_out, tables_path, debug = FALSE) {
  log4r::debug(.le$logger, "Starting add_tables function")
  tictoc::tic()

  if (!file.exists(docx_in)) {
    log4r::error(
      .le$logger,
      paste("The input document does not exist:", docx_in)
    )
    stop(paste("The input document does not exist:", docx_in))
  }
  log4r::info(.le$logger, paste0("Input document found: ", docx_in))

  if (
    !(tools::file_ext(docx_in) == "docx") ||
      !(tools::file_ext(docx_out) == "docx")
  ) {
    log4r::error(.le$logger, "Both input and output files must be .docx")
    stop("Both input and output files must be .docx")
  }

  if (debug) {
    log4r::debug(.le$logger, "Debug mode enabled")
    browser()
  }

  # Define magic string pattern
  start_pattern <- "\\{rpfy\\}:" # Matches "{rpfy}:"
  end_pattern <- "\\.[^.]+$" # Matches the file extension (e.g., ".csv", ".RDS")
  magic_pattern <- paste0(start_pattern, ".*?", end_pattern)

  document <- officer::read_docx(docx_in)

  # Extract the document summary, which includes text for paragraphs
  doc_summary <- officer::docx_summary(document)
  paragraphs_df <- doc_summary[doc_summary$content_type == "paragraph", c("doc_index", "text")]

  found_matches <- FALSE # Track if we find any matches

  # Store the matches information for processing in correct order
  matches_to_process <- list()
  processed_files <- c()

  # First pass: identify all magic strings and their positions
  for (i in seq_len(nrow(paragraphs_df))) {
    par_text <- paragraphs_df$text[i]
    doc_index <- paragraphs_df$doc_index[i]

    # Find matches for the magic string pattern
    matches <- regmatches(par_text, regexec(magic_pattern, par_text))[[1]]

    if (length(matches) > 0) {
      log4r::info(
        .le$logger,
        paste0("Found magic string: ", matches[1], " in paragraph index ", doc_index)
      )

      table_name <- gsub("\\{rpfy\\}:", "", matches[1]) |> trimws() # Remove "{rpfy}:"
      table_file <- file.path(tables_path, table_name)

      # Check if the file exists
      if (file.exists(table_file)) {
        found_matches <- TRUE

        # Store this match for processing
        if (!(table_name %in% processed_files)) {
          matches_to_process[[length(matches_to_process) + 1]] <- list(
            doc_index = doc_index,
            table_name = table_name,
            table_file = table_file,
            magic_string = matches[1]
          )
          processed_files <- c(processed_files, table_name)
        } else {
					warning(paste("Duplicate table:", table_name))
				}
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
    # Save the unchanged document
    print(document, target = docx_out)
    log4r::info(.le$logger, paste0("Unchanged document saved to: ", docx_out))
    tictoc::toc()
    return(invisible(NULL))
  }

  # Sort matches by doc_index to process them in document order
  matches_to_process <- matches_to_process[order(sapply(matches_to_process, function(x) x$doc_index))]

  # Second pass: process the matches in order from last to first (to avoid position shifts)
  for (i in rev(seq_along(matches_to_process))) {
    match_info <- matches_to_process[[i]]
    table_file <- match_info$table_file
    table_name <- match_info$table_name

    log4r::info(
      .le$logger,
      paste0("Processing table file: ", table_file)
    )

    # Load the table data
    data_in <- switch(tools::file_ext(table_file),
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

    # Create the exact pattern to search for
    magic_file_pattern <- paste0("\\{rpfy\\}:", table_name)

    # Find this specific magic string
    officer::cursor_reach(document, magic_file_pattern) |>
      flextable::body_add_flextable(
        value = flextable,
        pos = "after",
        align = "center",
        split = F,
        keepnext = F
      )

    log4r::info(.le$logger, paste0("Inserted table for: ", table_file))
  }

  # Save the final document
  print(document, target = docx_out)
  log4r::info(.le$logger, paste0("Final document saved to: ", docx_out))
  tictoc::toc()
}
