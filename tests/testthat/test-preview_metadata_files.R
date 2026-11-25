test_that("preview_metadata_files throws an error if the directory does not exist", {
  temp_dir <- file.path("path", "to", "dir", "that", "doesnt", "exist")
  expect_error(
    preview_metadata_files(temp_dir),
    regexp = "Directory does not exist."
  )
  unlink(temp_dir, recursive = TRUE)
})

test_that("preview_metadata_files throws an error if no metadata files are found", {
  temp_dir <- tempfile()
  dir.create(temp_dir)
  expect_error(
    preview_metadata_files(temp_dir),
    regexp = "No .json files found in the specified directory."
  )
  unlink(temp_dir, recursive = TRUE)
})

test_that("preview_metadata_files processes metadata correctly", {
  temp_dir <- tempfile()
  dir.create(temp_dir)

  # Create metadata with {1: eq1, 2: eq2} format for equations, notes, and abbreviations
  metadata_1 <- list(
    object_meta = list(
      meta_type = "table",
      footnotes = list(
        equations = list(`1` = "E = mc^2", `2` = "F = ma"),
        notes = list(`1` = "Test note 1", `2` = "Test note 2"),
        abbreviations = list(`1` = "abbr1", `2` = "abbr2")
      )
    )
  )

  metadata_2 <- list(
    object_meta = list(
      meta_type = "figure",
      footnotes = list(
        equations = list(`1` = "P = IV"),
        notes = list(`1` = "Single note"),
        abbreviations = list(`1` = "abbr_single")
      )
    )
  )

  metadata_3 <- list(
    object_meta = list(
      meta_type = NULL,
      footnotes = list(
        equations = NULL,
        notes = NULL,
        abbreviations = NULL
      )
    )
  )

  file_1 <- file.path(temp_dir, "object1_table_csv_metadata.json")
  file_2 <- file.path(temp_dir, "object2_figure_png_metadata.json")
  file_3 <- file.path(temp_dir, "object3_figure_png_metadata.json")

  jsonlite::write_json(metadata_1, file_1)
  jsonlite::write_json(metadata_2, file_2)
  jsonlite::write_json(metadata_3, file_3)

  result_df <- preview_metadata_files(temp_dir)

  expect_equal(nrow(result_df), 3)
  expect_true("object1.table" %in% result_df$name)
  expect_true("object2.figure" %in% result_df$name)
  expect_true("object3.figure" %in% result_df$name)

  expect_true(grepl("E \\= mc\\^2", result_df$meta_equations[1]))
  expect_true(grepl("F \\= ma", result_df$meta_equations[1]))
  expect_true(grepl("P \\= IV", result_df$meta_equations[2]))
  expect_true(grepl("N/A", result_df$meta_equations[3]))

  expect_true(grepl("Test note 1", result_df$meta_notes[1]))
  expect_true(grepl("Test note 2", result_df$meta_notes[1]))
  expect_true(grepl("Single note", result_df$meta_notes[2]))
  expect_true(grepl("N/A", result_df$meta_notes[3]))

  expect_true(grepl("abbr1", result_df$meta_abbrevs[1]))
  expect_true(grepl("abbr2", result_df$meta_abbrevs[1]))
  expect_true(grepl("abbr_single", result_df$meta_abbrevs[2]))
  expect_true(grepl("N/A", result_df$meta_abbrevs[3]))

  unlink(temp_dir, recursive = TRUE)
})

test_that("preview_metadata_files collapses unnamed arrays to one row per file", {
  temp_dir <- tempfile()
  dir.create(temp_dir)

  # Plain character vectors written with auto_unbox produce the *unnamed* JSON
  # arrays that write_object_metadata() writes, which fromJSON() reads back as
  # atomic vectors rather than lists. Footnote vectors of differing lengths
  # previously recycled into extra rows (equal lengths) or errored outright
  # (mismatched lengths).
  metadata_mismatched <- list(
    object_meta = list(
      meta_type = "figure",
      footnotes = list(
        equations = NULL,
        notes = c("Note one.", "Note two."),
        abbreviations = c("PK", "PD", "AUC")
      )
    )
  )

  metadata_equal <- list(
    object_meta = list(
      meta_type = "figure",
      footnotes = list(
        equations = NULL,
        notes = c("Note one.", "Note two."),
        abbreviations = c("PK", "PD")
      )
    )
  )

  metadata_recycled <- list(
    object_meta = list(
      meta_type = "figure",
      footnotes = list(
        equations = NULL,
        notes = "Only note.",
        abbreviations = c("PK", "PD", "AUC")
      )
    )
  )

  jsonlite::write_json(
    metadata_mismatched,
    file.path(temp_dir, "mismatched_png_metadata.json"),
    auto_unbox = TRUE
  )
  jsonlite::write_json(
    metadata_equal,
    file.path(temp_dir, "equal_png_metadata.json"),
    auto_unbox = TRUE
  )
  jsonlite::write_json(
    metadata_recycled,
    file.path(temp_dir, "recycled_png_metadata.json"),
    auto_unbox = TRUE
  )

  result_df <- preview_metadata_files(temp_dir)

  # One row per file, not one row per footnote element
  expect_equal(nrow(result_df), 3)
  expect_setequal(
    result_df$name,
    c("mismatched.png", "equal.png", "recycled.png")
  )

  mismatched <- result_df[result_df$name == "mismatched.png", ]
  expect_equal(nrow(mismatched), 1)
  expect_equal(mismatched$meta_notes, "Note one., Note two.")
  expect_equal(mismatched$meta_abbrevs, "PK, PD, AUC")
  expect_equal(mismatched$meta_equations, "N/A")
  expect_equal(mismatched$meta_type, "figure")

  equal <- result_df[result_df$name == "equal.png", ]
  expect_equal(equal$meta_notes, "Note one., Note two.")
  expect_equal(equal$meta_abbrevs, "PK, PD")

  recycled <- result_df[result_df$name == "recycled.png", ]
  expect_equal(recycled$meta_notes, "Only note.")
  expect_equal(recycled$meta_abbrevs, "PK, PD, AUC")

  unlink(temp_dir, recursive = TRUE)
})
