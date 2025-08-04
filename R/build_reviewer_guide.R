#' Build a reviewer's guide of file names and source paths
#'
#' @description Reads in a `.docx` file and returns a `.docx` table of file names and source paths.
#' @param docx_in The file path to the input `.docx` file.
#' @param docx_out The file path to the output `.docx` file to save to. Default is `NULL`.
#' @param figures_path The file path to the figures and associated metadata directory.
#' @param tables_path The file path to the tables and associated metadata directory.
#'
#' @export
#'
#' @examples \dontrun{
#' reviewer_guide(
#'   docx_in = docx_in,
#'   docx_out = docx_out,
#'   figures_path = figures_path,
#'   tables_path = tables_path
#' )
#' }
build_reviewer_guide <- function(
    docx_in,
    docx_out = NULL,
    figures_path,
    tables_path) {
  log4r::debug(.le$logger, "Starting build_reviewer_guide function")

  if (is.null(docx_out)) {
    dir <- dirname(docx_in)
    docx_out <- file.path(dir, "reviewer_guide.docx")
    log4r::info(.le$logger, paste0("docx_out is null, setting docx_out to: ", docx_out))
  }

  start_pattern <- "\\{rpfy\\}:"
  end_pattern <- "\\.[^.]+$"
  magic_pattern <- paste0(start_pattern, ".*?", end_pattern)

  doc <- officer::read_docx(docx_in)
  doc_summary <- officer::docx_summary(doc)
  magic_indices <- grep(magic_pattern, doc_summary$text)

  venv_path <- file.path(getOption("venv_dir"), ".venv")
  if (!dir.exists(venv_path)) {
    log4r::error(.le$logger, "Virtual environment not found. Please initialize with initialize_python.")
    stop("Create virtual environment with initialize_python")
  }

  uv_path <- get_uv_path()
  if (is.null(uv_path)) {
    log4r::error(.le$logger, "uv not found. Please install with initialize_python")
    stop("Please install uv with initialize_python")
  }

  file_names <- c()
  for (i in magic_indices) {
    magic_string <- doc_summary$text[[i]]
    parser <- system.file("scripts/parse_magic_string.py", package = "reportifyr")
    args <- c("run", parser, "-i", magic_string)

    result <- processx::run(
      command = uv_path,
      args = args,
      env = c("current", VIRTUAL_ENV = venv_path)
    )

    j <- jsonlite::fromJSON(result$stdout)
    file_names <- c(file_names, names(j))
  }

  ext2dir <- list(
    csv = tables_path,
    rds = tables_path,
    png = figures_path
  )

  index_tbl <- purrr::map_dfr(file_names, function(f) {
    stem <- tools::file_path_sans_ext(f)
    ext <- tolower(tools::file_ext(f))
    meta_basename <- sprintf("%s_%s_metadata.json", stem, ext)

    cand_dirs <- rlang::`%||%`(ext2dir[[ext]], character(0))
    meta_file <- purrr::detect(
      cand_dirs,
      ~ file.exists(file.path(.x, meta_basename)),
      .default = NA_character_
    )
    meta_file <- if (!is.na(meta_file)) file.path(meta_file, meta_basename) else NA_character_

    src_path <- if (!is.na(meta_file)) {
      purrr::pluck(jsonlite::read_json(meta_file, simplifyVector = TRUE),
        "source_meta", "path",
        .default = NA_character_
      )
    } else {
      NA_character_
    }

    # Extract input datasets from the R script
    input <- NA_character_
    if (!is.na(src_path) && file.exists(src_path)) {
      datasets <- get_input_datasets(src_path)
      if (length(datasets) > 0) input <- paste(datasets, collapse = "\n")
    }

    data.frame(
      Program = basename(src_path),
      Input = input,
      Output = f,
      Description = NA_character_
    )
  })

  index_tbl <- index_tbl |>
    dplyr::group_by(.data$Program) |>
    dplyr::summarise(
      Input = paste(unique(.data$Input), collapse = "\n"),
      Output = paste(sort(unique(.data$Output)), collapse = "\n"),
      Description = paste(unique(Description), collapse = "\n"),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      Description = "",
      Program = factor(
        .data$Program,
        levels = gtools::mixedsort(.data$Program, decreasing = TRUE)
      )
    ) |>
    dplyr::arrange(.data$Program)

  dataset_tbl <- index_tbl |>
    dplyr::select(`File Name` = Input) |>
    dplyr::distinct(`File Name`) |>
    dplyr::mutate(
      Description = "",
      Notes       = ""
    )

  ft <- flextable::flextable(dataset_tbl) |>
    format_flextable(table1_format = FALSE)

  ft <- reportifyr::fit_flextable_to_page(ft, page_width = 9.73)

  ft2 <- flextable::flextable(index_tbl) |>
    format_flextable(table1_format = FALSE)

  ft2 <- reportifyr::fit_flextable_to_page(ft2, page_width = 9.73)

  doc <- officer::read_docx()

  # Title Page
  doc <- officer::body_add_par(doc, "MODELING ANALYSIS ELECTRONIC SUBMISSION REVIEWERS GUIDE", style = "centered")
  doc <- officer::body_add_par(doc, "", style = "Normal")
  doc <- officer::body_end_section_portrait(doc)

  # TOC
  doc <- officer::body_add_par(doc, "Contents", style = "centered")
  doc <- officer::body_add_toc(doc, level = 2)
  doc <- officer::body_end_section_portrait(doc)

  # Insert Tables
  doc <- officer::body_add_par(doc, "Listing of Submitted Files", style = "heading 1")
  doc <- officer::body_add_par(doc, "Datasets", style = "heading 2")
  doc <- officer::body_add_par(doc, "", style = "Normal")
  doc <- flextable::body_add_flextable(doc, value = ft)
  doc <- officer::body_add_break(doc)

  doc <- officer::body_add_par(doc, "Programs", style = "heading 2")
  doc <- officer::body_add_par(doc, "", style = "Normal")
  doc <- flextable::body_add_flextable(doc, value = ft2)
  doc <- officer::body_end_section_landscape(doc)

  # Save
  print(doc, target = docx_out)

  log4r::info(.le$logger, paste("Artifact index saved to:", docx_out))
  invisible(index_tbl)
}

