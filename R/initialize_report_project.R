#' Create report directories within a project
#'
#' @param project_dir The file path to the main project directory
#' where the directory structure will be created.
#' The directory must already exist; otherwise, an error will be thrown.
#' @param report_dir_name The directory name for where reports will be saved.
#' Default is `NULL`. If `NULL`, `report` will be used.
#' @param outputs_dir_name The directory name for where artifacts will be saved.
#' Default is `NULL`. If `NULL`, `OUTPUTS` will be used.
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

    fyrstartr::initialize_python()

    # Overwrite fyrstartr's default JSON with reportifyr's schema; deps
    pyv <- build_python_version_data(project_dir)
    keep <- pyv$package_names != "venv_dir"
    venv_path <- file.path(getOption("venv_dir"), ".venv")
    metadata_path <- fyrstartr::write_package_version_metadata(
      pyv$versions[keep], pyv$package_names[keep], venv_path
    )

    if (file.exists(metadata_path)) {
      file.copy(
        metadata_path,
        file.path(report_dir, basename(metadata_path)),
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

    # Resolve report and outputs dir paths
    init_path <- file.path(project_dir, init_file)
    init_data <- jsonlite::read_json(init_path, simplifyVector = TRUE)

    if (is.null(report_dir_name)) {
      rdn <- init_data$config$report_dir_name
      resolved_report_name <- if (!is.null(rdn)) rdn else "report"
    } else {
      resolved_report_name <- report_dir_name
    }
    report_dir <- file.path(project_dir, resolved_report_name)

    odn <- init_data$config$outputs_dir_name
    resolved_outputs_name <- if (!is.null(odn)) odn else "OUTPUTS"
    outputs_dir <- file.path(project_dir, resolved_outputs_name)

    # Check report directory and subdirectories
    if (!dir.exists(report_dir)) {
      log4r::warn(
        .le$logger,
        paste0("Report directory missing, recreating: ", report_dir)
      )
      message(paste0("Report directory missing. Recreating: ", report_dir))
      create_report_directories(project_dir, resolved_report_name)
    } else {
      report_subdirs <- c("draft", "final", "scripts", "shell")
      for (subdir in report_subdirs) {
        subdir_path <- file.path(report_dir, subdir)
        if (!dir.exists(subdir_path)) {
          log4r::warn(
            .le$logger,
            paste0("Report subdirectory missing, recreating: ", subdir_path)
          )
          message(paste0("Recreating missing directory: ", subdir_path))
          dir.create(subdir_path, showWarnings = FALSE, recursive = TRUE)
        }
      }
    }

    # Check config.yaml
    if (!file.exists(file.path(report_dir, "config.yaml"))) {
      log4r::warn(
        .le$logger,
        "config.yaml missing from report directory, restoring default"
      )
      message("config.yaml missing. Restoring default.")
      copy_config(report_dir, resolved_report_name, resolved_outputs_name)
    }

    # Check standard_footnotes.yaml
    if (!file.exists(file.path(report_dir, "standard_footnotes.yaml"))) {
      log4r::warn(
        .le$logger,
        paste0(
          "standard_footnotes.yaml missing from report directory,",
          " restoring default"
        )
      )
      message("standard_footnotes.yaml missing. Restoring default.")
      copy_footnotes(report_dir)
    }

    # Check outputs directory and subdirectories
    if (!dir.exists(outputs_dir)) {
      log4r::warn(
        .le$logger,
        paste0("Outputs directory missing, recreating: ", outputs_dir)
      )
      message(paste0("Outputs directory missing. Recreating: ", outputs_dir))
    }
    create_outputs_directories(project_dir, resolved_outputs_name)

    # Check if .venv directory still exists, recreate if missing
    venv_parent <- getOption("venv_dir") %||% here::here()
    venv_dir <- file.path(venv_parent, ".venv")

    if (!dir.exists(venv_dir)) {
      log4r::warn(
        .le$logger,
        ".venv directory missing, reinitializing Python environment"
      )
      message("Python virtual environment missing. Reinitializing...")
      metadata_path <- fyrstartr::initialize_python()
    }

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
  pyv <- build_python_version_data(project_dir)
  data$python_versions <- stats::setNames(as.list(pyv$versions), pyv$package_names)

  log4r::debug(.le$logger, "Assembled data for saving as JSON")
  json_data <- jsonlite::toJSON(data, pretty = TRUE, auto_unbox = TRUE)
  log4r::debug(.le$logger, "Data converted to json string")

  path_name <- sub("/", "_", fs::path_rel(report_dir, project_dir))
  init_file <- file.path(project_dir, paste0(".", path_name, "_init.json"))
  write(json_data, file = init_file)

  log4r::info(.le$logger, paste0("metadata written to file: ", init_file))

  log4r::debug(.le$logger, "Exiting create_init_file function")
}
