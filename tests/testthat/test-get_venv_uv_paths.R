test_that("get_venv_uv_path sets venv_dir if unset", {
  withr::local_options(list(venv_dir = NULL))

  temp_dir <- tempfile()
  dir.create(file.path(temp_dir, ".venv"), recursive = TRUE)

  mockery::stub(get_venv_uv_paths, "here::here", temp_dir)

  mockery::stub(get_venv_uv_paths, "get_uv_path", function() "~/.local/bin/uv")

  mockery::stub(get_venv_uv_paths, "log4r::info", function(...) invisible(NULL))

  expect_message(
    {
      result <- get_venv_uv_paths()
    },
    "Setting options\\('venv_dir'\\) to project root"
  )

  expect_equal(getOption("venv_dir"), temp_dir)
})

test_that("get_venv_uv_path throws error when .venv directory is missing", {
  temp_dir <- tempfile()
  withr::local_options(list(venv_dir = temp_dir))

  unlink(file.path(temp_dir, ".venv"), recursive = TRUE, force = TRUE)

  mockery::stub(
    get_venv_uv_paths,
    "log4r::error",
    function(...) invisible(NULL)
  )

  expect_error(
    get_venv_uv_paths(),
    "Create virtual environment with initialize_python"
  )
})

test_that("get_venv_uv_path throws error when uv path is NULL", {
  temp_dir <- tempfile()
  venv_path <- file.path(temp_dir, ".venv")
  dir.create(venv_path, recursive = TRUE)

  withr::local_options(list(venv_dir = temp_dir))

  mockery::stub(get_venv_uv_paths, "get_uv_path", function() NULL)

  mockery::stub(
    get_venv_uv_paths,
    "log4r::error",
    function(...) invisible(NULL)
  )

  expect_error(
    get_venv_uv_paths(),
    "Please install uv with initialize_python"
  )
})

test_that("get_venv_uv_path returns correct paths", {
  temp_dir <- tempfile()
  venv_path <- file.path(temp_dir, ".venv")
  dir.create(venv_path, recursive = TRUE)

  withr::local_options(list(venv_dir = temp_dir))

  mockery::stub(get_venv_uv_paths, "get_uv_path", function() "~/.local/bin/uv")

  result <- get_venv_uv_paths()
  expect_type(result, "list")
  expect_equal(result$uv, "~/.local/bin/uv")
  expect_equal(result$venv, venv_path)
})
