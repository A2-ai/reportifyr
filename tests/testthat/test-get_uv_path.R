test_that("get_uv_path returns ~/.local/bin/uv if it exists", {
  withr::local_envvar(c(HOME = tempdir()))
  local_path <- normalizePath("~/.local/bin/uv", mustWork = FALSE)
  dir.create(dirname(local_path), recursive = TRUE, showWarnings = FALSE)
  file.create(local_path)

  result <- get_uv_path()

  expect_equal(result, local_path)
})

test_that("get_uv_path returns ~/.cargo/bin/uv if ~/.local/bin/uv does not exist", {
  withr::local_envvar(c(HOME = tempdir()))
  local_path <- normalizePath("~/.local/bin/uv", mustWork = FALSE)
  cargo_path <- normalizePath("~/.cargo/bin/uv", mustWork = FALSE)

  unlink(local_path, force = TRUE)
  dir.create(dirname(cargo_path), recursive = TRUE, showWarnings = FALSE)
  file.create(cargo_path)

  result <- get_uv_path()

  expect_equal(result, cargo_path)
})
