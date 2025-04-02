#' Create report directories within a project
#'
#' @param project_dir The file path to the main project directory
#' where the directory structure will be created.
#' The directory must already exist; otherwise, an error will be thrown.
#'
#' @export
#'
#' @examples \dontrun{
#' initialize_report_project(project_dir = tempdir())
#' }
initialize_report_project <- function(project_dir) {
  log4r::debug(.le$logger, "Starting initialize_report_project function")

  if (!dir.exists(project_dir)) {
    log4r::error(
      .le$logger,
      paste0("The directory does not exist: ", project_dir)
    )
    stop("The directory does not exist")
  }
  log4r::info(.le$logger, paste0("Project directory found: ", project_dir))

  report_dir <- file.path(project_dir, "report")
  dir.create(report_dir, showWarnings = FALSE)
  log4r::info(.le$logger, paste0("Report directory created at: ", report_dir))

  dir.create(file.path(report_dir, "draft"), showWarnings = FALSE)
  log4r::debug(.le$logger, "Draft directory created")
  writeLines(
    "Directory for reportifyr draft documents",
    file.path(report_dir, "draft/readme.txt")
  )

  dir.create(file.path(report_dir, "final"), showWarnings = FALSE)
  log4r::debug(.le$logger, "Final directory created")
  writeLines(
    "Directory for reportifyr final document",
    file.path(report_dir, "final/readme.txt")
  )

  dir.create(file.path(report_dir, "scripts"), showWarnings = FALSE)
  log4r::debug(.le$logger, "Scripts directory created")
  writeLines(
    "Directory for R and Rmd scripts for creating reportifyr documents",
    file.path(report_dir, "scripts/readme.txt")
  )

  dir.create(file.path(report_dir, "shell"), showWarnings = FALSE)
  log4r::debug(.le$logger, "Shell directory created")
  writeLines(
    "Directory for reportifyr shell",
    file.path(report_dir, "shell/readme.txt")
  )

  outputs_dir <- file.path(project_dir, "OUTPUTS")

  if (!dir.exists(outputs_dir)) {
    dir.create(outputs_dir)
    log4r::info(
      .le$logger,
      paste0("Outputs directory created at: ", outputs_dir)
    )
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
  
	initialize_python()
  
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
  if (!("config.yaml" %in% list.files(report_dir))) {
    file.copy(
      from = system.file(
        "extdata/config.yaml",
        package = "reportifyr"
      ),
      to = file.path(report_dir, "config.yaml")
    )
    log4r::info(
      .le$logger,
      paste0("copied config.yaml into ", report_dir)
    )
    message(paste("copied config.yaml into", report_dir))
  }

  log4r::debug(.le$logger, "Exiting initialize_report_project function")
}
