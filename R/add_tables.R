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

  # tblkit engine: one tblkit::report_build() places every table it can after its
  # magic string and verifies the document. The officer pass below then handles only
  # what tblkit did not place (none, usually); under the officer engine it handles all.
  tblkit_placed <- character()
  if (identical(table_engine, "tblkit")) {
    tblkit_docx <- gsub(".docx", "-tblkit.docx", docx_out)
    tblkit_placed <- add_tables_tblkit(
      intermediate_docx,
      tblkit_docx,
      tables_path,
      tblkit_repo,
      max_story_bytes = config$tblkit_max_story_bytes %||% TBLKIT_MAX_STORY_BYTES
    )
    file.copy(tblkit_docx, intermediate_docx, overwrite = TRUE)
    unlink(tblkit_docx)
  }

  # define magic string pattern
  start_pattern <- "\\{rpfy\\}:" # matches "{rpfy}:"
  end_pattern <- "\\.[^.]+$" # matches the file extension (e.g., ".csv", ".rds")
  magic_pattern <- paste0(start_pattern, ".*?", end_pattern)

  if (identical(table_engine, "tblkit") &&
      !length(tblkit_officer_names(
        intermediate_docx,
        tblkit_placed,
        config$tblkit_max_story_bytes %||% TBLKIT_MAX_STORY_BYTES
      ))) {
    # every table went through tblkit: no officer read or write of the document
    if (isTRUE(config$add_alt_text)) {
      add_tables_alt_text(intermediate_docx, docx_out, tables_path = tables_path)
    } else {
      file.copy(intermediate_docx, docx_out, overwrite = TRUE)
    }
    unlink(intermediate_docx)
    log4r::debug(.le$logger, "Deleting intermediate document")
    log4r::info(.le$logger, paste0("Final document saved to: ", docx_out))
    tictoc::toc()
    return(invisible(NULL))
  }

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
    if (table_name %in% tblkit_placed) {
      next
    }
    table_file <- safe_resolve(tables_path, table_name)
    # check extension is valid
    if (tolower(tools::file_ext(table_file)) %in% c("rds", "csv", "xml")) {
      # Check if the file exists
      if (file.exists(table_file)) {
        if (!(table_file %in% processed_files)) {
          # the tblkit pass already placed what tblkit can; the rest goes in with officer
          document <- process_table_file(table_file, document, table_name)
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

  # pre-exported WML (e.g. from tblkit): inserted as is, whatever the engine
  if (tolower(tools::file_ext(table_file)) == "xml") {
    insert_wml_table(document, magic_par, table_file)
    log4r::info(.le$logger, paste0("Inserted WML table for: ", table_file))
    return(document)
  }

  flextable <- read_table_flextable(table_file)

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


# Reads a table file (.csv or .rds) as a flextable: a flextable as is, other data
# formatted with format_flextable() and its metadata, as add_tables() always has.
read_table_flextable <- function(table_file) {
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
  flextable
}

# tblkit report pass -----------------------------------------------------------

TBLKIT_PREFIX <- "{rpfy}:"
# tblkit's limit on word/document.xml unless config sets tblkit_max_story_bytes
TBLKIT_MAX_STORY_BYTES <- 512 * 1024^2

# Places every table tblkit can take into `docx_in` with one tblkit::report_build()
# (marker anchors: each table goes right after its "{rpfy}:<file>" paragraph; a magic
# string already followed by a table is skipped, as the officer path skips it) and
# writes the result to `docx_out`. Returns the names it handled (placed, skipped, or
# missing a file, which it logs as the officer pass would), which the officer pass then
# leaves alone. Left to the officer pass: a table tblkit refuses to store, and every
# table when the build fails or when any table magic string is one tblkit cannot place
# (it appears more than once, has text before "{rpfy}:", sits in a content control or
# text box, ...).
add_tables_tblkit <- function(docx_in, docx_out, tables_path, repo,
                              max_story_bytes = TBLKIT_MAX_STORY_BYTES) {
  inspected <- tryCatch(
    tblkit::report_inspect(
      docx_in,
      marker_prefix = TBLKIT_PREFIX,
      max_story_bytes = max_story_bytes
    )$markers,
    tblkit_error = function(e) {
      log4r::warn(.le$logger, paste0(
        "tblkit could not read the magic strings (", conditionMessage(e),
        "); using officer for all tables"
      ))
      NULL
    }
  )
  file.copy(docx_in, docx_out, overwrite = TRUE)
  if (is.null(inspected) || !nrow(inspected)) {
    return(character())
  }
  is_table <- tolower(tools::file_ext(inspected$name)) %in% c("rds", "csv", "xml")
  counts <- table(inspected$name)
  usable <- is_table &
    inspected$leading %in% TRUE &
    inspected$status %in% c("admitted", "MarkerOccupied") &
    as.vector(counts[inspected$name]) == 1L

  # A magic string tblkit cannot place (duplicated, text before "{rpfy}:", inside a
  # content control or text box, ...) needs the officer pass over the whole document
  # anyway; then officer places every table, which costs no more than its own pass.
  needs_officer <- is_table & !usable
  if (any(needs_officer)) {
    log4r::warn(.le$logger, paste0(
      "tblkit cannot place the magic string(s) ",
      paste(unique(inspected$name[needs_officer]), collapse = ", "),
      " (", paste(unique(inspected$status[needs_officer]), collapse = ", "),
      "); using officer for all tables"
    ))
    return(character())
  }

  width_inches <- docx_text_width_file(docx_in)
  log4r::debug(.le$logger, paste0("tblkit width ceiling (in): ", width_inches))
  placements <- list()
  missing <- character()
  for (name in inspected$name[usable]) {
    table_file <- safe_resolve(tables_path, name)
    if (!file.exists(table_file)) {
      log4r::warn(.le$logger, paste0("Table file not found: ", table_file))
      missing <- c(missing, name)
      next
    }
    if (tolower(tools::file_ext(table_file)) == "xml") {
      placements[[name]] <- table_file
      next
    }
    artifact <- tryCatch(
      export_tblkit_table(read_table_flextable(table_file), width_inches, repo),
      tblkit_error = function(e) {
        log4r::warn(.le$logger, paste0(
          "tblkit could not store ", name, " (",
          if (is.null(e$code)) class(e)[[1]] else e$code, "): ",
          conditionMessage(e), "; falling back to officer"
        ))
        NULL
      }
    )
    if (!is.null(artifact)) {
      placements[[name]] <- artifact
    }
  }
  if (!length(placements)) {
    return(missing)
  }

  built <- tryCatch(
    tblkit::report_build(
      docx_in,
      placements,
      run_dir = tempfile("rpfy-tblkit-run-"),
      anchor = tblkit::tbl_marker(TBLKIT_PREFIX, existing = "skip"),
      max_story_bytes = max_story_bytes
    ),
    tblkit_placement_skipped = function(m) invokeRestart("muffleMessage"),
    tblkit_error = function(e) {
      log4r::warn(.le$logger, paste0(
        "tblkit could not build the document (",
        if (is.null(e$code)) class(e)[[1]] else e$code, "): ",
        conditionMessage(e), "; falling back to officer for all tables"
      ))
      NULL
    }
  )
  if (is.null(built)) {
    return(missing)
  }
  file.copy(built$report, docx_out, overwrite = TRUE)
  p <- built$placements
  for (i in seq_len(nrow(p))) {
    if (identical(p$outcome[[i]], "skipped_occupied")) {
      log4r::info(.le$logger, paste0(
        "Table already present, skipping insertion for: ", p$tag[[i]]
      ))
    } else {
      log4r::info(.le$logger, paste0("Inserted table with tblkit for: ", p$tag[[i]]))
    }
  }
  c(p$tag, missing)
}

# Stores `ft` as a tblkit artifact, with the officer path's body_add_flextable(align,
# split, keepnext) arguments. A table wider than the page goes in as it is, as the
# officer path inserts it, with the warning insert_wml_table() gives (tblkit's width is
# a ceiling it would otherwise refuse the table at).
export_tblkit_table <- function(ft, width_inches, repo) {
  ft$properties$align <- "center"
  ft$properties$opts_word$split <- FALSE
  ft$properties$opts_word$keep_with_next <- FALSE
  table_width <- sum(ft$body$colwidths)
  if (table_width > width_inches) {
    log4r::warn(
      .le$logger,
      sprintf(
        "Table is %.2f in wide but the page text width is %.2f in",
        table_width, width_inches
      )
    )
  }
  tblkit::tbl_from_flextable(
    ft,
    width_inches = max(width_inches, table_width),
    repo = repo,
    check_refresh = FALSE
  )
}

# The magic-string names in `docx` the officer pass still has to place: those not in
# `placed`. Reads the paragraph text with tblkit (no officer read of the document).
tblkit_officer_names <- function(docx, placed,
                                 max_story_bytes = TBLKIT_MAX_STORY_BYTES) {
  markers <- tryCatch(
    tblkit::report_inspect(
      docx,
      marker_prefix = TBLKIT_PREFIX,
      max_story_bytes = max_story_bytes
    )$markers,
    tblkit_error = function(e) NULL
  )
  if (is.null(markers)) {
    return(NA_character_)
  }
  # a magic string that is not a leading marker has no reliable name here: officer
  # reads it with its own pattern
  if (any(!(markers$leading %in% TRUE))) {
    return(NA_character_)
  }
  names <- markers$name[tolower(tools::file_ext(markers$name)) %in% c("rds", "csv", "xml")]
  setdiff(unique(names), placed)
}

# Usable text width, in inches, of the document's default (last) section, read from
# word/document.xml, as officer::docx_dim() reports it, without an officer read.
docx_text_width_file <- function(docx) {
  dir <- tempfile("rpfy-docx-")
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  utils::unzip(docx, files = "word/document.xml", exdir = dir)
  path <- file.path(dir, "word", "document.xml")
  xml <- readChar(path, file.size(path), useBytes = TRUE)
  starts <- gregexpr("<w:sectPr[ >]", xml, perl = TRUE)[[1]]
  sect <- substring(xml, starts[[length(starts)]])
  sect <- substring(sect, 1, regexpr("</w:sectPr>", sect, fixed = TRUE))
  attr_of <- function(element, name) {
    tag <- regmatches(sect, regexpr(paste0("<w:", element, "\\b[^>]*>"), sect))
    as.numeric(sub(paste0('.*\\bw:', name, '="(-?[0-9]+)".*'), "\\1", tag))
  }
  (attr_of("pgSz", "w") - attr_of("pgMar", "left") - attr_of("pgMar", "right")) / 1440
}

# WML insertion (officer pass) -------------------------------------------------

# Places the w:tbl in `wml_file` directly after the magic string paragraph.
insert_wml_table <- function(document, magic_par, wml_file) {
  tbl <- xml2::read_xml(wml_file)
  if (xml2::xml_name(tbl) != "tbl") {
    log4r::error(.le$logger, paste0("WML file does not hold a w:tbl: ", wml_file))
    stop("WML file does not hold a w:tbl: ", wml_file)
  }

  # saved WML was sized for some page; say so if it does not fit this one
  grid_w <- xml2::xml_attr(
    xml2::xml_find_all(tbl, "w:tblGrid/w:gridCol", ns = c(w = W_NS)),
    "w:w",
    ns = c(w = W_NS)
  )
  table_width <- sum(as.numeric(grid_w), na.rm = TRUE) / 1440
  text_width <- docx_text_width(document)
  # each column is rounded to whole twips, so allow one twip per column
  if (table_width > text_width + length(grid_w) / 1440) {
    log4r::warn(
      .le$logger,
      sprintf(
        "Table %s is %.2f in wide but the page text width is %.2f in",
        basename(wml_file), table_width, text_width
      )
    )
  }

  set_normal_style_id(tbl, document)
  xml2::xml_add_sibling(magic_par, tbl, .where = "after")
  invisible(document)
}

W_NS <- "http://schemas.openxmlformats.org/wordprocessingml/2006/main"

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
    ns = c(w = W_NS)
  )
  xml2::xml_set_attr(nodes, "w:val", normal_id[[1]])
  invisible(tbl)
}
