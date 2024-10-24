test_that("get_meta_abbrevs gives named list for footnotes yaml file", {
  temp_fn_file <- tempfile(fileext = ".yaml")
  write("abbreviations:", temp_fn_file)
  write(" AGEBL: Baseline age", temp_fn_file, append = TRUE)
  write(" ALBBL: Baseline albumin", temp_fn_file, append = TRUE)

  expect_no_condition(get_meta_abbrevs(temp_fn_file))

  unlink(temp_fn_file)
})

test_that("get_meta_abbrevs gives abbreviation when called", {
  temp_used_file <- tempfile(fileext = ".yaml")
  write("abbreviations:", temp_used_file)
  write(" AGEBL: Baseline age", temp_used_file, append = TRUE)
  write(" ALBBL: Baseline albumin", temp_used_file, append = TRUE)

  meta_abbrevs <- get_meta_abbrevs(temp_used_file)
  expect_equal(meta_abbrevs$AGEBL, 'AGEBL')
  unlink(temp_used_file)
})

test_that("get_meta_abbrevs fails for nonexistent file", {
  expect_error(get_meta_abbrevs("footnote_file_that_does_not_exist.yaml"))
})

test_that("get_meta_abbrevs fails for footnote file without `abbreviations:`", {
  temp_no_abbrev_file <- tempfile(fileext = ".yaml")
  write(" AGEBL: Baseline age", temp_no_abbrev_file)
  write(" ALBBL: Baseline albumin", temp_no_abbrev_file, append = TRUE)

  expect_message(get_meta_abbrevs(temp_no_abbrev_file))
  unlink(temp_no_abbrev_file)
})

test_that("get_meta_abbrevs fails for non yaml input file.", {
  temp_txt_file <- tempfile(fileext = ".txt")
  write("abbreviations:", temp_txt_file)
  write(" AGEBL: Baseline age", temp_txt_file, append = TRUE)
  write(" ALBBL: Baseline albumin", temp_txt_file, append = TRUE)

  expect_error(get_meta_abbrevs(temp_txt_file))
  unlink(temp_txt_file)
})


