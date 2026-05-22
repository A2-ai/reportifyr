#' Save a flextable or gt object as a Word `<w:tbl>` XML fragment with metadata
#'
#' @description Renders a `flextable` or `gt` object to a standalone Word
#'   OOXML `<w:tbl>` fragment on disk, then writes the standard
#'   `_xml_metadata.json` sidecar via [write_object_metadata()]. The resulting
#'   `.xml` file is consumed by the Python-side `add-table-xml` CLI when
#'   [add_tables()] encounters an `{rpfy}:name.xml` magic string.
#'
#' @param object A `flextable` or `gt` object. `flextable` is the preferred
#'   input — `gt` support uses `gt::as_word()`, whose Word output is less
#'   feature-complete than gt's HTML output. Complex gt styling (group rows,
#'   spanners, summary rows, footnotes) may not survive the round-trip; for
#'   table layouts that require full fidelity, build with `flextable` instead.
#' @param file Path to write the XML fragment to. Must end in `.xml`.
#' @param config_yaml The file path to the `config.yaml`. Currently unused for
#'   the XML path (kept for API symmetry with [write_csv_with_metadata()] and
#'   [save_rds_with_metadata()]).
#' @param meta_type A string to specify the type of object. Default is `"NA"`.
#' @param meta_equations A string or vector of strings representing equations
#'   to include in the metadata. Default is `NULL`.
#' @param meta_notes A string or vector of strings representing notes to
#'   include in the metadata. Default is `NULL`.
#' @param meta_abbrevs A string or vector of strings representing abbreviations
#'   to include in the metadata. Default is `NULL`.
#' @param context An `rpfy_context` built via [rpfy_context()]. When `NULL`
#'   (default) an ephemeral context is constructed with all defaults.
#'
#' @export
#'
#' @examples \dontrun{
#' tables_path <- here::here("OUTPUTS", "tables")
#'
#' ft <- flextable::qflextable(head(Theoph))
#' write_xml_with_metadata(
#'   object = ft,
#'   file = file.path(tables_path, "01-12345-pk-theoph.xml")
#' )
#' }
write_xml_with_metadata <- function(
  object,
  file,
  config_yaml = NULL,
  meta_type = "NA",
  meta_equations = NULL,
  meta_notes = NULL,
  meta_abbrevs = NULL,
  context = NULL
) {
  log4r::debug(.le$logger, "Starting write_xml_with_metadata function")

  if (tolower(tools::file_ext(file)) != "xml") {
    stop("`file` must have an .xml extension; got: ", file)
  }

  context <- resolve_context(context)

  tbl_node <- if (inherits(object, "flextable")) {
    flextable_to_word_xml(object)
  } else if (inherits(object, "gt_tbl")) {
    gt_to_word_xml(object)
  } else {
    stop(
      "`object` must be a `flextable` or `gt` object (got class: ",
      paste(class(object), collapse = ", "),
      ")"
    )
  }

  xml2::write_xml(tbl_node, file)
  log4r::info(.le$logger, paste0("XML written to file: ", file))

  write_object_metadata(
    file,
    meta_type = meta_type,
    meta_equations = meta_equations,
    meta_notes = meta_notes,
    meta_abbrevs = meta_abbrevs,
    context = context
  )

  log4r::debug(.le$logger, "Exiting write_xml_with_metadata function")
}

flextable_to_word_xml <- function(ft) {
  tmp_docx <- tempfile(fileext = ".docx")
  on.exit(unlink(tmp_docx), add = TRUE)

  flextable::save_as_docx(ft, path = tmp_docx)

  extract_tbl_from_docx(tmp_docx)
}

gt_to_word_xml <- function(gt_obj) {
  if (!requireNamespace("gt", quietly = TRUE)) {
    stop(
      "Package `gt` is required to save gt objects but is not installed."
    )
  }

  raw <- gt::as_word(gt_obj)

  # gt::as_word() returns the <w:tbl> tag content as a character string but
  # may not declare the `w` namespace on the root, so wrap it in a parent
  # that declares the namespace before parsing.
  w_ns <- "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
  wrapped <- paste0(
    '<rpfy_root xmlns:w="',
    w_ns,
    '">',
    paste(raw, collapse = ""),
    "</rpfy_root>"
  )

  parsed <- xml2::read_xml(wrapped)
  tbl_node <- xml2::xml_find_first(
    parsed,
    ".//w:tbl",
    ns = c(w = w_ns)
  )

  if (inherits(tbl_node, "xml_missing")) {
    stop("Could not extract <w:tbl> element from gt::as_word() output")
  }

  tbl_node
}

extract_tbl_from_docx <- function(docx_path) {
  tmp_dir <- tempfile()
  dir.create(tmp_dir)
  on.exit(unlink(tmp_dir, recursive = TRUE), add = TRUE)

  utils::unzip(docx_path, files = "word/document.xml", exdir = tmp_dir)
  doc_xml <- xml2::read_xml(file.path(tmp_dir, "word", "document.xml"))

  ns <- c(w = "http://schemas.openxmlformats.org/wordprocessingml/2006/main")
  tbl_node <- xml2::xml_find_first(doc_xml, ".//w:tbl", ns = ns)

  if (inherits(tbl_node, "xml_missing")) {
    stop("Could not extract <w:tbl> element from rendered table")
  }

  tbl_node
}
