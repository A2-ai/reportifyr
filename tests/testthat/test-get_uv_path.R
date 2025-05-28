test_that("get_uv_path returns ~/.local/bin/uv if it exists", {
  withr::local_envvar(c(HOME = tempdir()))
  local_path <- normalizePath("~/.local/bin/uv", mustWork = FALSE)
  dir.create(dirname(local_path), recursive = TRUE, showWarnings = FALSE)
  file.create(local_path)

  result <- get_uv_path(quiet = FALSE)

  expect_equal(result, local_path)
})

test_that("get_uv_path returns ~/.cargo/bin/uv if ~/.local/bin/uv does not exist", {
  withr::local_envvar(c(HOME = tempdir()))
  local_path <- normalizePath("~/.local/bin/uv", mustWork = FALSE)
  cargo_path <- normalizePath("~/.cargo/bin/uv", mustWork = FALSE)

  unlink(local_path, force = TRUE)
  dir.create(dirname(cargo_path), recursive = TRUE, showWarnings = FALSE)
  file.create(cargo_path)

  result <- get_uv_path(quiet = FALSE)

  expect_equal(result, cargo_path)
})

test_that("get_uv_path handles the quiet flag correctly when uv is absent", {
  withr::local_envvar(c(HOME = withr::local_tempdir()))

  warn_stub_false <- mockery::mock(NULL)
  mockery::stub(get_uv_path, "log4r::warn", warn_stub_false)

  expect_null(get_uv_path(quiet = FALSE))
  mockery::expect_called(warn_stub_false, 1)

  warn_stub_true <- mockery::mock(NULL)
  mockery::stub(get_uv_path, "log4r::warn", warn_stub_true)

  expect_null(get_uv_path(quiet = TRUE))
  mockery::expect_called(warn_stub_true, 0)
})

test_that("get_uv_path returns NULL when no uv binary is present", {
  home_tmp <- withr::local_tempdir()
  withr::local_envvar(c(HOME = home_tmp))

  expect_false(file.exists(file.path(home_tmp, ".local/bin/uv")))
  expect_false(file.exists(file.path(home_tmp, ".cargo/bin/uv")))
  expect_null(get_uv_path(quiet = FALSE))
})
