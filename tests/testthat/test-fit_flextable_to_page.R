test_that("fit_flextable_to_page throws an error if 'ft' is not a flextable object", {
  ft <- iris

  expect_error(fit_flextable_to_page(ft, page_width = 6), "'ft' must be a flextable object")
})

test_that("fit_flextable_to_page adjusts flextable width based on page width", {
  ft <-  flextable::flextable(iris)
  page_width <- 6

  header_initial_widths <- as.numeric(ft$header$colwidths)
  body_initial_widths <- as.numeric(ft$body$colwidths)

  ftout <- fit_flextable_to_page(ft, page_width)

  header_adjusted_widths <- as.numeric(ftout$header$colwidths)
  body_adjusted_widths <- as.numeric(ftout$body$colwidths)

  expect_false(all(header_initial_widths == header_adjusted_widths))
  expect_false(all(body_initial_widths == body_adjusted_widths))

  tot_header_adj_width <- sum(header_adjusted_widths)
  tot_body_adj_width <- sum(body_adjusted_widths)

  expect_equal(tot_header_adj_width, page_width)
  expect_equal(tot_body_adj_width, page_width)
})

test_that("fit_flextable_to_page returns a flextable object", {
  ft <- flextable::flextable(iris)

  ftout <- fit_flextable_to_page(ft, page_width = 6)

  expect_s3_class(ftout, "flextable")
})
