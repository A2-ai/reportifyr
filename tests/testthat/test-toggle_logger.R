test_that("toggle_logger sets default log level to WARN when RPFY_VERBOSE is unset", {
  withr::local_envvar(c(RPFY_VERBOSE = NA)) # Unset the env var
  toggle_logger(quiet = TRUE)
  logger <- get("logger", envir = .le)
  level_name <- as.character(log4r::level(logger))
  expect_s3_class(logger, "logger")
  expect_equal(level_name, "DEBUG")
})

test_that("toggle_logger sets the correct log level from RPFY_VERBOSE", {
  withr::local_envvar(c(RPFY_VERBOSE = "INFO"))
  toggle_logger(quiet = TRUE)
  logger <- get("logger", envir = .le)
  level_name <- as.character(log4r::level(logger))
  expect_equal(level_name, "DEBUG")
})

test_that("toggle_logger does not error on invalid verbosity", {
  withr::local_envvar(c(RPFY_VERBOSE = "LOUD"))
  expect_output(
    toggle_logger(quiet = TRUE),
    "Invalid verbosity level. Available options are:"
  )
})

test_that("toggle_logger emits a message unless quiet = TRUE", {
  withr::local_envvar(c(RPFY_VERBOSE = "ERROR"))
  expect_message(toggle_logger(quiet = FALSE), "Console logging at ERROR level")
})
