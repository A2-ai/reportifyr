#' Writes an object's metadata .json file
#'
#' @param object_file The file path of the object to write metadata for.
#' @param meta_type A string to specify the type of object. Default is `"NA"`.
#' @param meta_equations A string or vector of strings representing equations to include in the metadata. Default is `NULL`.
#' @param meta_notes A string or vector of strings representing notes to include in the metadata. Default is `NULL`.
#' @param meta_abbrevs A string or vector of strings representing abbreviations to include in the metadata. Default is `NULL`.
#' @param table1_format A boolean indicating whether table1 formatting is used for `add_tables()`. Default is `FALSE`.
#'
#' @export
#'
#' @examples \dontrun{
#' figures_path <- here::here("OUTPUTS", "figures")
#' plot_file_name <- "01-12345-pk-timecourse1.png"
#'
#' write_object_metadata(object_file = file.path(figures_path, plot_file_name))
#' }
write_object_metadata <- function(
  object_file,
  meta_type = NULL,
  meta_equations = NULL,
  meta_notes = NULL,
  meta_abbrevs = NULL,
  table1_format = FALSE
) {
  log4r::debug(.le$logger, "Starting write_object_metadata function")

  if (!file.exists(object_file)) {
    log4r::error(.le$logger, paste0("File does not exist: ", object_file))
    stop(paste0(
      "Please pass path to object that exists: ",
      object_file,
      " does not exist"
    ))
  }

  log4r::info(.le$logger, paste0("File exists: ", object_file))

  # Collect vars
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  rvers <- R.version$version.string
  platform <- R.version$platform

  log4r::info(
    .le$logger,
    paste0("Collected system metadata: ", list(timestamp, rvers, platform))
  )

  hash <- digest::digest(file = object_file, algo = "blake3")
  log4r::info(.le$logger, paste0("Generated file hash: ", hash))

  source_path <- tryCatch({
    qmd_path <- detect_quarto_render()
    if (!is.null(qmd_path)) {
      log4r::info(.le$logger,
                  paste0("Detected Quarto render; using .qmd file: ", qmd_path))
      qmd_path
    } else if (requireNamespace("this.path", quietly = TRUE)) {
      sp <- this.path::this.path()
      if (!is.null(sp) && nzchar(sp)) {
        sp <- normalizePath(sp)
        log4r::info(.le$logger,
                    paste0("Source path detected via this.path: ", sp))
        sp
      } else {
        log4r::warn(.le$logger,
                    "this.path did not return a valid script path; setting placeholder")
        "SOURCE_PATH_NOT_DETECTED"
      }
    } else {
      log4r::warn(.le$logger,
                  "Unable to detect source path via Quarto or this.path(); setting placeholder")
      "SOURCE_PATH_NOT_DETECTED"
    }
  },
  error = function(e) {
    log4r::warn(.le$logger,
                paste0("Error detecting source path: ", e$message))
    "SOURCE_PATH_NOT_DETECTED"
  })

  # Find project root directory (containing .*_init.json)
  project_root <- find_project_root()

  if (is.null(project_root)) {
    log4r::error(.le$logger, "Could not find project root directory (no *_init.json file found)")
    stop("Could not find project root directory. Make sure you're in a reportifyr project (run initialize_report_project() first)")
  }

  # Convert source path to relative path from project root
  source_path_relative <- fs::path_rel(source_path, project_root)
  log4r::info(.le$logger, paste0("Source file path (relative): ", source_path_relative))

  # Convert object path to relative path from project root
  object_path_relative <- fs::path_rel(normalizePath(object_file), project_root)
  log4r::info(.le$logger, paste0("Object file path (relative): ", object_path_relative))

  source_path_git_info <- get_git_info(source_path)
  log4r::info(
    .le$logger,
    paste0("Fetched git info for source file: ", source_path_git_info)
  )

  # Combine into expected structure
  data_to_save <- list(
    system_meta = list(
      platform = platform,
      software = list(
        version = as.character(rvers),
        packages_used = get_packages()
      )
    ),
    source_meta = list(
      creation_author = source_path_git_info$creation_author,
      latest_author = source_path_git_info$latest_author,
      path = source_path_relative,
      creation_time = source_path_git_info$creation_time,
      latest_time = source_path_git_info$latest_time
    ),
    object_meta = list(
      author = get_git_config_author(),
      path = object_path_relative,
      creation_time = as.character(timestamp),
      file_type = tools::file_ext(object_file),
      meta_type = meta_type,
      hash = hash,
      table1 = table1_format,
      footnotes = list(
        equations = as.list(meta_equations),
        notes = as.list(meta_notes),
        abbreviations = as.list(unique(c(meta_abbrevs)))
      )
    )
  )

  log4r::debug(.le$logger, "Assembled data for saving as JSON")

  json_data <- jsonlite::toJSON(data_to_save, pretty = TRUE, auto_unbox = TRUE)
  log4r::debug(.le$logger, "Data converted to json string")

  file_path <- paste0(
    tools::file_path_sans_ext(object_file),
    "_",
    tools::file_ext(object_file),
    "_metadata.json"
  )

  write(json_data, file = file_path)

  log4r::info(.le$logger, paste0("Metadata written to file: ", file_path))

  log4r::debug(.le$logger, "Exiting write_object_metadata function")
}

