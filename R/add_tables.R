#' Inserts Tables in appropriate places in a Microsoft Word file
#'
#' @description Reads in a `.docx` file and returns a new version with tables placed at appropriate places in the document.
#'
#' Tables are inserted with [tblkit::tk_report_build()]: every table goes in
#' directly after its `{rpfy}:` magic string in one pass over the document, and
#' the result is verified before it is written. `.csv` and `.rds` files are
#' formatted as flextables first (an `.rds` that already holds a flextable is
#' used as is); an `.xml` file holding a `w:tbl` is inserted as written.
#'
#' A magic string that already has a table directly after it (kept by
#' `skip_unchanged`) is left alone. A flextable caption (`flextable::set_caption()`)
#' is not inserted: put the caption in the template, above the magic string.
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

  add_alt_text <- isTRUE(config$add_alt_text)
  tables_docx <- if (add_alt_text) {
    gsub(".docx", "-inttabs.docx", docx_out)
  } else {
    docx_out
  }

  found <- insert_tables_tblkit(intermediate_docx, tables_docx, tables_path)

  if (add_alt_text) {
    if (found) {
      add_tables_alt_text(tables_docx, docx_out, tables_path = tables_path)
    } else {
      file.copy(tables_docx, docx_out, overwrite = TRUE)
    }
    unlink(tables_docx)
    log4r::debug(.le$logger, "Deleting intermediate tabs document")
  }

  unlink(intermediate_docx)
  log4r::debug(.le$logger, "Deleting intermediate document")

  log4r::info(.le$logger, paste0("Final document saved to: ", docx_out))

  tictoc::toc()
}

# Table insertion with tblkit -------------------------------------------------

rpfy_prefix <- "{rpfy}:"
table_extensions <- c("rds", "csv", "xml")

# tblkit refuses a word/document.xml over 64 MiB unless the option
# tblkit.max_story_bytes raises it; large reports go past that. Used when the
# option is not set.
rpfy_max_story_bytes <- 512 * 1024^2

# Inserts every table named by a `{rpfy}:` magic string in `docx_in` with one
# tblkit::tk_report_build() and writes the result to `docx_out`. Returns
# invisible(FALSE) when the document has no magic strings at all (`docx_out`
# is then a copy of `docx_in`), TRUE otherwise.
insert_tables_tblkit <- function(docx_in, docx_out, tables_path) {
  if (is.null(getOption("tblkit.max_story_bytes"))) {
    old <- options(tblkit.max_story_bytes = rpfy_max_story_bytes)
    on.exit(options(old), add = TRUE)
  }

  markers <- tblkit_call(
    tblkit::tk_report_inspect(docx_in, marker_prefix = rpfy_prefix)
  )$markers

  if (is.null(markers) || !nrow(markers)) {
    log4r::warn(.le$logger, "No magic strings were found in the document.")
    file.copy(docx_in, docx_out, overwrite = TRUE)
    return(invisible(FALSE))
  }

  is_table <- tolower(tools::file_ext(markers$name)) %in% table_extensions
  leading <- markers$leading %in% TRUE

  for (name in unique(markers$name[is_table & !leading])) {
    log4r::warn(
      .le$logger,
      paste0(
        "Table magic string has text before {rpfy}: and is skipped: ",
        name
      )
    )
  }

  table_markers <- markers[is_table & leading, , drop = FALSE]
  if (nrow(table_markers)) {
    log4r::info(
      .le$logger,
      paste0(
        "Found table magic strings: ",
        paste0(table_markers$name, collapse = ", ")
      )
    )
  }

  duplicates <- unique(table_markers$name[duplicated(table_markers$name)])
  if (length(duplicates)) {
    log4r::warn(
      .le$logger,
      paste0(
        "Duplicate tables found in magic strings of document; ",
        "only the first of each is used: ",
        paste0(duplicates, collapse = ", ")
      )
    )
  }

  work_dir <- tempfile("rpfy-tblkit-")
  dir.create(work_dir)
  on.exit(unlink(work_dir, recursive = TRUE), add = TRUE)
  repo <- file.path(work_dir, "artifacts")

  placements <- list()
  for (name in unique(table_markers$name)) {
    table_file <- safe_resolve(tables_path, name)
    if (!file.exists(table_file)) {
      log4r::warn(.le$logger, paste0("Table file not found: ", table_file))
      next
    }
    log4r::info(.le$logger, paste0("Processing table file: ", table_file))
    if (tolower(tools::file_ext(table_file)) == "xml") {
      placements[[name]] <- table_file
      next
    }
    flextable <- read_table_flextable(table_file)
    # what body_add_flextable(align = "center", split = FALSE) set
    flextable$properties$align <- "center"
    flextable$properties$opts_word$split <- FALSE
    width <- table_markers$text_width_in[match(name, table_markers$name)]
    placements[[name]] <- tblkit_call(
      tblkit::tk_from_flextable(
        flextable,
        width_inches = width,
        repo = repo,
        check_refresh = FALSE
      )
    )
  }

  if (!length(placements)) {
    file.copy(docx_in, docx_out, overwrite = TRUE)
    return(invisible(TRUE))
  }

  template <- docx_in
  if (length(duplicates)) {
    template <- file.path(work_dir, "template.docx")
    hide_duplicate_magic_strings(docx_in, template, duplicates)
  }

  built <- tblkit_call(
    tblkit::tk_report_build(
      template,
      placements,
      output = file.path(work_dir, "report.docx"),
      anchor = rpfy_prefix,
      repo = repo,
      from = NULL,
      existing = "skip"
    )
  )

  placed <- built$tables
  for (i in seq_len(nrow(placed))) {
    if (identical(placed$outcome[[i]], "skipped_occupied")) {
      log4r::info(
        .le$logger,
        paste0("Table already present, skipping insertion for: ", placed$tag[[i]])
      )
    } else {
      log4r::info(.le$logger, paste0("Inserted table for: ", placed$tag[[i]]))
    }
  }

  if (length(duplicates)) {
    restore_duplicate_magic_strings(built$report, docx_out)
  } else {
    file.copy(built$report, docx_out, overwrite = TRUE)
  }

  invisible(TRUE)
}

