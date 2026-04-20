#' Internal generics dispatching on `rpfy_source_meta` variants.
#'
#' @keywords internal
#' @noRd
format_source <- function(x, ...) UseMethod("format_source")

#' @keywords internal
#' @noRd
format_source.default <- function(x, ...) "(unresolved)"

#' @keywords internal
#' @noRd
to_list <- function(x, ...) UseMethod("to_list")

#' @keywords internal
#' @noRd
to_list.default <- function(x, ...) {
  list(
    type            = "unresolved",
    creation_author = NA_character_,
    latest_author   = NA_character_,
    path            = NA_character_,
    creation_time   = NA_character_,
    latest_time     = NA_character_
  )
}


#' Build a structured `source` value for an artifact produced from a Shiny app
#'
#' @description Returns a classed list suitable for the `origin`
#'   argument of [rpfy_context()]. The `type` discriminator is not
#'   stored on the list; it is emitted at serialization time so the
#'   class is the single source of truth.
#'
#' @param app_name Character scalar. Name of the installed R package that
#'   is the Shiny app.
#' @param app_version Optional character scalar version. When `NULL`
#'   (default) the version is resolved via `utils::packageVersion()`,
#'   which requires the app to be installed as a package.
#'
#' @return A named list with `app_name` and `app_version` elements,
#'   classed as `c("shiny_source", "rpfy_source_meta")`.
#'
#' @export
#'
#' @examples \dontrun{
#' ctx <- rpfy_context(origin = shiny_source("myapp"))
#' ggsave_with_metadata(
#'   filename = "OUTPUTS/figures/plot.png",
#'   context = ctx
#' )
#' }
shiny_source <- function(app_name, app_version = NULL) {
  if (!is.character(app_name) || length(app_name) != 1L || !nzchar(app_name)) {
    stop("`app_name` must be a non-empty character scalar.", call. = FALSE)
  }

  if (is.null(app_version)) {
    app_version <- tryCatch(
      as.character(utils::packageVersion(app_name)),
      error = function(e) {
        stop(
          sprintf(
            paste0(
              "Could not resolve version for package '%s'. ",
              "`shiny_source()` requires the app to be installed as a ",
              "package, or pass `app_version` explicitly. ",
              "Underlying error: %s"
            ),
            app_name,
            conditionMessage(e)
          ),
          call. = FALSE
        )
      }
    )
  }

  x <- new_shiny_source(app_name = app_name, app_version = app_version)
  validate_shiny_source(x)
  x
}

#' Low-level constructor for `shiny_source`
#'
#' @param app_name Character scalar.
#' @param app_version Character scalar.
#'
#' @return A `shiny_source` / `rpfy_source_meta` object. Unvalidated.
#'
#' @keywords internal
#' @noRd
new_shiny_source <- function(app_name, app_version) {
  structure(
    list(
      app_name    = app_name,
      app_version = app_version
    ),
    class = c("shiny_source", "rpfy_source_meta")
  )
}

#' Validate a `shiny_source` object
#'
#' @description Errors if `x` is not a `shiny_source` or if
#'   `app_name` / `app_version` are not non-empty character scalars.
#'
#' @param x A `shiny_source` object.
#'
#' @return `x` invisibly.
#'
#' @export
validate_shiny_source <- function(x) {
  if (!inherits(x, "shiny_source")) {
    stop("`x` must inherit from class \"shiny_source\".", call. = FALSE)
  }
  for (nm in c("app_name", "app_version")) {
    v <- x[[nm]]
    if (!is.character(v) || length(v) != 1L || !nzchar(v)) {
      stop(
        sprintf("`%s` must be a non-empty character scalar.", nm),
        call. = FALSE
      )
    }
  }
  invisible(x)
}

#' @keywords internal
#' @noRd
format_source.shiny_source <- function(x, ...) {
  sprintf("shiny | %s v%s", x$app_name, x$app_version)
}

#' @keywords internal
#' @noRd
to_list.shiny_source <- function(x, ...) {
  c(list(type = "shiny"), unclass(x))
}


