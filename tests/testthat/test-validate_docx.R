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

mock_paths <- list(venv = "/fake/.venv", uv = "/fake/uv")

test_that("validate_docx succeeds with valid docx and .csv file", {
  docx <- create_docx_with_magic_string("{rpfy}:example.csv")
  config <- create_config_yaml(strict = TRUE)

  mockery::stub(validate_docx, "pyro::get_venv_uv_paths", function() mock_paths)
  mockery::stub(validate_docx, "processx::run", function(...) {
    list(stdout = jsonlite::toJSON(list(
      success = TRUE,
      file_names = list("example.csv"),
      warnings = list(),
      errors = list()
    )))
  })

  expect_silent(validate_docx(docx, config))
})

test_that("validate_docx errors if file extension is invalid", {
  docx <- create_docx_with_magic_string("{rpfy}:example.doc")
  config <- create_config_yaml(strict = TRUE)

  mockery::stub(validate_docx, "pyro::get_venv_uv_paths", function() mock_paths)
  mockery::stub(validate_docx, "processx::run", function(...) {
    list(stdout = jsonlite::toJSON(list(
      success = FALSE,
      file_names = list("example.doc"),
      warnings = list(),
      errors = list(
        "Unsupported file types found in document: example.doc",
        "Fix artifact extensions to continue. Currently .csv, .RDS are accepted for tables and .png is accepted for figures."
      )
    )))
  })

  expect_error(validate_docx(docx, config), "Fix artifact extensions")
})

test_that("validate_docx errors on duplicated files in strict mode", {
  docx <- create_docx_with_magic_string("{rpfy}:[example.csv, example.csv]")
  config <- create_config_yaml(strict = TRUE)

  mockery::stub(validate_docx, "pyro::get_venv_uv_paths", function() mock_paths)
  mockery::stub(validate_docx, "processx::run", function(...) {
    list(stdout = jsonlite::toJSON(list(
      success = FALSE,
      file_names = list("example.csv", "example.csv"),
      warnings = list(),
      errors = list(
        "Found duplicate files, please fix: example.csv",
        "Using strict mode. Fix duplicate artifacts to continue."
      )
    )))
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

test_that("validate_docx warns and succeeds if magic strings are missing", {
  docx <- tempfile(fileext = ".docx")
  print(officer::read_docx(), target = docx)
  config <- create_config_yaml()

  mockery::stub(validate_docx, "pyro::get_venv_uv_paths", function() mock_paths)
  mockery::stub(validate_docx, "processx::run", function(...) {
    list(stdout = jsonlite::toJSON(list(
      success = TRUE,
      file_names = list(),
      warnings = list("The file does not contain magic strings; nothing to process."),
      errors = list()
    )))
  })

  expect_no_error(validate_docx(docx, config))
})

test_that("validate_docx errors if .venv directory is missing", {
  docx <- create_docx_with_magic_string("{rpfy}:example.csv")

  mockery::stub(validate_docx, "pyro::get_venv_uv_paths", function() {
    stop("Create virtual environment with initialize_python")
  })

  expect_error(
    validate_docx(docx, NULL),
    "Create virtual environment with initialize_python"
  )
})

test_that("validate_docx errors if uv path is NULL", {
  docx <- create_docx_with_magic_string("{rpfy}:example.csv")

  mockery::stub(validate_docx, "pyro::get_venv_uv_paths", function() {
    stop("Please install uv with initialize_python")
  })

  expect_error(
    validate_docx(docx, NULL),
    "Please install uv with initialize_python"
  )
})
