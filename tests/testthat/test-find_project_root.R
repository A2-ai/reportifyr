test_that("finds root when init file is in start_path", {
  tmp <- tempfile()
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE))

  writeLines("{}", file.path(tmp, ".report_init.json"))

  result <- find_project_root(start_path = tmp)
  expect_equal(normalizePath(result), normalizePath(tmp))
})

test_that("walks upward to find init file in ancestor", {
  tmp <- tempfile()
  nested <- file.path(tmp, "a", "b", "c")
  dir.create(nested, recursive = TRUE)
  on.exit(unlink(tmp, recursive = TRUE))

  writeLines("{}", file.path(tmp, ".report_init.json"))

  result <- find_project_root(start_path = nested)
  expect_equal(normalizePath(result), normalizePath(tmp))
})

test_that("returns NULL when no init file exists", {
  tmp <- tempfile()
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE))

  # Search from a bare directory with no init files anywhere nearby.
  # Use tmp itself as start — the traversal will hit filesystem root
  # without finding an init file (unless the test machine has one,
  # which is unlikely inside a random tempdir).
  result <- find_project_root(start_path = tmp)
  expect_null(result)
})

test_that("finds custom-named init files", {
  tmp <- tempfile()
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE))

  # Simulates report_dir_name = "sub/report" -> .sub_report_init.json
  writeLines("{}", file.path(tmp, ".sub_report_init.json"))

  result <- find_project_root(start_path = tmp)
  expect_equal(normalizePath(result), normalizePath(tmp))
})
