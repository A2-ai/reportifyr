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
#'     \item `NULL` (default) — auto-detect via `this.path` + git lookup.
#'     \item A character scalar — free-form text written as
#'       `source_meta$text`.
#'     \item A named list — written verbatim, e.g., the structured
#'       output of [shiny_source()].
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
#' @export
#'
#' @examples \dontrun{
#' ctx <- rpfy_context(
#'   origin = shiny_source("myapp"),
#'   addl_metadata = list(analyst = "jake", study = "PK-001")
#' )
#'
#' print(ctx)
#' validate(ctx)
#'
#' ggsave_with_metadata("plot.png", context = ctx, meta_type = "efficacy")
#' }
rpfy_context <- function(
  origin = NULL,
  addl_metadata = NULL
) {
  log4r::debug(.le$logger, "Building rpfy_context")

  project_root <- find_project_root()

  addl_metadata <- validate_addl_metadata(addl_metadata)

  source_meta <- if (is.null(origin)) {
    detect_script_source_meta(project_root)
  } else if (is.character(origin)) {
    if (length(origin) != 1L || !nzchar(origin)) {
      stop(
        "`origin` must be a non-empty character scalar.",
        call. = FALSE
      )
    }
    list(text = origin)
  } else if (is.list(origin)) {
    origin
  } else {
    stop(
      "`origin` must be NULL, a string, or a list (e.g., shiny_source()).",
      call. = FALSE
    )
  }

  system_meta <- list(
    platform = R.version$platform,
    software = list(
      version = as.character(R.version$version.string),
      packages_used = get_packages()
    )
  )

  author <- get_git_config_author()

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
  sm <- x$source_meta
  origin_str <- if (isTRUE(identical(sm$type, "shiny"))) {
    sprintf("shiny | %s v%s", sm$app_name %||% "?", sm$app_version %||% "?")
  } else if (!is.null(sm$text)) {
    sprintf("text | %s", sm$text)
  } else if (!is.null(sm$path)) {
    sprintf("script | %s", sm$path)
  } else {
    "unknown"
  }

  addl_str <- if (length(x$addl_metadata)) {
    paste(names(x$addl_metadata), collapse = ", ")
  } else {
    "(none)"
  }

  sprintf(
    "<rpfy_context> origin=%s addl=[%s]",
    origin_str,
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
  sm <- x$source_meta

  origin_line <- if (isTRUE(identical(sm$type, "shiny"))) {
    sprintf("shiny | %s v%s", sm$app_name %||% "?", sm$app_version %||% "?")
  } else if (!is.null(sm$text)) {
    sprintf("text | %s", sm$text)
  } else if (!is.null(sm$path)) {
    sprintf("script | %s", sm$path)
  } else {
    "(unresolved)"
  }

  addl_line <- if (length(x$addl_metadata)) {
    paste(names(x$addl_metadata), collapse = ", ")
  } else {
    "(none)"
  }

  cat("<rpfy_context>\n")
  cat(sprintf("  origin:   %s\n", origin_line))
  cat(sprintf("  author:   %s\n", x$author %||% "(unknown)"))
  cat(sprintf("  platform: %s\n", x$system_meta$platform %||% "(unknown)"))
  cat(sprintf("  addl:     %s\n", addl_line))
  invisible(x)
}

#' Validate a reportifyr context
#'
#' @description Generic for validating structured objects. Reportifyr
#'   ships a method for `rpfy_context` that checks the context is
#'   well-formed before artifacts are written. Intended for use at the
#'   top of a script before the artifact loop.
#'
#' @param x Object to validate.
#' @param ... Additional arguments passed to methods.
#'
#' @return The object invisibly. Emits messages describing each check.
#'
#' @export
validate <- function(x, ...) {
  UseMethod("validate")
}

#' @rdname validate
#' @export
validate.rpfy_context <- function(x, ...) {
  checks <- list()

  checks$project_root <- !is.null(x$project_root) &&
    dir.exists(x$project_root)

  checks$source_meta <- length(x$source_meta) > 0L

  checks$addl_metadata <- is.null(x$addl_metadata) || (
    is.list(x$addl_metadata) &&
      !is.null(names(x$addl_metadata)) &&
      all(nzchar(names(x$addl_metadata))) &&
      all(vapply(
        x$addl_metadata,
        function(v) {
          (is.character(v) || is.numeric(v) || is.logical(v)) &&
            length(v) == 1L &&
            !is.na(v)
        },
        logical(1)
      ))
  )

  labels <- c(
    project_root  = "project root exists",
    source_meta   = "source_meta is non-empty",
    addl_metadata = "addl_metadata values are scalar"
  )

  for (nm in names(checks)) {
    mark <- if (isTRUE(checks[[nm]])) "PASS" else "FAIL"
    message(sprintf("[%s] %s", mark, labels[[nm]]))
  }

  invisible(x)
}

validate_context <- function(context) {
  if (is.null(context)) {
    return(rpfy_context())
  }

  if (!inherits(context, "rpfy_context")) {
    stop(
      "`context` must be NULL or inherit from class \"rpfy_context\".",
      call. = FALSE
    )
  }

  context
}

`%||%` <- function(a, b) if (is.null(a)) b else a
