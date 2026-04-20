#' Writes an object's metadata .json file
#'
#' @param object_file The file path of the object to write metadata for.
#' @param meta_type A string to specify the type of object. Default is `"NA"`.
#' @param meta_equations A string or vector of strings representing equations to include in the metadata. Default is `NULL`.
#' @param meta_notes A string or vector of strings representing notes to include in the metadata. Default is `NULL`.
#' @param meta_abbrevs A string or vector of strings representing abbreviations to include in the metadata. Default is `NULL`.
#' @param table1_format A boolean indicating whether table1 formatting is used for `add_tables()`. Default is `FALSE`.
#' @param context An `rpfy_context` built via [rpfy_context()]. When
#'   `NULL` (default) an ephemeral context is constructed with all
#'   defaults. Passing an existing context avoids recomputing
#'   session-level fields on every artifact.
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
  table1_format = FALSE,
  context = NULL
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

  context <- validate_context(context)

  project_root <- context$project_root
  if (is.null(project_root)) {
    log4r::error(
      .le$logger,
      "Could not find project root directory (no *_init.json file found)"
    )
    stop(
      "Could not find project root directory. Make sure you're in a reportifyr project (run initialize_report_project() first)"
    )
  }

  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")

  hash <- digest::digest(file = object_file, algo = "blake3")
  log4r::info(.le$logger, paste0("Generated file hash: ", hash))

  object_path_relative <- fs::path_rel(normalizePath(object_file), project_root)
  log4r::info(
    .le$logger,
    paste0("Object file path (relative): ", object_path_relative)
  )

  data_to_save <- list(
    system_meta = context$system_meta,
    source_meta = context$source_meta,
    object_meta = list(
      author = context$author,
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

  if (!is.null(context$addl_metadata)) {
    data_to_save$addl_meta <- context$addl_metadata
  }

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
