library(testthat)
library(jsonlite)

test_that("write_object_metadata throws error for missing object file", {
  non_existent_file <- tempfile(fileext = ".txt")
  expect_error(write_object_metadata(non_existent_file),
               regexp = "Please pass path to object that exists")
})

test_that("write_object_metadata creates a JSON metadata file", {
  temp_object <- tempfile(fileext = ".txt")

  writeLines("Temporary file content", temp_object)

  write_object_metadata(temp_object, meta_type = "table")

  expected_json_file <- paste0(tools::file_path_sans_ext(temp_object), "_txt_metadata.json")
  expect_true(file.exists(expected_json_file))

  json_data <- fromJSON(expected_json_file)

  expect_equal(json_data$object_meta$path, normalizePath(temp_object))
  expect_equal(json_data$object_meta$file_type, "txt")
  expect_equal(json_data$object_meta$meta_type, "table")
})

test_that("write_object_metadata includes additional metadata fields", {
  temp_object <- tempfile(fileext = ".txt")
  writeLines("Temporary file content", temp_object)

  equations <- "E = mc^2"
  notes <- "This is a test note"
  abbrevs <- c("abbrev1", "abbrev2")

  write_object_metadata(temp_object, meta_type = "table", equations = equations, notes = notes, abbrevs = abbrevs)

  expected_json_file <- paste0(tools::file_path_sans_ext(temp_object), "_txt_metadata.json")
  expect_true(file.exists(expected_json_file))

  json_data <- fromJSON(expected_json_file)

  expect_equal(json_data$object_meta$footnotes$equations, equations)
  expect_equal(json_data$object_meta$footnotes$notes, notes)
  expect_equal(json_data$object_meta$footnotes$abbreviations, abbrevs)
})