#' Build a structured `source` value for an artifact produced from a script
#'
#' @description Returns a classed list suitable for the `origin`
#'   argument of [rpfy_context()]. Typically produced internally by
#'   [rpfy_context()] via auto-detection; exposed for callers that want
#'   to stamp a known script identity. The `type` discriminator is not
#'   stored on the list; it is emitted at serialization time so the
#'   class is the single source of truth.
#'
#' @param path Character scalar. Path to the source script, relative to
#'   the project root.
#' @param creation_author Character scalar. Git author of the first commit
#'   touching the script.
#' @param latest_author Character scalar. Git author of the most recent
#'   commit touching the script.
#' @param creation_time Character scalar. Timestamp of the first commit.
#' @param latest_time Character scalar. Timestamp of the most recent commit.
#'
#' @return A named list with `creation_author`, `latest_author`, `path`,
#'   `creation_time`, and `latest_time` elements, classed as
#'   `c("script_source", "rpfy_source_meta")`.
#'
#' @export
#'
#' @examples \dontrun{
#' src <- script_source(
#'   path            = "scripts/01-pk.R",
#'   creation_author = "jake",
#'   latest_author   = "jake",
#'   creation_time   = "2026-01-01 00:00:00",
#'   latest_time     = "2026-04-20 12:00:00"
#' )
#' ctx <- rpfy_context(origin = src)
#' }
script_source <- function(
  path,
  creation_author,
  latest_author,
  creation_time,
  latest_time
) {
  x <- new_script_source(
    path            = path,
    creation_author = creation_author,
    latest_author   = latest_author,
    creation_time   = creation_time,
    latest_time     = latest_time
  )
  validate_script_source(x)
  x
}

#' Low-level constructor for `script_source`
#'
#' @param path,creation_author,latest_author,creation_time,latest_time
#'   Character scalars matching the fields of `script_source`.
#'
#' @return A `script_source` / `rpfy_source_meta` object. Unvalidated.
#'
#' @keywords internal
#' @noRd
new_script_source <- function(
  path,
  creation_author,
  latest_author,
  creation_time,
  latest_time
) {
  structure(
    list(
      creation_author = creation_author,
      latest_author   = latest_author,
      path            = path,
      creation_time   = creation_time,
      latest_time     = latest_time
    ),
    class = c("script_source", "rpfy_source_meta")
  )
}

#' Validate a `script_source` object
#'
#' @description Errors if `x` is not a `script_source` or if any of
#'   `path`, `creation_author`, `latest_author`, `creation_time`,
#'   `latest_time` are not non-empty character scalars.
#'
#' @param x A `script_source` object.
#'
#' @return `x` invisibly.
#'
#' @export
validate_script_source <- function(x) {
  if (!inherits(x, "script_source")) {
    stop("`x` must inherit from class \"script_source\".", call. = FALSE)
  }
  for (nm in c(
    "path",
    "creation_author",
    "latest_author",
    "creation_time",
    "latest_time"
  )) {
    v <- x[[nm]]
    if (!is.character(v) || length(v) != 1L || !nzchar(v)) {
      stop(
        sprintf("`%s` must be a non-empty character scalar.", nm),
        call. = FALSE
      )
    }
  }
  invisible(x)
}

#' @keywords internal
#' @noRd
format_source.script_source <- function(x, ...) {
  sprintf("script | %s", x$path)
}

#' @keywords internal
#' @noRd
to_list.script_source <- function(x, ...) {
  c(list(type = "script"), unclass(x))
}


#' Build the script-case `source_meta` via this.path + git lookup
#'
#' @param project_root Character. Project root used to relativize the
#'   detected script path.
#'
#' @return A `script_source` object on success, or `list()` if detection
#'   failed.
#'
#' @keywords internal
#' @noRd
detect_script_source_meta <- function(project_root) {
  if (is.null(project_root)) {
    return(list())
  }

  source_path <- get_source_path()

  source_path_relative <- fs::path_rel(source_path, project_root)
  log4r::info(
    .le$logger,
    paste0("Source file path (relative): ", source_path_relative)
  )

  git_info <- get_git_info(source_path)
  log4r::info(
    .le$logger,
    paste0("Fetched git info for source file: ", git_info)
  )

  script_source(
    path            = as.character(source_path_relative),
    creation_author = git_info$creation_author,
    latest_author   = git_info$latest_author,
    creation_time   = git_info$creation_time,
    latest_time     = git_info$latest_time
  )
}
