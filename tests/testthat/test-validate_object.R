test_that("validate_object throws an error if the file does not exist", {
  temp_file <- tempfile(fileext = ".csv")
  expect_error(
    validate_object(temp_file),
    regexp = "The specified file does not exist."
  )
})

test_that("validate_object throws an error if the metadata file does not exist", {
  temp_file <- tempfile(fileext = ".csv")
  file.create(temp_file)

  expect_error(
    validate_object(temp_file),
    regexp = "The associated metadata JSON file does not exist."
  )

  file.remove(temp_file)
})

test_that("validate_object throws an error if the metadata file does not contain a hash", {
  temp_file <- tempfile(fileext = ".csv")
  file.create(temp_file)

  temp_metadata <- tempfile(fileext = "_csv_metadata.json")
  metadata <- list(object_meta = list())
  jsonlite::write_json(metadata, temp_metadata)

  file.copy(
    temp_metadata,
    paste0(tools::file_path_sans_ext(temp_file), "_csv_metadata.json")
  )

  expect_error(
    validate_object(temp_file),
    regexp = "The metadata JSON file does not contain a hash value."
  )

  file.remove(temp_file, temp_metadata)
})

test_that("validate_object returns TRUE when file hash matches metadata hash", {
  temp_file <- tempfile(fileext = ".csv")
  file.create(temp_file)

  file_hash <- digest::digest(file = temp_file, algo = "blake3")

  temp_metadata <- tempfile(fileext = "_csv_metadata.json")
  metadata <- list(object_meta = list(hash = file_hash))
  jsonlite::write_json(metadata, temp_metadata)

  file.copy(
    temp_metadata,
    paste0(tools::file_path_sans_ext(temp_file), "_csv_metadata.json")
  )

  result <- validate_object(temp_file)

  expect_true(result)

  file.remove(temp_file, temp_metadata)
})

test_that("validate_object returns FALSE when file hash does not match metadata hash", {
  temp_file <- tempfile(fileext = ".csv")
  file.create(temp_file)

  incorrect_hash <- digest::digest("some other content", algo = "blake3")

  temp_metadata <- tempfile(fileext = "_csv_metadata.json")
  metadata <- list(object_meta = list(hash = incorrect_hash))
  jsonlite::write_json(metadata, temp_metadata)

  file.copy(
    temp_metadata,
    paste0(tools::file_path_sans_ext(temp_file), "_csv_metadata.json")
  )

  result <- validate_object(temp_file)

  expect_false(result)

  file.remove(temp_file, temp_metadata)
})
