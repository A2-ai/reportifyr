local_save_fixture <- function(.local_envir = parent.frame()) {
  sandbox <- withr::local_tempdir(.local_envir = .local_envir)
  project <- file.path(sandbox, "project")
  outside <- file.path(sandbox, "outside")
  other <- file.path(sandbox, "other-project")
  for (directory in c(project, outside, other)) {
    dir.create(directory)
  }
  writeLines("{}", file.path(project, ".report_init.json"))
  writeLines("{}", file.path(other, ".custom_init.json"))
  withr::local_dir(outside, .local_envir = .local_envir)
  testthat::local_mocked_bindings(
    get_packages = function() list(),
    get_git_config_author = function() "Test author",
    detect_script_source_meta = function(project_root) {
      script_source(
        path = as.character(fs::path_rel(
          file.path(project_root, "analysis.R"),
          project_root
        )),
        creation_author = "Test author",
        latest_author = "Test author",
        creation_time = "2026-01-01",
        latest_time = "2026-01-01"
      )
    },
    save_rtf = function(...) invisible(NULL),
    .env = .local_envir
  )
  list(project = project, outside = outside, other = other)
}

read_saved_metadata <- function(file) {
  jsonlite::fromJSON(paste0(
    tools::file_path_sans_ext(file),
    "_",
    tools::file_ext(file),
    "_metadata.json"
  ))
}

local_no_project <- function(.local_envir = parent.frame()) {
  testthat::local_mocked_bindings(
    find_project_root = function(start_path = getwd()) NULL,
    .env = .local_envir
  )
}
