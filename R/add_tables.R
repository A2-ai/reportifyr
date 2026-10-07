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
  tictoc::tic("add tables")

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

  config <- yaml::read_yaml(config_yaml)

  table_engine <- config$table_engine %||% "officer"
  tblkit_repo <- NULL
  if (identical(table_engine, "tblkit")) {
    if (!requireNamespace("tblkit", quietly = TRUE)) {
      log4r::error(.le$logger, "table_engine is 'tblkit' but tblkit is not installed")
      stop("table_engine is 'tblkit' but tblkit is not installed")
    }
    # throwaway artifact repository; artifacts only live for this call
    tblkit_repo <- tempfile("rpfy-tblkit-")
    on.exit(unlink(tblkit_repo, recursive = TRUE), add = TRUE)
  }
  log4r::info(.le$logger, paste0("Table engine: ", table_engine))

  intermediate_docx <- gsub(".docx", "-int.docx", docx_out)
  log4r::info(
    .le$logger,
    paste0("Intermediate document path set: ", intermediate_docx)
  )

  if (isTRUE(config$keep_caption_next)) {
    keep_caption_next(docx_in, intermediate_docx)
  } else {
    file.copy(docx_in, intermediate_docx, overwrite = TRUE)
  }

  # define magic string pattern
  start_pattern <- "\\{rpfy\\}:" # matches "{rpfy}:"
  end_pattern <- "\\.[^.]+$" # matches the file extension (e.g., ".csv", ".rds")
  magic_pattern <- paste0(start_pattern, ".*?", end_pattern)

  document <- officer::read_docx(intermediate_docx)

  # Extract the document summary, which includes text for paragraphs
  doc_summary <- officer::docx_summary(document)
  magic_indices <- grep(magic_pattern, doc_summary$text)
  processed_files <- c()
  skipped_duplicates <- FALSE
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
    table_file <- safe_resolve(tables_path, table_name)
    # check extension is valid
    if (tolower(tools::file_ext(table_file)) %in% c("rds", "csv")) {
      # Check if the file exists
      if (file.exists(table_file)) {
        if (!(table_file %in% processed_files)) {
          document <- process_table_file(
            table_file,
            document,
            table_name,
            table_engine = table_engine,
            tblkit_repo = tblkit_repo
          )
          processed_files <- c(processed_files, table_file)
        } else {
          skipped_duplicates <- TRUE
        }
      } else {
        log4r::warn(.le$logger, paste0("Table file not found: ", table_file))
      }
    } else {
      log4r::debug(.le$logger, paste0("Skipping non-table file: ", table_name))
    }
  }

  if (skipped_duplicates) {
    log4r::warn(
      .le$logger,
      "Duplicate tables found in magic strings of document."
    )
  }

  if (isTRUE(config$add_alt_text)) {
    intermediate_tabs_docx <- gsub(".docx", "-inttabs.docx", docx_out)

    print(document, target = intermediate_tabs_docx)

    add_tables_alt_text(
      intermediate_tabs_docx,
      docx_out,
      tables_path = tables_path
    )

    unlink(intermediate_tabs_docx)
    log4r::debug(.le$logger, "Deleting intermediate tabs document")
  } else {
    print(document, target = docx_out)
  }

  unlink(intermediate_docx)
  log4r::debug(.le$logger, "Deleting intermediate document")

  log4r::info(.le$logger, paste0("Final document saved to: ", docx_out))

  tictoc::toc()
}

