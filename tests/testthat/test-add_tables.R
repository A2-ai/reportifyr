w_ns_test <- c(w = "http://schemas.openxmlformats.org/wordprocessingml/2006/main")

make_template <- function(paragraphs, dir) {
  doc <- officer::read_docx()
  for (p in paragraphs) {
    doc <- officer::body_add_par(doc, p)
  }
  path <- tempfile("template-", tmpdir = dir, fileext = ".docx")
  print(doc, target = path)
  path
}

make_tables_dir <- function(dir) {
  tables <- file.path(dir, "tables")
  dir.create(tables)
  saveRDS(flextable::flextable(head(iris, 3)), file.path(tables, "iris.rds"))
  utils::write.csv(head(cars, 3), file.path(tables, "cars.csv"), row.names = FALSE)
  tables
}

# The body as a sequence: paragraph text, or "[tbl]" for a table.
body_sequence <- function(docx) {
  dir <- withr::local_tempdir()
  utils::unzip(docx, files = "word/document.xml", exdir = dir)
  doc <- xml2::read_xml(file.path(dir, "word", "document.xml"))
  nodes <- xml2::xml_find_all(doc, "/w:document/w:body/*[self::w:p or self::w:tbl]", ns = w_ns_test)
  ifelse(xml2::xml_name(nodes) == "tbl", "[tbl]", xml2::xml_text(nodes))
}

test_that("tables go directly after their magic strings", {
  dir <- withr::local_tempdir()
  tables <- make_tables_dir(dir)
  template <- make_template(c(
    "Table 1", "{rpfy}:iris.rds", "Table 2", "{rpfy}:cars.csv",
    "{rpfy}:missing.rds", "{rpfy}:figure.png", "End"
  ), dir)
  out <- file.path(dir, "out.docx")

  expect_true(insert_tables_tblkit(template, out, tables))
  expect_equal(body_sequence(out), c(
    "Table 1", "{rpfy}:iris.rds", "[tbl]", "Table 2", "{rpfy}:cars.csv", "[tbl]",
    "{rpfy}:missing.rds", "{rpfy}:figure.png", "End"
  ))
})

test_that("a magic string that already has a table is skipped", {
  dir <- withr::local_tempdir()
  tables <- make_tables_dir(dir)
  template <- make_template(c("{rpfy}:iris.rds", "End"), dir)
  first <- file.path(dir, "first.docx")
  second <- file.path(dir, "second.docx")

  insert_tables_tblkit(template, first, tables)
  insert_tables_tblkit(first, second, tables)
  expect_equal(body_sequence(second), c("{rpfy}:iris.rds", "[tbl]", "End"))
})

test_that("only the first of a duplicated magic string gets the table", {
  dir <- withr::local_tempdir()
  tables <- make_tables_dir(dir)
  template <- make_template(c(
    "{rpfy}:iris.rds", "middle", "{rpfy}:cars.csv", "{rpfy}:iris.rds", "End"
  ), dir)
  out <- file.path(dir, "out.docx")

  insert_tables_tblkit(template, out, tables)
  expect_equal(body_sequence(out), c(
    "{rpfy}:iris.rds", "[tbl]", "middle", "{rpfy}:cars.csv", "[tbl]",
    "{rpfy}:iris.rds", "End"
  ))
})

test_that("an .xml table is inserted as written", {
  dir <- withr::local_tempdir()
  tables <- make_tables_dir(dir)
  artifact <- tblkit::tk_from_flextable(
    flextable::flextable(head(iris, 3)),
    width_inches = 6,
    repo = file.path(dir, "repo"),
    check_refresh = FALSE
  )
  tblkit::tk_wml(artifact, out = file.path(tables, "iris.xml"))

  out <- file.path(dir, "out.docx")
  insert_tables_tblkit(make_template(c("{rpfy}:iris.xml", "End"), dir), out, tables)
  expect_equal(body_sequence(out), c("{rpfy}:iris.xml", "[tbl]", "End"))
})

