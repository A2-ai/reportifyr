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
