mock_pyv <- list(
  versions = c(
    "0.1.0", ".", "1.1.2", "6.0.2", "11.1.0", "0.7.8", "3.13.2"
  ),
  package_names = c(
    "fyrstartr.version",
    "venv_dir",
    "python-docx.version",
    "pyyaml.version",
    "pillow.version",
    "uv.version",
    "python.version"
  )
)

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

test_that("init file python_versions carries the 7-key canonical schema", {
  dirs <- make_test_project()
  on.exit(unlink(dirs$project_dir, recursive = TRUE))

  mockery::stub(
    create_init_file, "build_python_version_data",
    function(project_dir) mock_pyv
  )

  create_init_file(dirs$project_dir, dirs$report_dir, dirs$outputs_dir)

  init_file <- file.path(dirs$project_dir, ".report_init.json")
  expect_true(file.exists(init_file))

  init <- jsonlite::read_json(init_file)
  nms <- names(init$python_versions)
  expect_equal(nms[1], "fyrstartr.version")
  expect_equal(nms[2], "venv_dir")
  expect_equal(length(init$python_versions), 7L)
  expect_equal(init$python_versions$venv_dir, ".")
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

  mockery::stub(
    create_init_file, "build_python_version_data",
    function(project_dir) mock_pyv
  )

  create_init_file(dirs$project_dir, custom_report, dirs$outputs_dir)

  expected_file <- file.path(dirs$project_dir, ".custom_reports_init.json")
  expect_true(file.exists(expected_file))
})

test_that("init file contains required structure", {
  dirs <- make_test_project()
  on.exit(unlink(dirs$project_dir, recursive = TRUE))

  mockery::stub(
    create_init_file, "build_python_version_data",
    function(project_dir) mock_pyv
  )

  create_init_file(dirs$project_dir, dirs$report_dir, dirs$outputs_dir)

  init_file <- file.path(dirs$project_dir, ".report_init.json")
  init <- jsonlite::read_json(init_file)

  expect_true("creation_timestamp" %in% names(init))
  expect_true("last_modified" %in% names(init))
  expect_true("user" %in% names(init))
  expect_true("config" %in% names(init))
  expect_true("python_versions" %in% names(init))
  expect_equal(init$config$report_dir_name, "report")
  expect_equal(init$config$outputs_dir_name, "OUTPUTS")
})