test_that("a tblkit table saved as .rds is inserted as authored", {
  dir <- withr::local_tempdir()
  tables <- make_tables_dir(dir)
  d <- data.frame(stat = c("n", "Mean", "SD"), weight = c(12, 70.256, 8.1))
  spec <- tblkit::tk(d) |>
    tblkit::tk_label(stat = "Statistic", weight = "Weight (kg)") |>
    tblkit::tk_format(decimals = 2)
  saveRDS(spec, file.path(tables, "iris-tk.rds"))

  out <- file.path(dir, "out.docx")
  insert_tables_tblkit(make_template(c("{rpfy}:iris-tk.rds", "End"), dir), out, tables)
  expect_equal(body_sequence(out), c("{rpfy}:iris-tk.rds", "[tbl]", "End"))

  # its own label and format, not format_flextable()'s
  text <- officer::docx_summary(officer::read_docx(out))$text
  expect_true("Weight (kg)" %in% text)
  expect_true("70.26" %in% text)
})

test_that("a data frame from .rds or .csv is formatted with format_table()", {
  dir <- withr::local_tempdir()
  d <- data.frame(arm = c("Placebo", "Drug"), n = c(12L, 11L))
  saveRDS(d, file.path(dir, "d.rds"))
  utils::write.csv(d, file.path(dir, "d.csv"), row.names = FALSE)

  expect_equal(read_table(file.path(dir, "d.rds")), format_table(d))
  expect_equal(read_table(file.path(dir, "d.csv")), format_table(d))
})

test_that("save_rtf skips tblkit tables", {
  dir <- withr::local_tempdir()
  file <- file.path(dir, "t.rds")
  d <- data.frame(stat = c("n", "Mean"), weight = c(12, 70.2))
  expect_null(save_rtf(tblkit::tk(d), file, table1_format = FALSE))
  expect_false(file.exists(file.path(dir, "t_rds.RTF")))

  # a stored tblkit table, as tk_from_spec() returns
  artifact <- structure(list(), class = "tblkit_artifact")
  expect_null(save_rtf(artifact, file, table1_format = FALSE))
  expect_false(file.exists(file.path(dir, "t_rds.RTF")))
})

test_that("a document without magic strings is copied", {
  dir <- withr::local_tempdir()
  tables <- make_tables_dir(dir)
  template <- make_template("Nothing here", dir)
  out <- file.path(dir, "out.docx")

  expect_false(insert_tables_tblkit(template, out, tables))
  expect_equal(body_sequence(out), "Nothing here")
})

test_that("a table wider than the page stops add_tables", {
  dir <- withr::local_tempdir()
  tables <- make_tables_dir(dir)
  wide <- flextable::width(flextable::flextable(head(mtcars, 2)), width = 2)
  saveRDS(wide, file.path(tables, "wide.rds"))
  template <- make_template("{rpfy}:wide.rds", dir)

  expect_error(
    insert_tables_tblkit(template, file.path(dir, "out.docx"), tables),
    "add_tables stopped"
  )
})

test_that("hiding and restoring duplicate magic strings round trips", {
  dir <- withr::local_tempdir()
  doc <- officer::read_docx()
  for (p in c("{rpfy}:a.rds", "  {rpfy}:a.rds ", "{rpfy}:b.rds", "{rpfy}:a.rds")) {
    doc <- officer::body_add_par(doc, p)
  }
  # a magic string split over two runs
  doc <- officer::body_add_fpar(
    doc,
    officer::fpar(officer::ftext("{rpfy"), officer::ftext("}:b.rds"))
  )
  src <- file.path(dir, "src.docx")
  print(doc, target = src)
  text_of <- function(p) officer::docx_summary(officer::read_docx(p))$text

  hidden <- file.path(dir, "hidden.docx")
  hide_duplicate_magic_strings(src, hidden, c("a.rds", "b.rds"))
  hidden_text <- text_of(hidden)
  expect_equal(startsWith(hidden_text, duplicate_token), c(FALSE, TRUE, FALSE, TRUE, TRUE))

  restored <- file.path(dir, "restored.docx")
  restore_duplicate_magic_strings(hidden, restored)
  expect_identical(text_of(restored), text_of(src))
})