#' Extract dataset file names from an R script
#'
#' @param script_path Path to the R script
#'
#' @return A character vector of input dataset file names
#' @export
get_input_datasets <- function(script_path) {
  if (!file.exists(script_path)) {
    warning("Script file not found: ", script_path)
    return(character(0))
  }

  # Read + strip comments
  lines <- readLines(script_path, warn = FALSE)
  lines <- lines[!grepl("^\\s*#", lines)] # drop full-line comments
  lines <- sub("#.*$", "", lines) # drop trailing comments

  # Regex bits
  read_fun <- "(?:[A-Za-z0-9_]+::)?(?:read_csv|read\\.csv|read_excel|read_parquet|readRDS)"
  file_ext <- "(?i:csv(?:\\.gz)?|tsv(?:\\.gz)?|parquet|rds|xlsx|xls)" # add more if needed

  # Helpers
  extract_filename_literals <- function(txt) {
    # any quoted token ending with a known extension
    rx <- paste0("['\"]([^'\"]+\\.", file_ext, ")['\"]")
    m <- stringr::str_match_all(txt, stringr::regex(rx))[[1]]
    if (nrow(m)) m[, 2] else character(0)
  }

  # keep most recent simple assignment var -> "filename.ext"
  sym <- new.env(parent = emptyenv())

  record_assignments <- function(txt) {
    # only simple single-line assignments with quoted literals somewhere on RHS
    m <- stringr::str_match(
      txt,
      stringr::regex("^\\s*([A-Za-z.][A-Za-z0-9_.]*)\\s*(?:<-|=)\\s*(.+?)\\s*$", dotall = TRUE)
    )
    if (anyNA(m)) {
      return(invisible(NULL))
    }
    var <- m[2]
    rhs <- m[3]
    lits <- extract_filename_literals(rhs)
    if (length(lits)) assign(var, utils::tail(lits, 1), envir = sym) # last literal wins
    invisible(NULL)
  }

  extract_from_read_call <- function(txt) {
    rx <- paste0("(?s)", read_fun, "\\s*\\(([^)]*)\\)")
    mm <- stringr::str_match_all(txt, stringr::regex(rx, dotall = TRUE))[[1]]
    out <- character(0)
    if (!nrow(mm)) {
      return(out)
    }
    for (i in seq_len(nrow(mm))) {
      inside <- mm[i, 2]

      # 1) any literal filenames inside the call
      out <- c(out, extract_filename_literals(inside))

      # 2) identifiers that we’ve already seen bound to a filename
      ids <- stringr::str_match_all(inside, "\\b([A-Za-z.][A-Za-z0-9_.]*)\\b")[[1]]
      if (nrow(ids)) {
        for (j in seq_len(nrow(ids))) {
          key <- ids[j, 2]
          if (exists(key, envir = sym, inherits = FALSE)) {
            out <- c(out, get(key, envir = sym, inherits = FALSE))
          }
        }
      }
    }
    unique(out)
  }

  results <- character(0)

  # Single pass: update symbol table, and collect from any read_* on the same line
  for (ln in lines) {
    record_assignments(ln)
    results <- c(results, extract_from_read_call(ln))
  }

  if (!length(results)) {
    return(character(0))
  }
  unique(basename(results))
}


