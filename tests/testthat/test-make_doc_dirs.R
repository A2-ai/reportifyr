test_that("make_doc_dirs throws an error if input file does not exist", {
  temp_docx <- tempfile(fileext = ".docx")
  expect_error(
    make_doc_dirs(temp_docx),
    regexp = "The input document does not exist"
  )
})

test_that("make_doc_dirs throws an error if input file is not a docx file", {
  temp_txt <- tempfile(fileext = ".txt")
  file.create(temp_txt)
  expect_error(make_doc_dirs(temp_txt), regexp = "The file must be a docx file")
  file.remove(temp_txt)
})

test_that("make_doc_dirs returns correct paths for a valid input docx", {
  temp_docx <- tempfile(fileext = ".docx")
  file.create(temp_docx)
  doc_dirs <- make_doc_dirs(docx_in = temp_docx)
  print(doc_dirs)
  base_path <- sub("/[^/]+$", "", temp_docx)
  doc_name <- gsub(".*/(.*)\\.docx", "\\1", temp_docx)

  expect_equal(
    doc_dirs$doc_clean,
    paste0(base_path, '/', doc_name, "-clean.docx")
  )
  expect_equal(
    doc_dirs$doc_tables,
    paste0(base_path, '/', doc_name, "-tabs.docx")
  )
  expect_equal(
    doc_dirs$doc_tabs_figs,
    paste0(base_path, '/', doc_name, "-tabsfigs.docx")
  )
  expect_equal(
    doc_dirs$doc_draft,
    paste0(base_path, '/', doc_name, "-draft.docx")
  )
  expect_equal(
    doc_dirs$doc_final,
    paste0(base_path, '/', doc_name, "-final.docx")
  )

  file.remove(temp_docx)
})
