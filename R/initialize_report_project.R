#' Create report directories within a project
#'
#' @param project_dir The file path to the main project directory
#' where the directory structure will be created.
#' The directory must already exist; otherwise, an error will be thrown.
#' @param report_dir_name The directory name for where reports will be saved,
#' default NULL will use "report"
#' @param outputs_dir_name The directory name for where artifacts will be saved,
#' default NULL will use "OUTPUTS"
#'
#' @export
#'
#' @examples \dontrun{
#' initialize_report_project(project_dir = tempdir())
#' }
initialize_report_project <- function(
  project_dir,
  report_dir_name = NULL,
  outputs_dir_name = NULL
) {
  log4r::debug(.le$logger, "Starting initialize_report_project function")

  if (!dir.exists(project_dir)) {
    log4r::error(
      .le$logger,
      paste0("The directory does not exist: ", project_dir)
    )
    stop("The directory does not exist")
  }
  log4r::info(.le$logger, paste0("Project directory found: ", project_dir))

  # check if reportifyr has been initialized
  if (is.null(report_dir_name)) {
    init_file <- ".report_init.json"
  } else {
    path_name <- sub("/", "_", report_dir_name)
    init_file <- paste0(".", path_name, "_init.json")
  }
  log4r::debug(.le$logger, paste("Checking for", init_file))

  if (!file.exists(file.path(project_dir, init_file))) {
    # create report directory tree
    report_dir <- create_report_directories(project_dir, report_dir_name)

    # Create artifact output directory tree
    outputs_dir <- create_outputs_directories(project_dir, outputs_dir_name)

    metadata_path <- initialize_python()

    if (file.exists(metadata_path)) {
      file.copy(
        from = metadata_path,
        to = file.path(report_dir, basename(metadata_path)),
        overwrite = TRUE
      )
    }

    copy_footnotes(report_dir)
    copy_config(report_dir, report_dir_name, outputs_dir_name)
    create_init_file(project_dir, report_dir, outputs_dir)
  } else {
    message(
      "reportifyr has already been initialized. Syncing with config file now."
    )
    sync_report_project(project_dir, report_dir_name)
  }

  log4r::debug(.le$logger, "Exiting initialize_report_project function")
}

#' @keywords internal
#' @noRd
create_report_directories <- function(project_dir, report_dir_name) {
  if (is.null(report_dir_name)) {
    report_dir <- file.path(project_dir, "report")
  } else {
    report_dir <- file.path(project_dir, report_dir_name)
  }
  dir.create(report_dir, showWarnings = FALSE, recursive = TRUE)
  log4r::info(.le$logger, paste0("Report directory created at: ", report_dir))

  dir.create(
    file.path(report_dir, "draft"),
    showWarnings = FALSE,
    recursive = TRUE
  )
  log4r::debug(.le$logger, "Draft directory created")
  writeLines(
    "Directory for reportifyr draft documents",
    file.path(report_dir, "draft/readme.txt")
  )

  dir.create(
    file.path(report_dir, "final"),
    showWarnings = FALSE,
    recursive = TRUE
  )
  log4r::debug(.le$logger, "Final directory created")
  writeLines(
    "Directory for reportifyr final document",
    file.path(report_dir, "final/readme.txt")
  )

  dir.create(
    file.path(report_dir, "scripts"),
    showWarnings = FALSE,
    recursive = TRUE
  )
  log4r::debug(.le$logger, "Scripts directory created")
  writeLines(
    "Directory for R and Rmd scripts for creating reportifyr documents",
    file.path(report_dir, "scripts/readme.txt")
  )

  dir.create(
    file.path(report_dir, "shell"),
    showWarnings = FALSE,
    recursive = TRUE
  )
  log4r::debug(.le$logger, "Shell directory created")
  writeLines(
    "Directory for reportifyr shell",
    file.path(report_dir, "shell/readme.txt")
  )

  report_dir
}