#' Extract input and output file paths from a NONMEM .mod or .ctl model file
#'
#' @param mod_file Path to the NONMEM control stream (.mod or .ctl file)
#'
#' @return A list with elements:
#'   - `input`: character vector (length 1 or 0) with relative input file path
#'   - `output`: character vector of output artifact file paths
#' @export
get_mod_io_paths <- function(mod_file) {
  if (!file.exists(mod_file)) {
    warning("Model file not found: ", mod_file)
    return(list(input = character(0), output = character(0)))
  }

  # Read and clean lines
  lines <- readLines(mod_file, warn = FALSE)
  lines <- trimws(lines)
  lines <- lines[nzchar(lines)] # Drop empty lines

  # Collapse to single string for regex
  full_text <- paste(lines, collapse = "\n")

  # Extract $DATA path
  data_path <- stringr::str_match(full_text, stringr::regex("\\$DATA\\s+([^\\s]+)", ignore_case = TRUE))[, 2]

  # Extract $TABLE FILE=... paths
  table_files <- stringr::str_match_all(full_text, stringr::regex("FILE\\s*=\\s*([^\\s]+)", ignore_case = TRUE))
  table_files <- unlist(lapply(table_files, function(x) if (ncol(x) >= 2) x[, 2] else NULL))

  # Input: resolve relative path and normalize to POSIX style
  input_path <- if (!is.na(data_path)) {
    raw_input <- file.path(dirname(mod_file), data_path)
    fs::path_norm(raw_input)
  } else {
    NA_character_
  }

  # Output: return just filenames (basename only)
  output_files <- if (length(table_files)) {
    basename(table_files)
  } else {
    character(0)
  }

  output_files <- c(
    output_files,
    paste0(
      tools::file_path_sans_ext(basename(mod_file)),
      ".lst"
    )
  )

  list(
    input = input_path,
    output = output_files
  )
}


#' Add a modelling section to an existing reviewer guide document
#'
#' @description Takes a list of NONMEM control streams, processes them through get_mod_io_paths, 
#' creates a formatted flextable, and adds it as a new "Modelling" section to an existing reviewer guide document.
#'
#' @param reviewer_guide_in The file path to the input reviewer guide `.docx` file.
#' @param reviewer_guide_out The file path to the output `.docx` file to save to. Default is `NULL` (saves to same directory with "_modelling" suffix).
#' @param control_streams A character vector of file paths to NONMEM control stream files (.mod or .ctl).
#' @param section_title The title for the modelling section. Default is "Modelling".
#' @param descriptions Either a named list where names are control stream basenames and values are descriptions, or a single string description (for single control stream).
#'
#' @return Invisibly returns the modelling data frame that was added to the document.
#' @export
#'
#' @examples \dontrun{
#' # Add modelling section with multiple control streams
#' add_modelling_section(
#'   reviewer_guide_in = "reviewer_guide.docx",
#'   control_streams = c("model1.mod", "model2.mod"),
#'   descriptions = list(
#'     "model1.mod" = "Base population PK model",
#'     "model2.mod" = "Final covariate model"
#'   )
#' )
#' 
#' # Add modelling section with single control stream
#' add_modelling_section(
#'   reviewer_guide_in = "reviewer_guide.docx",
#'   control_streams = "final_model.mod",
#'   descriptions = "Final population PK model"
#' )
#' }
add_modelling_section <- function(
  reviewer_guide_in,
  reviewer_guide_out = NULL,
  control_streams,
  section_title = "Modelling",
  descriptions = NULL
) {
  log4r::debug(.le$logger, "Starting add_modelling_section function")
  
  # Set default reviewer_guide_out before validation
  if (is.null(reviewer_guide_out)) {
    dir <- dirname(reviewer_guide_in)
    base_name <- tools::file_path_sans_ext(basename(reviewer_guide_in))
    reviewer_guide_out <- file.path(dir, paste0(base_name, "_modelling.docx"))
    log4r::info(.le$logger, paste0("reviewer_guide_out is null, setting reviewer_guide_out to: ", reviewer_guide_out))
  }
  
  # Validation
  validate_input_args(reviewer_guide_in, reviewer_guide_out)
  
  # Validate control streams exist
  missing_files <- control_streams[!file.exists(control_streams)]
  if (length(missing_files) > 0) {
    log4r::warn(
      .le$logger, 
      paste0("Control stream files not found: ", paste(missing_files, collapse = ", "))
    )
  }
  
  valid_streams <- control_streams[file.exists(control_streams)]
  if (length(valid_streams) == 0) {
    log4r::warn(.le$logger, "No valid control stream files found")
    return(invisible(NULL))
  }
  
  # Validate descriptions parameter
  if (!is.null(descriptions) && is.character(descriptions) && 
      length(descriptions) > 1 && is.null(names(descriptions))) {
    log4r::warn(
      .le$logger, 
      paste0("Multiple descriptions provided without names. Use a named vector with control stream basenames as names: ",
             "c(", paste0('"', basename(valid_streams), '" = "description"', collapse = ", "), ")")
    )
  }
  
  # Process control streams with warnings for failures
  modelling_table <- create_modelling_flextable(valid_streams, descriptions)
  
  # Update document
  modelling_data <- update_reviewer_guide_with_modelling(reviewer_guide_in, reviewer_guide_out, modelling_table, section_title)
  
  log4r::debug(.le$logger, "Exiting add_modelling_section function")
  
  invisible(modelling_data)
}


