#' Generics over `rpfy_source_meta` variants
#'
#' @description Two generics dispatch on the class of a source object:
#'   \itemize{
#'     \item [format_source()] — one-line human summary for print/format
#'       of [rpfy_context()].
#'     \item [to_list()] — plain named list for JSON serialization, with
#'       the `type` discriminator Python uses to render the footnote
#'       Source line.
#'   }
#'
#'   Methods are provided for `shiny_source`, `script_source`, and
#'   `default` (the "unresolved" case where detection failed and
#'   `source_meta` is a plain empty list).
#'
#' @name source_meta_generics
NULL

#' @rdname source_meta_generics
#'
#' @param x An object to summarize.
#' @param ... Unused.
#'
#' @return Character scalar.
#'
#' @export
format_source <- function(x, ...) UseMethod("format_source")

#' @rdname source_meta_generics
#' @export
format_source.default <- function(x, ...) "(unresolved)"

#' @rdname source_meta_generics
#'
#' @return A plain named list with a `type` field, ready for
#'   `jsonlite::toJSON()`.
#'
#' @export
to_list <- function(x, ...) UseMethod("to_list")

#' @rdname source_meta_generics
#' @export
to_list.default <- function(x, ...) list(type = "unresolved")


#' Build a structured `source` value for an artifact produced from a Shiny app
#'
#' @description Returns a classed list suitable for the `origin`
#'   argument of [rpfy_context()]. The `type` discriminator is not
#'   stored on the list; it is emitted by [to_list.shiny_source()] at
#'   serialization time so the class is the single source of truth.
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

  if (
    !is.character(app_version) ||
      length(app_version) != 1L ||
      !nzchar(app_version)
  ) {
    stop("`app_version` must be a non-empty character scalar.", call. = FALSE)
  }

  structure(
    list(
      app_name = app_name,
      app_version = app_version
    ),
    class = c("shiny_source", "rpfy_source_meta")
  )
}

#' @export
format_source.shiny_source <- function(x, ...) {
  sprintf("shiny | %s v%s", x$app_name, x$app_version)
}

#' @export
to_list.shiny_source <- function(x, ...) {
  c(list(type = "shiny"), unclass(x))
}


#' Build a structured `source` value for an artifact produced from a script
#'
#' @description Returns a classed list suitable for the `origin`
#'   argument of [rpfy_context()]. Typically produced internally by
#'   [rpfy_context()] via auto-detection; exposed for callers that want
#'   to stamp a known script identity. The `type` discriminator is not
#'   stored on the list; it is emitted by [to_list.script_source()] at
#'   serialization time so the class is the single source of truth.
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
  for (nm in c(
    "path",
    "creation_author",
    "latest_author",
    "creation_time",
    "latest_time"
  )) {
    v <- get(nm)
    if (!is.character(v) || length(v) != 1L || !nzchar(v)) {
      stop(
        sprintf("`%s` must be a non-empty character scalar.", nm),
        call. = FALSE
      )
    }
  }

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

#' @export
format_source.script_source <- function(x, ...) {
  sprintf("script | %s", x$path)
}

#' @export
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
  source_path <- get_source_path()
  if (source_path == "SOURCE_PATH_NOT_DETECTED" || is.null(project_root)) {
    return(list())
  }

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
