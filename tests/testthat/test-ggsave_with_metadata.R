test_that("plot saving discovers the destination project and honors path", {
  paths <- local_save_fixture()
  output <- file.path(paths$project, "plot.png")

  ggsave_with_metadata(
    "plot.png",
    plot = ggplot2::ggplot(),
    path = paths$project,
    width = 1,
    height = 1,
    units = "in"
  )

  expect_identical(file.exists(output), TRUE)
  metadata <- read_saved_metadata(output)
  expect_equal(metadata$object_meta$path, "plot.png")
  expect_equal(metadata$source_meta$path, "analysis.R")
  expect_equal(
    metadata$object_meta$hash,
    digest::digest(file = output, algo = "blake3")
  )
})

test_that("plot saving prefers the destination project with relative paths", {
  paths <- local_save_fixture()
  setwd(paths$other)

  ggsave_with_metadata(
    file.path("..", "project", "plot.png"),
    plot = ggplot2::ggplot(),
    width = 1,
    height = 1,
    units = "in"
  )

  expect_equal(
    read_saved_metadata(file.path(paths$project, "plot.png"))$object_meta$path,
    "plot.png"
  )
})

test_that("plot saving finds a project before ggsave creates nested directories", {
  paths <- local_save_fixture()
  directory <- file.path(paths$project, "new", "nested")
  output <- file.path(directory, "plot.png")
  skip_if_not("create.dir" %in% names(formals(ggplot2::ggsave)))

  ggsave_with_metadata(
    "plot.png",
    plot = ggplot2::ggplot(),
    path = directory,
    create.dir = TRUE,
    width = 1,
    height = 1,
    units = "in"
  )

  expect_equal(
    read_saved_metadata(output)$object_meta$path,
    "new/nested/plot.png"
  )
})

test_that("plot saving honors explicit context roots and working-directory fallback", {
  paths <- local_save_fixture()
  context <- new_rpfy_context(
    list(platform = "test", software = list()),
    list(),
    NULL,
    "Test author",
    paths$other
  )
  output <- file.path(paths$project, "plot.png")
  ggsave_with_metadata(
    output,
    plot = ggplot2::ggplot(),
    context = context,
    width = 1,
    height = 1,
    units = "in"
  )
  expect_equal(
    read_saved_metadata(output)$object_meta$path,
    "../project/plot.png"
  )

  setwd(paths$project)
  output <- file.path(paths$outside, "plot.png")
  ggsave_with_metadata(
    output,
    plot = ggplot2::ggplot(),
    width = 1,
    height = 1,
    units = "in"
  )
  expect_equal(
    read_saved_metadata(output)$object_meta$path,
    "../outside/plot.png"
  )
})

test_that("plot overlays use the same destination as ggsave path", {
  paths <- local_save_fixture()
  output <- file.path(paths$project, "plot.png")
  config <- file.path(paths$outside, "config.yaml")
  writeLines("add_path_overlay: object", config)
  overlay_args <- NULL
  local_mocked_bindings(run_python_script = function(args, script_name) {
    overlay_args <<- args
  })

  ggsave_with_metadata(
    "plot.png",
    plot = ggplot2::ggplot(),
    path = paths$project,
    config_yaml = config,
    width = 1,
    height = 1,
    units = "in"
  )

  expect_equal(
    overlay_args[match("-i", overlay_args) + 1L],
    normalizePath(output)
  )
  expect_equal(overlay_args[match("-s", overlay_args) + 1L], "plot.png")
  expect_equal(read_saved_metadata(output)$object_meta$path, "plot.png")
})

test_that("plot saving without a project never writes or overwrites the artifact", {
  paths <- local_save_fixture()
  local_no_project()
  output <- file.path(paths$outside, "plot.png")
  error <- tryCatch(
    ggsave_with_metadata(output, plot = ggplot2::ggplot()),
    error = identity
  )
  expect_s3_class(error, "error")
  expect_match(conditionMessage(error), "Nothing was saved.", fixed = TRUE)
  expect_identical(file.exists(output), FALSE)

  writeBin(charToRaw("original"), output)
  tryCatch(
    ggsave_with_metadata(output, plot = ggplot2::ggplot()),
    error = identity
  )
  expect_identical(readBin(output, "raw", n = 8), charToRaw("original"))
  expect_identical(
    file.exists(file.path(paths$outside, "plot_png_metadata.json")),
    FALSE
  )
})