#' Write enhanced metadata for objects with additional context
#'
#' @inheritParams write_object_metadata
#' @param source_type Type of source context. One of "script" (default),
#'   or "shiny_app".
#' @param source_info Named list of source information. For shiny_app, should
#'   include app_name, app_version, and optionally app_repo and app_commit.
#' @param execution_info Named list of execution context (e.g., user, session_id).
#' @param additional_metadata Named list of any additional metadata to include
#'   at the top level of the JSON structure.
#'
#' @export
#'
#' @examples \dontrun{
#' # Shiny application usage
#' write_enhanced_object_metadata(
#'   object_file = plot_path,
#'   source_type = "shiny_app",
#'   source_info = list(
#'     app_name = "CHRONOS",
#'     app_version = "1.2.0"
#'   ),
#'   execution_info = list(
#'     user = session$user,
#'     session_id = session$token
#'   )
#' )
#'
#' # Standard script usage
#' write_enhanced_object_metadata(
#'   object_file = plot_path,
#'   source_type = "script"
#' )
#' }
write_enhanced_object_metadata <- function(
    object_file,
    source_type = c("script", "shiny_app"),
    source_info = NULL,
    execution_info = NULL,
    meta_type = NULL,
    meta_equations = NULL,
    meta_notes = NULL,
    meta_abbrevs = NULL,
    table1_format = FALSE,
    additional_metadata = NULL
) {
  source_type <- match.arg(source_type)

  log4r::debug(.le$logger, "Starting write_enhanced_object_metadata function")
  log4r::info(.le$logger, paste0("Source type: ", source_type))

  write_object_metadata(
    object_file = object_file,
    meta_type = meta_type,
    meta_equations = meta_equations,
    meta_notes = meta_notes,
    meta_abbrevs = meta_abbrevs,
    table1_format = table1_format
  )

  json_path <- paste0(
    tools::file_path_sans_ext(object_file),
    "_",
    tools::file_ext(object_file),
    "_metadata.json"
  )

  metadata <- jsonlite::fromJSON(json_path, simplifyVector = FALSE)
  log4r::debug(.le$logger, "Read generated metadata JSON")

  if (source_type == "shiny_app") {
    if (is.null(source_info) || is.null(source_info$app_name) || is.null(source_info$app_version)) {
      log4r::error(.le$logger, "source_info must include app_name and app_version")
      stop("For source_type='shiny_app', source_info must include app_name and app_version")
    }

    metadata$source_meta$path <- paste0(
      source_info$app_name,
      " v",
      source_info$app_version
    )
    log4r::info(.le$logger, paste0("Modified source_meta for Shiny app: ", source_info$app_name))
  }

  # Add execution metadata if needed
  if (!is.null(execution_info)) {
    metadata$execution_meta <- execution_info
    log4r::info(.le$logger, paste0("Added execution_meta: ", paste(names(execution_info), collapse = ", ")))
  }

  # Add additional metadata if needed
  if (!is.null(additional_metadata)) {
    metadata$additional_meta <- additional_metadata
    log4r::info(.le$logger, paste0("Added additional metadata: ", paste(names(additional_metadata), collapse = ", ")))
  }

  json_data <- jsonlite::toJSON(metadata, pretty = TRUE, auto_unbox = TRUE)
  write(json_data, file = json_path)

  log4r::info(.le$logger, paste0("Enhanced metadata written to: ", json_path))
  log4r::debug(.le$logger, "Exiting write_enhanced_object_metadata function")

  invisible(json_path)
}
