d <- data.frame(
  arm = c("Placebo", "Placebo", "Drug with a long name"),
  stat = c("n", "Mean", "n"),
  weight = c(12, 70.25, 11),
  height = c(12, 171.2, 11)
)

# assertions
test_that("fit_table_to_page throws an error for an invalid 'x'", {
  expect_error(fit_table_to_page(d), "'x' must be a tblkit table")
  expect_error(
    fit_table_to_page(flextable::flextable(d)),
    "'x' must be a tblkit table"
  )
})

test_that("fit_table_to_page throws an error for an invalid 'page_width'", {
  x <- tblkit::tk(d, stub = character())
  expect_error(fit_table_to_page(x, page_width = "6"), "'page_width'")
  expect_error(fit_table_to_page(x, page_width = 0), "'page_width'")
})

# scaling
test_that("fit_table_to_page scales the measured widths to the page width", {
  x <- tblkit::tk(d, stub = character())
  before <- tblkit::tk_check(x)$widths_twips
  after <- tblkit::tk_check(fit_table_to_page(x, page_width = 6.5))$widths_twips

  expect_lte(sum(after), 6.5 * 1440)
  expect_gt(sum(after), 6.5 * 1440 - length(after))
  # each column keeps its share of the width
  expect_true(all(abs(after - before * 6.5 * 1440 / sum(before)) <= 1))
})

test_that("fit_table_to_page gives stub columns their own widths", {
  x <- tblkit::tk(d, stub = c("arm", "stat"))
  before <- tblkit::tk_check(x)$widths_twips
  after <- tblkit::tk_check(fit_table_to_page(x))$widths_twips

  expect_length(after, ncol(d))
  expect_true(all(abs(after - before * 6 * 1440 / sum(before)) <= 1))
})
