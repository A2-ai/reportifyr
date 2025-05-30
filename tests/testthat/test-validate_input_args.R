test_that("validate_input_args passes without error", {
  docx_in <- withr::local_tempfile(fileext = ".docx")
  file.create(docx_in)
  docx_out <- withr::local_tempfile(fileext = ".docx")

  expect_silent(validate_input_args(docx_in, docx_out))
})

test_that("validate_input_args errors if input docx does not exist", {
  docx_in <- withr::local_tempfile(fileext = ".docx")
  docx_out <- withr::local_tempfile(fileext = ".docx")

  expect_error(
    validate_input_args(docx_in, docx_out),
    "The input document does not exist"
  )
})

test_that("validate_input_args errors if input and output files are the same", {
  docx <- withr::local_tempfile(fileext = ".docx")
  file.create(docx)

  expect_error(
    validate_input_args(docx, docx),
    "You must save the output document as a new file"
  )
})

test_that("validate_input_args errors if input is not a .docx file", {
  docx_in <- tempfile(fileext = ".txt")
  file.create(docx_in)
  docx_out <- withr::local_tempfile(fileext = ".docx")

  expect_error(
    validate_input_args(docx_in, docx_out),
    "The file must be a docx file not: txt"
  )
})

test_that("validate_input_args errors if output is not a .docx file", {
  docx_in <- withr::local_tempfile(fileext = ".docx")
  file.create(docx_in)
  docx_out <- withr::local_tempfile(fileext = ".pdf")

  expect_error(
    validate_input_args(docx_in, docx_out),
    "The file must be a docx file not: pdf"
  )
})
