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

  source_path <- tryCatch(
    {
      # Check if the script is being sourced
      src_path <- if (!is.null(sys.frame(1)$ofile)) {
        normalizePath(sys.frame(1)$ofile) # Path of the currently sourced file
      } else if (!is.null(knitr::current_input())) {
        normalizePath(knitr::current_input())
      } else if (
        requireNamespace("rstudioapi", quietly = TRUE) &&
          rstudioapi::isAvailable()
      ) {
        context <- rstudioapi::getSourceEditorContext()
        if (!is.null(context$path) && nzchar(context$path)) {
          normalizePath(context$path)
        } else {
          normalizePath("Object created from console")
        }
      } else if (!is.null(rmarkdown::metadata$input_file)) {
        normalizePath(rmarkdown::metadata$input_file)
      } else if (!is.null(getOption("knitr.in.file"))) {
        normalizePath(getOption("knitr.in.file"))
      } else if (testthat::is_testing()) {
        normalizePath(testthat::test_path())
      } else {
        stop("Unable to detect input file")
      }
      src_path
    },
    error = function(e) {
      log4r::error(.le$logger, "Error detecting source file path")
      stop(e)
    }
  )

  log4r::info(.le$logger, paste0("Source file path detected: ", source_path))

  source_path_git_info <- get_git_info(source_path)
  log4r::info(
    .le$logger,
    paste0("Fetched git info for source file: ", source_path_git_info)
  )

  init_root <-  tryCatch(
    {
      find_init_root(source_path)
    },
    error = function(e) {
      log4r::error(.le$logger, "Error detecting project root")
      stop(e)
    }
  )

  src_rel  <- fs::path_rel(source_path, start = init_root)
  obj_rel  <- fs::path_rel(object_file, start = init_root)

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
      path = src_rel,
      creation_time = source_path_git_info$creation_time,
      latest_time = source_path_git_info$latest_time
    ),
    object_meta = list(
      author = get_git_config_author(),
      path = obj_rel,
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
