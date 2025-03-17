test_that("update_object_footnotes throws an error if file does not exist", {
  temp_json <- tempfile(fileext = ".json")
  expect_error(
    update_object_footnotes(temp_json),
    regexp = "The metadata associated with the specified file does not exist"
  )
})

test_that("update_object_footnotes appends footnotes when overwrite is FALSE", {
  temp_json <- tempfile(fileext = ".json")
  metadata <- list(
    object_meta = list(
      footnotes = list(
        equations = "E = mc^2",
        notes = "Test note",
        abbreviations = "abbr1"
      )
    )
  )

  jsonlite::write_json(metadata, temp_json)

  update_object_footnotes(
    temp_json,
    meta_equations = "New equation",
    meta_notes = "New note",
    meta_abbrevs = "abbr2",
    overwrite = FALSE
  )

  updated_metadata <- jsonlite::fromJSON(temp_json, simplifyVector = TRUE)

  expect_true(
    "New equation" %in% updated_metadata$object_meta$footnotes$equations
  )
  expect_true("E = mc^2" %in% updated_metadata$object_meta$footnotes$equations)

  expect_true("New note" %in% updated_metadata$object_meta$footnotes$notes)
  expect_true("Test note" %in% updated_metadata$object_meta$footnotes$notes)

  expect_true("abbr2" %in% updated_metadata$object_meta$footnotes$abbreviations)
  expect_true("abbr1" %in% updated_metadata$object_meta$footnotes$abbreviations)

  file.remove(temp_json)
})

test_that("update_object_footnotes overwrites footnotes when overwrite is TRUE", {
  temp_json <- tempfile(fileext = ".json")
  metadata <- list(
    object_meta = list(
      footnotes = list(
        equations = "E = mc^2",
        notes = "Test note",
        abbreviations = "abbr1"
      )
    )
  )

  jsonlite::write_json(metadata, temp_json)

  update_object_footnotes(
    temp_json,
    meta_equations = "Overwritten equation",
    meta_notes = "Overwritten note",
    meta_abbrevs = "abbr_overwrite",
    overwrite = TRUE
  )

  updated_metadata <- jsonlite::fromJSON(temp_json, simplifyVector = TRUE)

  expect_equal(
    updated_metadata$object_meta$footnotes$equations,
    "Overwritten equation"
  )
  expect_equal(updated_metadata$object_meta$footnotes$notes, "Overwritten note")
  expect_equal(
    updated_metadata$object_meta$footnotes$abbreviations,
    "abbr_overwrite"
  )

  file.remove(temp_json)
})

test_that("update_object_footnotes adjusts file path if not .json", {
  temp_txt <- tempfile(fileext = ".txt")
  metadata <- list(
    object_meta = list(
      footnotes = list(
        equations = "E = mc^2",
        notes = "Test note",
        abbreviations = "abbr1"
      )
    )
  )

  json_file_path <- paste0(
    tools::file_path_sans_ext(temp_txt),
    "_txt_metadata.json"
  )
  jsonlite::write_json(metadata, json_file_path)

  update_object_footnotes(
    temp_txt,
    meta_equations = "New equation",
    meta_notes = "New note",
    meta_abbrevs = "abbr2"
  )

  updated_metadata <- jsonlite::fromJSON(json_file_path, simplifyVector = TRUE)

  expect_true(
    "New equation" %in% updated_metadata$object_meta$footnotes$equations
  )
  expect_true("E = mc^2" %in% updated_metadata$object_meta$footnotes$equations)

  expect_true("New note" %in% updated_metadata$object_meta$footnotes$notes)
  expect_true("Test note" %in% updated_metadata$object_meta$footnotes$notes)

  expect_true("abbr2" %in% updated_metadata$object_meta$footnotes$abbreviations)
  expect_true("abbr1" %in% updated_metadata$object_meta$footnotes$abbreviations)
})
