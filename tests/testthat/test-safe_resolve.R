test_that("safe_resolve resolves a simple filename", {
  dir <- withr::local_tempdir()
  file.create(file.path(dir, "table.csv"))

  result <- safe_resolve(dir, "table.csv")
  expect_equal(result, normalizePath(file.path(dir, "table.csv"), mustWork = FALSE))
})

test_that("safe_resolve resolves a subdirectory path", {
  dir <- withr::local_tempdir()
  sub <- file.path(dir, "sub")
  dir.create(sub)
  file.create(file.path(sub, "fig.png"))

  result <- safe_resolve(dir, file.path("sub", "fig.png"))
  expect_equal(result, normalizePath(file.path(sub, "fig.png"), mustWork = FALSE))
})

test_that("safe_resolve blocks traversal outside boundary", {
  dir <- withr::local_tempdir()

  expect_error(
    safe_resolve(dir, "../../etc/passwd"),
    "resolves outside"
  )
})

test_that("safe_resolve treats absolute relative_path as relative", {
  # Unlike Python's os.path.join, R's file.path concatenates rather than

  # replacing, so "/etc/passwd" resolves inside the boundary as "etc/passwd".
  dir <- withr::local_tempdir()

  result <- safe_resolve(dir, "/etc/passwd")
  expect_true(startsWith(result, normalizePath(dir, mustWork = TRUE)))
})

test_that("safe_resolve resolves boundary itself without error", {
  dir <- withr::local_tempdir()

  result <- safe_resolve(dir, ".")
  expect_equal(result, normalizePath(dir, mustWork = TRUE))
})
