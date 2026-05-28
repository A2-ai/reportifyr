## Helper: scaffold a minimal project structure for create_init_file
make_test_project <- function() {
  project_dir <- tempfile()
  report_dir <- file.path(project_dir, "report")
  outputs_dir <- file.path(project_dir, "OUTPUTS")
  dir.create(report_dir, recursive = TRUE)
  dir.create(outputs_dir, recursive = TRUE)

  # Minimal config.yaml
  yaml::write_yaml(
    list(
      report_dir_name = "report",
      outputs_dir_name = "OUTPUTS"
    ),
    file.path(report_dir, "config.yaml")
  )

  list(
    project_dir = project_dir,
    report_dir = report_dir,
    outputs_dir = outputs_dir
  )
}

test_that("init file records venv_dir relative to project_dir", {
  dirs <- make_test_project()
  on.exit(unlink(dirs$project_dir, recursive = TRUE))

  withr::local_options(list(venv_dir = dirs$project_dir))
  create_init_file(dirs$project_dir, dirs$report_dir, dirs$outputs_dir)

  init_file <- file.path(dirs$project_dir, ".report_init.json")
  expect_true(file.exists(init_file))

  init <- jsonlite::read_json(init_file)
  expect_equal(init$venv_dir, ".")
  expect_false("python_versions" %in% names(init))
})

test_that("init file is named correctly for custom report_dir_name", {
  dirs <- make_test_project()
  on.exit(unlink(dirs$project_dir, recursive = TRUE))

  custom_report <- file.path(dirs$project_dir, "custom_reports")
  dir.create(custom_report, recursive = TRUE)
  file.copy(
    file.path(dirs$report_dir, "config.yaml"),
    file.path(custom_report, "config.yaml")
  )

  withr::local_options(list(venv_dir = dirs$project_dir))
  create_init_file(dirs$project_dir, custom_report, dirs$outputs_dir)

  expected_file <- file.path(
    dirs$project_dir, ".custom_reports_init.json"
  )
  expect_true(file.exists(expected_file))
})

test_that("init file contains required structure", {
  dirs <- make_test_project()
  on.exit(unlink(dirs$project_dir, recursive = TRUE))

  withr::local_options(list(venv_dir = dirs$project_dir))
  create_init_file(dirs$project_dir, dirs$report_dir, dirs$outputs_dir)

  init_file <- file.path(dirs$project_dir, ".report_init.json")
  init <- jsonlite::read_json(init_file)

  expect_true("creation_timestamp" %in% names(init))
  expect_true("last_modified" %in% names(init))
  expect_true("user" %in% names(init))
  expect_true("config" %in% names(init))
  expect_true("venv_dir" %in% names(init))
  expect_equal(init$config$report_dir_name, "report")
  expect_equal(init$config$outputs_dir_name, "OUTPUTS")
})
