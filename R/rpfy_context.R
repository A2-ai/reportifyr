#' Build a reportifyr metadata context
#'
#' @description Captures session-level metadata once so that it can be
#'   reused across many `*_with_metadata()` wrapper calls without
#'   recomputing on every artifact. Construct the context at the top
#'   of a script or Shiny app and pass it via the `context` argument
#'   to [ggsave_with_metadata()], [save_rds_with_metadata()],
#'   [write_csv_with_metadata()], or [write_object_metadata()].
#'
#' @param origin Controls what is recorded in `source_meta` in the
#'   artifact JSON. One of:
#'   \itemize{
#'     \item `NULL` (default) — auto-detect via `this.path` + git lookup,
#'       producing a `script_source` (or an empty list if detection fails).
#'     \item An `rpfy_source_meta` object — the output of [shiny_source()]
#'       or [script_source()].
#'   }
#' @param addl_metadata Optional named list of caller-supplied
#'   provenance tags, written under the `addl_meta` key in the JSON.
#'   Values must be scalar character, numeric, or logical. Purely
#'   informational; never rendered into the report footer.
#'
#' @return An object of class `rpfy_context` — a list with fields
#'   `system_meta`, `source_meta`, `addl_metadata`, `author`,
#'   `project_root`.
#'
#' @importFrom rlang `%||%`
#'
#' @export
#'
#' @examples \dontrun{
#' ctx <- rpfy_context(
#'   origin = shiny_source("myapp"),
#'   addl_metadata = list(analyst = "jake", study = "PK-001")
#' )
#'
#' print(ctx)
#' validate_rpfy_context(ctx)
#'
#' ggsave_with_metadata("plot.png", context = ctx, meta_type = "efficacy")
#' }
rpfy_context <- function(
  origin = NULL,
  addl_metadata = NULL
) {
  log4r::debug(.le$logger, "Building rpfy_context")

  if (!is.null(origin) && !inherits(origin, "rpfy_source_meta")) {
    stop(
      "`origin` must be NULL or an `rpfy_source_meta` object ",
      "(built via shiny_source() or script_source()). Got: ",
      paste(class(origin), collapse = "/"),
      call. = FALSE
    )
  }

  project_root <- find_project_root()

  addl_metadata <- validate_addl_metadata(addl_metadata)

  source_meta <- if (is.null(origin)) {
    detect_script_source_meta(project_root)
  } else {
    origin
  }

  system_meta <- list(
    platform = R.version$platform,
    software = list(
      version = as.character(R.version$version.string),
      packages_used = get_packages()
    )
  )

  author <- get_git_config_author()

  context <- new_rpfy_context(
    system_meta   = system_meta,
    source_meta   = source_meta,
    addl_metadata = addl_metadata,
    author        = author,
    project_root  = project_root
  )

  validate_rpfy_context(context)

  context
}

#' Low-level constructor for `rpfy_context`
#'
#' Creates an `rpfy_context` object from already-prepared components.
#' Performs no validation; callers are expected to pass correct values
#' and run [validate_rpfy_context()] afterward.
#'
#' @param system_meta Named list with `platform` and `software`.
#' @param source_meta An `rpfy_source_meta` object or empty `list()`.
#' @param addl_metadata `NULL` or a named scalar-valued list.
#' @param author Character scalar. Git config author.
#' @param project_root Character scalar. Absolute path to project root.
#'
#' @return An object of class `rpfy_context`.
#'
#' @keywords internal
#' @noRd
new_rpfy_context <- function(
  system_meta,
  source_meta,
  addl_metadata,
  author,
  project_root
) {
  structure(
    list(
      system_meta   = system_meta,
      source_meta   = source_meta,
      addl_metadata = addl_metadata,
      author        = author,
      project_root  = project_root
    ),
    class = "rpfy_context"
  )
}

#' Format a one-line summary of a reportifyr context
#'
#' @param x An `rpfy_context` object.
#' @param ... Unused.
#'
#' @return Character scalar suitable for logging.
#'
#' @export
format.rpfy_context <- function(x, ...) {
  addl_str <- if (length(x$addl_metadata)) {
    paste(names(x$addl_metadata), collapse = ", ")
  } else {
    "(none)"
  }

  sprintf(
    "<rpfy_context> origin=%s addl=[%s]",
    format_source(x$source_meta),
    addl_str
  )
}

