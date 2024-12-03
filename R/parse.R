parse_directory_for_images <- function(directory, recursive = TRUE, full.names = TRUE, exclude_dirs = NULL) {
  if (!dir.exists(directory)) {
    stop("The specified directory does not exist.")
  }

  image_pattern <- "\\.(png|jpg|jpeg|gif|bmp|tiff|webp)$"

  # List files in the directory
  image_files <- list.files(
    path = directory,
    pattern = image_pattern,
    recursive = recursive,
    full.names = full.names,
    ignore.case = TRUE # Case-insensitive match
  )

  # Exclude specified subdirectories
  if (!is.null(exclude_dirs) && length(image_files) > 0) {
    exclude_pattern <- paste0(exclude_dirs, collapse = "|")
    image_files <- image_files[!grepl(exclude_pattern, image_files, ignore.case = TRUE)]
  }

  if (length(image_files) == 0) {
    message("No image files found in the specified directory.")
  }

  return(image_files)
}