# Reads a table file (.csv or .rds) as a flextable: a flextable as is, other
# data formatted with format_flextable() and its metadata.
read_table_flextable <- function(table_file) {
  data_in <- switch(
    tolower(tools::file_ext(table_file)),
    "csv" = utils::read.csv(table_file),
    "rds" = readRDS(table_file),
    stop("Unsupported file type")
  )

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
      return(format_flextable(data_in))
    }
    log4r::warn(
      .le$logger,
      paste0(
        "Data is already a flextable so no formatting will be applied for ",
        table_file,
        "."
      )
    )
    return(data_in)
  }

  if (!inherits(data_in, "flextable")) {
    metadata <- jsonlite::fromJSON(metadata_file)
    return(format_flextable(data_in, metadata$object_meta$table1))
  }
  log4r::info(
    .le$logger,
    paste0(
      "Data is already a flextable so no formatting will be applied for ",
      table_file,
      "."
    )
  )
  data_in
}

# Runs a tblkit call, sending its messages and warnings to the log. A tblkit
# error is logged and stops add_tables().
tblkit_call <- function(expr) {
  tryCatch(
    withCallingHandlers(
      expr,
      tblkit_placement_skipped = function(m) invokeRestart("muffleMessage"),
      tblkit_caption_not_placed = function(m) {
        log4r::warn(
          .le$logger,
          paste0(
            "Flextable caption not inserted for: ",
            paste0(m$tables, collapse = ", "),
            ". Put the caption in the template above the magic string."
          )
        )
        invokeRestart("muffleMessage")
      },
      tblkit_producer_fallback = function(m) {
        log4r::debug(.le$logger, paste0("tblkit: ", conditionMessage(m)))
        invokeRestart("muffleMessage")
      },
      tblkit_table_too_wide = function(w) {
        log4r::warn(.le$logger, conditionMessage(w))
        invokeRestart("muffleWarning")
      },
      # reportifyr does not use tblkit's refresh
      tblkit_report_not_refreshable = function(w) invokeRestart("muffleWarning"),
      tblkit_not_refreshable = function(w) invokeRestart("muffleWarning")
    ),
    tblkit_error = function(e) {
      log4r::error(
        .le$logger,
        paste0("Table insertion failed: ", conditionMessage(e))
      )
      stop("add_tables stopped: ", conditionMessage(e), call. = FALSE)
    }
  )
}

# Duplicate magic strings -------------------------------------------------------
#
# tblkit refuses a magic string that appears more than once. To place the first
# and leave the rest (as reportifyr always has), the later ones get a token in
# front of "{rpfy}:" for the build, which makes them plain text to tblkit, and
# the token is taken out of the built document afterwards.

duplicate_token <- "__rpfy_duplicate__"
w_ns <- c(w = "http://schemas.openxmlformats.org/wordprocessingml/2006/main")

hide_duplicate_magic_strings <- function(docx_in, docx_out, names) {
  edit_document_xml(docx_in, docx_out, function(doc) {
    seen <- character()
    for (p in xml2::xml_find_all(doc, "//w:body//w:p", ns = w_ns)) {
      runs <- xml2::xml_find_all(p, ".//w:t", ns = w_ns)
      text <- trimws(
        paste0(xml2::xml_text(runs), collapse = ""),
        whitespace = "[ \t\r\n]"
      )
      if (!startsWith(text, rpfy_prefix)) {
        next
      }
      name <- trimws(
        substring(text, nchar(rpfy_prefix) + 1),
        whitespace = "[ \t\r\n]"
      )
      if (!name %in% names) {
        next
      }
      if (!name %in% seen) {
        seen <- c(seen, name)
        next
      }
      first <- runs[nzchar(trimws(xml2::xml_text(runs)))][[1]]
      xml2::xml_text(first) <- paste0(duplicate_token, xml2::xml_text(first))
    }
  })
}

restore_duplicate_magic_strings <- function(docx_in, docx_out) {
  edit_document_xml(docx_in, docx_out, function(doc) {
    runs <- xml2::xml_find_all(
      doc,
      paste0("//w:body//w:t[starts-with(., '", duplicate_token, "')]"),
      ns = w_ns
    )
    for (run in runs) {
      xml2::xml_text(run) <- substring(
        xml2::xml_text(run),
        nchar(duplicate_token) + 1
      )
    }
  })
}

# Applies `edit` to the parsed word/document.xml of `docx_in` and writes the
# package to `docx_out`.
edit_document_xml <- function(docx_in, docx_out, edit) {
  dir <- tempfile("rpfy-docx-")
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  officer::unpack_folder(docx_in, dir)
  path <- file.path(dir, "word", "document.xml")
  doc <- xml2::read_xml(path)
  edit(doc)
  xml2::write_xml(doc, path)
  officer::pack_folder(dir, normalizePath(docx_out, mustWork = FALSE))
  invisible(docx_out)
}
