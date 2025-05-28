create_docx_with_magic_string <- function(magic_string) {
  path <- tempfile(fileext = ".docx")
  doc <- officer::read_docx()
  doc <- officer::body_add_par(doc, magic_string)
  print(doc, target = path)
  withr::defer(unlink(path), envir = parent.frame())
  path
}

create_config_yaml <- function(strict = TRUE) {
  path <- tempfile(fileext = ".yaml")
  writeLines(paste0("strict: ", tolower(strict)), path)
  withr::defer(unlink(path), envir = parent.frame())
  path
}

test_that("validate_docx succeeds with valid docx and .csv file", {
  docx <- create_docx_with_magic_string("{rpfy}:example.csv")
  config <- create_config_yaml(strict = TRUE)

  mockery::stub(validate_docx, "file.exists", function(x) TRUE)
  mockery::stub(validate_docx, "dir.exists", function(x) TRUE)
  mockery::stub(validate_docx, "get_uv_path", function() "~/.local/bin/uv")
  mockery::stub(validate_docx, "processx::run", function(...) {
    list(stdout = jsonlite::toJSON(list("example.csv" = list())))
  })

  expect_silent(validate_docx(docx, config))
})

test_that("validate_docx errors if file extension is invalid", {
  docx <- create_docx_with_magic_string("{rpfy}:example.doc")
  config <- create_config_yaml(strict = TRUE)

  mockery::stub(validate_docx, "file.exists", function(x) TRUE)
  mockery:: stub(validate_docx, "dir.exists", function(x) TRUE)
  mockery::stub(validate_docx, "get_uv_path", function() "~/.local/bin/uv")

  mockery::stub(validate_docx, "processx::run", function(...) {
    list(stdout = jsonlite::toJSON(list("example.doc" = list())))
  })

  expect_error(validate_docx(docx, config), "Fix artifact extensions")
})

test_that("validate_docx errors on duplicated files in strict mode", {
  docx <- create_docx_with_magic_string("{rpfy}:[example.csv, example.csv]")
  config <- create_config_yaml(strict = TRUE)

  mockery::stub(validate_docx, "file.exists", function(x) TRUE)
  mockery::stub(validate_docx, "dir.exists", function(x) TRUE)
  mockery::stub(validate_docx, "get_uv_path", function() "~/.local/bin/uv")

  mockery::stub(validate_docx, "processx::run", function(...) {
    raw_json <- '{"example.csv": {}, "example.csv": {}}'
    list(stdout = raw_json)
  })

  expect_error(
    validate_docx(docx, config),
    "Using strict mode. Fix duplicate artifacts to continue."
  )
})

test_that("validate_docx errors if input .docx does not exist", {
  fake_path <- tempfile(fileext = ".docx")

  expect_error(
    validate_docx(fake_path, NULL),
    "The input document does not exist"
  )
})

test_that("validate_docx errors if magic string is missing", {
  docx <- tempfile(fileext = ".docx")
  print(officer::read_docx(), target = docx)
  config <- create_config_yaml()

  mockery::stub(validate_docx, "file.exists", function(x) TRUE)
  mockery::stub(validate_docx, "dir.exists", function(x) TRUE)
  mockery::stub(validate_docx, "get_uv_path", function() "~/.local/bin/uv")

  expect_error(validate_docx(docx, config), "does not contain magic strings")
})

test_that("validate_docx errors if .venv directory is missing", {
  docx <- create_docx_with_magic_string("{rpfy}:example.csv")

  mockery::stub(validate_docx, "file.exists", function(x) TRUE)
  mockery::stub(validate_docx, "dir.exists", function(x) FALSE)

  expect_error(validate_docx(docx, NULL), "Create virtual environment with initialize_python")
})

test_that("validate_docx errors if uv path is NULL", {
  docx <- create_docx_with_magic_string("{rpfy}:example.csv")

  mockery::stub(validate_docx, "file.exists", function(x) TRUE)
  mockery::stub(validate_docx, "dir.exists", function(x) TRUE)
  mockery::stub(validate_docx, "get_uv_path", function() NULL)

  expect_error(validate_docx(docx, NULL), "Please install uv with initialize_python")
})
