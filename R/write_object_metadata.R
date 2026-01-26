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

  source_path <- get_source_path()

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