### New function for processing #####
process_table_file <- function(
  table_file,
  document,
  table_name,
  table_engine = "officer",
  tblkit_repo = NULL
) {
  log4r::info(
    .le$logger,
    paste0("Processing table file: ", table_file)
  )

  # Load the table data
  data_in <- switch(
    tolower(tools::file_ext(table_file)),
    "csv" = utils::read.csv(table_file),
    "rds" = readRDS(table_file),
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
    metadata <- jsonlite::fromJSON(metadata_file)
    if (!inherits(data_in, "flextable")) {
      flextable <- format_flextable(data_in, metadata$object_meta$table1)
    } else {
      log4r::info(
        .le$logger,
        paste0(
          "Data is already a flextable so no formatting will be applied for ",
          table_file,
          "."
        )
      )
      flextable <- data_in
    }
  }

  document <- officer::cursor_reach(
    document,
    paste0("\\{rpfy\\}:", table_name)
  )

  magic_par <- officer::docx_current_block_xml(document)

  # Check if table already exists after the magic string (skip_unchanged kept it)
  next_block <- xml2::xml_find_first(magic_par, "following-sibling::*[1]")
  if (identical(xml2::xml_name(next_block), "tbl")) {
    log4r::info(
      .le$logger,
      paste0("Table already present, skipping insertion for: ", table_name)
    )
    return(document)
  }

  if (identical(table_engine, "tblkit")) {
    inserted <- tryCatch(
      {
        insert_tblkit_table(document, magic_par, flextable, tblkit_repo)
        TRUE
      },
      tblkit_error = function(e) {
        log4r::warn(
          .le$logger,
          paste0(
            "tblkit could not insert ", table_name, " (",
            if (is.null(e$code)) class(e)[[1]] else e$code, "): ",
            conditionMessage(e), "; falling back to officer"
          )
        )
        FALSE
      }
    )
    if (inserted) {
      log4r::info(.le$logger, paste0("Inserted table with tblkit for: ", table_file))
      return(document)
    }
  }

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

# tblkit insertion -------------------------------------------------------------

# Exports `ft` through tblkit (verified, fixed-width WML) and places the table
# directly after the magic string paragraph `magic_par`. Signals a tblkit_error
# when tblkit refuses the table (e.g. WIDTH_OVERFLOW, UNSUPPORTED_DEPENDENCY).
insert_tblkit_table <- function(document, magic_par, ft, repo) {
  # match the officer path's body_add_flextable(align, split, keepnext) arguments
  ft$properties$align <- "center"
  ft$properties$opts_word$split <- FALSE
  ft$properties$opts_word$keep_with_next <- FALSE

  width_inches <- docx_text_width(document)
  log4r::debug(.le$logger, paste0("tblkit width ceiling (in): ", width_inches))

  artifact <- tblkit::tbl_from_flextable(
    ft,
    width_inches = width_inches,
    repo = repo,
    check_refresh = FALSE
  )
  wml_file <- tblkit::tbl_wml(artifact, out = tempfile(fileext = ".xml"))
  on.exit(unlink(wml_file), add = TRUE)

  tbl <- xml2::read_xml(wml_file)
  set_normal_style_id(tbl, document)

  xml2::xml_add_sibling(magic_par, tbl, .where = "after")
  invisible(document)
}

# Usable text width of the document's default section, in inches.
docx_text_width <- function(document) {
  dims <- officer::docx_dim(document)
  unname(dims$page[["width"]] - dims$margins[["left"]] - dims$margins[["right"]])
}

# tblkit spells the paragraph style as the style *name* "Normal"; Word needs the
# template's style *id*, which differs in localized templates.
set_normal_style_id <- function(tbl, document) {
  styles <- officer::styles_info(document, type = "paragraph")
  normal_id <- styles$style_id[styles$style_name == "Normal"]
  if (!length(normal_id)) {
    normal_id <- styles$style_id[styles$is_default]
  }
  if (!length(normal_id) || identical(normal_id[[1]], "Normal")) {
    return(invisible(tbl))
  }
  nodes <- xml2::xml_find_all(
    tbl,
    ".//w:pStyle[@w:val='Normal']",
    ns = c(w = "http://schemas.openxmlformats.org/wordprocessingml/2006/main")
  )
  xml2::xml_set_attr(nodes, "w:val", normal_id[[1]])
  invisible(tbl)
}
