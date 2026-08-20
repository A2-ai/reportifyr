test_that("py_log_callback filters the console by verbosity", {
  cb <- py_log_callback(log_file = NULL, no_log = TRUE, verbosity = "WARN")

  expect_silent(cb("2026-08-19 17:32:45 [py] [DEBUG] skipping a file", NULL))
  expect_silent(cb("2026-08-19 17:32:45 [py] [INFO] doing a thing", NULL))
  expect_output(
    cb("2026-08-19 17:32:46 [py] [WARNING] real warning", NULL),
    "real warning",
    fixed = TRUE
  )
  expect_output(
    cb("2026-08-19 17:32:47 [py] [ERROR] boom", NULL),
    "boom",
    fixed = TRUE
  )
})

test_that("an untagged line follows the last tagged line's visibility", {
  cb <- py_log_callback(log_file = NULL, no_log = TRUE, verbosity = "WARN")

  # A traceback body under an ERROR header must stay visible.
  expect_output(cb("[py] [ERROR] boom", NULL), "boom", fixed = TRUE)
  expect_output(
    cb("Traceback (most recent call last):", NULL),
    "Traceback",
    fixed = TRUE
  )

  # The same untagged shape under a filtered DEBUG line must stay hidden.
  expect_silent(cb("[py] [DEBUG] quiet", NULL))
  expect_silent(cb("  File \"cli.py\", line 1", NULL))
})

test_that("py_log_callback writes every level to the log file", {
  log_file <- withr::local_tempfile()
  cb <- py_log_callback(log_file = log_file, no_log = FALSE, verbosity = "WARN")

  capture.output(
    for (line in c("[py] [DEBUG] one", "[py] [WARNING] two")) cb(line, NULL)
  )

  # Console filtering must not reach the file: DEBUG is suppressed above but
  # still recorded here.
  expect_identical(readLines(log_file), c("[py] [DEBUG] one", "[py] [WARNING] two"))
})

test_that("py_log_callback honors no_log and skips blank lines", {
  log_file <- withr::local_tempfile()
  cb <- py_log_callback(log_file = log_file, no_log = TRUE, verbosity = "DEBUG")
  capture.output(cb("[py] [DEBUG] one", NULL))
  expect_false(file.exists(log_file))

  log_file2 <- withr::local_tempfile()
  cb2 <- py_log_callback(log_file2, no_log = FALSE, verbosity = "DEBUG")
  expect_silent(cb2("   ", NULL))
  expect_false(file.exists(log_file2))
})

test_that("an invalid verbosity falls back to WARN", {
  cb <- py_log_callback(log_file = NULL, no_log = TRUE, verbosity = "LOUD")

  expect_silent(cb("[py] [DEBUG] quiet", NULL))
  expect_output(cb("[py] [WARNING] loud", NULL), "loud", fixed = TRUE)
})