#' Print a reportifyr context
#'
#' @param x An `rpfy_context` object.
#' @param ... Unused.
#'
#' @return The context invisibly.
#'
#' @export
print.rpfy_context <- function(x, ...) {
  addl_line <- if (length(x$addl_metadata)) {
    paste(names(x$addl_metadata), collapse = ", ")
  } else {
    "(none)"
  }

  cat("<rpfy_context>\n")
  cat(sprintf("  origin:   %s\n", format_source(x$source_meta)))
  cat(sprintf("  author:   %s\n", x$author))
  cat(sprintf("  platform: %s\n", x$system_meta$platform))
  cat(sprintf("  addl:     %s\n", addl_line))
  invisible(x)
}

#' Validate a reportifyr context
#'
#' @description Checks that an `rpfy_context` has the expected fields
#'   and that each field holds a valid value. Errors on any problem.
#'
#' @param context An `rpfy_context` object.
#'
#' @return The context invisibly.
#'
#' @export
validate_rpfy_context <- function(context) {
  if (!inherits(context, "rpfy_context")) {
    stop(
      "`context` must inherit from class \"rpfy_context\".",
      call. = FALSE
    )
  }

  required <- c(
    "system_meta",
    "source_meta",
    "addl_metadata",
    "author",
    "project_root"
  )
  missing_fields <- setdiff(required, names(context))
  if (length(missing_fields)) {
    stop(
      sprintf(
        "`context` is missing required field(s): %s",
        paste(missing_fields, collapse = ", ")
      ),
      call. = FALSE
    )
  }

  if (!is.null(context$project_root)) {
    if (
      !is.character(context$project_root) ||
        length(context$project_root) != 1L ||
        !nzchar(context$project_root) ||
        !dir.exists(context$project_root)
    ) {
      stop(
        "`context$project_root` must be NULL or a path to an existing directory.",
        call. = FALSE
      )
    }
  }

  if (
    !(
      inherits(context$source_meta, "rpfy_source_meta") ||
        identical(context$source_meta, list())
    )
  ) {
    stop(
      "`context$source_meta` must be an `rpfy_source_meta` object or `list()`.",
      call. = FALSE
    )
  }

  if (
    !is.character(context$author) ||
      length(context$author) != 1L ||
      !nzchar(context$author)
  ) {
    stop(
      "`context$author` must be a non-empty character scalar.",
      call. = FALSE
    )
  }

  if (
    !is.list(context$system_meta) ||
      !all(c("platform", "software") %in% names(context$system_meta))
  ) {
    stop(
      "`context$system_meta` must be a list with `platform` and `software`.",
      call. = FALSE
    )
  }

  validate_addl_metadata(context$addl_metadata)

  invisible(context)
}

#' Coerce a caller-supplied `context` argument
#'
#' Used by the `*_with_metadata()` wrappers. If `context` is `NULL`,
#' constructs a default one via [rpfy_context()]. Otherwise runs
#' [validate_rpfy_context()] and returns the object. Errors for any
#' other input type.
#'
#' @param context `NULL` or an `rpfy_context`.
#'
#' @return An `rpfy_context`.
#'
#' @keywords internal
#' @noRd
resolve_context <- function(context) {
  if (is.null(context)) {
    return(rpfy_context())
  }
  validate_rpfy_context(context)
  context
}

#' Validate an addl_metadata argument
#'
#' Accepts `NULL` or a named list whose values are scalar (length-1)
#' character, numeric, or logical.
#'
#' @param x The value passed as `addl_metadata` to a wrapper.
#'
#' @return `NULL` or the validated named list.
#'
#' @keywords internal
#' @noRd
validate_addl_metadata <- function(x) {
  if (is.null(x)) {
    return(NULL)
  }
  if (!is.list(x)) {
    stop("`addl_metadata` must be NULL or a list.", call. = FALSE)
  }
  if (length(x) == 0L) {
    return(NULL)
  }
  nms <- names(x)
  if (is.null(nms) || any(!nzchar(nms)) || anyDuplicated(nms)) {
    stop(
      "`addl_metadata` must be a named list with unique, non-empty names.",
      call. = FALSE
    )
  }
  bad <- vapply(
    x,
    function(v) {
      !(is.character(v) || is.numeric(v) || is.logical(v)) ||
        length(v) != 1L ||
        is.na(v)
    },
    logical(1)
  )
  if (any(bad)) {
    stop(
      sprintf(
        paste0(
          "`addl_metadata` values must be scalar character/numeric/",
          "logical. Offending key(s): %s"
        ),
        paste(nms[bad], collapse = ", ")
      ),
      call. = FALSE
    )
  }
  x
}