#' @keywords internal
#' @noRd
create_outputs_directories <- function(project_dir, outputs_dir_name) {
  if (is.null(outputs_dir_name)) {
    outputs_dir <- file.path(project_dir, "OUTPUTS")
  } else {
    outputs_dir <- file.path(project_dir, outputs_dir_name)
  }

  if (!dir.exists(outputs_dir)) {
    dir.create(outputs_dir, recursive = TRUE)
    log4r::info(
      .le$logger,
      paste0("Outputs directory created at: ", outputs_dir)
    )
  }

  if (!dir.exists(file.path(outputs_dir, "figures"))) {
    dir.create(file.path(outputs_dir, "figures"), recursive = TRUE)
    log4r::debug(.le$logger, "Figures directory created")
  }
  if (!dir.exists(file.path(outputs_dir, "tables"))) {
    dir.create(file.path(outputs_dir, "tables"), recursive = TRUE)
    log4r::debug(.le$logger, "Tables directory created")
  }
  if (!dir.exists(file.path(outputs_dir, "listings"))) {
    dir.create(file.path(outputs_dir, "listings"), recursive = TRUE)
    log4r::debug(.le$logger, "Listings directory created")
  }

  outputs_dir
}

#'  internal
#' @noRd
copy_footnotes <- function(report_dir) {
  if (!("standard_footnotes.yaml" %in% list.files(report_dir))) {
    file.copy(
      from = system.file(
        "extdata/standard_footnotes.yaml",
        package = "reportifyr"
      ),
      to = file.path(report_dir, "standard_footnotes.yaml")
    )
    log4r::info(
      .le$logger,
      paste0("copied standard_footnotes.yaml into ", report_dir)
    )
    message(paste("copied standard_footnotes.yaml into", report_dir))
  }
}


#' @keywords internal
#' @noRd
update_config <- function(config_path, report_dir_name, outputs_dir_name) {
  config <- yaml::read_yaml(config_path)

  # Update report_dir_name if provided
  if (!is.null(report_dir_name)) {
    config$report_dir_name <- report_dir_name
  }

  # Update outputs_dir_name if provided
  if (!is.null(outputs_dir_name)) {
    config$outputs_dir_name <- outputs_dir_name
  }

  # Write the updated config back to the file
  yaml::write_yaml(
    config,
    config_path,
    handlers = list(logical = yaml::verbatim_logical)
  )
}

#'  internal
#' @noRd
copy_config <- function(report_dir, report_dir_name, outputs_dir_name) {
  if (!("config.yaml" %in% list.files(report_dir))) {
    file.copy(
      from = system.file(
        "extdata/config.yaml",
        package = "reportifyr"
      ),
      to = file.path(report_dir, "config.yaml")
    )
    # updating config with correct report/outputs_dir_name
    update_config(
      file.path(report_dir, "config.yaml"),
      report_dir_name,
      outputs_dir_name
    )

    log4r::info(
      .le$logger,
      paste0("copied config.yaml into ", report_dir)
    )
    message(paste("copied config.yaml into", report_dir))
  }
}

#'  internal
#' @noRd
create_init_file <- function(project_dir, report_dir, outputs_dir) {
  log4r::info(.le$logger, "Writing reportifyr_init json")

  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  user <- Sys.info()[["user"]] # need to think about if this fails

  data <- list(
    creation_timestamp = timestamp,
    last_modified = timestamp,
    user = user
  )

  log4r::debug(
    .le$logger,
    paste0("Reading ", file.path(report_dir, "config.yaml"))
  )
  config <- yaml::read_yaml(file.path(report_dir, "config.yaml"))
  data$config <- config

  log4r::debug(
    .le$logger,
    paste0("Reading ", report_dir, "/.python_dependency_versions.json")
  )
  py_versions <- jsonlite::read_json(
    file.path(report_dir, ".python_dependency_versions.json")
  )
  data$python_versions <- py_versions

  log4r::debug(.le$logger, "Assembled data for saving as JSON")
  json_data <- jsonlite::toJSON(data, pretty = TRUE, auto_unbox = TRUE)
  log4r::debug(.le$logger, "Data converted to json string")

  log4r::debug(.le$logger, "Adding warning message to json")
  json_with_comment <- paste(
    "// WARNING: This file is automatically generated on initialization. Do not edit by hand!",
    json_data,
    sep = "\n"
  )
  path_name <- sub("/", "_", fs::path_rel(report_dir, project_dir))
  init_file <- file.path(project_dir, paste0(".", path_name, "_init.json"))
  write(json_with_comment, file = init_file)

  log4r::info(.le$logger, paste0("metadata written to file: ", init_file))

  log4r::debug(.le$logger, "Exiting write_package_version_metadata function")
}
