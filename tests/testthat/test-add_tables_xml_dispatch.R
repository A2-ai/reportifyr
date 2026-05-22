library(testthat)

mock_paths <- list(venv = "/fake/.venv", uv = "/fake/uv")

build_test_docx <- function(magic_string) {
  path <- tempfile(fileext = ".docx")
  doc <- officer::read_docx()
  doc <- officer::body_add_par(doc, magic_string)
  print(doc, target = path)
  path
}

build_test_config <- function() {
  path <- tempfile(fileext = ".yaml")
  writeLines(
    c(
      "keep_caption_next: false",
      "add_alt_text: false",
      "save_table_rtf: false"
    ),
    path
  )
  path
}

# Simulates the Python add-table-xml CLI by copying input → output.
simulate_python <- function(captured_env) {
  function(uv, args, venv, name) {
    captured_env$args <- args
    captured_env$name <- name
    in_idx <- which(args == "-i")
    out_idx <- which(args == "-o")
    if (length(in_idx) == 1 && length(out_idx) == 1) {
      file.copy(args[in_idx + 1], args[out_idx + 1], overwrite = TRUE)
    }
  }
}

test_that("add_tables dispatches .xml magic strings to add-table-xml CLI", {
  tables_path <- tempfile()
  dir.create(tables_path)
  writeLines(
    paste0(
      "<w:tbl xmlns:w=\"",
      "http://schemas.openxmlformats.org/wordprocessingml/2006/main",
      "\"/>"
    ),
    file.path(tables_path, "demographics.xml")
  )

  docx_in <- build_test_docx("{rpfy}:demographics.xml")
  docx_out <- tempfile(fileext = ".docx")
  config <- build_test_config()

  captured <- new.env()

  mockery::stub(add_tables, "validate_docx", function(...) invisible(NULL))
  mockery::stub(
    add_tables, "pyro::get_venv_uv_paths", function() mock_paths
  )
  mockery::stub(
    add_tables, "run_python_script", simulate_python(captured)
  )

  add_tables(
    docx_in = docx_in,
    docx_out = docx_out,
    tables_path = tables_path,
    config_yaml = config
  )

  expect_true("add-table-xml" %in% captured$args)
  expect_true(tables_path %in% captured$args)
  expect_equal(captured$name, "Add table xml script")
})

test_that("add_tables does not call add-table-xml for csv-only documents", {
  tables_path <- tempfile()
  dir.create(tables_path)
  # CSV file so the R/officer path can resolve it, even if it skips later
  writeLines("a,b\n1,2\n", file.path(tables_path, "demographics.csv"))

  docx_in <- build_test_docx("{rpfy}:demographics.csv")
  docx_out <- tempfile(fileext = ".docx")
  config <- build_test_config()

  captured <- new.env()
  captured$called <- FALSE

  mockery::stub(add_tables, "validate_docx", function(...) invisible(NULL))
  mockery::stub(
    add_tables, "pyro::get_venv_uv_paths", function() mock_paths
  )
  mockery::stub(
    add_tables,
    "run_python_script",
    function(uv, args, venv, name) {
      captured$called <- TRUE
      captured$args <- args
    }
  )

  add_tables(
    docx_in = docx_in,
    docx_out = docx_out,
    tables_path = tables_path,
    config_yaml = config
  )

  expect_false(captured$called)
})
