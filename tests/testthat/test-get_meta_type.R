test_that("get_meta_type gives named list for footnotes yaml file", {
  temp_fn_file <- tempfile(fileext = ".yaml")
  write("figure_footnotes:", temp_fn_file)
  write(" simple-figure: A simple figure footnote", temp_fn_file, append = TRUE)
  write("table_footnotes:", temp_fn_file, append = TRUE)
  write(" simple-table: A simple table footnote.", temp_fn_file, append = TRUE)

  expect_no_condition(get_meta_type(temp_fn_file))

  unlink(temp_fn_file)
})

test_that("get_meta_type gives type when called", {
  temp_fn_file <- tempfile(fileext = ".yaml")
  write("figure_footnotes:", temp_fn_file)
  write(" simple-figure: A simple figure footnote", temp_fn_file, append = TRUE)
  write("table_footnotes:", temp_fn_file, append = TRUE)
  write(" simple-table: A simple table footnote.", temp_fn_file, append = TRUE)

  meta_type <- get_meta_type(temp_fn_file)
  expect_equal(meta_type$`simple-figure`, 'simple-figure')
  expect_equal(meta_type$`simple-table`, 'simple-table')
  unlink(temp_fn_file)
})

test_that("get_meta_type fails for nonexistent file", {
  expect_error(get_meta_type("footnote_file_that_does_not_exist.yaml"))
})

test_that("get_meta_type fails for footnote file without `figure_footnotes:`", {
  temp_fn_file <- tempfile(fileext = ".yaml")
  write("abbreviations:", temp_fn_file)
  write(" simple-figure: A simple figure footnote", temp_fn_file, append = TRUE)
  write("table_footnotes:", temp_fn_file, append = TRUE)
  write(" simple-table: A simple table footnote.", temp_fn_file, append = TRUE)

  expect_message(get_meta_type(temp_fn_file))
  unlink(temp_fn_file)
})

test_that("get_meta_type fails for footnote file without `table_footnotes:`", {
  temp_fn_file <- tempfile(fileext = ".yaml")
  write("figure_footnotes:", temp_fn_file)
  write(" simple-figure: A simple figure footnote", temp_fn_file, append = TRUE)
  write(" simple-table: A simple table footnote.", temp_fn_file, append = TRUE)

  expect_message(get_meta_type(temp_fn_file))
  unlink(temp_fn_file)
})

test_that("get_meta_type fails for non yaml input file.", {
  temp_txt_file <- tempfile(fileext = "txt")
  write("figure_footnotes:", temp_txt_file)
  write(
    " simple-figure: A simple figure footnote",
    temp_txt_file,
    append = TRUE
  )
  write("table_footnotes:", temp_txt_file, append = TRUE)
  write(" simple-table: A simple table footnote.", temp_txt_file, append = TRUE)

  expect_error(get_meta_type(temp_txt_file))
  unlink(temp_txt_file)
})
