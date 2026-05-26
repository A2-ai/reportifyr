library(testthat)
library(jsonlite)

w_ns <- "http://schemas.openxmlformats.org/wordprocessingml/2006/main"

setup_project <- function() {
  temp_project_dir <- tempfile()
  dir.create(temp_project_dir)
  writeLines(
    '{"test": true}',
    file.path(temp_project_dir, ".report_init.json")
  )
  temp_project_dir
}

test_that("write_xml_with_metadata rejects non-.xml extensions", {
  ft <- flextable::qflextable(head(iris))
  expect_error(
    write_xml_with_metadata(ft, file = tempfile(fileext = ".docx")),
    regexp = "must have an .xml extension"
  )
})

test_that("write_xml_with_metadata rejects unsupported object classes", {
  expect_error(
    write_xml_with_metadata(iris, file = tempfile(fileext = ".xml")),
    regexp = "must be a `flextable` or `gt` object"
  )
})

test_that("write_xml_with_metadata writes a w:tbl fragment for a flextable", {
  project_dir <- setup_project()
  old_wd <- getwd()
  on.exit({
    setwd(old_wd)
    unlink(project_dir, recursive = TRUE)
  })
  setwd(project_dir)

  out_file <- file.path(project_dir, "iris.xml")
  ft <- flextable::qflextable(head(iris, 3))

  write_xml_with_metadata(ft, file = out_file, meta_type = "demographics")

  expect_true(file.exists(out_file))

  parsed <- xml2::read_xml(out_file)
  expect_equal(xml2::xml_name(parsed), "tbl")
  expect_equal(xml2::xml_ns(parsed)[["w"]], w_ns)

  rows <- xml2::xml_find_all(
    parsed,
    ".//w:tr",
    ns = c(w = w_ns)
  )
  expect_gt(length(rows), 0)
})

test_that("write_xml_with_metadata declares xmlns:w on the fragment root", {
  # Regression: the <w:tbl> node is extracted from a parent document where
  # xmlns:w is declared on the ancestor <w:document>. A naive write drops that
  # declaration, leaving the `w` prefix undeclared -- libxml2/xml2 parses it
  # leniently but lxml (Python's add-table-xml CLI) rejects it with
  # "Namespace prefix w on tbl is not defined". Assert the literal declaration
  # is present so the fragment stands alone.
  project_dir <- setup_project()
  old_wd <- getwd()
  on.exit({
    setwd(old_wd)
    unlink(project_dir, recursive = TRUE)
  })
  setwd(project_dir)

  out_file <- file.path(project_dir, "iris.xml")
  ft <- flextable::qflextable(head(iris, 3))

  write_xml_with_metadata(ft, file = out_file)

  raw <- paste(readLines(out_file, warn = FALSE), collapse = "\n")
  # The w namespace must be declared on the root, not just used as a prefix.
  expect_match(raw, paste0('xmlns:w="', w_ns, '"'), fixed = TRUE)
  # No namespace prefix may appear duplicated on the root start tag.
  start_tag <- sub("^\\s*(<w:tbl[^>]*>).*$", "\\1", raw)
  prefixes <- regmatches(
    start_tag,
    gregexpr("xmlns:[A-Za-z0-9]+", start_tag)
  )[[1]]
  expect_equal(anyDuplicated(prefixes), 0L)
})

test_that("write_xml_with_metadata writes metadata sidecar with xml type", {
  project_dir <- setup_project()
  old_wd <- getwd()
  on.exit({
    setwd(old_wd)
    unlink(project_dir, recursive = TRUE)
  })
  setwd(project_dir)

  out_file <- file.path(project_dir, "iris.xml")
  ft <- flextable::qflextable(head(iris, 3))

  write_xml_with_metadata(
    ft,
    file = out_file,
    meta_type = "demographics",
    meta_notes = "a note",
    meta_abbrevs = c("PK", "PD")
  )

  sidecar <- file.path(project_dir, "iris_xml_metadata.json")
  expect_true(file.exists(sidecar))

  meta <- jsonlite::fromJSON(sidecar)
  expect_equal(meta$object_meta$file_type, "xml")
  expect_equal(meta$object_meta$meta_type, "demographics")
  expect_equal(meta$object_meta$path, "iris.xml")
  expect_equal(meta$object_meta$footnotes$notes, "a note")
  expect_equal(meta$object_meta$footnotes$abbreviations, c("PK", "PD"))
})

test_that("write_xml_with_metadata handles gt objects", {
  skip_if_not_installed("gt")

  project_dir <- setup_project()
  old_wd <- getwd()
  on.exit({
    setwd(old_wd)
    unlink(project_dir, recursive = TRUE)
  })
  setwd(project_dir)

  out_file <- file.path(project_dir, "iris_gt.xml")
  gt_obj <- gt::gt(head(iris, 3))

  write_xml_with_metadata(gt_obj, file = out_file)

  expect_true(file.exists(out_file))

  parsed <- xml2::read_xml(out_file)
  expect_equal(xml2::xml_name(parsed), "tbl")
  expect_equal(xml2::xml_ns(parsed)[["w"]], w_ns)
})
