# data_in assertion
test_that("format_flextable does not throw an error if 'data_in' is of class: data frame", {
  data_in <- iris

  expect_no_error(format_flextable(data_in, table1_format = FALSE))
})

test_that("format_flextable throws an error for invalid 'data_in' class", {
  data_in <- "data"

  expect_error(
    format_flextable(data_in, table1_format = FALSE),
    "'data_in' must be either a data frame or a flextable. If you are reading in a table1 table, pass table1_format = TRUE"
  )
})

# table1 assertion
test_that("format_flextable does not throw an error if 'table1_format' is of class: logical", {
  data_in <- readRDS(testthat::test_path("data", "example.RDS"))
  table1_format <- TRUE

  expect_no_error(format_flextable(data_in, table1_format))
})

test_that("format_flextable throws an error for invalid 'table1_format' class", {
  data_in <- readRDS(testthat::test_path("data", "example.RDS"))
  table1_format <- "Y"

  expect_error(
    format_flextable(data_in, table1_format),
    "'table1_format' must be TRUE or FALSE"
  )
})


# processing table1
test_that("format_flextable correctly processes data_in when 'table1_format' is TRUE", {
  data_in <- readRDS(testthat::test_path("data", "example.RDS"))
  result <- format_flextable(data_in, table1_format = TRUE)
  border_dim <- c("top", "left", "right", "bottom") # To simplify testing

  expect_true(
    result$header$dataset[[1]][1] == "" | result$header$dataset[[1]][1] == " "
  ) # Original data frame for header should have empty first cell
  expect_true(result$body$dataset[[1]][1] != "") # Original data frame for body should have non-empty first cell

  for (i in 2:ncol(result$body$dataset)) {
    expect_true(
      result$body$dataset[[i]][1] == "" | result$body$dataset[[i]][1] == " "
    ) # Original data frame for body should have empty first cells for all columns but the first
  }

  expect_s3_class(result, "flextable")

  expect_true(all(result$header$styles$pars$text.align[[1]] == "left"))
  expect_true(all(result$body$styles$pars$text.align[[1]] == "left"))

  # Generate indices to confirm proper bolding of cells
  text_index <- grepl("^[A-Za-z]", result$body$dataset[[1]])

  bold_index <- result$body$styles$text$bold$data[, 1]

  expect_equal(text_index, bold_index)

  expect_true(all(unlist(result$header$styles$text$bold$data[1])))

  for (border in border_dim) {
    expect_true(all(
      result$header$styles$pars[[paste0("border.color.", border)]][[1]] ==
        "black"
    ))
    expect_true(all(
      result$body$styles$pars[[paste0("border.color.", border)]][[1]] == "black"
    ))
  }

  for (border in border_dim) {
    expect_true(all(
      result$header$styles$pars[[paste0("border.style.", border)]][[1]] ==
        "solid"
    ))
    expect_true(all(
      result$body$styles$pars[[paste0("border.style.", border)]][[1]] == "solid"
    ))
  }

  for (border in border_dim) {
    expect_true(all(
      result$header$styles$cells[[paste0("border.width.", border)]][[1]] == 1
    ))
    expect_true(all(
      result$body$styles$cells[[paste0("border.width.", border)]][[1]] == 1
    ))
  }

  expect_true(all(result$header$styles$text$font.family[[1]] == "Arial Narrow"))
  expect_true(all(result$body$styles$text$font.family[[1]] == "Arial Narrow"))

  expect_true(all(result$header$styles$text$font.size[[1]] == 10))
  expect_true(all(result$body$styles$text$font.size[[1]] == 10))

  expect_true(all(result$header$styles$pars$line_spacing[[1]] == 1))
  expect_true(all(result$body$styles$pars$line_spacing[[1]] == 1))

  expect_true(all(result$header$styles$pars$padding.top[[1]] == 1))
  expect_true(all(result$header$styles$pars$padding.bottom[[1]] == 1))
  expect_true(all(result$body$styles$pars$padding.top[[1]] == 1))
  expect_true(all(result$body$styles$pars$padding.bottom[[1]] == 1))
})

