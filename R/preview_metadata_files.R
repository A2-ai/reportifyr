#' Preview all metadata .json files in a directory
#'
#' @param file_dir The file path to a directory containing metadata .json files.
#'
#' @return A data frame of metadata footnotes and meta type
#'
#' @export
#'
#' @examples \dontrun{
#' figures_path <- here::here("OUTPUTS", "figures")
#' preview_metadata_file(figures_path)
#' }
preview_metadata_files <- function(file_dir) {
  log4r::debug(.le$logger, "Starting preview_metadata_files function")


  if (!dir.exists(file_dir)) {
    log4r::error(.le$logger, paste0("Directory does not exist: ", file_dir))
    stop("Directory does not exist.")
  }
  log4r::info(.le$logger, paste0("Directory found: ", file_dir))

  json_files <- list.files(path = file_dir, pattern = "\\_metadata.json$", full.names = TRUE)

  if (length(json_files) == 0) {
    log4r::error(.le$logger, "No .json files found in the specified directory")
    stop("No .json files found in the specified directory.")
  }
  log4r::info(.le$logger, paste0("Found ", length(json_files), " metadata .json files in directory"))

  # Extract the necessary fields for each JSON file and return as a data frame
  json_content_list <- purrr::map(json_files, function(file) {
    log4r::debug(.le$logger, paste0("Processing file: ", file))

    json_content <- jsonlite::fromJSON(file, flatten = TRUE)

    # Extract the base name, split by underscore, and format it as object.ext
    base_name <- tools::file_path_sans_ext(basename(file)) # remove .json
    log4r::info(.le$logger, paste0("Base name extracted: ", base_name))

    name_parts <- strsplit(base_name, "_")[[1]]
    name <- paste(name_parts[1], name_parts[2], sep = ".") # create object.ext
    log4r::info(.le$logger, paste0("Formatted name: ", name))

    meta_type <- if (length(json_content$object_meta$meta_type) == 0) {
      "N/A"
    } else {
      json_content$object_meta$meta_type
    }
    log4r::info(.le$logger, paste0("Extracted meta_type: ", meta_type))

    # If these fields are lists, join them into a single string, if empty make them "N/A"
    meta_equations <- if (length(json_content$object_meta$footnotes$equations) == 0) {
      "N/A"
    } else if (is.list(json_content$object_meta$footnotes$equations)) {
      paste(json_content$object_meta$footnotes$equations, collapse = ", ")
    } else {
      json_content$object_meta$footnotes$equations
    }
    log4r::info(.le$logger, paste0("Extracted equations: ", meta_equations))

    meta_notes <- if (length(json_content$object_meta$footnotes$notes) == 0) {
      "N/A"
    } else if (is.list(json_content$object_meta$footnotes$notes)) {
      paste(json_content$object_meta$footnotes$notes, collapse = ", ")
    } else {
      json_content$object_meta$footnotes$notes
    }
    log4r::info(.le$logger, paste0("Extracted notes: ", meta_notes))

    meta_abbrevs <- if (length(json_content$object_meta$footnotes$abbreviations) == 0) {
      "N/A"
    } else if (is.list(json_content$object_meta$footnotes$abbreviations)) {
      paste(json_content$object_meta$footnotes$abbreviations, collapse = ", ")
    } else {
      json_content$object_meta$footnotes$abbreviations
    }
    log4r::info(.le$logger, paste0("Extracted abbreviations: ", meta_abbrevs))

    # Return as a named list
    log4r::debug(.le$logger, paste0("Returning extracted data for file: ", file))
    return(list(
      name = name, meta_type = meta_type, meta_equations = meta_equations,
      meta_notes = meta_notes, meta_abbrevs = meta_abbrevs
    ))
  })

  # Convert list of lists into a data frame
  result_df <- do.call(rbind, lapply(json_content_list, as.data.frame))

  log4r::info(.le$logger, paste0("Metadata preview successfully generated:", result_df))
  log4r::debug(.le$logger, "Exiting preview_metadata_files function")

  return(result_df)
}



#' Previews a single metadata file for an object
#'
#' @param file_name The file path of the file whose metadata you want to preview.
#'
#' @return A single row data frame consisting of metadata type and footnotes for the object supplied
#'
#' @importFrom rlang .data
#'
#' @export
#'
#' @examples \dontrun{
#' figures_path <- here::here("OUTPUTS", "figures")
#' plot_file_name <- "myplot.png"
#' preview_metadata(file.path(figures_path, plot_file_name))
#' }
preview_metadata <- function(file_name) {
  log4r::debug(.le$logger, "Starting preview_metadata function")

  if (!file.exists(file_name)) {
    log4r::error(.le$logger, paste0("File does not exist: ", file_name))
    stop("Error: file does not exist.")
  }

  log4r::info(.le$logger, paste0("File found: ", file_name))

  file_dir <- dirname(file_name)
  log4r::info(.le$logger, paste0("Directory of the file: ", file_dir))

  metadata_df <- preview_metadata_files(file_dir)
  log4r::debug(.le$logger, "Metadata preview for directory generated")

  filtered_metadata <- metadata_df |>
    dplyr::filter(.data$name == basename(file_name))
  log4r::info(.le$logger, paste0("Filtered metadata for file: ", file_name))

  log4r::debug(.le$logger, "Exiting preview_metadata function")

  return(filtered_metadata)
}
