#' Writes an object's metadata .json file
#'
#' @param object_file Path to the file of the object to write metadata for
#' @param meta_type A string denoting what standard notes to use
#' @param equations Additional equations to include in metadata, either string of single equation or vector of multiple
#' @param notes Additional notes to include in metadata, either string of single note or vector of multiple
#' @param abbrevs Additional abbreviations to include in metadata, either string of single abbrev or vector of multiple
#' @param table1_format Boolean for using table1 formatting for flextables
#'
#' @export
#'
#' @examples \dontrun{
#' ft <- flextable(iris)
#'
#' write_object_metadata(ft, "table", file_path)
#' }
write_object_metadata <- function(
    object_file,
    meta_type = NULL,
    equations = NULL,
    notes = NULL,
    abbrevs = NULL,
    table1_format = F) {

  log4r::debug(.le$logger, "Starting write_object_metadata function")

  if (!file.exists(object_file)) {
    log4r::error(.le$logger, paste0("File does not exist: ", object_file))
    stop(paste0("Please pass path to object that exists: ", object_file, " does not exist"))
  }

  log4r::info(.le$logger, paste0("File exists: ", object_file))

  # Collect vars
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  rvers <- R.version$version.string
  platform <- R.version$platform

  log4r::info(.le$logger, paste0("Collected system metadata: ", list(timestamp, rvers, platform)))

  hash <- digest::digest(file = object_file, algo = "blake3")
  log4r::info(.le$logger, paste0("Generated file hash: ", hash))

  source_path <- tryCatch({
    if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
      context <- rstudioapi::getSourceEditorContext()
      if (!is.null(context$path) && nzchar(context$path)) {  # Check if the context and path are non-null and non-empty
        normalizePath(context$path)
      } else {
        normalizePath(getwd())  # Fallback to the working directory if no source file is open
      }
    } else if (!is.null(knitr::current_input())) {
      normalizePath(knitr::current_input())
    } else if (!is.null(rmarkdown::metadata$input_file)) {
      normalizePath(rmarkdown::metadata$input_file)
    } else if (!is.null(getOption("knitr.in.file"))) {
      normalizePath(getOption("knitr.in.file"))
    } else if (testthat::is_testing()) {
      normalizePath(testthat::test_path())
    } else {
      stop("Unable to detect input file")
    }
  }, error = function(e) {
    log4r::error(.le$logger, "Error detecting source file path")
    stop(e)
  })

  log4r::info(.le$logger, paste0("Source file path detected: ", source_path))

  source_path_git_info <- get_git_info(source_path)
  log4r::info(.le$logger, paste0("Fetched git info for source file: ", source_path_git_info))

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
      path = source_path,
      creation_time = source_path_git_info$creation_time,
      latest_time = source_path_git_info$latest_time
    ),
    object_meta = list(
      author = get_git_config_author(),
      path = object_file,
      creation_time = as.character(timestamp),
      file_type = tools::file_ext(object_file),
      meta_type = meta_type,
      hash = hash,
      table1 = table1_format,
      footnotes = list(
        equations = as.list(equations),
        notes = as.list(notes),
        abbreviations = as.list(unique(c(abbrevs)))
      )
    )
  )

  log4r::debug(.le$logger, "Assembled data for saving as JSON")

  json_data <- jsonlite::toJSON(data_to_save, pretty = TRUE, auto_unbox = TRUE)
  log4r::debug(.le$logger, "Data converted to json string")

  file_path <- paste0(tools::file_path_sans_ext(object_file), "_", tools::file_ext(object_file), "_metadata.json")

  write(json_data, file = file_path)

  log4r::info(.le$logger, paste0("Metadata written to file: ", file_path))

  log4r::debug(.le$logger, "Exiting write_object_metadata function")
}