# processing non-table1
test_that("format_flextable correctly processes data_in data frame when 'table1_format' is FALSE", {
  data_in <- iris
  result <- format_flextable(data_in, table1_format = FALSE)
  border_dim <- c("top", "left", "right", "bottom") # To simplify testing

  expect_s3_class(result, "flextable")

  expect_equal(colnames(result$header$dataset), colnames(data_in))
  expect_equal(nrow(result$body$dataset), nrow(data_in))
  expect_equal(ncol(result$body$dataset), ncol(data_in))

  expect_equal(result$properties$layout, "autofit")
  expect_equal(result$properties$width, 1)

  expect_true(all(result$header$styles$pars$text.align[[1]] == "left"))
  expect_true(all(result$body$styles$pars$text.align[[1]] == "left"))

  expect_true(all(unlist(result$header$styles$text$bold$data[1])))

  for (border in border_dim) {
    expect_true(all(
      result$header$styles$pars[[paste0("border.color.", border)]][[1]] ==
        "black"
    ))
    expect_true(all(
      result$body$styles$pars[[paste0("border.color.", border)]][[1]] == "black"
    ))
  }

  for (border in border_dim) {
    expect_true(all(
      result$header$styles$pars[[paste0("border.style.", border)]][[1]] ==
        "solid"
    ))
    expect_true(all(
      result$body$styles$pars[[paste0("border.style.", border)]][[1]] == "solid"
    ))
  }

  for (border in border_dim) {
    expect_true(all(
      result$header$styles$cells[[paste0("border.width.", border)]][[1]] == 1
    ))
    expect_true(all(
      result$body$styles$cells[[paste0("border.width.", border)]][[1]] == 1
    ))
  }

  expect_true(all(result$header$styles$text$font.family[[1]] == "Arial Narrow"))
  expect_true(all(result$body$styles$text$font.family[[1]] == "Arial Narrow"))

  expect_true(all(result$header$styles$text$font.size[[1]] == 10))
  expect_true(all(result$body$styles$text$font.size[[1]] == 10))

  expect_true(all(result$header$styles$pars$line_spacing[[1]] == 1))
  expect_true(all(result$body$styles$pars$line_spacing[[1]] == 1))

  expect_true(all(result$header$styles$pars$padding.top[[1]] == 1))
  expect_true(all(result$header$styles$pars$padding.bottom[[1]] == 1))
  expect_true(all(result$body$styles$pars$padding.top[[1]] == 1))
  expect_true(all(result$body$styles$pars$padding.bottom[[1]] == 1))
})

test_that("format_flextable correctly processes data_in flextable when 'table1_format' is FALSE", {
  data_in <- flextable::flextable(iris)
  result <- format_flextable(data_in, table1_format = FALSE)

  border_dim <- c("top", "left", "right", "bottom") # To simplify testing

  expect_s3_class(result, "flextable")

  expect_equal(nrow(result$header$dataset), nrow(data_in$header$dataset))
  expect_equal(nrow(result$body$dataset), nrow(data_in$body$dataset))

  expect_equal(ncol(result$header$dataset), ncol(data_in$header$dataset))
  expect_equal(ncol(result$body$dataset), ncol(data_in$body$dataset))

  expect_equal(result$properties$layout, "autofit")
  expect_equal(result$properties$width, 1)

  expect_true(all(result$header$styles$pars$text.align[[1]] == "left"))
  expect_true(all(result$body$styles$pars$text.align[[1]] == "left"))

  expect_true(all(unlist(result$header$styles$text$bold$data[1])))

  for (border in border_dim) {
    expect_true(all(
      result$header$styles$pars[[paste0("border.color.", border)]][[1]] ==
        "black"
    ))
    expect_true(all(
      result$body$styles$pars[[paste0("border.color.", border)]][[1]] == "black"
    ))
  }

  for (border in border_dim) {
    expect_true(all(
      result$header$styles$pars[[paste0("border.style.", border)]][[1]] ==
        "solid"
    ))
    expect_true(all(
      result$body$styles$pars[[paste0("border.style.", border)]][[1]] == "solid"
    ))
  }

  for (border in border_dim) {
    expect_true(all(
      result$header$styles$cells[[paste0("border.width.", border)]][[1]] == 1
    ))
    expect_true(all(
      result$body$styles$cells[[paste0("border.width.", border)]][[1]] == 1
    ))
  }

  expect_true(all(result$header$styles$text$font.family[[1]] == "Arial Narrow"))
  expect_true(all(result$body$styles$text$font.family[[1]] == "Arial Narrow"))

  expect_true(all(result$header$styles$text$font.size[[1]] == 10))
  expect_true(all(result$body$styles$text$font.size[[1]] == 10))

  expect_true(all(result$header$styles$pars$line_spacing[[1]] == 1))
  expect_true(all(result$body$styles$pars$line_spacing[[1]] == 1))

  expect_true(all(result$header$styles$pars$padding.top[[1]] == 1))
  expect_true(all(result$header$styles$pars$padding.bottom[[1]] == 1))
  expect_true(all(result$body$styles$pars$padding.top[[1]] == 1))
  expect_true(all(result$body$styles$pars$padding.bottom[[1]] == 1))
})
