test_that("safe_resolve resolves a simple filename", {
  dir <- withr::local_tempdir()
  file.create(file.path(dir, "table.csv"))

  result <- safe_resolve(dir, "table.csv")
  boundary <- as.character(fs::path_norm(
    normalizePath(dir, mustWork = TRUE)
  ))
  expect_equal(result, file.path(boundary, "table.csv"))
})

test_that("safe_resolve resolves a subdirectory path", {
  dir <- withr::local_tempdir()
  sub <- file.path(dir, "sub")
  dir.create(sub)
  file.create(file.path(sub, "fig.png"))

  result <- safe_resolve(dir, file.path("sub", "fig.png"))
  boundary <- as.character(fs::path_norm(
    normalizePath(dir, mustWork = TRUE)
  ))
  expect_equal(result, file.path(boundary, "sub", "fig.png"))
})

test_that("safe_resolve blocks traversal outside boundary", {
  dir <- withr::local_tempdir()

  expect_error(
    safe_resolve(dir, "../../etc/passwd"),
    "resolves outside"
  )
})

test_that("safe_resolve resolves boundary itself without error", {
  dir <- withr::local_tempdir()

  result <- safe_resolve(dir, ".")
  expected <- as.character(fs::path_norm(
    normalizePath(dir, mustWork = TRUE)
  ))
  expect_equal(result, expected)
})
