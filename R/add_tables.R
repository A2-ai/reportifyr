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
            table_name
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
process_table_file <- function(table_file, document, table_name) {
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

  # Check if table already exists after the magic string (skip_unchanged kept it)
  # Access the XML body directly via officer's internal structure
  doc_xml <- document$doc_obj$get()
  magic_node <- find_table_magic_paragraph(doc_xml, table_name)
  if (!is.null(magic_node)) {
    existing <- table_after_magic(magic_node)
    if (!is.null(existing$tbl)) {
      log4r::info(
        .le$logger,
        paste0(
          "Table already present, skipping insertion for: ",
          table_name
        )
      )
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

  # A flextable caption (set_caption()) is written as its own paragraph
  # between the magic string and the table. Bookmark it so the Python
  # pipeline can tell it apart from user text and walk past it.
  if (!is.null(flextable$caption$value) && !is.null(magic_node)) {
    tag_inserted_caption(doc_xml, magic_node, table_name)
  }

  log4r::info(.le$logger, paste0("Inserted table for: ", table_file))
  # save to tmp docx file for next iteration
  document
}

# Bookmark prefix for flextable captions inserted by add_tables(). Keep in
# sync with CAPTION_BOOKMARK_PREFIX in inst/python/reportipyr/docx_utils.py.
caption_bookmark_prefix <- "rpcap_"

w_ns <- c(w = "http://schemas.openxmlformats.org/wordprocessingml/2006/main")

# First body-level paragraph whose text contains `{rpfy}:<table_name>`, or NULL.
find_table_magic_paragraph <- function(doc_xml, table_name) {
  magic <- paste0("{rpfy}:", table_name)
  paragraphs <- xml2::xml_find_all(doc_xml, "/w:document/w:body/w:p", ns = w_ns)
  hits <- grepl(magic, xml2::xml_text(paragraphs), fixed = TRUE)
  if (!any(hits)) {
    return(NULL)
  }
  paragraphs[[which(hits)[1]]]
}

is_inserted_caption <- function(node) {
  !inherits(node, "xml_missing") &&
    xml2::xml_name(node) == "p" &&
    !inherits(
      xml2::xml_find_first(
        node,
        paste0(
          ".//w:bookmarkStart[starts-with(@w:name, '",
          caption_bookmark_prefix,
          "')]"
        ),
        ns = w_ns
      ),
      "xml_missing"
    )
}

# R mirror of artifact_after_magic() in docx_utils.py: the table directly after
# the magic string, allowing one rpcap_-bookmarked caption paragraph between.
table_after_magic <- function(magic_node) {
  nxt <- xml2::xml_find_first(magic_node, "following-sibling::*[1]")
  caption <- NULL
  if (is_inserted_caption(nxt)) {
    caption <- nxt
    nxt <- xml2::xml_find_first(nxt, "following-sibling::*[1]")
  }
  tbl <- if (!inherits(nxt, "xml_missing") && xml2::xml_name(nxt) == "tbl") {
    nxt
  } else {
    NULL
  }
  list(caption = caption, tbl = tbl)
}

# Wrap the caption paragraph that body_add_flextable() just wrote between
# `magic_node` and its table in an rpcap_<md5(table_name)> bookmark.
tag_inserted_caption <- function(doc_xml, magic_node, table_name) {
  caption <- xml2::xml_find_first(magic_node, "following-sibling::*[1]")
  after <- xml2::xml_find_first(caption, "following-sibling::*[1]")
  if (
    inherits(caption, "xml_missing") ||
      xml2::xml_name(caption) != "p" ||
      inherits(after, "xml_missing") ||
      xml2::xml_name(after) != "tbl"
  ) {
    log4r::warn(
      .le$logger,
      paste0(
        "Could not locate the inserted flextable caption for: ",
        table_name,
        ". Removal, footnotes and alt text may not find this table."
      )
    )
    return(invisible(NULL))
  }

  # w:id one above the highest numeric bookmark id (0 if there are none).
  # UUID ids written by officer are skipped.
  ids <- suppressWarnings(as.numeric(xml2::xml_attr(
    xml2::xml_find_all(doc_xml, "//w:bookmarkStart", ns = w_ns),
    "w:id",
    ns = w_ns
  )))
  ids <- ids[!is.na(ids)]
  bm_id <- format(max(c(ids, -1)) + 1, scientific = FALSE)
  bm_name <- paste0(
    caption_bookmark_prefix,
    digest::digest(table_name, algo = "md5", serialize = FALSE)
  )

  # bookmarkStart goes after w:pPr (or first, if there is none). Attributes
  # are set with xml_set_attr(ns = ) so they are real w: attributes in memory;
  # passing them to xml_add_child() leaves them un-namespaced until reparse,
  # and the existing-table check could not see them on a later iteration.
  ppr <- xml2::xml_find_first(caption, "w:pPr", ns = w_ns)
  bm_start <- if (inherits(ppr, "xml_missing")) {
    xml2::xml_add_child(caption, "w:bookmarkStart", .where = 0)
  } else {
    xml2::xml_add_sibling(ppr, "w:bookmarkStart", .where = "after")
  }
  xml2::xml_set_attr(bm_start, "w:id", bm_id, ns = w_ns)
  xml2::xml_set_attr(bm_start, "w:name", bm_name, ns = w_ns)
  bm_end <- xml2::xml_add_child(caption, "w:bookmarkEnd")
  xml2::xml_set_attr(bm_end, "w:id", bm_id, ns = w_ns)

  log4r::debug(
    .le$logger,
    paste0("Bookmarked inserted caption ", bm_name, " for: ", table_name)
  )
  invisible(NULL)
}
