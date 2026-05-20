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

test_that("prune_rpfy_logs is a no-op when log_dir does not exist", {
  tmp <- withr::local_tempdir()
  missing_dir <- file.path(tmp, "nope")
  expect_silent(prune_rpfy_logs(missing_dir))
  expect_false(dir.exists(missing_dir))
})

test_that("prune_rpfy_logs is a no-op when directory has no matching files", {
  log_dir <- withr::local_tempdir()
  expect_silent(prune_rpfy_logs(log_dir))
  expect_equal(length(list.files(log_dir)), 0)
})

test_that("prune_rpfy_logs deletes files older than max_age_days", {
  log_dir <- withr::local_tempdir()
  old <- file.path(log_dir, "2020-01-01-00-00-00-rpfy.log")
  file.create(old)
  Sys.setFileTime(old, Sys.time() - (40 * 86400))

  prune_rpfy_logs(log_dir, max_age_days = 30)

  expect_false(file.exists(old))
})

test_that("prune_rpfy_logs keeps files newer than max_age_days", {
  log_dir <- withr::local_tempdir()
  fresh <- file.path(log_dir, "2026-01-01-00-00-00-rpfy.log")
  file.create(fresh)
  Sys.setFileTime(fresh, Sys.time() - (5 * 86400))

  prune_rpfy_logs(log_dir, max_age_days = 30)

  expect_true(file.exists(fresh))
})

test_that("prune_rpfy_logs trims oldest excess when over max_files", {
  log_dir <- withr::local_tempdir()
  now <- Sys.time()
  files <- file.path(
    log_dir,
    sprintf("session-%02d-rpfy.log", 1:5)
  )
  for (i in seq_along(files)) {
    file.create(files[i])
    Sys.setFileTime(files[i], now - ((6 - i) * 60))
  }

  prune_rpfy_logs(log_dir, max_age_days = 30, max_files = 3)

  survivors <- list.files(log_dir, full.names = TRUE)
  expect_equal(length(survivors), 3)
  expect_true(all(files[3:5] %in% survivors))
  expect_false(any(files[1:2] %in% survivors))
})

test_that("prune_rpfy_logs ignores files that don't match the log glob", {
  log_dir <- withr::local_tempdir()
  keeper <- file.path(log_dir, "README.md")
  other <- file.path(log_dir, "notes.txt")
  old_log <- file.path(log_dir, "2020-01-01-00-00-00-rpfy.log")
  file.create(c(keeper, other, old_log))
  Sys.setFileTime(keeper, Sys.time() - (40 * 86400))
  Sys.setFileTime(other, Sys.time() - (40 * 86400))
  Sys.setFileTime(old_log, Sys.time() - (40 * 86400))

  prune_rpfy_logs(log_dir, max_age_days = 30)

  expect_true(file.exists(keeper))
  expect_true(file.exists(other))
  expect_false(file.exists(old_log))
})
