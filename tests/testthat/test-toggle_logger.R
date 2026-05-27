# The logger is always built at DEBUG (file logging captures everything);
# RPFY_VERBOSE controls only what reaches the console via the filtered
# console appender. These tests assert on console output, not on
# log4r::level(logger), which would be "DEBUG" regardless of RPFY_VERBOSE.

test_that("console defaults to WARN threshold when RPFY_VERBOSE is unset", {
  withr::local_envvar(c(RPFY_VERBOSE = NA)) # Unset the env var
  toggle_logger(quiet = TRUE, log_file = NULL)
  logger <- get("logger", envir = .le)
  expect_s3_class(logger, "logger")
  # Below the WARN threshold: nothing reaches the console
  expect_output(log4r::info(logger, "info-hidden"), NA)
  # At/above the WARN threshold: message reaches the console
  expect_output(log4r::warn(logger, "warn-shown"), "warn-shown")
})

test_that("RPFY_VERBOSE controls the console verbosity threshold", {
  withr::local_envvar(c(RPFY_VERBOSE = "INFO"))
  toggle_logger(quiet = TRUE, log_file = NULL)
  logger <- get("logger", envir = .le)
  # Below the INFO threshold: DEBUG is suppressed
  expect_output(log4r::debug(logger, "debug-hidden"), NA)
  # At/above the INFO threshold: INFO now reaches the console
  expect_output(log4r::info(logger, "info-shown"), "info-shown")
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

test_that("lazy file logger recreates missing log directory", {
  withr::local_envvar(c(RPFY_VERBOSE = NA))
  withr::local_options(list(rpfy.no_log = FALSE))
  log_dir <- file.path(withr::local_tempdir(), ".rpfy-logs")
  log_file <- file.path(log_dir, "lazy-rpfy.log")

  toggle_logger(quiet = TRUE, log_file = log_file, lazy_file = TRUE)
  logger <- get("logger", envir = .le)
  log4r::debug(logger, "before deleting log directory")
  unlink(log_dir, recursive = TRUE)

  expect_silent(log4r::debug(logger, "after deleting log directory"))
  expect_true(dir.exists(log_dir))
  expect_true(file.exists(log_file))
  expect_true(any(grepl("after deleting log directory", readLines(log_file))))
})

test_that("eager file logger recreates missing log directory", {
  withr::local_envvar(c(RPFY_VERBOSE = NA))
  log_dir <- file.path(withr::local_tempdir(), ".rpfy-logs")
  log_file <- file.path(log_dir, "eager-rpfy.log")

  toggle_logger(quiet = TRUE, log_file = log_file, lazy_file = FALSE)
  logger <- get("logger", envir = .le)
  unlink(log_dir, recursive = TRUE)

  expect_silent(log4r::debug(logger, "after deleting eager log directory"))
  expect_true(dir.exists(log_dir))
  expect_true(file.exists(log_file))
  expect_true(any(grepl(
    "after deleting eager log directory",
    readLines(log_file)
  )))
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
