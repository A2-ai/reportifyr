#' Create report directories within a project
#'
#' @param project_dir The file path to the main project directory where the directory structure will be created. The directory must already exist; otherwise, an error will be thrown.
#'
#' @export
#'
#' @examples \dontrun{
#' initialize_report_project(project_dir = tempdir())
#' }
initialize_report_project <- function(project_dir) {
  log4r::debug(.le$logger, "Starting initialize_report_project function")

  if (!dir.exists(project_dir)) {
    log4r::error(.le$logger, paste0("The directory does not exist: ", project_dir))
    stop("The directory does not exist")
  }
  log4r::info(.le$logger, paste0("Project directory found: ", project_dir))

  report_dir <- file.path(project_dir, "report")
  dir.create(report_dir, showWarnings = F)
  log4r::info(.le$logger, paste0("Report directory created at: ", report_dir))

  dir.create(file.path(report_dir, "draft"), showWarnings = F)
  log4r::debug(.le$logger, "Draft directory created")
  writeLines(
    "Directory for reportifyr draft documents",
    file.path(report_dir, "draft/readme.txt")
  )

  dir.create(file.path(report_dir, "final"), showWarnings = F)
  log4r::debug(.le$logger, "Final directory created")
  writeLines(
    "Directory for reportifyr final document",
    file.path(report_dir, "final/readme.txt")
  )

  dir.create(file.path(report_dir, "scripts"), showWarnings = F)
  log4r::debug(.le$logger, "Scripts directory created")
  writeLines(
    "Directory for R and Rmd scripts for creating reportifyr documents",
    file.path(report_dir, "scripts/readme.txt")
  )

  dir.create(file.path(report_dir, "shell"), showWarnings = F)
  log4r::debug(.le$logger, "Shell directory created")
  writeLines(
    "Directory for reportifyr shell",
    file.path(report_dir, "shell/readme.txt")
  )

  outputs_dir <- file.path(project_dir, "OUTPUTS")

  if (!dir.exists(outputs_dir)) {
    dir.create(outputs_dir)
    log4r::info(.le$logger, paste0("Outputs directory created at: ", outputs_dir))
  }

  if (!dir.exists(file.path(outputs_dir, "figures"))) {
    dir.create(file.path(outputs_dir, "figures"))
    log4r::debug(.le$logger, "Figures directory created")
  }
  if (!dir.exists(file.path(outputs_dir, "tables"))) {
    dir.create(file.path(outputs_dir, "tables"))
    log4r::debug(.le$logger, "Tables directory created")
  }
  if (!dir.exists(file.path(outputs_dir, "listings"))) {
    dir.create(file.path(outputs_dir, "listings"))
    log4r::debug(.le$logger, "Listings directory created")
  }
  if (!is.null(getOption("venv_dir"))) {
    if (!dir.exists(file.path(getOption("venv_dir"), ".venv"))) {
      log4r::info(.le$logger, "Virtual environment not found, initializing Python environment")
      initialize_python()
    }
  } else {
    log4r::info(.le$logger, "Virtual environment not set, initializing Python environment")
    initialize_python()
  }

  if (!("standard_footnotes.yaml" %in% list.files(report_dir))) {
    result <- file.copy(
      from = system.file("extdata/standard_footnotes.yaml", package = "reportifyr"),
      to = file.path(report_dir, "standard_footnotes.yaml")
    )
    log4r::info(.le$logger, paste0("Copied standard_footnotes.yaml into ", report_dir))
    message(paste("Copied standard_footnotes.yaml into", report_dir))
  }
  log4r::debug(.le$logger, "Exiting initialize_report_project function")
}
