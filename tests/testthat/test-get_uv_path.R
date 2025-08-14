test_that("get_uv_path returns ~/.local/bin/uv if it exists", {
  home_tmp <- tempdir()
  withr::local_envvar(c(HOME = home_tmp, PATH = ""))  # isolate from system uv
  local_path <- file.path(home_tmp, ".local", "bin", "uv")
  dir.create(dirname(local_path), recursive = TRUE, showWarnings = FALSE)
  file.create(local_path)

  result <- get_uv_path(quiet = FALSE)

  expect_equal(result, normalizePath(local_path))
})

test_that("get_uv_path returns ~/.cargo/bin/uv if ~/.local/bin/uv does not exist", {
  home_tmp <- tempdir()
  withr::local_envvar(c(HOME = home_tmp, PATH = ""))  # isolate from system uv
  local_path <- file.path(home_tmp, ".local", "bin", "uv")
  cargo_path <- file.path(home_tmp, ".cargo", "bin", "uv")

  unlink(local_path, force = TRUE)
  dir.create(dirname(cargo_path), recursive = TRUE, showWarnings = FALSE)
  file.create(cargo_path)

  result <- get_uv_path(quiet = FALSE)

  expect_equal(result, normalizePath(cargo_path))
})

test_that("get_uv_path handles the quiet flag correctly when uv is absent", {
  home_tmp <- withr::local_tempdir()
  withr::local_envvar(c(
    HOME = home_tmp,                # new empty HOME
    PATH = "",                      # prevent Sys.which from finding real uv
    UV_PATH = ""                    # ensure no explicit override
  ))

  # Ensure no uv files exist
  local_path <- file.path(home_tmp, ".local", "bin", "uv")
  cargo_path <- file.path(home_tmp, ".cargo", "bin", "uv")
  unlink(local_path, force = TRUE)
  unlink(cargo_path, force = TRUE)

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
  withr::local_envvar(c(
    HOME = home_tmp,               # new empty HOME
    PATH = "",                     # prevent Sys.which from finding real uv
    UV_PATH = ""                   # ensure no explicit override
  ))

  # Ensure no uv files exist
  local_path <- file.path(home_tmp, ".local", "bin", "uv")
  cargo_path <- file.path(home_tmp, ".cargo", "bin", "uv")
  unlink(local_path, force = TRUE)
  unlink(cargo_path, force = TRUE)

  expect_false(file.exists(local_path))
  expect_false(file.exists(cargo_path))
  expect_null(get_uv_path(quiet = FALSE))
})
