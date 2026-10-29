test_that("RDS saving discovers the destination project outside its working directory", {
  paths <- local_save_fixture()
  output <- file.path(paths$project, "table.rds")

  save_rds_with_metadata(data.frame(value = 1), output)

  expect_identical(readRDS(output), data.frame(value = 1))
  metadata <- read_saved_metadata(output)
  expect_equal(metadata$object_meta$path, "table.rds")
  expect_equal(metadata$source_meta$path, "analysis.R")
})

test_that("RDS saving prefers the destination project and supports relative paths", {
  paths <- local_save_fixture()
  setwd(paths$other)

  save_rds_with_metadata(1, file.path("..", "project", "table.rds"))

  expect_equal(
    read_saved_metadata(file.path(paths$project, "table.rds"))$object_meta$path,
    "table.rds"
  )
})

test_that("RDS saving falls back to the working directory for external output", {
  paths <- local_save_fixture()
  setwd(paths$project)
  output <- file.path(paths$outside, "table.rds")

  save_rds_with_metadata(1, output)

  expect_equal(
    read_saved_metadata(output)$object_meta$path,
    "../outside/table.rds"
  )
})

test_that("RDS saving preserves explicit context roots and unresolved origins", {
  paths <- local_save_fixture()
  context <- new_rpfy_context(
    list(platform = "test", software = list()),
    list(),
    list(study = "example"),
    "Test author",
    paths$other
  )
  output <- file.path(paths$project, "table.rds")
  save_rds_with_metadata(1, output, context = context)
  metadata <- read_saved_metadata(output)
  expect_equal(metadata$object_meta$path, "../project/table.rds")
  expect_equal(metadata$source_meta$type, "unresolved")
  expect_equal(metadata$addl_meta$study, "example")

  context["project_root"] <- list(NULL)
  save_rds_with_metadata(2, output, context = context)
  expect_equal(read_saved_metadata(output)$object_meta$path, "table.rds")
  expect_null(context$project_root)
})

test_that("RDS saving without a project never writes or overwrites the artifact", {
  paths <- local_save_fixture()
  local_no_project()
  output <- file.path(paths$outside, "table.rds")
  error <- tryCatch(save_rds_with_metadata(1, output), error = identity)
  expect_s3_class(error, "error")
  expect_match(conditionMessage(error), "Nothing was saved.", fixed = TRUE)
  expect_match(
    conditionMessage(error),
    "initialize_report_project()",
    fixed = TRUE
  )
  expect_identical(file.exists(output), FALSE)

  saveRDS("original", output)
  tryCatch(save_rds_with_metadata(2, output), error = identity)
  expect_identical(readRDS(output), "original")
  expect_identical(
    file.exists(file.path(paths$outside, "table_rds_metadata.json")),
    FALSE
  )
})
