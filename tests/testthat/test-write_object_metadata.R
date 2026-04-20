library(testthat)
library(jsonlite)

test_that("write_object_metadata throws error for missing object file", {
  non_existent_file <- tempfile(fileext = ".txt")
  expect_error(
    write_object_metadata(non_existent_file),
    regexp = "Please pass path to object that exists"
  )
})

test_that("write_object_metadata fails without initialized project", {
  # Create a temporary directory without init file
  temp_dir <- tempdir()
  temp_object <- file.path(temp_dir, "test.txt")
  writeLines("Temporary file content", temp_object)

  # Set working directory to temp dir to ensure no project root is found
  old_wd <- getwd()
  on.exit(setwd(old_wd))
  setwd(temp_dir)

  expect_error(
    write_object_metadata(temp_object, meta_type = "table"),
    regexp = "Could not find project root directory"
  )
})

test_that("write_object_metadata creates a JSON metadata file", {
  # Create a temporary project directory with init file
  temp_project_dir <- tempfile()
  dir.create(temp_project_dir)
  init_file <- file.path(temp_project_dir, ".report_init.json")
  writeLines('{"test": true}', init_file)

  # Create temp object within the project
  temp_object <- file.path(temp_project_dir, "test.txt")
  writeLines("Temporary file content", temp_object)

  # Set working directory to project dir
  old_wd <- getwd()
  on.exit({
    setwd(old_wd)
    unlink(temp_project_dir, recursive = TRUE)
  })
  setwd(temp_project_dir)

  write_object_metadata(temp_object, meta_type = "table")

  expected_json_file <- paste0(
    tools::file_path_sans_ext(temp_object),
    "_txt_metadata.json"
  )
  expect_true(file.exists(expected_json_file))

  json_data <- fromJSON(expected_json_file)

  # Path should now be relative to project root
  expect_equal(json_data$object_meta$path, "test.txt")
  expect_equal(json_data$object_meta$file_type, "txt")
  expect_equal(json_data$object_meta$meta_type, "table")
})

test_that("write_object_metadata includes additional metadata fields", {
  # Create a temporary project directory with init file
  temp_project_dir <- tempfile()
  dir.create(temp_project_dir)
  init_file <- file.path(temp_project_dir, ".report_init.json")
  writeLines('{"test": true}', init_file)

  # Create temp object within the project
  temp_object <- file.path(temp_project_dir, "test.txt")
  writeLines("Temporary file content", temp_object)

  # Set working directory to project dir
  old_wd <- getwd()
  on.exit({
    setwd(old_wd)
    unlink(temp_project_dir, recursive = TRUE)
  })
  setwd(temp_project_dir)

  equations <- "E = mc^2"
  notes <- "This is a test note"
  abbrevs <- c("abbrev1", "abbrev2")

  write_object_metadata(
    temp_object,
    meta_type = "table",
    meta_equations = equations,
    meta_notes = notes,
    meta_abbrevs = abbrevs
  )

  expected_json_file <- paste0(
    tools::file_path_sans_ext(temp_object),
    "_txt_metadata.json"
  )
  expect_true(file.exists(expected_json_file))

  json_data <- fromJSON(expected_json_file)

  expect_equal(json_data$object_meta$footnotes$equations, equations)
  expect_equal(json_data$object_meta$footnotes$notes, notes)
  expect_equal(json_data$object_meta$footnotes$abbreviations, abbrevs)
})

test_that("write_object_metadata writes source_meta from context", {
  temp_project_dir <- tempfile()
  dir.create(temp_project_dir)
  writeLines(
    '{"test": true}',
    file.path(temp_project_dir, ".report_init.json")
  )
  temp_object <- file.path(temp_project_dir, "test.txt")
  writeLines("x", temp_object)

  old_wd <- getwd()
  on.exit({
    setwd(old_wd)
    unlink(temp_project_dir, recursive = TRUE)
  })
  setwd(temp_project_dir)

  ctx <- rpfy_context(
    origin = script_source(
      path            = "scripts/foo.R",
      creation_author = "jake",
      latest_author   = "jake",
      creation_time   = "2026-01-01 00:00:00",
      latest_time     = "2026-04-20 12:00:00"
    )
  )

  write_object_metadata(temp_object, context = ctx, meta_type = "table")

  json_file <- paste0(
    tools::file_path_sans_ext(temp_object),
    "_txt_metadata.json"
  )
  json_data <- fromJSON(json_file)

  expect_equal(json_data$source_meta$type, "script")
  expect_equal(json_data$source_meta$path, "scripts/foo.R")
  expect_equal(json_data$source_meta$latest_time, "2026-04-20 12:00:00")
})