#' Create a formatted flextable from NONMEM control streams
#'
#' @description Processes a list of control streams through get_mod_io_paths and creates a formatted flextable.
#'
#' @param control_streams A character vector of file paths to NONMEM control stream files.
#' @param descriptions Either a named list, a single string, or NULL for descriptions.
#'
#' @return A formatted flextable object, or NULL if no valid data found.
#' @keywords internal
create_modelling_flextable <- function(control_streams, descriptions = NULL) {
  log4r::debug(.le$logger, "Processing control streams for modelling table")
  
  modelling_data <- purrr::map_dfr(control_streams, function(ctrl_file) {
    tryCatch({
      io_paths <- get_mod_io_paths(ctrl_file)
      
      # Handle descriptions - can be NULL, single string, or named list
      description_text <- ""
      if (!is.null(descriptions)) {
        if (is.character(descriptions) && length(descriptions) == 1 && is.null(names(descriptions))) {
          # Single string description
          description_text <- descriptions
        } else if (is.list(descriptions) || (!is.null(names(descriptions)))) {
          # Named list or named vector
          description_text <- descriptions[[basename(ctrl_file)]] %||% ""
        }
      }
      
      data.frame(
        Program = basename(ctrl_file),
        Input = ifelse(length(io_paths$input) > 0 && !is.na(io_paths$input), 
                       basename(io_paths$input), 
                       ""),
        Output = ifelse(length(io_paths$output) > 0, 
                        paste(io_paths$output, collapse = "\n"), 
                        ""),
        Description = description_text,
        stringsAsFactors = FALSE
      )
    }, error = function(e) {
      log4r::warn(
        .le$logger, 
        paste0("Failed to process control stream: ", ctrl_file, ". Error: ", e$message)
      )
      # Return empty row to maintain structure
      data.frame(
        Program = basename(ctrl_file),
        Input = "",
        Output = "",
        Description = "",
        stringsAsFactors = FALSE
      )
    })
  })
  
  # Remove completely empty rows (where all processing failed)
  modelling_data <- modelling_data[!(modelling_data$Program == "" & 
                                   modelling_data$Input == "" & 
                                   modelling_data$Output == ""), ]
  
  if (nrow(modelling_data) == 0) {
    log4r::warn(.le$logger, "No valid modelling data found from control streams")
    return(NULL)
  }
  
  log4r::info(.le$logger, paste0("Successfully processed ", nrow(modelling_data), " control streams"))
  
  # Create and format flextable
  ft <- flextable::flextable(modelling_data) |>
    format_flextable(table1_format = FALSE) |>
    fit_flextable_to_page(page_width = 9.73)
  
  return(ft)
}


#' Update reviewer guide document with modelling section
#'
#' @description Adds the modelling flextable to the end of an existing reviewer guide document.
#'
#' @param docx_in The file path to the input `.docx` file.
#' @param docx_out The file path to the output `.docx` file.
#' @param modelling_table A formatted flextable object.
#' @param section_title The title for the modelling section.
#'
#' @return Invisibly returns the modelling data frame.
#' @keywords internal
update_reviewer_guide_with_modelling <- function(docx_in, docx_out, modelling_table, section_title) {
  if (is.null(modelling_table)) {
    log4r::warn(.le$logger, "No modelling table to add to reviewer guide")
    return(invisible(NULL))
  }
  
  # Read the existing document
  doc <- officer::read_docx(docx_in)
  
  # Add the modelling section at the end
  doc <- officer::body_add_par(doc, section_title, style = "heading 2")
  doc <- officer::body_add_par(doc, "", style = "Normal")
  doc <- flextable::body_add_flextable(doc, value = modelling_table)
  doc <- officer::body_end_section_landscape(doc)
  
  # Save the updated document
  print(doc, target = docx_out)
  
  log4r::info(.le$logger, paste0("Modelling section added to reviewer guide: ", docx_out))
  
  # Extract the data from the flextable for return value
  modelling_data <- modelling_table$body$dataset
  invisible(modelling_data)
}
