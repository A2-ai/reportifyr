# data_in assertion
test_that("format_table does not throw an error if 'data_in' is of class: data frame", {
  expect_no_error(format_table(iris))
})

test_that("format_table does not throw an error if 'data_in' is a tblkit table", {
  expect_no_error(format_table(tblkit::tk(iris, stub = "Species")))
})

test_that("format_table throws an error for invalid 'data_in' class", {
  expect_error(
    format_table("data"),
    "'data_in' must be either a data frame or a tblkit table"
  )
  expect_error(
    format_table(flextable::flextable(iris)),
    "'data_in' must be either a data frame or a tblkit table"
  )
})

# the look
test_that("format_table gives a data frame format_flextable's look with no stub", {
  result <- format_table(head(iris, 3))

  expect_s3_class(result, "tblkit_spec")
  expect_equal(result$spec$theme$font_family, "Arial Narrow")
  expect_equal(result$spec$theme$font_size, 10)
  expect_equal(result$spec$theme$value_align, "left")
  expect_equal(result$spec$settings$layout$align, "center")
  expect_length(unlist(result$spec$data$stub), 0)
})

test_that("format_table keeps a tblkit table's own formats", {
  d <- data.frame(stat = c("n", "Mean"), weight = c(12, 70.256))
  x <- tblkit::tk(d, stub = "stat") |> tblkit::tk_format(decimals = 2)
  result <- format_table(x)

  expect_equal(result$spec$theme$font_family, "Arial Narrow")
  expect_true("70.26" %in% tblkit::tk_cells(result)$.text)
})

# widths
test_that("format_table fits a data frame to the page but not a tblkit table", {
  expect_equal(format_table(head(iris, 3))$spec$settings$layout$width_inches, 6)

  d <- data.frame(stat = c("n", "Mean"), weight = c(12, 70.2))
  x <- tblkit::tk(d, stub = "stat") |> tblkit::tk_layout(widths = c(.default = 1))
  expect_equal(
    format_table(x)$spec$settings$layout$widths,
    x$spec$settings$layout$widths
  )
})
