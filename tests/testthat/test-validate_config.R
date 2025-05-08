make_config_file <- function(config_list) {
  path <- tempfile(fileext = ".yaml")  # use tempfile directly
  writeLines(yaml::as.yaml(config_list), path)
  withr::defer(unlink(path), envir = parent.frame())  # ensures cleanup
  path
}

test_that("validate_config returns TRUE for valid config ", {
  config <- list(
    footnotes_font = "Arial",
    footnotes_font_size = 10,
    use_object_path_as_source = TRUE,
    `wrap_path_in_[]` = FALSE,
    footnote_order = c("Object", "Source"),
    save_table_rtf = TRUE,
    fig_alignment = c("center", "right"),
    use_artifact_size = TRUE,
    default_fig_width = 6.5,
    use_embedded_dimensions = FALSE,
    label_multi_figures = TRUE,
    strict = FALSE
  )
  config_path <- make_config_file(config)

  expect_true(validate_config(config_path))
})

test_that("validate_config returns FALSE for invalid footnotes_font", {
  config <- list(footnotes_font = 123L)
  config_path <- make_config_file(config)

  expect_false(validate_config(config_path))
})

test_that("validate_config returns FALSE for invalid footnotes_font_size", {
  config <- list(footnotes_font_size = "big")
  config_path <- make_config_file(config)

  expect_false(validate_config(config_path))
})

test_that("validate_config returns FALSE for invalid wrap_path_in_[]", {
  config <- list(`wrap_path_in_[]` = "nope")
  config_path <- make_config_file(config)

  expect_false(validate_config(config_path))
})

test_that("validate_config returns FALSE for invalid footnote_order value", {
  config <- list(footnote_order = c("Source", "Aliens"))
  config_path <- make_config_file(config)

  expect_false(validate_config(config_path))
})

test_that("validate_config returns FALSE for invalid fig_alignment value", {
  config <- list(fig_alignment = c("diagonal"))
  config_path <- make_config_file(config)

  expect_false(validate_config(config_path))
})

test_that("validate_config returns FALSE for invalid default_fig_width", {
  config <- list(default_fig_width = "wide")
  config_path <- make_config_file(config)

  expect_false(validate_config(config_path))
})

test_that("validate_config returns FALSE for multiple invalid fields", {
  config <- list(
    footnotes_font = 1,
    use_object_path_as_source = "no",
    label_multi_figures = "maybe",
    fig_alignment = "middle"
  )
  config_path <- make_config_file(config)

  expect_false(validate_config(config_path))
})
