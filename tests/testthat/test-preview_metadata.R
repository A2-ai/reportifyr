test_that("preview_metadata throws an error if the object file does not exist", {
  temp_file <- tempfile(fileext = ".csv")
  expect_error(preview_metadata(temp_file), regexp = "Error: file does not exist.")
})

test_that("preview_metadata returns correct filtered metadata for an existing object file", {
  temp_dir <- tempdir()

  # Create metadata with object1.csv and object2.png as object files
  metadata_1 <- list(object_meta = list(
    meta_type = "table",
    footnotes = list(
      equations = list(`1` = "E = mc^2", `2` = "F = ma"),
      notes = list(`1` = "Test note 1", `2` = "Test note 2"),
      abbreviations = list(`1` = "abbr1", `2` = "abbr2")
    )
  ))

  metadata_2 <- list(object_meta = list(
    meta_type = "figure",
    footnotes = list(
      equations = list(`1` = "P = IV"),
      notes = list(`1` = "Single note"),
      abbreviations = list(`1` = "abbr_single")
    )
  ))


  file_1 <- file.path(temp_dir, "object1_csv_metadata.json")
  file_2 <- file.path(temp_dir, "object2_png_metadata.json")

  jsonlite::write_json(metadata_1, file_1)
  jsonlite::write_json(metadata_2, file_2)

  # Create object files
  object_file_1 <- file.path(temp_dir, "object1.csv")
  object_file_2 <- file.path(temp_dir, "object2.png")
  file.create(object_file_1)
  file.create(object_file_2)

  result_df <- preview_metadata(object_file_1)

  expect_equal(nrow(result_df), 1)
  expect_true("object1.csv" %in% result_df$name)

  # Test that the extracted metadata for object1.csv is correct
  expect_true(grepl("E \\= mc\\^2", result_df$meta_equations))
  expect_true(grepl("Test note 1", result_df$meta_notes))
  expect_true(grepl("abbr1", result_df$meta_abbrevs))

  file.remove(file_1, file_2, object_file_1, object_file_2)
})

test_that("preview_metadata returns empty dataframe if object file not in metadata", {
  temp_dir <- tempdir()

  # Create metadata for another object file
  metadata_1 <- list(object_meta = list(
    meta_type = "table",
    footnotes = list(
      equations = list(`1` = "E = mc^2"),
      notes = list(`1` = "Test note"),
      abbreviations = list(`1` = "abbr1")
    )
  ))

  file_1 <- file.path(temp_dir, "object_table_metadata.json")
  jsonlite::write_json(metadata_1, file_1)

  # Create the object file for non_matching_file.csv
  object_file <- file.path(temp_dir, "non_matching_file.csv")
  file.create(object_file)

  # Test for an object file that doesn't match any metadata
  result_df <- preview_metadata(object_file)

  expect_equal(nrow(result_df), 0)

  file.remove(file_1, object_file)
})
