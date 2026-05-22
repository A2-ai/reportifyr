library(testthat)
library(jsonlite)

W_NS <- "http://schemas.openxmlformats.org/wordprocessingml/2006/main"

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
  expect_equal(xml2::xml_ns(parsed)[["w"]], W_NS)

  rows <- xml2::xml_find_all(
    parsed,
    ".//w:tr",
    ns = c(w = W_NS)
  )
  expect_gt(length(rows), 0)
})

test_that("write_xml_with_metadata writes metadata sidecar with file_type=xml", {
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
  expect_equal(xml2::xml_ns(parsed)[["w"]], W_NS)
})
