#' Synchronizes report project with the bundled pyro Python
#' environment and reconciles the report `config.yaml` against the
#' `.<report>_init.json` snapshot. Always runs
#' `pyro::initialize_python(groups = "reportifyr")`; prompts the
#' user only when the project `.venv` is missing, otherwise runs
#' non-interactively (a no-op when uv reports no work needed).
#'
#' @param project_dir The file path to the main project directory
#' where the directory structure will be created.
#' The directory must already exist; otherwise, an error will be thrown.
#' @param report_dir_name The directory name for where reports will be saved.
#' Default is `NULL`. If `NULL`, `report` will be used.
#'
#' @export
#'
#' @examples \dontrun{
#' sync_report_project(here::here())
#' }
sync_report_project <- function(project_dir, report_dir_name = NULL) {
  log4r::debug(.le$logger, "Starting sync_report_project function")

  # read in init.json files
  if (!is.null(report_dir_name)) {
    path_name <- sub("/", "_", report_dir_name)
    report_dir <- file.path(project_dir, report_dir_name)
  } else {
    path_name <- "report"
    report_dir <- file.path(project_dir, "report")
  }
  init_file <- file.path(project_dir, paste0(".", path_name, "_init.json"))
  log4r::debug(
    .le$logger,
    paste0("Using ", init_file, " as project initialization file.")
  )

  if (!file.exists(init_file)) {
    log4r::debug(.le$logger, paste0(init_file, " does not exist."))
    stop(
      paste(init_file, "file does not exist. "),
      "Are you sure you supplied the correct report_dir_name?"
    )
  }

  log4r::debug(.le$logger, paste0(init_file, " exists and being read now"))
  init <- jsonlite::read_json(init_file, simplifyVector = TRUE)
  # bool for later use
  update_init_file <- FALSE

  log4r::debug(.le$logger, "Calling pyro::initialize_python")
  pyro::write_group_to_pyproject("reportifyr")
  venv_path <- file.path(getOption("venv_dir") %||% project_dir, ".venv")
  if (dir.exists(venv_path)) {
    pyro::initialize_python(continue = "Y", groups = "reportifyr")
  } else {
    message("Python virtual environment missing. Reinitializing...")
    pyro::initialize_python(groups = "reportifyr")
  }

  # Check config
  log4r::debug(.le$logger, "getting config path now")
  config_path <- file.path(report_dir, "config.yaml")
  log4r::debug(.le$logger, paste0("using config path: ", config_path))

  config <- yaml::read_yaml(
    config_path,
    handlers = list(logical = yaml::verbatim_logical)
  )
  log4r::debug(.le$logger, paste0("Read in config successfully"))

  if (!identical(config, init$config)) {
    log4r::debug(.le$logger, "init file and config file out of sync.")
    message(
      paste0(
        "Configuration has changed, updating ",
        init_file
      )
    )
    if (config$report_dir_name != init$config$report_dir_name) {
      warning(
        paste0(
          "report_dir_name has been changed in config.yaml. \n",
          "  Please reconcile names\n",
          "\told: ",
          init$config$report_dir_name,
          "\n",
          "\tnew: ",
          config$report_dir_name
        )
      )
      config$report_dir_name <- init$config$report_dir_name
    }

    if (config$outputs_dir_name != init$config$outputs_dir_name) {
      warning(
        paste0(
          "outputs_dir_name has been changed in config.yaml. \n",
          "  Please reconcile names \n",
          "\told: ",
          init$config$outputs_dir_name,
          "\n",
          "\tnew: ",
          config$outputs_dir_name
        )
      )
      config$outputs_dir_name <- init$config$outputs_dir_name
    }
    update_init_file <- TRUE
  }

  if (update_init_file) {
    log4r::debug(.le$logger, "Updating init file now")
    message("Updated")
    init$last_modified <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
    init$user <- Sys.info()[["user"]]
    init$config <- config

    json_data <- jsonlite::toJSON(init, pretty = TRUE, auto_unbox = TRUE)
    write(json_data, file = init_file)
  } else {
    message("Nothing to do")
  }
}