test_that("write_object_metadata writes shiny source_meta from context", {
  temp_project_dir <- tempfile()
  dir.create(temp_project_dir)
  writeLines(
    '{"test": true}',
    file.path(temp_project_dir, ".report_init.json")
  )
  temp_object <- file.path(temp_project_dir, "test.txt")
  writeLines("x", temp_object)

  old_wd <- getwd()
  on.exit({
    setwd(old_wd)
    unlink(temp_project_dir, recursive = TRUE)
  })
  setwd(temp_project_dir)

  ctx <- rpfy_context(
    origin = shiny_source(app_name = "myapp", app_version = "1.0.0")
  )

  write_object_metadata(temp_object, context = ctx, meta_type = "table")

  json_file <- paste0(
    tools::file_path_sans_ext(temp_object),
    "_txt_metadata.json"
  )
  json_data <- fromJSON(json_file)

  expect_equal(json_data$source_meta$type, "shiny")
  expect_equal(json_data$source_meta$app_name, "myapp")
  expect_equal(json_data$source_meta$app_version, "1.0.0")
})

test_that("write_object_metadata writes addl_meta when context has it", {
  temp_project_dir <- tempfile()
  dir.create(temp_project_dir)
  writeLines(
    '{"test": true}',
    file.path(temp_project_dir, ".report_init.json")
  )
  temp_object <- file.path(temp_project_dir, "test.txt")
  writeLines("x", temp_object)

  old_wd <- getwd()
  on.exit({
    setwd(old_wd)
    unlink(temp_project_dir, recursive = TRUE)
  })
  setwd(temp_project_dir)

  ctx <- rpfy_context(
    origin = shiny_source("myapp", app_version = "1.0.0"),
    addl_metadata = list(analyst = "jake", study = "PK-001")
  )

  write_object_metadata(temp_object, context = ctx)

  json_file <- paste0(
    tools::file_path_sans_ext(temp_object),
    "_txt_metadata.json"
  )
  json_data <- fromJSON(json_file)

  expect_equal(json_data$addl_meta$analyst, "jake")
  expect_equal(json_data$addl_meta$study, "PK-001")
})

test_that("write_object_metadata omits addl_meta when context has none", {
  temp_project_dir <- tempfile()
  dir.create(temp_project_dir)
  writeLines(
    '{"test": true}',
    file.path(temp_project_dir, ".report_init.json")
  )
  temp_object <- file.path(temp_project_dir, "test.txt")
  writeLines("x", temp_object)

  old_wd <- getwd()
  on.exit({
    setwd(old_wd)
    unlink(temp_project_dir, recursive = TRUE)
  })
  setwd(temp_project_dir)

  ctx <- rpfy_context(origin = shiny_source("myapp", app_version = "1.0.0"))

  write_object_metadata(temp_object, context = ctx)

  json_file <- paste0(
    tools::file_path_sans_ext(temp_object),
    "_txt_metadata.json"
  )
  json_data <- fromJSON(json_file)

  expect_null(json_data$addl_meta)
})

test_that("write_object_metadata reuses author from context", {
  temp_project_dir <- tempfile()
  dir.create(temp_project_dir)
  writeLines(
    '{"test": true}',
    file.path(temp_project_dir, ".report_init.json")
  )
  temp_object <- file.path(temp_project_dir, "test.txt")
  writeLines("x", temp_object)

  old_wd <- getwd()
  on.exit({
    setwd(old_wd)
    unlink(temp_project_dir, recursive = TRUE)
  })
  setwd(temp_project_dir)

  ctx <- rpfy_context(origin = shiny_source("myapp", app_version = "1.0.0"))
  ctx$author <- "Test User <test@example.com>"

  write_object_metadata(temp_object, context = ctx)

  json_file <- paste0(
    tools::file_path_sans_ext(temp_object),
    "_txt_metadata.json"
  )
  json_data <- fromJSON(json_file)

  expect_equal(json_data$object_meta$author, "Test User <test@example.com>")
})

test_that("write_object_metadata rejects non-rpfy_context objects", {
  temp_project_dir <- tempfile()
  dir.create(temp_project_dir)
  writeLines(
    '{"test": true}',
    file.path(temp_project_dir, ".report_init.json")
  )
  temp_object <- file.path(temp_project_dir, "test.txt")
  writeLines("x", temp_object)

  old_wd <- getwd()
  on.exit({
    setwd(old_wd)
    unlink(temp_project_dir, recursive = TRUE)
  })
  setwd(temp_project_dir)

  expect_error(
    write_object_metadata(temp_object, context = list(foo = "bar")),
    regexp = "must be NULL or inherit from class"
  )
})
